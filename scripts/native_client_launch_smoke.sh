#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_ID="${1:-}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_ROOT="${LAN_ARCADE_CLIENT_REPORT_DIR:-$ROOT_DIR/qa/reports/native-client-launch}"
LOCK_DIR="${LAN_ARCADE_CLIENT_SMOKE_LOCK:-/tmp/lan-arcade-native-service-smoke.lock}"

usage() {
  cat <<'USAGE'
Usage: scripts/native_client_launch_smoke.sh <service-id>

Supported service ids:
  openttd-lan            Launch OpenTTD under Xvfb and capture a nonblank screenshot.
  freeciv-lan            Launch Freeciv GTK under Xvfb and capture a nonblank screenshot.
  teeworlds-ddnet-lan    Launch DDNet under Xvfb and capture a nonblank screenshot.
  hedgewars-lan          Launch Hedgewars under Xvfb and capture a nonblank screenshot.
  widelands-lan          Launch Widelands under Xvfb and capture a nonblank screenshot.
  warzone2100-lan        Launch Warzone 2100 under Xvfb and capture a nonblank screenshot.
  luanti-lan             Launch Luanti/Minetest under Xvfb and capture a nonblank screenshot.
  supertuxkart-lan       Launch a SuperTuxKart race under Xvfb and capture a nonblank screenshot.
  xonotic-lan            Extract cached Xonotic ZIP, launch client under Xvfb, capture screenshot.
  redeclipse-lan         Launch Red Eclipse under Xvfb and capture a nonblank screenshot.
  openarena-lan          Launch OpenArena into a map under Xvfb and capture a nonblank screenshot.
  freedoom-lan           Launch DSDA-Doom with Freedoom IWAD under Xvfb and capture screenshot.
  bzflag-lan             Launch BZFlag solo practice under Xvfb and capture a screenshot.
  freeorion-lan          Launch FreeOrion under Xvfb and capture a nonblank screenshot.
  endless-sky-lan        Launch Endless Sky under Xvfb and capture a nonblank screenshot.
  cataclysm-dda-lan      Launch Cataclysm DDA tiles under Xvfb and capture a screenshot.
  manaplus-lan           Launch ManaPlus safe mode under Xvfb and capture a screenshot.

This proves the client starts on the VM. It does not prove a player joined a server
or completed gameplay.
USAGE
}

if [ -z "$SERVICE_ID" ] || [ "$SERVICE_ID" = "--help" ] || [ "$SERVICE_ID" = "-h" ]; then
  usage
  exit 0
fi

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Another native smoke appears to be running: $LOCK_DIR" >&2
  exit 1
fi
trap 'rm -rf "$LOCK_DIR"' EXIT

if command -v realpath >/dev/null 2>&1; then
  REPORT_ROOT="$(realpath -m "$REPORT_ROOT")"
fi
REPORT_DIR="$REPORT_ROOT/${SERVICE_ID}-${STAMP}"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/report.txt"

