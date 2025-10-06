#!/bin/bash
set -euo pipefail
log(){ echo -e "\n==== $* ===="; }

TOK_FILE=".secrets/influx_admin_token"
WORK_TOKEN="$(cat "$TOK_FILE" 2>/dev/null || true)"
INFLUX_ORG="$(grep -E 'DOCKER_INFLUXDB_INIT_ORG=' docker-compose.yml | sed 's/.*=\s*//; s/"//g')"
INFLUX_BUCKET="$(grep -E 'DOCKER_INFLUXDB_INIT_BUCKET=' docker-compose.yml | sed 's/.*=\s*//; s/"//g')"

log "Waiting for InfluxDB"
for i in {1..60}; do docker compose exec influxdb curl -sf http://localhost:8086/health >/dev/null && { echo OK; break; }; sleep 1; [[ $i -eq 60 ]] && exit 1; done

log "Create explicit DBRP mapping for ${INFLUX_BUCKET}"
BID="$(docker compose exec influxdb influx bucket list --org "${INFLUX_ORG}" | awk '/'"${INFLUX_BUCKET}"'/ {print $1; exit}')"
# Удалить виртуальный DBRP если есть и создать explicit
docker compose exec influxdb influx v1 dbrp create --bucket-id "${BID}" --db "${INFLUX_BUCKET}" --rp "autogen" --org "${INFLUX_ORG}" --default 2>/dev/null || true
echo "✓ DBRP created"

log "Provision Grafana datasource"
[ -n "${WORK_TOKEN}" ] || { echo "✗ No saved token"; exit 1; }
mkdir -p provisioning/datasources
cat > provisioning/datasources/influxdb-asa.yml <<YAML
apiVersion: 1
datasources:
  - name: InfluxDB-asa
    uid: influxdb-asa-main
    type: influxdb
    access: proxy
    url: http://influxdb:8086
    isDefault: true
    jsonData:
      httpMode: GET
      dbName: ${INFLUX_BUCKET}
      httpHeaderName1: Authorization
    secureJsonData:
      httpHeaderValue1: "Token ${WORK_TOKEN}"
YAML
docker compose restart grafana >/dev/null || true

GRAFANA_PORT="$(docker inspect -f '{{(index (index .NetworkSettings.Ports "3000/tcp") 0).HostPort}}' grafana-asa 2>/dev/null || true)"
[[ -z "${GRAFANA_PORT}" ]] && GRAFANA_PORT="3000"
log "Waiting for Grafana API"
for i in {1..60}; do curl -sf "http://localhost:${GRAFANA_PORT}/api/health" >/dev/null && { echo OK; break; }; sleep 1; done

log "Patch dashboard to use UID"
DB_JSON="provisioning/dashboards/asa/ASA Dashboard-1585139033925.json"
[ -f "$DB_JSON" ] && sed -i 's/"datasource": "InfluxDB-asa"/"datasource": {"type":"influxdb","uid":"influxdb-asa-main"}/g' "$DB_JSON" || true

echo -e "\nDatasource health:"
curl -sS -u admin:admin "http://localhost:${GRAFANA_PORT}/api/datasources/uid/influxdb-asa-main/health" | jq .
echo -e "\n✓ Init done"
