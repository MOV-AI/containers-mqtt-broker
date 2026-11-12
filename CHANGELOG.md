# Changelog

All notable changes to the MQTT Broker container project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Removed
- **Breaking:** the MQTT over WebSocket listeners are removed from both images: HiveMQ
  `<websocket-listener>` on port 8000 (path `/mqtt`) and Mosquitto `listener 9001` with
  `protocol websockets`. `Dockerfile.mosquitto` no longer exposes 9001, and `docker-compose.yml` no
  longer publishes 8000 and 9001. Web clients that connect over WebSocket must use MQTT over TCP/TLS
  through haproxy instead. A mounted `config.xml` or `mosquitto.conf` that still has these
  listeners keeps them.

### Added
- Optional authentication for the HiveMQ broker: the File RBAC extension 4.6.19 is installed and
  turned on by `MQTT_AUTH_ENABLED=true`, with a mounted `credentials.xml`. Off by default.
- Example credentials with a `fleet` role and a per-robot `robot` role
  (`config/hivemq/extensions/hivemq-file-rbac-extension/credentials.example.xml`).

- Optional authentication for the Mosquitto edge broker with the same switch, `MQTT_AUTH_ENABLED=true`.
  It needs mounted, non-empty `/mosquitto/config/passwd` and `/mosquitto/config/acl` files and exits
  with an error if one is missing. New entrypoint `mosquitto-entrypoint.sh`. Off by default.
  The entrypoint copies both files to `/run/mosquitto-auth/` (owner `mosquitto`, mode 0700 and 0600,
  outside the data volume) and always starts the broker with a generated config that points at the
  copies, so Mosquitto no longer warns about world-readable or not-owned files, and an `include_dir`
  file cannot re-enable anonymous access. Files are read at start: restart to apply a change.
  `per_listener_settings true` is refused with a clear error when authentication is on.
- Dependabot now watches the Docker base images (`docker` ecosystem).

### Changed
- Mosquitto base image: `eclipse-mosquitto:2.0` (floating tag) is now pinned to
  `eclipse-mosquitto:2.1.2-alpine` with its digest (Mosquitto 2.1.2, Alpine 3.23), for reproducible
  builds. The 2.1 base entrypoint only changes the owner of `/mosquitto/data`, so the
  "chown: Read-only file system" noise for `:ro` mounts is gone. `password_file`, `acl_file` and
  `per_listener_settings` are deprecated in 2.1 (removal in 3.0) but still work and log no warning.
  Persistence data written by 2.0 is read by 2.1.
- The Mosquitto Dockerfile no longer runs the no-op `apk del --purge` and `rm -rf /var/cache/apk`
  (`apk add --no-cache` leaves no cache).
- The image entrypoint is now `mqtt-entrypoint.sh`, which applies the setting above and then runs
  the base HiveMQ entrypoint.
- The health check accepts a CONNACK that refuses the anonymous probe (codes 04 and 05), so it
  passes when authentication is on.

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
