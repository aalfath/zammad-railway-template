#!/bin/bash
# Elasticsearch start script for the Zammad Railway template.
set -e
ES_HOME=/usr/share/elasticsearch
DATA_DIR="${ES_DATA_DIR:-/usr/share/elasticsearch/data}"
export PORT="${PORT:-9200}"
export ES_JAVA_OPTS="${ES_JAVA_OPTS:--Xms1g -Xmx1g}"

if [ -z "$ELASTIC_PASSWORD" ]; then
  echo "railway-template: ELASTIC_PASSWORD is empty; refusing to start without a password" >&2
  exit 1
fi

mkdir -p "$DATA_DIR"
rm -rf "$DATA_DIR/lost+found"
if [ "$(id -u)" = "0" ] && [ "$(stat -c %u "$DATA_DIR")" != "1000" ]; then
  echo "railway-template: giving $DATA_DIR to uid 1000"
  chown -R 1000:0 "$DATA_DIR"
fi

# Railway hosts differ in vm.max_map_count, and a container can't raise it.
MMAP=true
MAPS=$(cat /proc/sys/vm/max_map_count 2>/dev/null || echo 0)
if [ "$MAPS" -lt 262144 ]; then MMAP=false; fi
echo "railway-template: Elasticsearch on port $PORT, data in $DATA_DIR, heap '$ES_JAVA_OPTS', vm.max_map_count=$MAPS allow_mmap=$MMAP"

cat > "$ES_HOME/config/elasticsearch.yml" <<YML
cluster.name: "zammad"
node.name: "elasticsearch"
path.data: "$DATA_DIR"
discovery.type: single-node
http.host: "::"
http.port: $PORT
transport.host: 127.0.0.1
node.store.allow_mmap: $MMAP
ingest.geoip.downloader.enabled: false
xpack.ml.enabled: false
xpack.security.enabled: true
xpack.security.enrollment.enabled: false
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
# Anonymous requests may read the cluster health (Railway's health check) and nothing else.
xpack.security.authc.anonymous.username: railway_healthcheck
xpack.security.authc.anonymous.roles: railway_healthcheck
xpack.security.authc.anonymous.authz_exception: false
YML
cat > "$ES_HOME/config/roles.yml" <<YML
railway_healthcheck:
  cluster: [ "cluster:monitor/health" ]
YML
chown 1000:0 "$ES_HOME/config/elasticsearch.yml" "$ES_HOME/config/roles.yml" 2>/dev/null || true

cd "$ES_HOME"
if [ "$(id -u)" = "0" ]; then
  # --skip-chdir keeps the working directory: the entrypoint needs it to add
  # ELASTIC_PASSWORD to the keystore on the first start.
  exec chroot --skip-chdir --userspec=1000:0 / env HOME="$ES_HOME" /usr/local/bin/docker-entrypoint.sh eswrapper
fi
exec /usr/local/bin/docker-entrypoint.sh eswrapper
