ARG HIVEMQ_CE_VERSION=2026.5

FROM hivemq/hivemq-ce:${HIVEMQ_CE_VERSION}

# Labels
LABEL description="MOV.AI MQTT Broker Image"
LABEL maintainer="devops@mov.ai"
LABEL movai="mqtt-broker"
LABEL environment="release"

# Environment variables
ENV ENV="release" \
    HIVEMQ_JMX_ENABLED=false \
    HIVEMQ_INFLUXDB_EXTENSION_VERSION="4.1.7"

# Copy configuration files
COPY config/hivemq/ /opt/hivemq/conf/

# Install plugins
# 1. HiveMQ InfluxDB Monitoring Extension
USER root
RUN apt-get update && apt-get install -y --no-install-recommends unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives && \
    curl -L -f "https://github.com/hivemq/hivemq-influxdb-extension/releases/download/${HIVEMQ_INFLUXDB_EXTENSION_VERSION}/hivemq-influxdb-extension-${HIVEMQ_INFLUXDB_EXTENSION_VERSION}.zip" \
    -o /tmp/hivemq-influxdb-extension.zip && \
    unzip /tmp/hivemq-influxdb-extension.zip -d /opt/hivemq/extensions/ && \
    rm /tmp/hivemq-influxdb-extension.zip && \
    cp -vf /opt/hivemq/conf/extensions/hivemq-influxdb-extension/influxdb.properties /opt/hivemq/extensions/hivemq-influxdb-extension/

USER 10000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD bash -ec ' \
    exec 3<>/dev/tcp/127.0.0.1/1883; \
    printf "\x10\x0e\x00\x04MQTT\x04\x02\x00\x05\x00\x02hc" >&3; \
    resp=$(dd bs=1 count=4 <&3 2>/dev/null | od -An -tx1 -v | tr -d " \\n"); \
    [ "$resp" = "20020000" ]'
