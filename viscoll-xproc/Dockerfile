FROM clojure:tools-deps

COPY deps.edn /app/deps.edn
WORKDIR /app

# Pull dependencies
RUN clojure -Stree

COPY . /app

ENTRYPOINT ["/usr/local/bin/clojure", "-M", "-m", "vceditor.xproc"]
