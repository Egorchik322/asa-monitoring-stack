# Datasource Configuration

After deployment, update the InfluxDB token in Grafana:

1. Go to Connections → Data sources → InfluxDB-asa
2. Update the token with your actual InfluxDB admin token
3. Click "Save & Test"

The token is displayed during InfluxDB initialization or can be found in docker-compose.yml environment variables.
