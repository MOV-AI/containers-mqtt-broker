#!/bin/sh
#
# mosquitto-entrypoint.sh - Apply the MOV.AI opt-in settings, then start Mosquitto through the base entrypoint.
#
# MQTT_AUTH_ENABLED=true
#   Requires the mounted, non-empty files /mosquitto/config/passwd and /mosquitto/config/acl.
#   If the active mosquitto.conf already has "allow_anonymous false", "password_file" and "acl_file",
#   it is used as it is (for example a config mounted by movai-service). Otherwise the entrypoint
#   builds /tmp/mosquitto-auth.conf from it (anonymous access off, the two files set) and starts
#   Mosquitto with that file. Unset or false: the config is not changed, anonymous clients are
#   accepted, as before.

set -eu

CONF=/mosquitto/config/mosquitto.conf
PASSWD=/mosquitto/config/passwd
ACL=/mosquitto/config/acl
AUTH_CONF=/tmp/mosquitto-auth.conf

fail() {
  echo "[mosquitto-entrypoint][ERROR] $1" >&2
  exit 1
}

if [ "${MQTT_AUTH_ENABLED:-false}" != "true" ]; then
  echo "[mosquitto-entrypoint] Authentication off: anonymous clients are accepted"
  exec /docker-entrypoint.sh "$@"
fi

for file in "$PASSWD" "$ACL"; do
  if [ ! -s "$file" ]; then
    echo "[mosquitto-entrypoint][ERROR] MQTT_AUTH_ENABLED=true but $file is missing or empty." >&2
    fail "Mount the passwd and acl files in /mosquitto/config (see README, \"Authentication\")."
  fi
done
[ -s "$CONF" ] || fail "MQTT_AUTH_ENABLED=true but $CONF is missing or empty."

if grep -Eq '^[[:space:]]*allow_anonymous[[:space:]]+false[[:space:]]*$' "$CONF" &&
  grep -Eq '^[[:space:]]*password_file[[:space:]]+[^[:space:]]' "$CONF" &&
  grep -Eq '^[[:space:]]*acl_file[[:space:]]+[^[:space:]]' "$CONF" &&
  ! grep -Eq '^[[:space:]]*allow_anonymous[[:space:]]+true' "$CONF"; then
  echo "[mosquitto-entrypoint] Authentication on: using the mounted $CONF"
else
  {
    printf 'allow_anonymous false\npassword_file %s\nacl_file %s\n' "$PASSWD" "$ACL"
    grep -Ev '^[[:space:]]*(allow_anonymous|password_file|acl_file)[[:space:]]' "$CONF" || true
  } >"$AUTH_CONF"
  echo "[mosquitto-entrypoint] Authentication on: anonymous access off, using $PASSWD and $ACL"
  # Replace the config path in the command (the base CMD is: mosquitto -c /mosquitto/config/mosquitto.conf)
  first=1
  for arg in "$@"; do
    if [ "$first" = 1 ]; then
      set --
      first=0
    fi
    [ "$arg" = "$CONF" ] && arg=$AUTH_CONF
    set -- "$@" "$arg"
  done
fi

exec /docker-entrypoint.sh "$@"
