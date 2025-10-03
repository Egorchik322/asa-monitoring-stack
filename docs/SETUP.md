# Настройка credentials

## 1. Скопировать example файлы

\`\`\`bash
cp telegraf-asa/testbed-asa.yaml.example telegraf-asa/testbed-asa.yaml
\`\`\`

## 2. Отредактировать testbed-asa.yaml

- YOUR_USERNAME → ваш SSH username для ASA
- YOUR_PASSWORD → ваш SSH password
- YOUR_ASA_IP → IP адрес ASA

## 3. Отредактировать telegraf-asa/telegraf-asa.conf

\`\`\`toml
[[outputs.influxdb_v2]]
  token = "YOUR_INFLUXDB_TOKEN"
  organization = "YOUR_ORG"
\`\`\`

## 4. Отредактировать provisioning/datasources/influxdb-asa.yml

\`\`\`yaml
secureJsonData:
  httpHeaderValue1: 'Token YOUR_INFLUXDB_TOKEN'
\`\`\`

## 5. Убедиться что testbed-asa.yaml в .gitignore!
