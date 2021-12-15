FROM gremid/idrovora:0.0.2020082920
COPY xproc/xpl /xpl

#  Remove the JndiLookup.class class from the log4j-core classpath
WORKDIR /
RUN set -eux; \
    apt-get update; \
    apt-get install --no-install-recommends -y zip; \
    base_files=$(find . -type f -name '*log4j-core*.jar'); \
    for base_file in ${base_files}; do \
        zip -d $base_file org/apache/logging/log4j/core/lookup/JndiLookup.class | grep 'deleting'; \
    done; \
    # apt-get remove zip; \
    rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/local/bin/clojure", "-J-Dlog4j2.formatMsgNoLookups=true", "-m", "idrovora.cli"]