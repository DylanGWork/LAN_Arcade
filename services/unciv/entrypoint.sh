#!/bin/sh
set -eu

SERVER_PORT=${UNCIV_PORT:-8090}
DATA_DIR=${UNCIV_DATA_DIR:-/var/lib/unciv/MultiplayerFiles}

mkdir -p "$DATA_DIR"

# UNCIV_JAVA_OPTS is intentionally word-split so deploys can pass normal JVM flags.
# shellcheck disable=SC2086
exec java ${UNCIV_JAVA_OPTS:-} -jar /opt/unciv/UncivServer.jar -p "$SERVER_PORT" -f "$DATA_DIR"
