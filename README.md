# Cisco ASA Monitoring Stack (Telegraf + pyATS + InfluxDB + Grafana)

Полный стек для мониторинга Cisco ASA через SSH с использованием pyATS/Unicon, сбором метрик в InfluxDB и визуализацией в Grafana.

Создано на основе https://github.com/mageru/ASA-Telemetry-Guide

Для Cisco ASA5540 - мб на чем то еще заведется.

Основные изменения: Заложено что в железке не стоит пароль на "enable", прикручено все в один docker compose, при необходимости можно сверху вкрутить сколько угодно инпутов, т.к используем последние образа grafana и influx

Скрипты переписывал Cluade Sonnet 4.5 , а я чисто рядом проходил - но вроде все работает.


## 🚀 Возможности

- Мониторинг VPN сессий (AnyConnect, Clientless, Site-to-Site)
- Отслеживание утилизации ресурсов (Connections, Xlates, Hosts)
- SSH connection tracking
- Device load и capacity monitoring
- Автоматический сбор метрик каждые 30-60 секунд
- Готовый дашборд Grafana

## 📋 Требования

- Docker & Docker Compose
- Доступ к Cisco ASA по SSH
- Linux host (тестировано на Debian 11/12)

## 🛠️ Быстрый старт

### 1. Клонировать репозиторий

git clone https://github.com/YOUR_USERNAME/asa-monitoring-stack.git
cd asa-monitoring-stack

### 2. Настроить credentials

См. docs/SETUP.md для подробной инструкции.

### 3. Запустить стек

docker compose up -d

### 4. Открыть Grafana

- URL: http://localhost:3000
- Login: admin / admin

## 📊 Собираемые метрики

- VPN Sessions (Active, Inactive, Peak)
- AnyConnect SSL/TLS/DTLS tunnels
- Site-to-Site IKEv2 IPsec
- ASA Resources (Connections, Xlates, Hosts)
- SSH sessions

## 🐛 Troubleshooting

А тут братва сами, LLM  в помощь

## 📝 Лицензия

MIT - наверное

## 🙏 Credits

- ASA-Telemetry-Guide - Original scripts
- pyATS/Unicon - Cisco automation
- Telegraf, InfluxDB, Grafana - TICK stack
