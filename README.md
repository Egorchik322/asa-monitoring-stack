# Cisco ASA Monitoring Stack (Telegraf + pyATS + InfluxDB 2.x + Grafana)

Контейнерный стек для сбора телеметрии с Cisco ASA по SSH (pyATS/Unicon), хранения метрик в InfluxDB 2.x и визуализации в Grafana с автоматической настройкой через скрипты.

## Возможности

- Мониторинг VPN сессий (AnyConnect, Clientless, Site-to-Site) и агрегированные итоги
- Контроль ресурсных метрик ASA (Connections, Xlates, Hosts, SSH Sessions) с историей
- Готовый дашборд Grafana с автоматической привязкой InfluxQL через DBRP
- Полностью автоматизированная установка: setup.sh → docker compose up → init-stack.sh
- Поддержка старых ASA (устаревшие SSH-алгоритмы настроены автоматически)

## Архитектура

    Cisco ASA (SSH) → Telegraf (pyATS/Genie) → InfluxDB 2.x (bucket + DBRP) → Grafana

## Быстрый старт

### 1. Требования
- Docker и Docker Compose
- Доступ к Cisco ASA по SSH (admin привилегии)

### 2. Установка

    ./setup.sh
    docker compose build telegraf-asa
    docker compose up -d
    ./scripts/init-stack.sh

### 3. Доступ к Grafana
- URL: http://localhost:3003 (или порт, указанный при setup.sh)
- Логин/пароль: admin/admin (или указанные при установке)
- Dashboard: ASA Dashboard

## Структура проекта

    asa-monitoring-clean/
    ├── setup.sh                    # Генерация конфигов
    ├── scripts/
    │   ├── init-stack.sh           # Авто-настройка DBRP и Grafana
    │   └── asascript.py            # Скрипт сбора метрик (pyATS)
    ├── telegraf-asa/
    │   ├── Dockerfile              # Telegraf + pyATS/Genie
    │   ├── telegraf-asa.conf       # Конфиг с name_override
    │   └── testbed-asa.yaml.example
    └── provisioning/
        ├── datasources/
        └── dashboards/

## Переустановка

    docker compose down -v
    rm -f .secrets/influx_admin_token
    ./setup.sh
    docker compose build telegraf-asa && docker compose up -d
    ./scripts/init-stack.sh

## Troubleshooting

### Telegraf падает
    docker compose logs telegraf-asa --tail=50

### Grafana datasource Unauthorized
    cat provisioning/datasources/influxdb-asa.yml | grep httpHeaderValue1
    cat .secrets/influx_admin_token

### Дашборд пустой
    TOKEN="$(cat .secrets/influx_admin_token)"
    curl -sS -H "Authorization: Token ${TOKEN}" \
      "http://localhost:8086/query?db=asa-metrics&q=SHOW%20MEASUREMENTS" | jq .

## Лицензия

MIT — основано на ASA-Telemetry-Guide, использует pyATS/Unicon, Telegraf, InfluxDB 2.x и Grafana
