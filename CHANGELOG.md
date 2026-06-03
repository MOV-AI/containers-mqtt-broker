# Changelog

All notable changes to the MQTT Broker container project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.2.1 [Unreleased]

### Added
- **Parallel dual-broker profile**: Mosquitto 2.0 edge broker runs alongside HiveMQ CE
- `mqtt-edge-broker` service (Dockerfile.mosquitto) with dedicated config and ports (1884, 9001)
- Edge broker config: `config/mosquitto/mosquitto.conf` with conservative resource limits
- Migration guide: `docs/MIGRATION_GUIDE.md` for gradual HiveMQ → Mosquitto transition
- Manifest-based CI: Both broker images built in parallel via `images-manifest.yml`
- Makefile: Updated to build both `mqtt-broker` and `mqtt-edge-broker` images

### Changed
- docker-compose now orchestrates both fleet manager (HiveMQ) and edge broker (Mosquitto) services
- `.dockerignore`: Expanded to include Dockerfile.mosquitto and config subtree
- README: Added dual-profile documentation and edge broker quick-start examples

### Deprecated
- Single-image workflow; new deployments should explicitly choose broker profile(s)

## 1.1.1 [2024-06-01]

### Added
- HiveMQ Community Edition 2026.5 support (upgraded from 2025.5)
- JMX metric writer disabled by default to prevent startup errors in containerized environments
- Enhanced control packet size limits for improved DoS protection
- Optimized heap memory thresholds for predictable performance under 2026.5

## 1.0.0 [Unreleased]

### Added
- Comprehensive documentation suite
- InfluxDB extension v4.1.7 for metrics collection
- Comprehensive monitoring stack with Chronograf and Kapacitor for development
- Robot fleet optimized configuration
- WebSocket support for web-based clients
- Health check endpoints
- Overload protection mechanisms
- MQTT 5.0 feature support
- Docker Compose orchestration
- GitHub Actions CI/CD pipeline
- Automated version bumping
- Dependabot configuration
- Multi-environment support
