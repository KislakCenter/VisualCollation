(ns vceditor.xproc
  (:require
   [babashka.fs :as fs]
   [chime.core :as chime]
   [clojure.java.io :as io]
   [clojure.stacktrace :refer [print-cause-trace]]
   [clojure.string :as str]
   [muuntaja.core :as m]
   [reitit.coercion.malli :as rcm]
   [reitit.core :as r]
   [reitit.ring :as ring]
   [reitit.ring.coercion :as coercion]
   [reitit.ring.middleware.exception :as exception]
   [reitit.ring.middleware.muuntaja :as muuntaja]
   [ring.adapter.jetty :as jetty]
   [ring.middleware.defaults :as defaults]
   [ring.util.io :as ring-io]
   [ring.util.request :as req]
   [ring.util.response :as resp]
   [taoensso.telemere :as tel]
   [tick.core :as t])
  (:import
   (com.xmlcalabash XmlCalabash XmlCalabashBuilder)
   (java.io File)
   (java.lang AutoCloseable)
   (java.net URL)
   (java.nio.charset Charset)
   (java.time Duration)
   (java.util UUID)
   (java.util.zip ZipEntry ZipOutputStream)
   (net.sf.saxon.s9api QName XdmAtomicValue)
   (org.eclipse.jetty.server Server)))

(defn getenv
  [k dv]
  (or (some-> (System/getenv (str "VCEDITOR_XPROC_" k)) (str/trim) (not-empty))
      dv))

(def http-port
  (parse-long (getenv "HTTP_PORT" "2000")))

(def http-context-path
  (getenv "HTTP_CONTEXT_PATH" "/xproc"))

(def http-doc-root
  (doto (io/file (getenv "HTTP_DOC_ROOT" "htdocs")) (.mkdirs)))

(def http-job-max-age
  (Duration/parse (getenv "HTTP_JOB_MAX_AGE" "PT168H")))

(def xpl-dir
  (io/file (getenv "XPL_DIR" "xpl")))

(defn wrap-job-coordinates
  [handler]
  (fn
    [{{:keys [pipeline job path]} :path-params :as request} respond raise]
    (let [coords  {::pipeline pipeline ::job job ::path path}
          request (merge request coords)]
      (tel/with-ctx+ {::job coords}
        (handler
         request
         (fn [response]
           (let [{:keys [::pipeline ::job]} (merge request response)]
             (respond
              (cond-> response
                pipeline (resp/header "X-Idrovora-Pipeline" pipeline)
                job      (resp/header "X-Idrovora-Job" job)))))
         raise)))))

(defn wrap-resource
  [handler]
  (fn
    [{::keys [pipeline job path] :as request} respond raise]
    (let [f (apply io/file (remove nil? [http-doc-root pipeline job path]))]
      (if (fs/starts-with? f http-doc-root)
        (tel/with-ctx+ {::resource f}
          (handler (assoc request ::file f) respond raise))
        (respond (resp/not-found {}))))))

(defn absolute-url
  [request url]
  (str (URL. (URL. (req/request-url request)) url)))

(defn self-url
  [request]
  (req/request-url request))

(defn index-url
  [{:keys [::r/router] :as request}]
  (->>
   (r/match-by-name router ::index-request)
   (r/match->path)
   (absolute-url request)))

(defn pipeline-url
  [{:keys [::r/router] :as request} pipeline]
  (->>
   {:pipeline pipeline}
   (r/match-by-name router ::job-request)
   (r/match->path)
   (absolute-url request)))

(defn job-url
  [{::r/keys [router] :as request} pipeline job]
  (->>
   {:pipeline pipeline :job job :path ""}
   (r/match-by-name router ::resource-request)
   (r/match->path)
   (absolute-url request)))

(defn link
  ([href] (link href :self))
  ([href rel] {rel {:href href}}))

(defn wrap-links
  [handler]
  (fn [{::keys [pipeline job] :as request} respond raise]
    (handler
     request
     (fn [{:keys [body status]      p   ::pipeline j ::job
           :or   {p pipeline j job} :as resp}]
       (respond
        (if-not (and (map? body) (< status 400))
          resp
          (->>
           (merge (link (self-url request))
                  (link (index-url request) :index)
                  (when p (link (pipeline-url request p) :pipeline))
                  (when j (link (job-url request p j) :job)))
           (assoc-in resp [:body :_links])))))
     raise)))

