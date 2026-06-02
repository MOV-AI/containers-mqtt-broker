# MQTT Broker Container

Production-ready MQTT broker solution based on HiveMQ Community Edition 2025.5, optimized for IoT devices and robot fleet management with integrated InfluxDB monitoring.

## Features

- **MQTT 5.0 Support** with TCP (1883) and WebSocket (8000) protocols
- **High Performance** with overload protection and rate limiting
- **Monitoring** via InfluxDB integration and health API (localhost:8889)
- **Persistence** with configurable session and message expiry
- **Security** with authentication and payload validation support

## Quick Start

```bash
# Start the broker
docker compose up -d

# Test MQTT connection
mosquitto_pub -h localhost -p 1883 -t test/topic -m "Hello MQTT"

# View logs
docker compose logs -f mqtt-broker
```

### Build Image Only
```bash
docker build -t mqtt-broker .
```

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 1883 | MQTT/TCP | Standard MQTT |
| 8000 | MQTT/WebSocket | MQTT over WebSocket |
| 8086 | HTTP | InfluxDB API |
| 8888 | HTTP | Monitoring Dashboard |
| 8889 | HTTP | Health Check |

## Configuration

### Environment Variables (.env)

| Variable | Default | Description |
|----------|---------|-------------|
| `HIVEMQ_CE_VERSION` | `2025.5` | HiveMQ version |
| `JAVA_OPTS` | `
` | JVM options, including heap cap |
| `INFLUXDB_URL` | `http://influxdb:8086` | InfluxDB connection |
| `INFLUXDB_USERNAME` | `telegraf` | InfluxDB username |
| `INFLUXDB_PASSWORD` | `telegraf` | InfluxDB password |

### Key Settings (config/config.xml)

- Session expiry: 24 hours
- Message retention: 7 days
- Max connections: 1000 per client
- Rate limit: 1000 msg/sec per client
- Bandwidth: 1MB/s per client

### InfluxDB Integration

Edit `config/extensions/hivemq-influxdb-extension/influxdb.properties`:
```properties
host=influxdb
port=8086
database=metrics
reportingInterval=10
```

## Production Security

**Important**: This configuration is for development. For production:

1. **Disable anonymous authentication** in `config.xml`
2. **Enable TLS** with proper certificates
3. **Use strong passwords** for all services
4. **Configure firewall rules** for exposed ports
5. **Implement client authentication** and authorization

## Monitoring

Access monitoring dashboard at `http://localhost:8888` for:
- Real-time broker performance
- Connection and message statistics
- System resource utilization
- Historical trends

Health check: `http://localhost:8889`

Data is automatically stored in InfluxDB with Docker volumes for persistence.

## Troubleshooting

### Common Issues

**Connection refused**: Check if services are running with `docker compose ps`

**High memory usage**: Monitor with `docker stats` and check overload protection in config.xml

**InfluxDB issues**: Verify container network connectivity

### Logs
```bash
# Broker logs
docker compose logs mqtt-broker

# All services
docker compose logs -f
```

## Development

Build with custom HiveMQ version:
```bash
docker build --build-arg HIVEMQ_CE_VERSION=2025.4 -t mqtt-broker .
```

Clean and rebuild:
```bash
make clean
docker compose up --build
```

## Reference
- **[CHANGELOG.md](./CHANGELOG.md)** - Version history and release notes

## License

Maintained by MOV.AI DevOps team. For support: devops@mov.ai
