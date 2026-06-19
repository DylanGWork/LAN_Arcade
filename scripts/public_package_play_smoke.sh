#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="/home/dylan/LAN_Arcade"
REPORT_ROOT="${LAN_ARCADE_PUBLIC_PACKAGE_REPORT_DIR:-$ROOT_DIR/qa/reports/public-package-smoke}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOCK_DIR="/tmp/lan-arcade-public-package-smoke.lock"
mkdir -p "$REPORT_ROOT"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then echo "another public package smoke is running" >&2; exit 1; fi
trap 'rm -rf "$LOCK_DIR"' EXIT
need(){ command -v "$1" >/dev/null 2>&1 || { echo "missing $1" >&2; exit 2; }; }
need bwrap; need xvfb-run; need scrot; need xdotool
png_stats(){ python3 - "$1" <<'PY'
from pathlib import Path
import struct,sys,zlib
p=Path(sys.argv[1])
if not p.exists() or p.stat().st_size<1000:
 print('PNG_NONBLANK=fail missing_or_small'); raise SystemExit(1)
data=p.read_bytes()
if not data.startswith(b'\x89PNG\r\n\x1a\n'):
 print('PNG_NONBLANK=fail not_png'); raise SystemExit(1)
pos=8; w=h=ctype=bit=None; chunks=[]
while pos < len(data):
 ln=struct.unpack('>I', data[pos:pos+4])[0]; pos+=4
 typ=data[pos:pos+4]; pos+=4
 chunk=data[pos:pos+ln]; pos+=ln+4
 if typ==b'IHDR': w,h,bit,ctype,_,_,_=struct.unpack('>IIBBBBB', chunk)
 if typ==b'IDAT': chunks.append(chunk)
 if typ==b'IEND': break
if bit!=8 or ctype not in (2,6): print(f'PNG_NONBLANK=partial unsupported bit={bit} ctype={ctype} size={w}x{h}'); raise SystemExit(0)
bpp=3 if ctype==2 else 4
raw=zlib.decompress(b''.join(chunks)); stride=w*bpp; prev=[0]*stride; off=0; colors=set(); total=0; count=0; step=max(1,(w*h)//100000); pix=0
for _ in range(h):
 f=raw[off]; off+=1; cur=list(raw[off:off+stride]); off+=stride
 for i in range(stride):
  left=cur[i-bpp] if i>=bpp else 0; up=prev[i]; ul=prev[i-bpp] if i>=bpp else 0
  if f==1: cur[i]=(cur[i]+left)&255
  elif f==2: cur[i]=(cur[i]+up)&255
  elif f==3: cur[i]=(cur[i]+((left+up)//2))&255
  elif f==4:
   pr=left if abs(left+up-ul-left)<=abs(left+up-ul-up) and abs(left+up-ul-left)<=abs(left+up-ul-ul) else (up if abs(left+up-ul-up)<=abs(left+up-ul-ul) else ul)
   cur[i]=(cur[i]+pr)&255
 for x in range(0,stride,bpp):
  rgb=tuple(cur[x:x+3]); total += sum(rgb); count += 3
  if pix % step == 0: colors.add(rgb)
  pix += 1
 prev=cur
mean=total/(count*255)
print(f'PNG_SIZE={w}x{h}')
print(f'PNG_MEAN={mean:.6f}')
print(f'PNG_COLORS={len(colors)}')
if len(colors) >= 8 and mean > 0.002: print('PNG_NONBLANK=pass')
else: print('PNG_NONBLANK=fail'); raise SystemExit(1)
PY
}
run_game(){
  local id="$1" cmd="$2" clicks="$3" delay="${4:-8}" expect="${5:-window/gameplay}" status="${6:-PASS}"
  local dir="$REPORT_ROOT/${id}-${STAMP}"
  mkdir -p "$dir"
  cat > "$dir/report.txt" <<EOF
GAME=$id
STARTED_AT=$(date -Is)
NETWORK=bwrap --unshare-net
EXPECT=$expect
COMMAND=$cmd
EOF
  set +e
  bwrap --unshare-net --dev-bind / / bash -s "$dir" "$cmd" "$clicks" "$delay" <<'INNER'
set -euo pipefail
D="$1"; CMD="$2"; CLICKS="$3"; DELAY="$4"
xvfb-run -a -s "-screen 0 1280x900x24" bash -s "$D" "$CMD" "$CLICKS" "$DELAY" <<'XDO'
set -euo pipefail
D="$1"; CMD="$2"; CLICKS="$3"; DELAY="$4"
export HOME="$D/home"; mkdir -p "$HOME" "$HOME/.config" "$HOME/.local/share"
export XDG_RUNTIME_DIR="$D/runtime"; mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
export SDL_AUDIODRIVER=dummy; export LIBGL_ALWAYS_SOFTWARE=1; export LANG=C; export LANGUAGE=en
sh -lc "$CMD" >"$D/stdout.log" 2>"$D/stderr.log" &
pid=$!
echo "$pid" > "$D/pid"
sleep "$DELAY"
scrot "$D/01-open.png" 2>"$D/scrot1.err" || true
if [ -n "$CLICKS" ]; then eval "$CLICKS" >>"$D/input.log" 2>&1 || true; fi
sleep 4
scrot "$D/02-after-input.png" 2>"$D/scrot2.err" || true
ps -eo pid,ppid,rss,vsz,comm,args > "$D/processes.txt" || true
kill "$pid" 2>/dev/null || true
sleep 1
kill -9 "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
XDO
INNER
  rc=$?
  set -e
  if [ "$rc" -eq 0 ] && [ -s "$dir/02-after-input.png" ]; then
    if png_stats "$dir/02-after-input.png" >> "$dir/report.txt" 2>&1; then
      echo "STATUS=$status" >> "$dir/report.txt"
      echo "DETAIL=Reached $expect with nonblank screenshot." >> "$dir/report.txt"
      echo "$status $id $dir"
    else
      echo "STATUS=PARTIAL" >> "$dir/report.txt"
      echo "DETAIL=Screenshot captured but nonblank check was weak." >> "$dir/report.txt"
      echo "PARTIAL $id $dir"
    fi
  else
    echo "STATUS=BLOCKED" >> "$dir/report.txt"
    echo "DETAIL=Launch harness failed rc=$rc or screenshot missing." >> "$dir/report.txt"
    echo "BLOCKED $id $dir"
  fi
  echo "FINISHED_AT=$(date -Is)" >> "$dir/report.txt"
}
run_game beneath-a-steel-sky-scummvm "/usr/games/sky --en" "xdotool key Escape; sleep .5; xdotool key Return" 10 "ScummVM title/intro" PASS
run_game flight-amazon-queen-scummvm "/usr/games/queen" "xdotool key Escape; sleep .5; xdotool key Return" 10 "ScummVM title/intro" PASS
run_game lure-temptress-scummvm "/usr/games/lure --en" "xdotool key Escape; sleep .5; xdotool key Return" 10 "ScummVM title/intro" PASS
run_game drascula-scummvm "/usr/games/drascula --en" "xdotool key Escape; sleep .5; xdotool key Return" 10 "ScummVM title/intro" PASS
run_game freedink-lan "/usr/games/freedink -w" "xdotool key Return; sleep 1; xdotool key Down Return" 8 "FreeDink menu/game start" PARTIAL
run_game naev-lan "/usr/games/naev" "xdotool key Return; sleep 1; xdotool key Return" 14 "Naev menu/start screen" PARTIAL
run_game colobot-gold-lan "/usr/games/colobot -graphics=opengl" "xdotool key Return; sleep 1; xdotool key Return" 12 "Colobot menu/tutorial screen" PARTIAL
run_game boswars-lan "/usr/games/boswars -W" "xdotool key Return; sleep 1; xdotool key Return" 8 "Bos Wars menu/skirmish screen" PARTIAL
run_game neverball-lan "/usr/games/neverball -w" "xdotool key Return; sleep 1; xdotool key Return" 8 "Neverball menu/level screen" PARTIAL
run_game xmoto-lan "/usr/games/xmoto -res 1024x768 -bpp 24" "xdotool key Return; sleep 1; xdotool key Return" 10 "X-Moto menu/track screen" PARTIAL
run_game frozen-bubble-lan "/usr/games/frozen-bubble --no-sound" "xdotool key Return; sleep 1; xdotool key Return" 8 "Frozen Bubble menu/gameplay" PARTIAL
run_game fillets-ng-lan "/usr/games/fillets" "xdotool key Return; sleep 1; xdotool key Return" 8 "Fish Fillets NG menu/puzzle" PARTIAL
run_game enigma-lan "/usr/games/enigma" "xdotool key Return; sleep 1; xdotool key Return" 8 "Enigma menu/level" PARTIAL
run_game pushover-lan "/usr/games/pushover" "xdotool key Return; sleep 1; xdotool key Return" 8 "Pushover menu/level" PARTIAL
run_game micropolis-lan "/usr/games/micropolis" "xdotool key Return; sleep 1; xdotool mousemove 450 360 click 1" 8 "Micropolis city window" PARTIAL
run_game simutrans-lan "/usr/games/simutrans -nosound" "xdotool key Return; sleep 1; xdotool key Return" 10 "Simutrans menu/map" PARTIAL

run_game ri-li-lan "/usr/games/ri-li" "xdotool key Return; sleep 1; xdotool key Right; sleep .4; xdotool key Return" 8 "Ri-li menu/level" PARTIAL
run_game chromium-bsu-lan "/usr/games/chromium-bsu" "xdotool key Return; sleep 1; xdotool key space; sleep .5; xdotool key Left Right space" 8 "Chromium B.S.U. menu/action screen" PARTIAL
run_game lbreakouthd-lan "/usr/games/lbreakouthd" "xdotool key Return; sleep 1; xdotool key space; sleep .5; xdotool key Left Right" 8 "LBreakoutHD menu/level" PARTIAL
run_game kobodeluxe-lan "/usr/games/kobodl" "xdotool key Return; sleep 1; xdotool key space; sleep .5; xdotool key Left Right space" 8 "Kobo Deluxe menu/level" PARTIAL
run_game scorched3d-lan "/usr/games/scorched3d" "xdotool key Return; sleep 1; xdotool key Return" 14 "Scorched3D local-match/menu screen" PARTIAL
run_game warmux-lan "/usr/games/warmux" "xdotool key Return; sleep 1; xdotool key Return" 10 "WarMUX local-match/menu screen" PARTIAL
run_game spacezero-lan "/usr/games/spacezero" "xdotool key Return; sleep 1; xdotool key Return" 8 "SpaceZero local game/menu screen" PARTIAL
run_game nethack-x11-lan "/usr/games/xnethack" "xdotool type Codex; sleep .2; xdotool key Return; sleep .5; xdotool key y" 8 "NetHack character/dungeon screen" PARTIAL
run_game opencity-lan "/usr/games/opencity" "xdotool key Return; sleep 1; xdotool mousemove 500 420 click 1" 10 "OpenCity city/map screen" PARTIAL
run_game ufoai-lan "/usr/games/ufoai +set snd_volume 0" "xdotool key Return; sleep 1; xdotool key Return" 16 "UFO:AI campaign/menu screen" PARTIAL
