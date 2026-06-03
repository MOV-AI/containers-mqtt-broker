# MQTT Broker Container

Production-ready MQTT broker solution with 2 different runtime profiles:
- **HiveMQ CE 2026.5** for fleet manager workloads (dedicated VMs or cloud instances).
- **Mosquitto 2.x** for edge device workloads (lightweight, suitable for edge devices).

## Features

- **MQTT 5.0 Support** with TCP (1883) and WebSocket (8000) protocols
- **High Performance** with overload protection and rate limiting
- **Monitoring** via InfluxDB integration and health API (localhost:8889)
- **Persistence** with configurable session and message expiry
- **Security** with authentication and payload validation support
- **Edge Profile** via Mosquitto with dedicated ports and persistence volume

### Key Differences

| Aspect | HiveMQ (Fleet) | Mosquitto (Edge) |
|--------|---|---|
| **Use Case** | Fleet managers, robot coordination | Edge devices, IoT sensors |
| **Memory Footprint** | ~350-512MB JVM heap | ~50-100MB process |
| **Config Format** | XML (config.xml) | Text (mosquitto.conf) |
| **MQTT 5 Support** | Full with MQTT 5 tuning | MQTT 3.1.1 + selected MQTT 5 |
| **Auth Strategy** | HiveMQ plugins | password_file + ACL |
| **Monitoring** | InfluxDB extension | $SYS/# topics (bridge to InfluxDB via Telegraf) |

## Quick Start

The docker compose file orchestrates both HiveMQ CE and Mosquitto brokers in parallel. To start both:

```bash
# Start the brokers
docker compose up -d

# Test MQTT connection to HiveMQ
mosquitto_pub -h localhost -p 1883 -t test/topic -m "Hello MQTT"

# View logs
docker compose logs -f mqtt-broker

# Test edge broker (Mosquitto)
mosquitto_pub -h localhost -p 1884 -t test/edge -m "Hello Edge MQTT"
```

### Build Images Only

```bash
docker build -t mqtt-broker .
docker build -f Dockerfile.mosquitto -t mqtt-edge-broker .
```

## Ports

| Service Port | Exposed Port | Protocol | Description |
|--------------|--------------|----------|-------------|
| 1883 | 1883 | MQTT/TCP | Standard MQTT (HiveMQ) |
| 8000 | 8000 | MQTT/WebSocket | MQTT over WebSocket (HiveMQ) |
| 8080 | 8080 | HTTP | Management REST API (HiveMQ) |
| 1883 | 1884 | MQTT/TCP | Edge broker (Mosquitto host port) |
| 9001 | 9001 | MQTT/WebSocket | Edge broker WebSocket (host port) |
| 8086 | 8086 | HTTP | InfluxDB API |
| 8888 | 8888 | HTTP | Monitoring Dashboard (`/monitoring`) |
| 8889 | 8889 | HTTP | Health Check |

## Runtime Profiles

### Fleet Manager Broker (HiveMQ)
- Service: `mqtt-broker`
- Config: `config/hivemq/config.xml`
- Data volume: `mqtt-broker`

### Edge Broker (Mosquitto)
- Service: `mqtt-edge-broker`
- Config: `config/mosquitto/mosquitto.conf`
- Data volume: `mqtt-edge-broker`
- Host ports: `1884` (MQTT/TCP) and `9001` (WebSocket)

## Configuration

### Global Variables
- Global variables for both brokers (e.g., logging level, ...) can be defined here. Specific variables for each broker are documented in their respective sections below.

| Variable | Default | Description |
|----------|---------|-------------|
| `INFLUXDB_URL` | `http://influxdb:8086` | InfluxDB connection |
| `INFLUXDB_USERNAME` | `telegraf` | InfluxDB username |
| `INFLUXDB_PASSWORD` | `telegraf` | InfluxDB password |


### HiveMQ-Specific Variables and Configurations