case "$SERVICE_ID" in
  openttd-lan)
    CMD=(openttd -g -r 1024x768 -s null -m null -x)
    ;;
  freeciv-lan)
    CMD=(/usr/games/freeciv-gtk3.22)
    ;;
  teeworlds-ddnet-lan)
    CMD=(/usr/games/DDNet)
    ;;
  hedgewars-lan)
    CMD=(/usr/games/hedgewars)
    ;;
  widelands-lan)
    CMD=(/usr/games/widelands --nosound --xres=1280 --yres=720)
    ;;
  warzone2100-lan)
    CMD=(/usr/games/warzone2100 --window --resolution=1280x720 --nosound --gfxbackend=opengl)
    ;;
  luanti-lan)
    CMD=(/usr/games/minetest)
    ;;
  supertuxkart-lan)
    CMD=(/usr/games/supertuxkart --windowed --screensize=1280x720 --no-start-screen --track=abyss --numkarts=4 --laps=1 --difficulty=0)
    CAPTURE_DELAY=14
    ;;
  xonotic-lan)
    XONOTIC_ZIP="/var/www/html/mirrors/games/downloads/native/xonotic/0.8.6/xonotic-0.8.6.zip"
    [ -f "$XONOTIC_ZIP" ] || { echo "missing Xonotic ZIP: $XONOTIC_ZIP" >&2; exit 2; }
    command -v unzip >/dev/null 2>&1 || { echo "missing unzip" >&2; exit 2; }
    XONOTIC_DIR="$REPORT_DIR/xonotic-extract"
    mkdir -p "$XONOTIC_DIR"
    unzip -q "$XONOTIC_ZIP" -d "$XONOTIC_DIR"
    XONOTIC_BIN="$(find "$XONOTIC_DIR" -type f \( -name 'xonotic-linux64-sdl' -o -name 'xonotic-linux-sdl' -o -name 'xonotic-linux64-glx' \) | head -1)"
    [ -n "$XONOTIC_BIN" ] || { echo "missing Linux Xonotic binary after extract" >&2; exit 2; }
    chmod +x "$XONOTIC_BIN"
    XONOTIC_BIN_DIR="$(dirname "$XONOTIC_BIN")"
    XONOTIC_BIN_NAME="$(basename "$XONOTIC_BIN")"
    CMD=(bash -lc "cd '$XONOTIC_BIN_DIR' && './$XONOTIC_BIN_NAME' +vid_fullscreen 0 +vid_width 1280 +vid_height 720 +cl_startcount 1")
    CAPTURE_DELAY=16
    ;;
  redeclipse-lan)
    CMD=(/usr/games/redeclipse -df0 -dw1280 -dh720 -gstdout)
    CAPTURE_DELAY=14
    ;;
  openarena-lan)
    CMD=(/usr/games/openarena +set r_mode -1 +set r_customwidth 1280 +set r_customheight 720 +set s_initsound 0 +set cl_motd 0 +set com_introplayed 1 +set name LANArcadeSmoke +map oa_dm1)
    CAPTURE_DELAY=14
    ;;
  freedoom-lan)
    CMD=(/usr/games/dsda-doom -iwad /usr/share/games/doom/freedoom2.wad -warp 1 -skill 1 -nomusic -nosound)
    ;;
  bzflag-lan)
    CMD=(/usr/games/bzflag -window 1280x720 -nolist -nomotd -solo 3 -team red)
    ;;
  freeorion-lan)
    CMD=(/usr/games/freeorion)
    CAPTURE_DELAY=22
    ;;
  endless-sky-lan)
    CMD=(/usr/games/endless-sky)
    CAPTURE_DELAY=22
    ;;
  cataclysm-dda-lan)
    CMD=(/usr/games/cataclysm-tiles --userdir "$REPORT_DIR/cdda-user")
    CAPTURE_DELAY=25
    ;;
  manaplus-lan)
    CMD=(/usr/games/manaplus --safemode --no-opengl --skip-update -C "$REPORT_DIR/manaplus-config" -L "$REPORT_DIR/manaplus-localdata")
    CAPTURE_DELAY=14
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

CAPTURE_DELAY="${CAPTURE_DELAY:-${LAN_ARCADE_CLIENT_CAPTURE_DELAY:-8}}"
export CAPTURE_DELAY

if ! command -v xvfb-run >/dev/null 2>&1 || ! command -v scrot >/dev/null 2>&1; then
  echo "xvfb-run and scrot are required" >&2
  exit 2
fi
if ! command -v "${CMD[0]}" >/dev/null 2>&1 && [ ! -x "${CMD[0]}" ]; then
  echo "missing client command: ${CMD[0]}" >&2
  exit 2
fi

{
  echo "SERVICE_ID=$SERVICE_ID"
  echo "STARTED_AT=$(date -Is)"
  printf 'COMMAND='; printf '%q ' "${CMD[@]}"; echo
  echo "REPORT_DIR=$REPORT_DIR"
} > "$REPORT"

xvfb-run -a -s "-screen 0 1280x720x24" bash -c '
  set -u
  dir="$1"; shift
  export HOME="$dir/home"
  export LIBGL_ALWAYS_SOFTWARE=1
  export SDL_AUDIODRIVER=dummy
  export QT_QPA_PLATFORM=xcb
  export XDG_RUNTIME_DIR="$dir/runtime"
  mkdir -p "$HOME" "$HOME/.local/share" "$HOME/.config" "$XDG_RUNTIME_DIR"
  chmod 700 "$XDG_RUNTIME_DIR"
  "$@" > "$dir/stdout.log" 2> "$dir/stderr.log" &
  pid=$!
  echo "$pid" > "$dir/pid"
  sleep "${CAPTURE_DELAY:-8}"
  if ps -p "$pid" >/dev/null 2>&1; then echo alive > "$dir/alive.txt"; else echo exited > "$dir/alive.txt"; fi
  scrot "$dir/screenshot.png" 2> "$dir/scrot.err" || true
  ps -o pid,ppid,rss,vsz,comm -p "$pid" > "$dir/process.txt" 2>/dev/null || true
  kill "$pid" 2>/dev/null || true
  sleep 1
  kill -9 "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
