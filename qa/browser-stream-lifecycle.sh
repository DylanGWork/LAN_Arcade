#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
REPORT_DIR="${1:-$ROOT/qa/reports/browser-stream-lifecycle}"
SCOPE=operator-qa000001
GAMES=(ace-of-penguins-lan tuxmath-lan sopwith-lan btanks-lan liquidwar-lan freedroidrpg-lan)

mkdir -p "$REPORT_DIR/status" "$REPORT_DIR/screenshots"
cleanup() {
  cd "$ROOT"
  python3 scripts/browser_stream_admin.py stop >/dev/null 2>&1 || true
}
trap cleanup EXIT

cd "$ROOT"
python3 scripts/browser_stream_admin.py cleanup >/dev/null 2>&1 || true
printf '# Browser Stream Lifecycle QA\n\n' >"$REPORT_DIR/report.md"
printf 'Runtime network: internal Docker network with no default internet route.\n\n' >>"$REPORT_DIR/report.md"

for game in "${GAMES[@]}"; do
  echo "Testing $game"
  python3 scripts/browser_stream_admin.py start "$game" --scope "$SCOPE"
  python3 scripts/browser_stream_admin.py status --json >"$REPORT_DIR/status/$game.json"
  python3 - "$REPORT_DIR/status/$game.json" "$game" <<'PY'
import json, sys
payload=json.load(open(sys.argv[1], encoding="utf-8"))
assert payload["running"] is True
assert payload["health"] == "healthy"
assert payload["gameId"] == sys.argv[2]
assert payload["gameProcess"].startswith(("15 ", "16 ", "17 ", "18 ", "19 ", "20 ")) or "/usr/games/" in payload["gameProcess"]
assert payload["visibleWindows"], payload
PY
  docker exec webserver wget -qO- http://lan-arcade-browser-stream:6080/vnc.html >/dev/null
  docker exec --env DISPLAY=:0 lan-arcade-browser-stream scrot "/home/player/$game.png"
  test -s "/srv/lan-arcade/native-downloads/browser-stream/saves/$SCOPE/$game/$game.png"
  cp "/srv/lan-arcade/native-downloads/browser-stream/saves/$SCOPE/$game/$game.png" "$REPORT_DIR/screenshots/$game.png"
  printf 'save-persistence-check\n' >"/srv/lan-arcade/native-downloads/browser-stream/saves/$SCOPE/$game/persistence.marker"
  python3 scripts/browser_stream_admin.py stop
  python3 scripts/browser_stream_admin.py start "$game" --scope "$SCOPE"
  test -s "/srv/lan-arcade/native-downloads/browser-stream/saves/$SCOPE/$game/persistence.marker"
  docker exec lan-arcade-browser-stream test -s /home/player/persistence.marker
  python3 scripts/browser_stream_admin.py stop
  printf -- '- **PASS** %s: healthy allowlisted process, visible X window, noVNC HTML, screenshot, and account-scope persistence across restart.\n' "$game" >>"$REPORT_DIR/report.md"
done

test -z "$(docker ps -aq --filter name=^/lan-arcade-browser-stream$)"
printf '\nAll six sessions were stopped and removed after QA.\n' >>"$REPORT_DIR/report.md"
echo "BROWSER_STREAM_LIFECYCLE_PASS"
