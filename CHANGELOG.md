# Changelog

All notable changes to the MQTT Broker container project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.1.0 [2024-06-01]

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
