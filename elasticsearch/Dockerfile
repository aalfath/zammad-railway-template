# Elasticsearch for the Zammad Railway template (Zammad's search index).
# Same build as docker.elastic.co/elasticsearch/elasticsearch:9.5.6 (identical digest on Docker Hub).
FROM elastic/elasticsearch:9.5.6@sha256:79b4f1de4c15e6eca824723086a51e5934406d614d410cc11be77748cafac537

# Railway volumes are owned by root. The start script runs as root only to fix the
# volume's ownership, then runs Elasticsearch as its normal user (uid 1000).
USER 0
COPY --chmod=0755 start.sh /usr/local/bin/railway-start.sh
ENTRYPOINT ["/bin/tini", "-s", "--", "/usr/local/bin/railway-start.sh"]
