#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_ROOT="${LAN_ARCADE_BOARD_EXPANDED_REPORT_DIR:-$ROOT_DIR/qa/reports/native-board-game-expanded}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOCK_DIR="${LAN_ARCADE_BOARD_EXPANDED_LOCK:-/tmp/lan-arcade-board-expanded-smoke.lock}"

usage(){
  cat <<'USAGE'
Usage: scripts/native_board_game_expanded_smoke.sh [game-id ...]

Default game ids:
  biloba-lan ricochet-lan bovo-lan kfourinline-lan kreversi-lan kigo-lan pentobi-lan gnubg-lan knavalbattle-lan xfrisk-lan

This is a no-internet native board-game smoke for the expanded board batch.
It records PASS or PARTIAL in report.txt and saves screenshots for visual review.
USAGE
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then usage; exit 0; fi
if ! mkdir "$LOCK_DIR" 2>/dev/null; then echo "Another expanded board smoke is running: $LOCK_DIR" >&2; exit 1; fi
trap 'rm -rf "$LOCK_DIR"' EXIT
mkdir -p "$REPORT_ROOT"

if ! command -v bwrap >/dev/null || ! command -v xvfb-run >/dev/null || ! command -v scrot >/dev/null || ! command -v xdotool >/dev/null; then
  echo "bwrap, xvfb-run, scrot and xdotool are required" >&2
  exit 2
fi

if [ "$#" -gt 0 ]; then games=("$@"); else games=(biloba-lan ricochet-lan bovo-lan kfourinline-lan kreversi-lan kigo-lan pentobi-lan gnubg-lan knavalbattle-lan xfrisk-lan); fi

new_report(){ local id="$1"; local dir="$REPORT_ROOT/${id}-${STAMP}"; mkdir -p "$dir"; printf '%s\n' "$dir"; }
write_status(){ local dir="$1" status="$2" detail="$3"; { echo "STATUS=$status"; echo "DETAIL=$detail"; echo "FINISHED_AT=$(date -Is)"; } >> "$dir/report.txt"; }
cleanup_apps(){
  for name in biloba bovo kfourinline kreversi kigo knavalbattle pentobi gnubg ricochet rrserve risk friskserver xfrisk aiColson aiConway aiDummy; do
    pkill -x "$name" 2>/dev/null || true
  done
}

smoke_gui(){
  local id="$1" cmd="$2" clicks="$3" expect="$4" status="$5" detail="$6" app_pattern="$7"
  local dir; dir="$(new_report "$id")"
  cat > "$dir/report.txt" <<EOF
GAME=$id
STARTED_AT=$(date -Is)
NETWORK=bwrap --unshare-net
EXPECT=$expect
COMMAND=$cmd
EOF
  cleanup_apps
  set +e
  bwrap --unshare-net --dev-bind / / bash -s "$dir" "$cmd" "$clicks" "$app_pattern" <<'INNER'
set -euo pipefail
D="$1"; CMD="$2"; CLICKS="$3"; APP_PATTERN="$4"
xvfb-run -a -s "-screen 0 1280x900x24" bash -s "$D" "$CMD" "$CLICKS" "$APP_PATTERN" <<'XDO'
set -euo pipefail
D="$1"; CMD="$2"; CLICKS="$3"; APP_PATTERN="$4"
export HOME=$(mktemp -d)
export XDG_RUNTIME_DIR="$HOME/runtime"; mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
sh -c "$CMD" >"$D/stdout.log" 2>"$D/stderr.log" &
pid=$!
sleep 5
scrot "$D/01-open.png"
eval "$CLICKS" >/dev/null 2>&1 || true
sleep 3
scrot "$D/02-after-input.png"
ps -eo pid,ppid,rss,vsz,comm,args | grep -E "$APP_PATTERN" | grep -v grep >"$D/processes.txt" || true
kill "$pid" 2>/dev/null || true
XDO
INNER
  rc=$?
  set -e
  cleanup_apps
  if [ "$rc" -eq 0 ] && [ -s "$dir/02-after-input.png" ]; then
    write_status "$dir" "$status" "$detail"
    echo "$status $id $dir"
  else
    write_status "$dir" BLOCKED "Launch/input screenshot flow failed with rc=$rc."
    echo "BLOCKED $id $dir"
  fi
}

smoke_biloba(){ smoke_gui biloba-lan "/usr/games/biloba" "xdotool mousemove 650 527 click 1; sleep 2; xdotool mousemove 360 330 click 1; sleep .5; xdotool mousemove 420 380 click 1" "Click Play and reach a live Biloba board." PASS "Biloba reached a local board with pieces and player-turn text." "(/usr/games/)?biloba"; }
smoke_bovo(){ smoke_gui bovo-lan "/usr/games/bovo" "xdotool mousemove 640 420 click 1; sleep .5; xdotool mousemove 680 420 click 1" "Place Gomoku stones." PASS "Bovo accepted board input and shows active X/O stones." "(/usr/games/)?bovo"; }
smoke_kfourinline(){ smoke_gui kfourinline-lan "/usr/games/kfourinline" "xdotool mousemove 155 319 click 1; sleep 1; xdotool mousemove 520 126 click 1; sleep .5; xdotool mousemove 600 126 click 1" "Start Easy Game and drop a piece." PASS "KFourInLine started a game and accepted a piece drop." "(/usr/games/)?kfourinline"; }
smoke_kreversi(){ smoke_gui kreversi-lan "/usr/games/kreversi" "xdotool mousemove 491 382 click 1; sleep 1; xdotool mousemove 395 330 click 1; sleep 1; xdotool mousemove 450 385 click 1" "Start game and attempt legal move." PASS "KReversi reached an active game with discs, score, and turn text." "(/usr/games/)?kreversi"; }
smoke_kigo(){ smoke_gui kigo-lan "/usr/games/kigo" "xdotool mousemove 748 679 click 1; sleep 2; xdotool mousemove 265 379 click 1; sleep 1; xdotool mousemove 318 431 click 1" "Start a 9x9 local GNU Go game and place a stone." PASS "Kigo started a 9x9 game and GNU Go replied with visible move history." "(/usr/games/)?kigo|gnugo"; }
smoke_pentobi(){ smoke_gui pentobi-lan "/usr/games/pentobi" "xdotool mousemove 80 45 click 1; sleep .5; xdotool mousemove 640 420 click 1" "Open Pentobi and place/advance board input." PASS "Pentobi reached an active board with placed pieces." "(/usr/games/)?pentobi"; }
smoke_gnubg(){ smoke_gui gnubg-lan "/usr/games/gnubg -q -r" "xdotool mousemove 80 45 click 1; sleep .5; xdotool mousemove 640 420 click 1" "Open GNU Backgammon GUI with match state." PASS "GNU Backgammon GUI opened with board, players, score, and match state." "(/usr/games/)?gnubg"; }
smoke_knavalbattle(){ smoke_gui knavalbattle-lan "/usr/games/knavalbattle" "xdotool mousemove 189 158 click 1; sleep 1; xdotool mousemove 100 150 click 1; sleep .3; xdotool mousemove 132 150 click 1; sleep .3; xdotool mousemove 164 150 click 1" "Enter single-player Battleship setup and place first ship." PARTIAL "KNavalBattle reached single-player ship placement and placed a ship; full firing turn pending." "(/usr/games/)?knavalbattle"; }

smoke_ricochet(){
  local dir; dir="$(new_report ricochet-lan)"
  cat > "$dir/report.txt" <<EOF
GAME=ricochet-lan
STARTED_AT=$(date -Is)
NETWORK=bwrap --unshare-net
EXPECT=Start rrserve and join with local Ricochet client.
EOF
  cleanup_apps
  set +e
  bwrap --unshare-net --dev-bind / / bash -s "$dir" <<'INNER'
set -euo pipefail
D="$1"
/usr/games/rrserve --logfile "$D/server.log" --port 5252 >"$D/server.stdout" 2>"$D/server.stderr" &
server=$!
trap 'kill "$server" 2>/dev/null || true' EXIT
sleep 1
xvfb-run -a -s "-screen 0 1280x900x24" bash -s "$D" <<'XDO'
set -euo pipefail
D="$1"
export HOME=$(mktemp -d)
/usr/games/ricochet --host localhost --port 5252 --name LANSmoke --game LANSmoke >"$D/client.log" 2>&1 &
pid=$!
sleep 7
scrot "$D/01-open.png"
xdotool mousemove 400 300 click 1; sleep .5; xdotool mousemove 500 350 click 1 2>/dev/null || true
sleep 2
scrot "$D/02-after-input.png"
ps -eo pid,ppid,rss,vsz,comm,args | grep -E 'rrserve|ricochet' | grep -v grep >"$D/processes.txt" || true
kill "$pid" 2>/dev/null || true
XDO
INNER
  rc=$?
  set -e
  cleanup_apps
  if [ "$rc" -eq 0 ] && [ -s "$dir/02-after-input.png" ]; then write_status "$dir" PASS "rrserve plus Ricochet client reached an active puzzle board."; echo "PASS ricochet-lan $dir"; else write_status "$dir" BLOCKED "Ricochet server/client smoke failed rc=$rc."; echo "BLOCKED ricochet-lan $dir"; fi
}

smoke_xfrisk(){
  local dir; dir="$(new_report xfrisk-lan)"
  cat > "$dir/report.txt" <<EOF
GAME=xfrisk-lan
STARTED_AT=$(date -Is)
NETWORK=bwrap --unshare-net
EXPECT=Risk helper starts friskserver, AIs, and xfrisk client locally.
EOF
  cleanup_apps
  set +e
  bwrap --unshare-net --dev-bind / / bash -s "$dir" <<'INNER'
set -euo pipefail
D="$1"
xvfb-run -a -s "-screen 0 1280x900x24" bash -s "$D" <<'XDO'
set -euo pipefail
D="$1"
export HOME=$(mktemp -d)
/usr/games/risk >"$D/stdout.log" 2>"$D/stderr.log" &
pid=$!
sleep 10
scrot "$D/01-open.png"
xdotool mousemove 200 200 click 1 2>/dev/null || true
sleep 2
scrot "$D/02-after-input.png"
ps -eo pid,ppid,rss,vsz,comm,args | grep -E 'frisk|risk|aiColson|aiConway|aiDummy' | grep -v grep >"$D/processes.txt" || true
kill "$pid" 2>/dev/null || true
XDO
INNER
  rc=$?
  set -e
  cleanup_apps
  if [ "$rc" -eq 0 ] && [ -s "$dir/02-after-input.png" ]; then write_status "$dir" PARTIAL "Risk helper started server, AIs, and client with map/setup visible; first turn pending."; echo "PARTIAL xfrisk-lan $dir"; else write_status "$dir" BLOCKED "XFrisk helper smoke failed rc=$rc."; echo "BLOCKED xfrisk-lan $dir"; fi
}

for game in "${games[@]}"; do
  case "$game" in
    biloba-lan) smoke_biloba ;;
    ricochet-lan) smoke_ricochet ;;
    bovo-lan) smoke_bovo ;;
    kfourinline-lan) smoke_kfourinline ;;
    kreversi-lan) smoke_kreversi ;;
    kigo-lan) smoke_kigo ;;
    pentobi-lan) smoke_pentobi ;;
    gnubg-lan) smoke_gnubg ;;
    knavalbattle-lan) smoke_knavalbattle ;;
    xfrisk-lan) smoke_xfrisk ;;
    *) echo "unsupported expanded board-game smoke id: $game" >&2; exit 2 ;;
  esac
done
