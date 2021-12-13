FROM gremid/idrovora:0.0.2020082920
COPY xproc/xpl /xpl

ENTRYPOINT ["/usr/local/bin/clojure", "-J-Dlog4j2.formatMsgNoLookups=true", "-m", "idrovora.cli"]
