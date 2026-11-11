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

# Get the docker group ID to allow telegraf to access Docker socket
DOCKER_GID=$(getent group docker | cut -d: -f3)
echo "TELEGRAF_GID=$DOCKER_GID" >> .env

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

1. **Turn on authentication** with `MQTT_AUTH_ENABLED=true` (see "Authentication" below)
2. **Enable TLS** with proper certificates, at the ingress or in `config.xml`
3. **Use strong passwords** for all services
4. **Configure firewall rules** for exposed ports


### Authentication (opt-in, both images)

Both images use the same switch, `MQTT_AUTH_ENABLED=true`. Unset or `false`, the broker accepts
anonymous clients, as before. With `true`, every client must log in, and the broker does not start
when the mounted files are missing or empty.

#### HiveMQ (`mqtt-broker`)

The image ships HiveMQ's [File RBAC extension](https://github.com/hivemq/hivemq-file-rbac-extension)
4.6.19, **disabled by default**. Without the variable below, the broker accepts anonymous clients,
as in 1.2.2.

| Variable | Default | Description |
|----------|---------|-------------|
| `MQTT_AUTH_ENABLED` | `false` | `true` enables the File RBAC extension and disables the allow-all extension. Every client must log in, and can only use the topics of its roles. The Mosquitto image uses the same variable (below). |

With `MQTT_AUTH_ENABLED=true`, mount a credentials file. The broker does not start without it:

```yaml
services:
  mqtt-broker:
    image: pubregistry.aws.cloud.mov.ai/ce/mqtt-broker:<version>
    environment:
      MQTT_AUTH_ENABLED: "true"
    volumes:
      - ./credentials.xml:/opt/hivemq/extensions/hivemq-file-rbac-extension/conf/credentials.xml:ro
```

- Start from `config/hivemq/extensions/hivemq-file-rbac-extension/credentials.example.xml`. It has
  a `fleet` role (every `mov.ai/#` topic) and a `robot` role (only
  `mov.ai/+/+/<its user name>/#`, so the user name is the robot's serial number). The example
  passwords are `change-me`: replace every hash.
- Passwords are hashed. Create a hash with the extension's jar, for example from the image:
  ```bash
  docker run --rm --entrypoint java pubregistry.aws.cloud.mov.ai/ce/mqtt-broker:<version> \
    -jar /opt/hivemq/extensions/hivemq-file-rbac-extension/hivemq-file-rbac-extension-4.6.19.jar -q -p '<password>'
  ```
- The broker reloads the file every 60 seconds, so users can be added without a restart.
- A client that publishes outside its topics is disconnected, and the message is dropped.
- The health check accepts a refused anonymous login: the broker answered, so it is up.
- TLS is expected at the ingress (for example a Traefik TCP router with TLS on 8883 in front of
  1883). The `tls-tcp-listener` in `config.xml` stays commented out.

#### Mosquitto (`mqtt-edge-broker`)

With `MQTT_AUTH_ENABLED=true`, mount a password file and an ACL file. The entrypoint
(`mosquitto-entrypoint.sh`) stops with exit code 1 and an error message if either file is missing or
empty:

```yaml
services:
  mqtt-edge-broker:
    image: pubregistry.aws.cloud.mov.ai/ce/mqtt-edge-broker:<version>
    environment:
      MQTT_AUTH_ENABLED: "true"
    volumes:
      - ./passwd:/mosquitto/config/passwd:ro
      - ./acl:/mosquitto/config/acl:ro
```

- Create the password file with `mosquitto_passwd`, for example from the image:
  `docker run --rm -v "$PWD:/w" --entrypoint mosquitto_passwd <image> -c -b /w/passwd <user> '<password>'`.
  The ACL file is the standard Mosquitto format (`user <name>` lines followed by `topic ...` lines).
- The configuration file is chosen like this:
  - If the active `/mosquitto/config/mosquitto.conf` (the image default or a file you mount) already
    has `allow_anonymous false`, a `password_file` line and an `acl_file` line, the broker uses it
    as it is.
  - Otherwise the entrypoint builds `/tmp/mosquitto-auth.conf` from that file: it removes any
    `allow_anonymous`, `password_file` and `acl_file` line, and adds `allow_anonymous false`,
    `password_file /mosquitto/config/passwd` and `acl_file /mosquitto/config/acl` at the top. The
    broker starts with that file. So mounting only `passwd` and `acl` is enough.
- Mosquitto 2.0 warns when the files are world-readable or not owned by `mosquitto`. It still loads
  them. Use mode 0640 and `chown 1883` where you can.
- The health check accepts a refused anonymous login: the broker answered, so it is up.

### Mosquitto-Specific Variables and Configurations

- Mosquitto-specific variables (e.g., `MOSQUITTO_PERSISTENCE`) can be set in the `mqtt-edge-broker` service definition.


## Monitoring

### Dashboards
Access monitoring dashboard at `http://localhost:8888/monitoring` for:
- Real-time broker performance
- Connection and message statistics
- System resource utilization
- Historical trends

Health check: `http://localhost:8889` (HiveMQ fleet broker)

### Metrics Collection

#### HiveMQ Fleet Broker
Metrics collected via native InfluxDB extension (`config/hivemq/extensions/hivemq-influxdb-extension/`):
- Connection counts and rates
- Message throughput (publish/subscribe)
- Resource usage (heap, threads)
- Client session states

#### Mosquitto Edge Broker
Metrics collected via Telegraf MQTT consumer (30s delay):
- Uptime and broker status
- Connected client counts (current/maximum)
- Message/byte rates (1-minute moving average)
- Source: `$SYS/broker/*` topics published every 10 seconds

**Database**: InfluxDB `telegraf` (UDP, low latency); measurement prefix: `mqtt_consumer`

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
