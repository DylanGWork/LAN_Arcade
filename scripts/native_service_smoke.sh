#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_ID="${1:-}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_ROOT="${LAN_ARCADE_SERVICE_REPORT_DIR:-$ROOT_DIR/qa/reports/service-smoke}"
LOCK_DIR="${LAN_ARCADE_SERVICE_SMOKE_LOCK:-/tmp/lan-arcade-native-service-smoke.lock}"

usage() {
  cat <<'USAGE'
Usage: scripts/native_service_smoke.sh <service-id>

Supported service ids:
  openttd-lan            Start an OpenTTD dedicated server, verify TCP, record memory, stop.
  freeciv-lan            Start a Freeciv server, verify TCP, record memory, stop.
  wesnoth-lan            Start a Wesnoth server, verify TCP, record memory, stop.
  teeworlds-ddnet-lan    Start a DDNet server, verify UDP listen, record memory, stop.
  luanti-lan             Start a Luanti/Minetest server, verify UDP listen, record memory, stop.
  hedgewars-lan          Record client-hosted/server-source status.
  widelands-lan          Record client-hosted multiplayer status.
  warzone2100-lan        Record headless/autohost research status.
  veloren-lan            Verify cached Airshipper artifact and record current VM compatibility.
  stendhal-lan           Verify cached Stendhal ZIP integrity and record launch/server status.

This is a smoke test, not a full gameplay proof. Client join/play tests must add
screenshots or protocol-level assertions on top of this script.
USAGE
}

if [ -z "$SERVICE_ID" ] || [ "$SERVICE_ID" = "--help" ] || [ "$SERVICE_ID" = "-h" ]; then
  usage
  exit 0
fi

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Another native-service smoke appears to be running: $LOCK_DIR" >&2
  exit 1
fi
trap 'rm -rf "$LOCK_DIR"' EXIT

REPORT_DIR="$REPORT_ROOT/${SERVICE_ID}-${STAMP}"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/report.txt"

log() { printf '%s
' "$*" | tee -a "$REPORT" >/dev/null; }
need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "MISSING_COMMAND=$1"
    exit 2
  fi
}
check_tcp() {
  local host="$1" port="$2"
  if nc -z "$host" "$port"; then
    log "TCP_CONNECT=pass host=$host port=$port"
  else
    log "TCP_CONNECT=fail host=$host port=$port"
    return 1
  fi
}
check_udp_listen() {
  local port="$1"
  if ss -lunp | grep -q ":$port"; then
    log "UDP_LISTEN=pass port=$port"
  else
    log "UDP_LISTEN=fail port=$port"
    return 1
  fi
}
record_process() {
  local pid="$1"
  ps -o pid,ppid,rss,vsz,comm -p "$pid" >> "$REPORT" || true
}
stop_pid() {
  local pid="$1"
  kill "$pid" 2>/dev/null || true
  sleep 1
  kill -9 "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

log "SERVICE_ID=$SERVICE_ID"
log "STARTED_AT=$(date -Is)"
log "REPORT_DIR=$REPORT_DIR"

case "$SERVICE_ID" in
  openttd-lan)
    need_cmd openttd; need_cmd nc; need_cmd ss
    PORT="${LAN_ARCADE_OPENTTD_PORT:-3979}"
    HOME_DIR="$REPORT_DIR/home"
    mkdir -p "$HOME_DIR"
    log "COMMAND=HOME=$HOME_DIR openttd -D 127.0.0.1:$PORT -g -v dedicated -s null -m null -x"
    HOME="$HOME_DIR" openttd -D "127.0.0.1:$PORT" -g -v dedicated -s null -m null -x > "$REPORT_DIR/server.log" 2>&1 &
    PID=$!
    echo "$PID" > "$REPORT_DIR/pid"
    sleep 6
    record_process "$PID"
    ss -ltnup | grep ":$PORT" > "$REPORT_DIR/ports.txt" || true
    check_tcp 127.0.0.1 "$PORT"
    stop_pid "$PID"
    log "STOPPED=yes"
    ;;
  freeciv-lan)
    need_cmd freeciv-server; need_cmd nc; need_cmd ss
    PORT="${LAN_ARCADE_FREECIV_PORT:-5556}"
    log "COMMAND=freeciv-server --bind 127.0.0.1 --Announce none --port $PORT --quitidle 10"
    freeciv-server --bind 127.0.0.1 --Announce none --port "$PORT" --quitidle 10 --log "$REPORT_DIR/server.log" > "$REPORT_DIR/stdout.log" 2>&1 &
    PID=$!
    echo "$PID" > "$REPORT_DIR/pid"
    sleep 5
    record_process "$PID"
    ss -ltnup | grep ":$PORT" > "$REPORT_DIR/ports.txt" || true
    check_tcp 127.0.0.1 "$PORT"
    stop_pid "$PID"
    log "STOPPED=yes"
    ;;
  wesnoth-lan)
    need_cmd /usr/games/wesnothd-1.16; need_cmd nc; need_cmd ss
    PORT="${LAN_ARCADE_WESNOTH_PORT:-15000}"
    log "COMMAND=/usr/games/wesnothd-1.16 --port $PORT --threads 1 --verbose"
    /usr/games/wesnothd-1.16 --port "$PORT" --threads 1 --verbose > "$REPORT_DIR/server.log" 2>&1 &
    PID=$!
    echo "$PID" > "$REPORT_DIR/pid"
    sleep 5
    record_process "$PID"
    ss -ltnup | grep ":$PORT" > "$REPORT_DIR/ports.txt" || true
    check_tcp 127.0.0.1 "$PORT"
    stop_pid "$PID"
    log "STOPPED=yes"
    if grep -qi 'could not make fifo' "$REPORT_DIR/server.log"; then
      log "WARN=wesnoth_fifo_path_missing_nonfatal_for_tcp_smoke"
    fi
    ;;
  teeworlds-ddnet-lan)
    need_cmd /usr/games/DDNet-Server; need_cmd ss
    PORT="${LAN_ARCADE_DDNET_PORT:-8303}"
    HOME_DIR="$REPORT_DIR/home"
    mkdir -p "$HOME_DIR"
    cat > "$REPORT_DIR/server.cfg" <<EOF
