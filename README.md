# Cisco ASA Monitoring Stack (Telegraf + pyATS + InfluxDB 2.x + Grafana)

Контейнерный стек для сбора телеметрии с Cisco ASA по SSH (pyATS/Unicon), хранения метрик в InfluxDB 2.x и визуализации в Grafana.

## Возможности

- Мониторинг VPN сессий (AnyConnect, Clientless, Site‑to‑Site) и агрегированные итоги по активным/пиковым значениям.  
- Контроль ресурсных метрик ASA (Connections, Xlates, Hosts, Syslogs rate и пр.) с историей.  
- Готовый дашборд Grafana и автоматическая привязка InfluxQL через DBRP после запуска init‑скрипта.  
- Автоконфигурация Grafana datasource с токеном через API в init‑скрипте, без ручного ввода.  

## Архитектура

Cisco ASA → Telegraf (pyATS) → InfluxDB 2.x → Grafana


## Быстрый старт

1. Скопировать шаблон конфигурации ASA и заполнить доступы:  
   cp telegraf-asa/testbed-asa.yaml.example telegraf-asa/testbed-asa.yaml
2. Запустить стек:  
   docker compose up -d.  
3. Инициализировать (DBRP + токен + datasource):  
   ./scripts/init-stack.sh.  
4. Открыть Grafana на порту 3000 и войти под admin/admin, затем открыть дашборд ASA.  

## Конфигурация

- Интервал опроса: telegraf-asa/telegraf-asa.conf, секция [agent] → interval = "30s".  
- Добавить несколько ASA: расширить devices в telegraf-asa/testbed-asa.yaml дополнительными узлами с ip/credentials.  
- Retention/настройки InfluxDB: править переменные окружения в docker-compose.yml и перезапускать стек.  

## Тонкости авто‑инициализации

- DBRP создаётся командой influx v1 dbrp create по bucket‑id для совместимости с InfluxQL в Grafana.  
- Токен для Grafana берётся из compose или при плейсхолдере создаётся новым All‑Access токеном через influx auth create и применяется к datasource через API.  

## Отладка

- Логи Telegraf: docker compose logs telegraf-asa.  
- Проверка данных в InfluxDB (InfluxQL): запросы к базе asa‑metrics через порт 8086 внутри контейнера.  
- Перезапуск авто‑инициализации: ./scripts/init-stack.sh повторно можно запускать без сноса стека.  

## Структура проекта

asa-monitoring-stack/
├── docker-compose.yml
├── telegraf-asa/
│ ├── Dockerfile
│ ├── telegraf-asa.conf
│ ├── testbed-asa.yaml.example
│ └── testbed-asa.yaml # локально, в .gitignore
├── scripts/
│ ├── init-stack.sh
│ └── asascript.py
└── provisioning/
├── datasources/
└── dashboards/


## Лицензия и кредиты

- Лицензия: MIT - наверное???.  
- Основано на идеях ASA‑Telemetry‑Guide и использует pyATS/Unicon, Telegraf, InfluxDB 2.x и Grafana.  
