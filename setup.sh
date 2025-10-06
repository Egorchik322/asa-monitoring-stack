#!/bin/bash
set -euo pipefail

read_password(){
  local p="$1" s=""
  echo -n "$p" >&2
  while IFS= read -r -s -n1 c; do
    [[ $c == $'\0' ]] && break
    if [[ $c == $'\177' ]]; then
      [[ ${#s} -gt 0 ]] && s="${s%?}" && echo -ne "\b \b" >&2
    else
      s+="$c"
      echo -n "*" >&2
    fi
  done
  echo "" >&2
  echo "$s"
}

# Токен InfluxDB
TOK_FILE=".secrets/influx_admin_token"
mkdir -p .secrets
if [[ -s "$TOK_FILE" ]]; then
  INFLUX_TOKEN="$(cat "$TOK_FILE")"
  echo "✓ Reusing saved InfluxDB token from $TOK_FILE"
else
  INFLUX_TOKEN="$(openssl rand -hex 32 || tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 64 | head -n1)"
  printf "%s" "$INFLUX_TOKEN" > "$TOK_FILE"
  chmod 600 "$TOK_FILE"
  echo "✓ Generated and saved InfluxDB token to $TOK_FILE"
fi

# Множественные ASA устройства
echo ""
echo "=== ASA Устройства ==="
read -p "Количество ASA устройств [1]: " ASA_COUNT
ASA_COUNT=${ASA_COUNT:-1}

declare -a ASA_DEVICES
for i in $(seq 1 $ASA_COUNT); do
  echo ""
  echo "--- Устройство $i ---"
  read -p "Имя устройства [ASA-$i]: " NAME
  NAME=${NAME:-ASA-$i}
  read -p "IP адрес: " IP
  read -p "SSH порт [22]: " PORT
  PORT=${PORT:-22}
  read -p "SSH логин: " USER
  PASS=$(read_password "SSH пароль: ")
  
  ASA_DEVICES+=("$NAME|$IP|$PORT|$USER|$PASS")
done

echo ""
echo "=== InfluxDB ==="
read -p "Admin логин [admin]: " INFLUX_USER
INFLUX_USER=${INFLUX_USER:-admin}
INFLUX_PASS=$(read_password "Admin пароль [admin123]: ")
INFLUX_PASS=${INFLUX_PASS:-admin123}
read -p "Организация [myorg]: " INFLUX_ORG
INFLUX_ORG=${INFLUX_ORG:-myorg}
read -p "Bucket [asa-metrics]: " INFLUX_BUCKET
INFLUX_BUCKET=${INFLUX_BUCKET:-asa-metrics}

echo ""
echo "=== Grafana ==="
read -p "Admin логин [admin]: " GRAFANA_USER
GRAFANA_USER=${GRAFANA_USER:-admin}
GRAFANA_PASS=$(read_password "Admin пароль [admin]: ")
GRAFANA_PASS=${GRAFANA_PASS:-admin}
read -p "Порт Grafana [3003]: " GRAFANA_PORT
GRAFANA_PORT=${GRAFANA_PORT:-3003}

echo ""
echo "=== Интервал сбора ==="
read -p "Интервал (сек) [30]: " INTERVAL
INTERVAL=${INTERVAL:-30}

echo ""
echo "Генерация файлов..."

# Создать testbed-asa.yaml с несколькими устройствами
cat > telegraf-asa/testbed-asa.yaml <<EOF
devices:
EOF

for device in "${ASA_DEVICES[@]}"; do
  IFS='|' read -r NAME IP PORT USER PASS <<< "$device"
  cat >> telegraf-asa/testbed-asa.yaml <<EOF
  ${NAME}:
    os: asa
    type: asa
    connections:
      cli:
        protocol: ssh
        ip: ${IP}
        port: ${PORT}
        ssh_options: >
          -o KexAlgorithms=diffie-hellman-group14-sha1
          -o HostkeyAlgorithms=+ssh-rsa
          -o PubkeyAcceptedAlgorithms=+ssh-rsa
          -o Ciphers=aes128-ctr
          -o StrictHostKeyChecking=no
          -o UserKnownHostsFile=/dev/null
        arguments:
          learn_hostname: true
          init_exec_commands: []
          init_config_commands: []
          goto_enable: false
    credentials:
      default:
        username: ${USER}
        password: "${PASS}"
      enable:
        password: ""
EOF
done

# Создать docker-compose.yml
cat > docker-compose.yml <<EOF
services:
  influxdb:
    image: influxdb:2.7
    container_name: influxdb-asa
    restart: unless-stopped
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=${INFLUX_USER}
      - DOCKER_INFLUXDB_INIT_PASSWORD=${INFLUX_PASS}
      - DOCKER_INFLUXDB_INIT_ORG=${INFLUX_ORG}
      - DOCKER_INFLUXDB_INIT_BUCKET=${INFLUX_BUCKET}
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=${INFLUX_TOKEN}
    ports:
      - "8086:8086"
    volumes:
      - influxdb-data:/var/lib/influxdb2
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:8086/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  telegraf-asa:
    build:
      context: ./telegraf-asa
      dockerfile: Dockerfile
    container_name: telegraf-asa
    restart: unless-stopped
    volumes:
      - ./telegraf-asa/telegraf-asa.conf:/etc/telegraf/telegraf.conf:ro
      - ./telegraf-asa/testbed-asa.yaml:/opt/telegraf/ASA-Telemetry-Guide/telegraf/scripts/testbed-asa.yaml:ro
      - ./scripts/asascript.py:/opt/telegraf/ASA-Telemetry-Guide/telegraf/scripts/asascript.py:ro
    depends_on:
      influxdb:
        condition: service_healthy

  grafana:
    image: grafana/grafana:latest
    container_name: grafana-asa
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_USER=${GRAFANA_USER}
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASS}
    ports:
      - "${GRAFANA_PORT}:3000"
    depends_on:
      influxdb:
        condition: service_healthy
    volumes:
      - grafana-data:/var/lib/grafana
      - ./provisioning/datasources:/etc/grafana/provisioning/datasources:ro
      - ./provisioning/dashboards:/etc/grafana/provisioning/dashboards:ro

volumes:
  influxdb-data:
  grafana-data:
EOF

# Обновить telegraf-asa.conf
sed -i \
  -e "s#^  token = \".*\"#  token = \"${INFLUX_TOKEN}\"#" \
  -e "s#^  organization = \".*\"#  organization = \"${INFLUX_ORG}\"#" \
  -e "s#^  bucket = \".*\"#  bucket = \"${INFLUX_BUCKET}\"#" \
  -e "s#^  interval = \".*\"#  interval = \"${INTERVAL}s\"#" \
  telegraf-asa/telegraf-asa.conf 2>/dev/null || true

echo ""
echo "=========================================="
echo "  ✅ Конфигурация завершена!"
echo "=========================================="
echo "ASA устройств: ${ASA_COUNT}"
for i in $(seq 1 ${#ASA_DEVICES[@]}); do
  IFS='|' read -r NAME IP PORT USER PASS <<< "${ASA_DEVICES[$((i-1))]}"
  echo "  - ${NAME} (${IP}:${PORT})"
done
echo ""
echo "InfluxDB: http://localhost:8086"
echo "Grafana:  http://localhost:${GRAFANA_PORT} (логин: ${GRAFANA_USER})"
echo ""
echo "Далее:"
echo "  docker compose build telegraf-asa"
echo "  docker compose up -d"
echo "  ./scripts/init-stack.sh"