sv_name LAN Arcade DDNet Smoke
sv_port $PORT
sv_register 0
sv_rcon_password smoke
EOF
    log "COMMAND=HOME=$HOME_DIR /usr/games/DDNet-Server -f $REPORT_DIR/server.cfg"
    HOME="$HOME_DIR" /usr/games/DDNet-Server -f "$REPORT_DIR/server.cfg" > "$REPORT_DIR/server.log" 2>&1 &
    PID=$!
    echo "$PID" > "$REPORT_DIR/pid"
    sleep 5
    record_process "$PID"
    ss -lunp | grep ":$PORT" > "$REPORT_DIR/ports.txt" || true
    check_udp_listen "$PORT"
    stop_pid "$PID"
    log "STOPPED=yes"
    ;;
  luanti-lan)
    need_cmd /usr/games/minetestserver; need_cmd ss
    PORT="${LAN_ARCADE_LUANTI_PORT:-30000}"
    HOME_DIR="$REPORT_DIR/home"
    WORLD_DIR="$REPORT_DIR/world"
    mkdir -p "$HOME_DIR" "$WORLD_DIR"
    cat > "$REPORT_DIR/minetest.conf" <<EOF
server_name = LAN Arcade Luanti Smoke
server_announce = false
default_game = minetest_game
motd = LAN Arcade smoke test
EOF
    log "COMMAND=HOME=$HOME_DIR /usr/games/minetestserver --world $WORLD_DIR --gameid minetest_game --port $PORT --config $REPORT_DIR/minetest.conf --logfile $REPORT_DIR/server.log"
    HOME="$HOME_DIR" /usr/games/minetestserver --world "$WORLD_DIR" --gameid minetest_game --port "$PORT" --config "$REPORT_DIR/minetest.conf" --logfile "$REPORT_DIR/server.log" > "$REPORT_DIR/stdout.log" 2>&1 &
    PID=$!
    echo "$PID" > "$REPORT_DIR/pid"
    sleep 6
    record_process "$PID"
    ss -lunp | grep ":$PORT" > "$REPORT_DIR/ports.txt" || true
    check_udp_listen "$PORT"
    stop_pid "$PID"
    log "STOPPED=yes"
    ;;
  hedgewars-lan)
    need_cmd /usr/games/hedgewars
    log "SERVER_SMOKE=not_applicable_client_hosts_lobby_or_uses_server_source"
    dpkg -s hedgewars | grep '^Version:' >> "$REPORT" || true
    ;;
  widelands-lan)
    need_cmd /usr/games/widelands
    log "SERVER_SMOKE=not_applicable_client_hosted_multiplayer"
    dpkg -s widelands | grep '^Version:' >> "$REPORT" || true
    ;;
  warzone2100-lan)
    need_cmd /usr/games/warzone2100
    log "SERVER_SMOKE=pending_headless_autohost_needs_saved_settings"
    /usr/games/warzone2100 --help > "$REPORT_DIR/warzone-help.txt" 2>&1 || true
    dpkg -s warzone2100 | grep '^Version:' >> "$REPORT" || true
    ;;
  veloren-lan)
    ARTIFACT="/var/www/html/mirrors/veloren/downloads/airshipper-linux-x86_64.zip"
    [ -f "$ARTIFACT" ] || { log "MISSING_ARTIFACT=$ARTIFACT"; exit 2; }
    sha256sum "$ARTIFACT" | tee "$REPORT_DIR/SHA256SUMS.txt" >> "$REPORT"
    unzip -l "$ARTIFACT" > "$REPORT_DIR/unzip-list.txt"
    mkdir -p "$REPORT_DIR/extract"
    unzip -q "$ARTIFACT" -d "$REPORT_DIR/extract"
    chmod +x "$REPORT_DIR/extract/airshipper" || true
    set +e
    "$REPORT_DIR/extract/airshipper" --version > "$REPORT_DIR/airshipper-version.txt" 2>&1
    STATUS=$?
    set -e
    cat "$REPORT_DIR/airshipper-version.txt" >> "$REPORT"
    if [ "$STATUS" -eq 0 ]; then
      log "AIRSHIPPER_EXEC=pass"
    else
      log "AIRSHIPPER_EXEC=blocked status=$STATUS"
      if grep -q 'GLIBC_2\.3[89]' "$REPORT_DIR/airshipper-version.txt"; then
        log "BLOCKER=latest_airshipper_requires_newer_glibc_than_debian_12"
      fi
      exit 2
    fi
    ;;
  stendhal-lan)
    ARTIFACT="/var/www/html/mirrors/stendhal/stendhal.zip"
    [ -f "$ARTIFACT" ] || { log "MISSING_ARTIFACT=$ARTIFACT"; exit 2; }
    unzip -t "$ARTIFACT" > "$REPORT_DIR/unzip-test.txt"
    unzip -l "$ARTIFACT" > "$REPORT_DIR/unzip-list.txt"
    sha256sum "$ARTIFACT" | tee "$REPORT_DIR/SHA256SUMS.txt" >> "$REPORT"
    log "ARTIFACT_ZIP_TEST=pass"
    log "SERVER_SMOKE=pending; cached ZIP appears client-focused"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

log "FINISHED_AT=$(date -Is)"
printf '%s
' "$REPORT_DIR"
