#!/bin/sh
#
# mosquitto-entrypoint.sh - Apply the MOV.AI opt-in settings, then start Mosquitto through the base entrypoint.
#
# MQTT_AUTH_ENABLED=true
#   Needs the mounted, non-empty files /mosquitto/config/passwd and /mosquitto/config/acl.
#   The entrypoint runs as root, before the base image drops privileges. It then:
#     1. copies passwd and acl into a private folder (/run/mosquitto-auth) that belongs to the
#        mosquitto user, mode 0700, files 0600. The folder is not in a volume, so credentials never
#        reach the data volume. The mounted originals are only read, never changed.
#        Mosquitto warns about, and a later version refuses, a password or acl file that is
#        world readable or not owned by the broker user: the copies are neither.
#     2. writes /run/mosquitto-auth/mosquitto.conf: the active mosquitto.conf without its
#        allow_anonymous, password_file and acl_file lines, followed by "allow_anonymous false",
#        "password_file" and "acl_file" (pointing at the copies). Mosquitto keeps the last global
#        value, so these lines also win over an included file (include_dir).
#     3. starts Mosquitto with that file instead of /mosquitto/config/mosquitto.conf.
#   The files are read when the container starts. To change a password or an ACL, restart the
#   container (movai-service recreates the broker when they change).
#   The entrypoint expects global security settings. It stops with an error when the config
#   (or a file in an include_dir folder) sets "per_listener_settings true".
#   Unset or false: the config is not changed, anonymous clients are accepted, as before.

set -eu

CONF=/mosquitto/config/mosquitto.conf
PASSWD=/mosquitto/config/passwd
ACL=/mosquitto/config/acl
AUTH_DIR=/run/mosquitto-auth
BROKER_USER=mosquitto

fail() {
  echo "[mosquitto-entrypoint][ERROR] $1" >&2
  exit 1
}

if [ "${MQTT_AUTH_ENABLED:-false}" != "true" ]; then
  echo "[mosquitto-entrypoint] Authentication off: anonymous clients are accepted"
  exec /docker-entrypoint.sh "$@"
fi

for file in "$PASSWD" "$ACL"; do
  [ -s "$file" ] ||
    fail "MQTT_AUTH_ENABLED=true but $file is missing or empty. Mount the passwd and acl files in /mosquitto/config (see README, \"Authentication\")."
done
[ -s "$CONF" ] || fail "MQTT_AUTH_ENABLED=true but $CONF is missing or empty."

# The command must use the active config, or the settings below would not apply
found=0
for arg in "$@"; do
  [ "$arg" = "$CONF" ] && found=1
done
[ "$found" = 1 ] || fail "MQTT_AUTH_ENABLED=true needs the broker to start with -c $CONF, but the command is: $*"

# Files that can set security options: the config and every file in its include_dir folders
sources=$CONF
include_dirs=$(sed -n 's/^[[:space:]]*include_dir[[:space:]][[:space:]]*\([^[:space:]]*\).*/\1/p' "$CONF")
# shellcheck disable=SC2086  # the paths have no spaces
for dir in $include_dirs; do
  [ -d "$dir" ] && sources="$sources $(find "$dir" -type f | tr '\n' ' ')"
done
# shellcheck disable=SC2086  # the paths have no spaces
if grep -Eqs '^[[:space:]]*per_listener_settings[[:space:]]+true' $sources; then
  fail "MQTT_AUTH_ENABLED=true does not work with per_listener_settings true (in $CONF or an include_dir file): the entrypoint sets global security options. Remove per_listener_settings."
fi

# Private, non-persistent copies owned by the broker user (see the header)
if [ "$(id -u)" != 0 ]; then
  BROKER_USER=$(id -un)
  AUTH_DIR=/tmp/mosquitto-auth # /run is writable only by root
fi
rm -rf "$AUTH_DIR"
(umask 077 && mkdir -p "$AUTH_DIR") || fail "Cannot create $AUTH_DIR"
for file in "$PASSWD" "$ACL"; do
  (umask 077 && cp "$file" "$AUTH_DIR/$(basename "$file")") || fail "Cannot read $file"
done

AUTH_CONF=$AUTH_DIR/mosquitto.conf
{
  grep -Ev '^[[:space:]]*(allow_anonymous|password_file|acl_file)([[:space:]]|$)' "$CONF" || true
  printf '\n# Added by mosquitto-entrypoint.sh (MQTT_AUTH_ENABLED=true). The last value wins.\n'
  printf 'allow_anonymous false\npassword_file %s/passwd\nacl_file %s/acl\n' "$AUTH_DIR" "$AUTH_DIR"
} >"$AUTH_CONF"
chmod 600 "$AUTH_CONF"
chmod 700 "$AUTH_DIR"
if [ "$(id -u)" = 0 ]; then
  chown -R "$BROKER_USER:$BROKER_USER" "$AUTH_DIR" || fail "Cannot give $AUTH_DIR to $BROKER_USER"
fi

echo "[mosquitto-entrypoint] Authentication on: anonymous access off, passwd and acl copied to $AUTH_DIR (owner $BROKER_USER, read at start)"

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

exec /docker-entrypoint.sh "$@"
