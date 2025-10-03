#!/bin/bash
set -euo pipefail

banner() { echo -e "\n==========================================\n$1\n=========================================="; }

banner "Initializing ASA Monitoring Stack"

# Читаем значения из compose
INFLUX_TOKEN_ENV=$(grep -E 'DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=' docker-compose.yml | sed 's/.*=\s*//; s/"//g' || true)
INFLUX_ORG=$(grep -E 'DOCKER_INFLUXDB_INIT_ORG=' docker-compose.yml | sed 's/.*=\s*//; s/"//g')
INFLUX_USER=$(grep -E 'DOCKER_INFLUXDB_INIT_USERNAME=' docker-compose.yml | sed 's/.*=\s*//; s/"//g')
INFLUX_BUCKET=$(grep -E 'DOCKER_INFLUXDB_INIT_BUCKET=' docker-compose.yml | sed 's/.*=\s*//; s/"//g')

echo "Org: $INFLUX_ORG"
echo "Bucket: $INFLUX_BUCKET"

echo "Waiting for InfluxDB (max 60s)..."
for i in {1..60}; do
  if docker exec influxdb-asa curl -sf http://localhost:8086/health >/dev/null; then
    echo "✓ InfluxDB is ready"
    break
  fi
  sleep 1
  [[ $i -eq 60 ]] && { echo "✗ InfluxDB failed to start in time"; exit 1; }
done

# Функция: проверка валидности токена
is_token_ok() {
  local t="$1"
  docker exec influxdb-asa curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Token ${t}" \
    http://localhost:8086/api/v2/authorizations | grep -qE '^(200|204)$'
}

# 1) Пытаемся использовать токен из compose
WORK_TOKEN="${INFLUX_TOKEN_ENV:-}"

if [[ -n "${WORK_TOKEN}" ]] && is_token_ok "${WORK_TOKEN}"; then
  echo "✓ Compose token is valid"
else
  echo "⚠ Compose token invalid or missing; trying to recover operator token (no data loss)"
  # Останавливаем InfluxDB и создаём operator token напрямую в bolt
  docker compose stop influxdb >/dev/null
  # Берём тэг 2.7 для совместимости recovery
  WORK_TOKEN=$(docker run --rm -v influxdb-data:/var/lib/influxdb2 influxdb:2.7 \
    influxd recovery auth create-operator --bolt-path /var/lib/influxdb2/influxd.bolt \
    --org "${INFLUX_ORG}" --username "${INFLUX_USER}" 2>/dev/null | awk '/token:/ {print $2}')
  docker compose start influxdb >/dev/null

  # Ждём возврата в online
  for i in {1..60}; do
    if docker exec influxdb-asa curl -sf http://localhost:8086/health >/dev/null; then break; fi
    sleep 1
  done

  if [[ -z "${WORK_TOKEN}" ]] || ! is_token_ok "${WORK_TOKEN}"; then
    echo "✗ Failed to obtain a valid operator token. Consider fresh init (down -v)."
    exit 1
  fi
  echo "✓ Operator token recovered"
fi

banner "Creating DBRP mapping (InfluxQL compatibility)"
BUCKET_ID=$(docker exec influxdb-asa influx bucket list --org "$INFLUX_ORG" --token "$WORK_TOKEN" 2>/dev/null | awk -v b="$INFLUX_BUCKET" '$0 ~ b {print $1; exit}')
if [[ -z "${BUCKET_ID:-}" ]]; then
  BUCKET_ID=$(docker exec influxdb-asa influx bucket list --org "$INFLUX_ORG" --token "$WORK_TOKEN" --json 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
fi
[[ -z "${BUCKET_ID:-}" ]] && { echo "✗ Failed to resolve bucket-id for $INFLUX_BUCKET"; exit 1; }

if docker exec influxdb-asa influx v1 dbrp list --org "$INFLUX_ORG" --token "$WORK_TOKEN" | grep -q "$INFLUX_BUCKET"; then
  echo "✓ DBRP already exists"
else
  docker exec influxdb-asa influx v1 dbrp create \
    --bucket-id "$BUCKET_ID" \
    --db "$INFLUX_BUCKET" \
    --rp default \
    --org "$INFLUX_ORG" \
    --token "$WORK_TOKEN" \
    --default
  echo "✓ DBRP mapping created"
fi

banner "Sync tokens to Telegraf and Grafana"

# Обновляем токен в telegraf.conf
sed -i "s/token = \".*\"/token = \"${WORK_TOKEN}\"/" telegraf-asa/telegraf-asa.conf || true
docker compose restart telegraf-asa >/dev/null || true

# Обновляем Grafana datasource по API
DS_UID="influxdb-asa-main"
docker exec grafana-asa curl -s -X PUT \
  -H "Content-Type: application/json" -u admin:admin \
  "http://localhost:3000/api/datasources/uid/$DS_UID" \
  -d "{
    \"uid\": \"$DS_UID\",
    \"name\": \"InfluxDB-asa\",
    \"type\": \"influxdb\",
    \"url\": \"http://influxdb:8086\",
    \"access\": \"proxy\",
    \"database\": \"${INFLUX_BUCKET}\",
    \"isDefault\": true,
    \"jsonData\": { \"httpMode\": \"POST\", \"httpHeaderName1\": \"Authorization\" },
    \"secureJsonData\": { \"httpHeaderValue1\": \"Token ${WORK_TOKEN}\" }
  }" >/dev/null || true

echo "✓ Tokens synchronized"
