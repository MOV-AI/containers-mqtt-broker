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
    HIVEMQ_INFLUXDB_EXTENSION_VERSION="4.1.7" \
    HIVEMQ_FILE_RBAC_EXTENSION_VERSION="4.6.19"

# Copy configuration files
COPY config/hivemq/ /opt/hivemq/conf/
COPY config/health_check.sh /usr/local/bin/health_check.sh
COPY config/mqtt-entrypoint.sh /usr/local/bin/mqtt-entrypoint.sh

# Install plugins and health check script
# 1. HiveMQ InfluxDB Monitoring Extension
# 2. HiveMQ File RBAC Extension, disabled until MQTT_AUTH_ENABLED=true (see mqtt-entrypoint.sh).
#    Its sample credentials.xml (known passwords) is removed: users must mount their own.
USER root
RUN apt-get update && apt-get install -y --no-install-recommends unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives && \
    curl -L -f "https://github.com/hivemq/hivemq-influxdb-extension/releases/download/${HIVEMQ_INFLUXDB_EXTENSION_VERSION}/hivemq-influxdb-extension-${HIVEMQ_INFLUXDB_EXTENSION_VERSION}.zip" \
    -o /tmp/hivemq-influxdb-extension.zip && \
    unzip /tmp/hivemq-influxdb-extension.zip -d /opt/hivemq/extensions/ && \
    rm /tmp/hivemq-influxdb-extension.zip && \
    cp -vf /opt/hivemq/conf/extensions/hivemq-influxdb-extension/influxdb.properties /opt/hivemq/extensions/hivemq-influxdb-extension/ && \
    curl -L -f "https://github.com/hivemq/hivemq-file-rbac-extension/releases/download/${HIVEMQ_FILE_RBAC_EXTENSION_VERSION}/hivemq-file-rbac-extension-${HIVEMQ_FILE_RBAC_EXTENSION_VERSION}.zip" \
    -o /tmp/hivemq-file-rbac-extension.zip && \
    unzip /tmp/hivemq-file-rbac-extension.zip -d /opt/hivemq/extensions/ && \
    rm /tmp/hivemq-file-rbac-extension.zip && \
    rm -f /opt/hivemq/extensions/hivemq-file-rbac-extension/conf/credentials.xml && \
    cp -vf /opt/hivemq/conf/extensions/hivemq-file-rbac-extension/config.xml /opt/hivemq/extensions/hivemq-file-rbac-extension/conf/ && \
    touch /opt/hivemq/extensions/hivemq-file-rbac-extension/DISABLED && \
    chown -R 10000 /opt/hivemq/extensions/hivemq-file-rbac-extension && \
    mkdir -p /usr/local/bin && \
    chmod +x /usr/local/bin/health_check.sh /usr/local/bin/mqtt-entrypoint.sh

USER 10000

ENTRYPOINT ["/usr/local/bin/mqtt-entrypoint.sh"]
CMD ["/opt/hivemq/bin/run.sh"]

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD /usr/local/bin/health_check.sh
