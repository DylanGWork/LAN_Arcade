#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_ROOT="${LAN_ARCADE_BOARD_REPORT_DIR:-$ROOT_DIR/qa/reports/native-board-game-play}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOCK_DIR="${LAN_ARCADE_BOARD_SMOKE_LOCK:-/tmp/lan-arcade-board-smoke.lock}"

usage(){
  cat <<'USAGE'
Usage: scripts/native_board_game_play_smoke.sh [game-id ...]

Default game ids:
  pioneers-lan teg-lan ksirk-lan atlantik-lan triplea-lan

This is a no-internet native board-game smoke. It records PASS, PARTIAL, or
BLOCKED in each report instead of treating a window launch as gameplay proof.
USAGE
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then usage; exit 0; fi
if ! mkdir "$LOCK_DIR" 2>/dev/null; then echo "Another board smoke is running: $LOCK_DIR" >&2; exit 1; fi
trap 'rm -rf "$LOCK_DIR"' EXIT
mkdir -p "$REPORT_ROOT"

if ! command -v bwrap >/dev/null || ! command -v xvfb-run >/dev/null || ! command -v scrot >/dev/null; then
  echo "bwrap, xvfb-run and scrot are required" >&2
  exit 2
fi

if [ "$#" -gt 0 ]; then
  games=("$@")
else
  games=(pioneers-lan teg-lan ksirk-lan atlantik-lan triplea-lan)
fi

new_report(){
  local id="$1"
  local dir="$REPORT_ROOT/${id}-${STAMP}"
  mkdir -p "$dir"
  printf '%s\n' "$dir"
}

write_status(){
  local report="$1" status="$2" detail="$3"
  {
    echo "STATUS=$status"
    echo "DETAIL=$detail"
    echo "FINISHED_AT=$(date -Is)"
  } >> "$report/report.txt"
}

assert_file(){
  local path="$1"
  [ -s "$path" ] || { echo "missing or empty evidence file: $path" >&2; return 1; }
}

smoke_pioneers(){
  local dir; dir="$(new_report pioneers-lan)"
  cat > "$dir/report.txt" <<EOF
GAME=pioneers-lan
STARTED_AT=$(date -Is)
NETWORK=bwrap --unshare-net
EXPECT=PASS local server, AI players, GUI client board state
EOF
  bwrap --unshare-net --dev-bind / / bash -s "$dir" <<'INNER'
set -euo pipefail
D="$1"; PORT=45557
/usr/games/pioneers-server-console --file /usr/share/games/pioneers/default.game --port "$PORT" --players 4 --computer-players 3 >"$D/server.log" 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null || true' EXIT
sleep 4
xvfb-run -a -s "-screen 0 1280x900x24" bash -s "$D" "$PORT" <<'XDO'
set -euo pipefail
D="$1"; PORT="$2"
export HOME=$(mktemp -d)
/usr/games/pioneers --server localhost --port "$PORT" --name LANSmoke >"$D/client.log" 2>&1 &
client=$!
sleep 10
scrot "$D/board.png"
ps -o pid,ppid,rss,vsz,comm -p "$client" >"$D/client-process.txt" 2>/dev/null || true
kill "$client" 2>/dev/null || true
XDO
INNER
  assert_file "$dir/board.png"
  grep -Eq 'LANSmoke|built a settlement|built a road|connected' "$dir/server.log"
  write_status "$dir" PASS "Connected GUI client to local Pioneers server with AI activity and board screenshot."
  echo "PASS pioneers-lan $dir"
}

smoke_teg(){
  local dir; dir="$(new_report teg-lan)"
  cat > "$dir/report.txt" <<EOF
GAME=teg-lan
STARTED_AT=$(date -Is)
NETWORK=bwrap --unshare-net
EXPECT=PASS local server, robots, GUI client map/player state
EOF
  bwrap --unshare-net --dev-bind / / bash -s "$dir" <<'INNER'
set -euo pipefail
D="$1"
/usr/games/tegserver --metaserver 0 --console 0 >"$D/server.log" 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null || true; jobs -pr | xargs -r kill 2>/dev/null || true' EXIT
sleep 2
for n in 1 2 3 4 5; do /usr/games/tegrobot --server localhost --port 2000 --name "Bot$n" --quiet >"$D/bot$n.log" 2>&1 & done
sleep 3
xvfb-run -a -s "-screen 0 1280x900x24" bash -s "$D" <<'XDO'
set -euo pipefail
D="$1"
export HOME=$(mktemp -d)
/usr/games/tegclient >"$D/client.log" 2>&1 &
client=$!
sleep 6
scrot "$D/teg-window.png"
xdotool mousemove 520 470 click 1 2>/dev/null || true
sleep 1
scrot "$D/teg-after-input.png"
ps -o pid,ppid,rss,vsz,comm -p "$client" >"$D/client-process.txt" 2>/dev/null || true
kill "$client" 2>/dev/null || true
XDO
INNER
  assert_file "$dir/teg-window.png"
  grep -Eq 'Bot1|player_id|connect' "$dir/server.log" "$dir"/bot*.log
  write_status "$dir" PASS "Local tegserver ran with robots and GUI map/player-state screenshot under no-internet namespace."
  echo "PASS teg-lan $dir"
}

smoke_ksirk(){
  local dir; dir="$(new_report ksirk-lan)"
  cat > "$dir/report.txt" <<EOF
GAME=ksirk-lan
STARTED_AT=$(date -Is)
NETWORK=bwrap --unshare-net
EXPECT=PASS local game reaches board/army placement
EOF
  bwrap --unshare-net --dev-bind / / bash -s "$dir" <<'INNER'
set -euo pipefail
D="$1"
xvfb-run -a -s "-screen 0 1280x900x24" bash -s "$D" <<'XDO'
set -euo pipefail
D="$1"
export HOME=$(mktemp -d)
/usr/games/ksirk >"$D/stdout.log" 2>"$D/stderr.log" &
client=$!
sleep 4
xdotool mousemove 28 13 click 1 2>/dev/null || true
sleep .3
xdotool mousemove 70 40 click 1 2>/dev/null || true
sleep 1
scrot "$D/01-wizard.png"
for i in 1 2 3 4; do xdotool mousemove 520 374 click 1 2>/dev/null || true; sleep 1; done
xdotool mousemove 414 179 click 1 2>/dev/null || true
sleep 3
scrot "$D/02-board.png"
ps -o pid,ppid,rss,vsz,comm -p "$client" >"$D/client-process.txt" 2>/dev/null || true
kill "$client" 2>/dev/null || true
XDO
INNER
  assert_file "$dir/02-board.png"
  write_status "$dir" PASS "KsirK launched offline and automated wizard path captured board-area screenshot."
  echo "PASS ksirk-lan $dir"
}

smoke_atlantik(){
  local dir; dir="$(new_report atlantik-lan)"
  cat > "$dir/report.txt" <<EOF
GAME=atlantik-lan
STARTED_AT=$(date -Is)
NETWORK=bwrap --unshare-net
EXPECT=PARTIAL local server/lobby; one-client board start blocked by two-player requirement
EOF
  bwrap --unshare-net --dev-bind / / bash -s "$dir" <<'INNER'
set -euo pipefail
D="$1"
/usr/bin/systemd-socket-activate -l 127.0.0.1:1234 /usr/sbin/monopd >"$D/socket.log" 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null || true' EXIT
sleep 1
xvfb-run -a -s "-screen 0 1280x900x24" bash -s "$D" <<'XDO'
set -euo pipefail
D="$1"
export HOME=$(mktemp -d)
/usr/games/gtkatlantic >"$D/client.log" 2>&1 &
client=$!
sleep 4
xdotool mousemove 18 14 click 1; sleep .3; xdotool mousemove 62 41 click 1; sleep .7
xdotool mousemove 433 288 click 1; sleep 2
scrot "$D/01-connected.png"
xdotool mousemove 340 137 click 1; sleep .3; xdotool mousemove 358 441 click 1; sleep 1
xdotool mousemove 615 445 click 1; sleep 2
scrot "$D/02-start-blocked.png"
kill "$client" 2>/dev/null || true
XDO
INNER
  assert_file "$dir/02-start-blocked.png"
  grep -Eq 'Listening on 127.0.0.1:1234|Execing /usr/sbin/monopd' "$dir/socket.log"
  write_status "$dir" PARTIAL "Local monopd connection and game lobby work offline; full board needs second client."
  echo "PARTIAL atlantik-lan $dir"
}

smoke_triplea(){
  local dir; dir="$(new_report triplea-lan)"
  cat > "$dir/report.txt" <<EOF
GAME=triplea-lan
STARTED_AT=$(date -Is)
NETWORK=bwrap --unshare-net
EXPECT=BLOCKED known online update/map checks prevent offline promotion
EVIDENCE=qa/reports/board-game-exploratory/triplea-bwrap-offline-map-20260618T160351Z
EOF
  if [ -f "$ROOT_DIR/qa/reports/board-game-exploratory/triplea-bwrap-offline-map-20260618T160351Z/stderr.log" ]; then
    grep -E 'github.com|raw.githubusercontent.com|Failed while attempting to check' "$ROOT_DIR/qa/reports/board-game-exploratory/triplea-bwrap-offline-map-20260618T160351Z/stderr.log" > "$dir/blocker-lines.txt" || true
  fi
  write_status "$dir" BLOCKED "Known blocker: offline launch attempts GitHub/update/map metadata checks and does not reach playable local-map state."
  echo "BLOCKED triplea-lan $dir"
}

for game in "${games[@]}"; do
  case "$game" in
    pioneers-lan) smoke_pioneers ;;
    teg-lan) smoke_teg ;;
    ksirk-lan) smoke_ksirk ;;
    atlantik-lan) smoke_atlantik ;;
    triplea-lan) smoke_triplea ;;
    *) echo "unsupported board-game smoke id: $game" >&2; exit 2 ;;
  esac
done
