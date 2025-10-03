# Cisco ASA Monitoring Stack (Telegraf + pyATS + InfluxDB 2.x + Grafana)

Контейнерный стек для сбора телеметрии с Cisco ASA по SSH (pyATS/Unicon), хранения метрик в InfluxDB 2.x и визуализации в Grafana.

## Возможности

- Мониторинг VPN сессий (AnyConnect, Clientless, Site-to-Site) и агрегированные итоги
- Контроль ресурсных метрик ASA (Connections, Xlates, Hosts, Syslogs rate) с историей
- Готовый дашборд Grafana и автоматическая привязка InfluxQL через DBRP
- Автоконфигурация Grafana datasource с токеном через API в init-скрипте

## Архитектура

    Cisco ASA → Telegraf (pyATS) → InfluxDB 2.x → Grafana

## Быстрый старт

1. Скопировать и настроить конфигурацию ASA
2. Запустить: docker compose up -d
3. Инициализировать: ./scripts/init-stack.sh
4. Открыть Grafana на http://localhost:3000 (admin/admin)

## Структура проекта

    asa-monitoring-stack/
    ├── docker-compose.yml
    ├── telegraf-asa/
    │   ├── Dockerfile
    │   ├── telegraf-asa.conf
    │   ├── testbed-asa.yaml.example
    │   └── testbed-asa.yaml
    ├── scripts/
    │   ├── init-stack.sh
    │   └── asascript.py
    └── provisioning/
        ├── datasources/
        └── dashboards/

## Лицензия

MIT - основано на ASA-Telemetry-Guide, использует pyATS/Unicon, Telegraf, InfluxDB 2.x и Grafana
