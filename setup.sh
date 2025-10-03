#!/bin/bash
set -euo pipefail

clear
echo "=========================================="
echo "  Cisco ASA Monitoring Stack - Setup"
echo "=========================================="
echo ""

read_password() {
  local prompt="$1" password=""
  echo -n "$prompt" >&2
  while IFS= read -r -s -n1 char; do
    [[ $char == $'\0' ]] && break
    if [[ $char == $'\177' ]]; then
      if [ ${#password} -gt 0 ]; then password="${password%?}"; echo -ne "\b \b" >&2; fi
    else
      password+="$char"; echo -n "*" >&2
    fi
  done
  echo "" >&2
  echo "$password"
}

echo "=== Настройка Cisco ASA ==="
read -p "IP адрес ASA: " ASA_IP
read -p "SSH порт [22]: " ASA_PORT; ASA_PORT=${ASA_PORT:-22}
read -p "Имя устройства [ASAv]: " ASA_NAME; ASA_NAME=${ASA_NAME:-ASAv}
read -p "SSH логин: " ASA_USER
ASA_PASS=$(read_password "SSH пароль: ")

echo ""; echo "=== Настройка InfluxDB ==="
read -p "Admin логин [admin]: " INFLUX_USER; INFLUX_USER=${INFLUX_USER:-admin}
INFLUX_PASS=$(read_password "Admin пароль [admin123]: "); INFLUX_PASS=${INFLUX_PASS:-admin123}
read -p "Организация [myorg]: " INFLUX_ORG; INFLUX_ORG=${INFLUX_ORG:-myorg}
read -p "Bucket [asa-metrics]: " INFLUX_BUCKET; INFLUX_BUCKET=${INFLUX_BUCKET:-asa-metrics}
INFLUX_TOKEN=$(openssl rand -hex 32 2>/dev/null || tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 64 | head -n 1)

echo ""; echo "=== Настройка Grafana ==="
read -p "Admin логин [admin]: " GRAFANA_USER; GRAFANA_USER=${GRAFANA_USER:-admin}
GRAFANA_PASS=$(read_password "Admin пароль [admin]: "); GRAFANA_PASS=${GRAFANA_PASS:-admin}

echo ""; echo "=== Порты ==="
read -p "InfluxDB порт [8086]: " INFLUX_PORT; INFLUX_PORT=${INFLUX_PORT:-8086}
read -p "Grafana порт [3000]: " GRAFANA_PORT; GRAFANA_PORT=${GRAFANA_PORT:-3000}

echo ""; echo "=== Интервал опроса ==="
read -p "Интервал сбора метрик (сек) [30]: " INTERVAL; INTERVAL=${INTERVAL:-30}

echo ""; echo "Создаю конфигурацию..."

# testbed-asa.yaml с ssh_options (рабочая схема)
cat > telegraf-asa/testbed-asa.yaml <<EOF
devices:
  ${ASA_NAME}:
    os: asa
    type: asa
    connections:
      cli:
        protocol: ssh
        ip: ${ASA_IP}
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
        username: ${ASA_USER}
        password: "${ASA_PASS}"
      enable:
        password: ""
EOF

# docker-compose.yml c InfluxDB 2.7
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
      - "${INFLUX_PORT}:8086"
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

# обновляем telegraf-asa.conf: токен и интервал
sed -i "s/token = \".*\"/token = \"${INFLUX_TOKEN}\"/" telegraf-asa/telegraf-asa.conf 2>/dev/null || true
sed -i "s/interval = \"[0-9]*s\"/interval = \"${INTERVAL}s\"/" telegraf-asa/telegraf-asa.conf 2>/dev/null || true

echo ""
echo "=========================================="
echo "  ✅ Конфигурация завершена!"
echo "=========================================="
echo "ASA: ${ASA_NAME} (${ASA_IP}:${ASA_PORT})"
echo "InfluxDB: http://localhost:${INFLUX_PORT}"
echo "Grafana:  http://localhost:${GRAFANA_PORT} (логин: ${GRAFANA_USER})"
echo "Далее: docker compose up -d && ./scripts/init-stack.sh"