(defn pipeline-names
  []
  (into []
        (comp (filter fs/regular-file?)
              (filter #(= "xpl" (fs/extension %)))
              (map (comp fs/strip-ext fs/file-name)))
        (fs/list-dir xpl-dir)))

(defn handle-index-request
  [request respond _]
  (->>
   (for [p (pipeline-names)] {:id p :_links (link (pipeline-url request p))})
   (assoc-in {} [:_embedded :pipelines])
   (resp/response)
   (respond)))

(defn xpl-file
  [pipeline]
  (let [f (fs/file xpl-dir (str pipeline ".xpl"))]
    (when (fs/regular-file? f) f)))

(defn wrap-xpl
  [handler]
  (fn [{:keys [::pipeline] :as request} respond raise]
    (if-let [xpl (xpl-file pipeline)]
      (tel/with-ctx+ {::xpl xpl}
        (handler (assoc request ::xpl xpl) respond raise))
      (respond (resp/not-found {:pipeline pipeline})))))

(defn resource
  [f]
  {:id       (fs/file-name f)
   :modified (str (. (fs/last-modified-time f) (toMillis)))})

(defn job-dirs
  [pipeline]
  (filter fs/directory? (fs/list-dir http-doc-root pipeline)))

(defn handle-pipeline-request
  [{:keys [::pipeline] :as request} respond _]
  (let [jobs (->> (map resource (job-dirs pipeline))
                  (sort-by :modified #(compare %2 %1)))]
    (->>
     (for [{:keys [id] :as job} (take 100 jobs)]
       (assoc job :_links (link (absolute-url request (str id "/")))))
     (assoc-in {:id pipeline :total_jobs (count jobs)} [:_embedded :jobs])
     (resp/response)
     (respond))))

(defn file-param?
  [[_ {:keys [tempfile]}]]
  tempfile)

(defn zip-file-param?
  [[_ {:keys [content-type filename] :or {filename ""}} :as param]]
  (and (file-param? param)
       (or (= "application/zip" content-type)
           (-> filename str/lower-case (str/ends-with? ".zip")))))

(defn string-param?
  [[_ v]]
  (string? v))

(defn param-key->filename
  [k]
  (let [filename (name k)
        has-ext? (str/last-index-of filename ".")]
    (if has-ext? filename (str filename ".xml"))))

(defn unzip-param
  [source-dir [_k {:keys [tempfile]}]]
  (fs/unzip tempfile source-dir))

(defn copy-param
  [source-dir [k {:keys [tempfile]}]]
  (io/copy tempfile (fs/file source-dir (param-key->filename k))))

(defn spit-param
  [source-dir [k v]]
  (spit (fs/file source-dir (param-key->filename k)) v :encoding "UTF-8"))

(defn wrap-job
  [handler]
  (fn
    [{:keys [::pipeline :params] :as request} respond raise]
    (tel/with-ctx+ {::pipeline pipeline}
      (try
        (let [job             (str (UUID/randomUUID))
              job-dir         (doto (fs/file http-doc-root pipeline job) (.mkdirs))
              file-params     (filter file-param? params)
              zip-file-params (filter zip-file-param? file-params)
              file-params     (remove zip-file-param? file-params)
              string-params   (filter string-param? params)]
          (doseq [p zip-file-params] (unzip-param job-dir p))
          (doseq [p file-params] (copy-param job-dir p))
          (doseq [p string-params] (spit-param job-dir p))
          (handler
           (assoc request ::job job ::job-dir job-dir)
           #(respond (assoc % ::job job))
           raise))
        (catch Throwable t
          (tel/error! ::job-request t)
          (respond (resp/bad-request {:pipeline pipeline})))))))

(def ^XmlCalabash xml-calabash
  (.. (XmlCalabashBuilder.) (build)))

(defn handle-job-request
  [{::keys [job job-dir pipeline xpl] :as request} respond _raise]
  (tel/with-ctx+ {::job request}
    (tel/event! ::resource :trace)
    (future
      (try
        (let [pipeline    (.. xml-calabash
                              (newXProcParser)
                              (parse (. ^File xpl (toURI)))
                              (getExecutable))
              job-dir-uri (.. (fs/file job-dir) (toURI) (toString))]
          (. pipeline (option (QName. "job-dir") (XdmAtomicValue. job-dir-uri)))
          (. pipeline (run)))
        (->
         (resp/created (job-url request pipeline job) (resource job-dir))
         (respond))
        (catch Throwable t
          (tel/error! ::job-error t)
          (->
           (resp/response {:error (with-out-str (print-cause-trace t))})
           (resp/status 502)
           (respond)))))))

(defn handle-resource-request
  [{^File f ::file :as request} respond _raise]
  (tel/event! ::resource :trace)
  (respond
   (cond
     ;; files are delivered as-is
     (fs/regular-file? f)
     (resp/response f)
     ;; a directory's representation can be negotiated
     (fs/directory? f)
     (cond
       ;; directories can be delivered as ZIP archives, if requested
       (some-> (m/get-response-format-and-charset request)
               :raw-format #{"application/zip"})
       (-> (fn [os]
             (with-open [zip (ZipOutputStream. os (Charset/forName "UTF-8"))]
               (doseq [fc (fs/list-dir f)]
                 (with-open [fis (io/input-stream (fs/file fc))]
                   (. zip (putNextEntry (ZipEntry. (fs/file-name fc))))
                   (io/copy fis zip)
                   (. zip (closeEntry))))))
           (ring-io/piped-input-stream)
           (resp/response)
           (resp/content-type "application/zip"))
       ;; otherwise return directory listing
       :else
       (->>
        (for [c (fs/list-dir f)]
          (let [n (str (fs/file-name c) (if (fs/directory? c) "/" ""))]
            (assoc (resource c) :_links (link (absolute-url request n)))))
        (assoc-in {} [:_embedded :resources])
        (resp/response)))
     ;; fallback
     :else
     (resp/not-found {}))))

(defn handle-job-removal
  [{^File f ::file ::keys [pipeline job path] :as request} respond _]
  (tel/event! ::job-removal :trace)
  (respond
   (if (and pipeline job (empty? path) (fs/directory? f))
     (do (fs/delete-tree f) (resp/redirect (pipeline-url request pipeline)))
     (resp/not-found {}))))

(def handlers
  [""
   {:middleware [wrap-job-coordinates wrap-resource wrap-links]}
   ["/"
    {:name    ::index-request
     :handler handle-index-request}]
   ["/:pipeline/"
    {:name       ::job-request
     :handler    handle-pipeline-request
     :middleware [wrap-xpl]
     :parameters {:path [:map [:pipeline :string]]}
     :post       {:handler    handle-job-request
                  :middleware [wrap-job]}}]
   ["/:pipeline/:job/*path"
    {:name       ::resource-request
     :handler    handle-resource-request
     :parameters {:path [:map [:pipeline :string] [:job :string] [:path :string]]}
     :delete     {:handler handle-job-removal}}]])

(defn log-exceptions
  [handler ^Throwable e request]
  (when-not (some-> e ex-data :type #{::ring/response}) (tel/error! ::ring e))
  (handler e request))

(def exception-middleware
  (exception/create-exception-middleware
   (assoc exception/default-handlers ::exception/wrap log-exceptions)))

(def handler-options
  {:coercion   rcm/coercion
   :muuntaja   m/instance
   :middleware [{:name ::defaults
                 :wrap #(defaults/wrap-defaults
                         % (-> defaults/secure-site-defaults
                               (assoc-in [:proxy] true)
                               (assoc-in [:session] false)
                               (assoc-in [:cookies] false)
                               (assoc-in [:security :ssl-redirect] false)
                               (assoc-in [:security :anti-forgery] false)))}
                muuntaja/format-negotiate-middleware
                muuntaja/format-request-middleware
                muuntaja/format-response-middleware
                exception-middleware
                coercion/coerce-exceptions-middleware
                coercion/coerce-request-middleware
                coercion/coerce-response-middleware]})

(defn cleanup-jobs!
  [& _]
  (doseq [pipeline (filter fs/directory? (fs/list-dir http-doc-root))
          job      (filter fs/directory? (fs/list-dir pipeline))
          :let     [age (- (System/currentTimeMillis)
                           (. (fs/last-modified-time job) (toMillis)))]
          :when    (pos? (compare (Duration/ofMillis age) http-job-max-age))]
    (tel/with-ctx+ {::job job}
      (tel/event! ::cleanup)
      (fs/delete-tree job))))

(defn schedule-job-cleanup
  []
  (-> (t/truncate (t/offset-date-time) :days)
      (t/instant)
      (chime/periodic-seq (t/of-days 1))
      (chime/without-past-times)
      (chime/chime-at cleanup-jobs!
                      {:error-handler #(tel/error! ::cleanup-error %)})))

(defn stop-server!
  [^AutoCloseable schedule ^Server server]
  (.close schedule)
  (.stop server))

(defn start-server!
  [& _]
  (partial
   stop-server!
   (schedule-job-cleanup)
   (jetty/run-jetty
    (ring/ring-handler
     (ring/router [http-context-path handler-options handlers])
     (ring/routes
      (ring/redirect-trailing-slash-handler)
      (ring/create-default-handler)))
    {:port   http-port
     :join?  false
      :async? true})))

(defn -main
  [& _]
  (tel/uncaught->error!)
  (let [stop-server! (start-server!)]
    (. (Runtime/getRuntime) (addShutdownHook (Thread. ^Runnable  stop-server!)))
    @(promise)))
