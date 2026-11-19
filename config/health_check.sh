#!/bin/bash
# MQTT Healthcheck: Connect to broker, send CONNECT frame, validate CONNACK response
# Usage: /usr/local/bin/health_check.sh [host] [port]

HOST="${1:-127.0.0.1}"
PORT="${2:-1883}"

# Open TCP socket to broker
exec 3<>/dev/tcp/"$HOST"/"$PORT" || exit 1

# Send MQTT 3.1.1 CONNECT packet
# Frame: 10 0E 00 04 MQTT 04 02 00 05 00 02 hc
# 10 = CONNECT packet type
# 0E = Remaining length (14 bytes)
# 00 04 = Protocol name length (4)
# MQTT = Protocol name
# 04 = Protocol version (3.1.1)
# 02 = Connect flags (clean session)
# 00 05 = Keep alive (5 seconds)
# 00 02 = Client ID length (2)
# hc = Client ID ("hc")
printf "\x10\x0e\x00\x04MQTT\x04\x02\x00\x05\x00\x02hc" >&3

# Read CONNACK response (4 bytes)
# Expected: 20 02 xx yy
# 20 = CONNACK packet type
# 02 = Remaining length (2)
# xx = Session present flag
# yy = Return code: 00 accepted, 04 bad user name or password, 05 not authorised.
#      MQTT_AUTH_ENABLED=true: this anonymous probe must be refused (04 or 05). An accepted probe
#      means authentication is not enforced, so the broker is reported unhealthy.
#      Otherwise: the probe must be accepted (00), as in 1.2.2.
resp=$(dd bs=1 count=4 <&3 2>/dev/null | od -An -tx1 -v | tr -d " \n")

# Close socket
exec 3>&-

# Validate the CONNACK against the authentication mode
if [ "${MQTT_AUTH_ENABLED:-false}" = "true" ]; then
    case "$resp" in
        2002??04 | 2002??05) exit 0 ;;
        *) exit 1 ;;
    esac
fi
case "$resp" in
    2002??00) exit 0 ;;
    *) exit 1 ;;
esac
