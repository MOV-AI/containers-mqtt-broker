#!/usr/bin/env bash
#
# mqtt-entrypoint.sh - Apply the MOV.AI opt-in settings, then start HiveMQ through the base entrypoint.
#
# MQTT_AUTH_ENABLED=true
#   Turns on the File RBAC extension and turns off the allow-all extension. Every client must then
#   log in with a user from the mounted credentials file. Unset or false: anonymous clients are
#   accepted, as in 1.2.2.

set -euo pipefail

RBAC_DIR=/opt/hivemq/extensions/hivemq-file-rbac-extension
CREDENTIALS="$RBAC_DIR/conf/credentials.xml"

if [[ "${MQTT_AUTH_ENABLED:-false}" == "true" ]]; then
  if [[ ! -s "$CREDENTIALS" ]]; then
    echo "[mqtt-entrypoint][ERROR] MQTT_AUTH_ENABLED=true but $CREDENTIALS is missing or empty." >&2
    echo "[mqtt-entrypoint][ERROR] Mount a credentials file there (see README, \"Authentication\")." >&2
    exit 1
  fi
  echo "[mqtt-entrypoint] Authentication on: File RBAC extension enabled, allow-all extension disabled"
  rm -f "$RBAC_DIR/DISABLED"
  # The base entrypoint removes the allow-all extension unless this is "true"
  export HIVEMQ_ALLOW_ALL_CLIENTS=false
else
  echo "[mqtt-entrypoint] Authentication off: anonymous clients are accepted"
  touch "$RBAC_DIR/DISABLED"
fi

exec /opt/docker-entrypoint.sh "$@"
