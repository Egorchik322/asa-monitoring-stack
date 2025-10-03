#!/bin/bash
set -euo pipefail

banner() { echo -e "\n==========================================\n$1\n=========================================="; }

banner "Initializing ASA Monitoring Stack"

INFLUX_TOKEN=$(grep -E 'DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=' docker-compose.yml | sed 's/.*=\s*//; s/"//g')
INFLUX_ORG=$(grep -E 'DOCKER_INFLUXDB_INIT_ORG=' docker-compose.yml | sed 's/.*=\s*//; s/"//g')
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
  if [[ $i -eq 60 ]]; then echo "✗ InfluxDB failed to start in time"; exit 1; fi
done

banner "Creating DBRP mapping (InfluxQL compatibility)"
BUCKET_ID=$(docker exec influxdb-asa influx bucket list --org "$INFLUX_ORG" --token "$INFLUX_TOKEN" 2>/dev/null | awk -v b="$INFLUX_BUCKET" '$0 ~ b {print $1; exit}')
if [[ -z "${BUCKET_ID:-}" ]]; then
  docker exec influxdb-asa influx bucket list --org "$INFLUX_ORG" --token "$INFLUX_TOKEN" || true
  BUCKET_ID=$(docker exec influxdb-asa influx bucket list --org "$INFLUX_ORG" --token "$INFLUX_TOKEN" --json 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
fi
if [[ -z "${BUCKET_ID:-}" ]]; then echo "✗ Failed to resolve bucket-id for $INFLUX_BUCKET"; exit 1; fi
echo "Bucket ID: $BUCKET_ID"

if docker exec influxdb-asa influx v1 dbrp list --org "$INFLUX_ORG" --token "$INFLUX_TOKEN" | grep -q "$INFLUX_BUCKET"; then
  echo "✓ DBRP already exists"
else
  docker exec influxdb-asa influx v1 dbrp create \
    --bucket-id "$BUCKET_ID" \
    --db "$INFLUX_BUCKET" \
    --rp default \
    --org "$INFLUX_ORG" \
    --token "$INFLUX_TOKEN" \
    --default
  echo "✓ DBRP mapping created"
fi

banner "Preparing API token for Grafana"
WORK_TOKEN=""
PLACEHOLDER="change-me-to-secure-token"

if [[ "$INFLUX_TOKEN" == "$PLACEHOLDER" || -z "$INFLUX_TOKEN" ]]; then
  echo "Admin token is placeholder; creating All-Access token for Grafana..."
  RAW=$(docker exec influxdb-asa influx auth create --all-access --org "$INFLUX_ORG" --token "$PLACEHOLDER" --json)
  WORK_TOKEN=$(echo "$RAW" | grep -o '"token":"[^"]*"' | head -1 | cut -d'"' -f4)
  if [[ -z "$WORK_TOKEN" ]]; then echo "✗ Failed to create/parse token"; echo "$RAW"; exit 1; fi
  echo "✓ Generated Grafana token"
else
  WORK_TOKEN="$INFLUX_TOKEN"
  echo "✓ Using admin token from compose"
fi

banner "Updating Grafana datasource"
for i in {1..60}; do
  if docker exec grafana-asa curl -sf http://localhost:3000/api/health >/dev/null; then
    echo "✓ Grafana is ready"
    break
  fi
  sleep 1
done

DS_UID="influxdb-asa-main"
docker exec grafana-asa curl -s -X PUT \
  -H "Content-Type: application/json" \
  -u admin:admin \
  http://localhost:3000/api/datasources/uid/$DS_UID \
  -d "{
    \"uid\": \"$DS_UID\",
    \"name\": \"InfluxDB-asa\",
    \"type\": \"influxdb\",
    \"url\": \"http://influxdb:8086\",
    \"access\": \"proxy\",
    \"database\": \"$INFLUX_BUCKET\",
    \"isDefault\": true,
    \"jsonData\": { \"httpMode\": \"POST\", \"httpHeaderName1\": \"Authorization\" },
    \"secureJsonData\": { \"httpHeaderValue1\": \"Token $WORK_TOKEN\" }
  }" >/dev/null && echo "✓ Grafana datasource updated" || echo "⚠ Grafana datasource update failed (check logs)"

banner "Initialization complete"
echo "Grafana: http://localhost:3000 (admin/admin)"
echo "Bucket:  $INFLUX_BUCKET"
echo "Org:     $INFLUX_ORG"