- HiveMQ-specific variables (e.g., `HIVEMQ_JMX_ENABLED`) can be set in the `mqtt-broker` service definition in `docker-compose.yml`.

| Variable | Default | Description |
|----------|---------|-------------|
| `HIVEMQ_CE_VERSION` | `2026.5` | HiveMQ version |
| `JAVA_OPTS` | `` | JVM options, including heap cap |

**Notes**:
- Adjust `JAVA_OPTS` for production workloads to balance performance and resource usage.
- Default value `HIVEMQ_JMX_ENABLED=false` disables **Java Management Extensions (JMX)**, which HiveMQ CE 2026.5 enables by default.
 JMX is a Java protocol for remote monitoring and management of the JVM (heap, threads, garbage collection, etc.).

**Key Settings (config/hivemq/config.xml)**:
- Session expiry: 24 hours
- Message retention: 7 days
- Max connections: 1000 per client
- Rate limit: 1000 msg/sec per client
- Bandwidth: 1MB/s per client

**Comparison 2025.5 vs 2026.5**:

Metric/Dimension | HiveMQ-CE 2025.5 | HiveMQ-CE 2026.5 | Impact
--- | --- | --- | ---
CPU: Steady-State Load | Moderate; higher context-switching during connection churn. | Low; optimized Netty event-loops and fewer cryptographic cycles. | Lower overall CPU usage per node; higher headroom for container auto-scaling.
CPU: Under Attack / Malformed Traffic | High; spikes due to validation logic processing bad payloads. | Extremely Low; drops packets immediately at the fixed header. | Prevents denial-of-service (DoS) via CPU starvation.
Memory: Heap Profile | Bursty/Sawtooth; high allocation rate requires frequent GC sweeps. | Flatter/Predictable; strict early packet limits protect the heap. | Minimizes the risk of JVM Out-Of-Memory (OOM) kills in Kubernetes.
Memory: Per-Client Footprint | Baseline (~X KB per idle connection). | ~5-10% lower per-client overhead (via SDK 4.52.0 maps). | Allows higher client density on the same instance/node sizes.
TLS Handshake Efficiency | 2 Round-Trips (RTT) on standard legacy ciphers. | 1 Round-Trip (RTT) optimized for TLS 1.3 / ECDHE. | Drastically speeds up reconnection times for fleet devices on cellular networks.
Underlying Base Image | eclipse-temurin:21-jre-noble | Updated Eclipse Temurin Base with matured runtime patches. | Benefits from core JVM-level security and threading optimizations.

**InfluxDB Integration**:
- The HiveMQ extension for InfluxDB is configured via `config/hivemq/extensions/hivemq-influxdb-extension/influxdb.properties`. Adjust the `reportingInterval` and other parameters as needed for your monitoring requirements. The extension collects key metrics such as:
- Connection counts and rates
- Message throughput (publish/subscribe rates)
- Resource usage (heap, threads)
- Client session states (active, expired)
- MQTT protocol usage (QoS levels, retained messages)

Edit `config/hivemq/extensions/hivemq-influxdb-extension/influxdb.properties`:
```properties
host=influxdb
port=8086
database=metrics
reportingInterval=10
```

**Important**: This configuration is for development. For production:

1. **Disable anonymous authentication** in `config/hivemq/config.xml`
2. **Enable TLS** with proper certificates
3. **Use strong passwords** for all services
4. **Configure firewall rules** for exposed ports
5. **Implement client authentication** and authorization


### Mosquitto-Specific Variables and Configurations

- Mosquitto-specific variables (e.g., `MOSQUITTO_PERSISTENCE`) can be set in the `mqtt-edge-broker` service definition.


## Monitoring

Access monitoring dashboard at `http://localhost:8888/monitoring` for:
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

# Edge broker logs
docker compose logs mqtt-edge-broker

# All services
docker compose logs -f
```

## Development

Build with custom HiveMQ version:
```bash
docker build --build-arg HIVEMQ_CE_VERSION=2026.5 -t mqtt-broker .
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