' bash "$REPORT_DIR" "${CMD[@]}"

ALIVE="$(cat "$REPORT_DIR/alive.txt" 2>/dev/null || echo missing)"
{
  echo "ALIVE_AT_SCREENSHOT=$ALIVE"
  file "$REPORT_DIR/screenshot.png" 2>/dev/null || echo "SCREENSHOT=missing"
  cat "$REPORT_DIR/process.txt" 2>/dev/null || true
} >> "$REPORT"

python3 - "$REPORT_DIR/screenshot.png" >> "$REPORT" <<'PNG_STATS_PY'
from pathlib import Path
import struct, sys, zlib
path = Path(sys.argv[1])
if not path.exists():
    print('PNG_STATS=missing')
    raise SystemExit(3)
data = path.read_bytes()
if not data.startswith(b'\x89PNG\r\n\x1a\n'):
    print('PNG_STATS=not_png')
    raise SystemExit(3)
pos = 8
w = h = bit = ctype = None
idat = []
while pos < len(data):
    ln = struct.unpack('>I', data[pos:pos+4])[0]; pos += 4
    typ = data[pos:pos+4]; pos += 4
    chunk = data[pos:pos+ln]; pos += ln + 4
    if typ == b'IHDR':
        w, h, bit, ctype, comp, filt, inter = struct.unpack('>IIBBBBB', chunk)
    elif typ == b'IDAT':
        idat.append(chunk)
    elif typ == b'IEND':
        break
if bit != 8 or ctype not in (2, 6):
    print(f'PNG_STATS=unsupported bit={bit} color_type={ctype} width={w} height={h}')
    raise SystemExit(3)
bpp = 3 if ctype == 2 else 4
raw = zlib.decompress(b''.join(idat))
stride = w * bpp
prev = [0] * stride
off = 0
vals_sum = 0
vals_count = 0
colors = set()
sample_step = max(1, (w * h) // 200000)
pixel_index = 0
for _ in range(h):
    f = raw[off]; off += 1
    cur = list(raw[off:off+stride]); off += stride
    for i in range(stride):
        left = cur[i-bpp] if i >= bpp else 0
        up = prev[i]
        ul = prev[i-bpp] if i >= bpp else 0
        if f == 1:
            cur[i] = (cur[i] + left) & 255
        elif f == 2:
            cur[i] = (cur[i] + up) & 255
        elif f == 3:
            cur[i] = (cur[i] + ((left + up) // 2)) & 255
        elif f == 4:
            p = left + up - ul
            pa, pb, pc = abs(p-left), abs(p-up), abs(p-ul)
            pr = left if pa <= pb and pa <= pc else (up if pb <= pc else ul)
            cur[i] = (cur[i] + pr) & 255
        elif f != 0:
            print(f'PNG_STATS=unsupported_filter filter={f}')
            raise SystemExit(3)
    for x in range(0, stride, bpp):
        rgb = tuple(cur[x:x+3])
        vals_sum += sum(rgb)
        vals_count += 3
        if pixel_index % sample_step == 0:
            colors.add(rgb)
        pixel_index += 1
    prev = cur
mean = vals_sum / (vals_count * 255)
print(f'PNG_WIDTH={w}')
print(f'PNG_HEIGHT={h}')
print(f'PNG_MEAN={mean:.6f}')
print(f'PNG_SAMPLED_COLORS={len(colors)}')
if len(colors) < 8 or mean <= 0.002:
    print('SCREENSHOT_NONBLANK=fail')
    raise SystemExit(4)
print('SCREENSHOT_NONBLANK=pass')
PNG_STATS_PY

if [ "$ALIVE" != "alive" ]; then
  echo "CLIENT_LAUNCH=fail" >> "$REPORT"
  exit 3
fi
if ! grep -q 'SCREENSHOT_NONBLANK=pass' "$REPORT"; then
  echo "CLIENT_LAUNCH=fail" >> "$REPORT"
  exit 4
fi

echo "CLIENT_LAUNCH=pass" >> "$REPORT"
echo "FINISHED_AT=$(date -Is)" >> "$REPORT"
printf '%s\n' "$REPORT_DIR"
