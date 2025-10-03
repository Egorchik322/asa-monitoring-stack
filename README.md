# Cisco ASA Monitoring Stack (Telegraf + pyATS + InfluxDB 2.x + Grafana)

Контейнерный стек для сбора телеметрии с Cisco ASA по SSH (pyATS/Unicon), хранения метрик в InfluxDB 2.x и визуализации в Grafana[attached_file:1].

## Возможности

- Мониторинг VPN сессий (AnyConnect, Clientless, Site‑to‑Site) и агрегированные итоги по активным/пиковым значениям[attached_file:1].  
- Контроль ресурсных метрик ASA (Connections, Xlates, Hosts, Syslogs rate и пр.) с историей[attached_file:1].  
- Готовый дашборд Grafana и автоматическая привязка InfluxQL через DBRP после запуска init‑скрипта[web:227][web:220].  
- Автоконфигурация Grafana datasource с токеном через API в init‑скрипте, без ручного ввода[web:224][web:212].  

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

- Интервал опроса: telegraf-asa/telegraf-asa.conf, секция [agent] → interval = "30s"[attached_file:1].  
- Добавить несколько ASA: расширить devices в telegraf-asa/testbed-asa.yaml дополнительными узлами с ip/credentials[attached_file:1].  
- Retention/настройки InfluxDB: править переменные окружения в docker-compose.yml и перезапускать стек[attached_file:1].  

## Тонкости авто‑инициализации

- DBRP создаётся командой influx v1 dbrp create по bucket‑id для совместимости с InfluxQL в Grafana[web:220].  
- Токен для Grafana берётся из compose или при плейсхолдере создаётся новым All‑Access токеном через influx auth create и применяется к datasource через API[web:212][web:224].  

## Отладка

- Логи Telegraf: docker compose logs telegraf-asa[attached_file:1].  
- Проверка данных в InfluxDB (InfluxQL): запросы к базе asa‑metrics через порт 8086 внутри контейнера[attached_file:1].  
- Перезапуск авто‑инициализации: ./scripts/init-stack.sh повторно можно запускать без сноса стека[web:224].  

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
- Основано на идеях ASA‑Telemetry‑Guide и использует pyATS/Unicon, Telegraf, InfluxDB 2.x и Grafana[attached_file:1].  
