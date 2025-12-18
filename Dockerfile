ARG HIVEMQ_CE_VERSION=2025.5

FROM hivemq/hivemq-ce:${HIVEMQ_CE_VERSION}

# Labels
LABEL description="MOV.AI MQTT Broker Image"
LABEL maintainer="devops@mov.ai"
LABEL movai="mqtt-broker"
LABEL environment="release"

# Environment variables
ENV ENV="release" \
    HIVEMQ_INFLUXDB_EXTENSION_VERSION="4.1.7"

# Copy configuration files
COPY config/ /opt/hivemq/conf/

# Install plugins
# 1. HiveMQ InfluxDB Monitoring Extension
USER root
RUN apt-get update && apt-get install -y unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives && \
    curl -L -f "https://github.com/hivemq/hivemq-influxdb-extension/releases/download/${HIVEMQ_INFLUXDB_EXTENSION_VERSION}/hivemq-influxdb-extension-${HIVEMQ_INFLUXDB_EXTENSION_VERSION}.zip" \
    -o /tmp/hivemq-influxdb-extension.zip && \
    unzip /tmp/hivemq-influxdb-extension.zip -d /opt/hivemq/extensions/ && \
    rm /tmp/hivemq-influxdb-extension.zip && \
    cp -vf /opt/hivemq/conf/extensions/hivemq-influxdb-extension/influxdb.properties /opt/hivemq/extensions/hivemq-influxdb-extension/