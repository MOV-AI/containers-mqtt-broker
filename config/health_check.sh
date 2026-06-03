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
# Expected: 20 02 00 00
# 20 = CONNACK packet type
# 02 = Remaining length (2)
# 00 00 = Return code 0 (connection accepted)
resp=$(dd bs=1 count=4 <&3 2>/dev/null | od -An -tx1 -v | tr -d " \n")

# Close socket
exec 3>&-

# Validate CONNACK success
if [ "$resp" = "20020000" ]; then
    exit 0
else
    exit 1
fi
