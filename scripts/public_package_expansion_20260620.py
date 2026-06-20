#!/usr/bin/env python3
from __future__ import annotations
import argparse
import csv
import hashlib
import html
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import time
import zlib
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / 'scripts/public_package_expansion_20260620.csv'
LOCAL_GAMES = ROOT / 'local-games'
REPORT_ROOT = ROOT / 'qa/reports/public-package-expansion-20260620'
DOWNLOAD_ROOT = Path('/var/www/html/mirrors/games/downloads/native')
POOL_ROOT = DOWNLOAD_ROOT / 'debian-bookworm-pool'
DOC_PATH = ROOT / 'docs/PUBLIC_PACKAGE_EXPANSION_2026-06-20.md'
DEP_RE = re.compile(r'^\s*\|?\s*(?:Pre)?Depends:\s+([^<\s][A-Za-z0-9+_.:-]+)')

@dataclass
class Game:
    id: str
    pkg: str
    title: str
    icon: str
    meta: str
    description: str
    tags: list[str]
    categories: str
    commands: list[str]

    @property
    def download_slug(self) -> str:
        return self.id.removesuffix('-lan')

    @property
    def source(self) -> str:
        return f'https://packages.debian.org/bookworm/{self.pkg}'

    @property
    def tag_string(self) -> str:
        return ','.join(self.tags)


def run(cmd: list[str], *, cwd: Path | None = None, check: bool = False, timeout: int | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=check, timeout=timeout)


def games() -> list[Game]:
    out: list[Game] = []
    with CSV_PATH.open(newline='', encoding='utf-8') as f:
        for row in csv.DictReader(f):
            out.append(Game(
                id=row['id'].strip(),
                pkg=row['pkg'].strip(),
                title=row['title'].strip(),
                icon=row['icon'].strip(),
                meta=row['meta'].strip(),
                description=row['description'].strip(),
                tags=[x.strip() for x in row['tags'].split(',') if x.strip()],
                categories=row['categories'].strip(),
                commands=[x.strip() for x in row['commands'].split('|') if x.strip()],
            ))
    return out


def package_exists(pkg: str) -> bool:
    return run(['apt-cache', 'show', pkg]).returncode == 0


def package_version(pkg: str) -> str:
    out = run(['apt-cache', 'policy', pkg]).stdout
    for line in out.splitlines():
        line = line.strip()
        if line.startswith('Candidate:'):
            return line.split(':', 1)[1].strip().replace(':', '_').replace('/', '_')
    return 'unknown'


def dependencies(pkg: str) -> set[str]:
    found: set[str] = set()
    out = run(['apt-cache', 'depends', pkg]).stdout
    for line in out.splitlines():
        m = DEP_RE.match(line)
        if not m:
            continue
        dep = m.group(1).split(':', 1)[0]
        if package_exists(dep):
            found.add(dep)
    return found


def closure(seed: list[str]) -> list[str]:
    seen: set[str] = set()
    queue = list(seed)
    while queue:
        pkg = queue.pop(0)
        if pkg in seen or not package_exists(pkg):
            continue
        seen.add(pkg)
        queue.extend(dep for dep in sorted(dependencies(pkg)) if dep not in seen)
    return sorted(seen)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def hsize(num: int | float) -> str:
    value = float(num)
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if value < 1024 or unit == 'TB':
            return f'{value:.1f} {unit}' if unit != 'B' else f'{int(value)} B'
        value /= 1024
    return f'{value:.1f} TB'


def deb_for(pkg: str) -> Path:
    POOL_ROOT.mkdir(parents=True, exist_ok=True)
    existing = sorted(POOL_ROOT.glob(f'{pkg}_*.deb'))
    if existing:
        return existing[-1]
    cached = sorted(Path('/var/cache/apt/archives').glob(f'{pkg}_*.deb'))
    if cached:
        dest = POOL_ROOT / cached[-1].name
        if not dest.exists():
            shutil.copy2(cached[-1], dest)
        return dest
    run(['apt-get', 'download', pkg], cwd=POOL_ROOT, check=True, timeout=600)
    files = sorted(POOL_ROOT.glob(f'{pkg}_*.deb'))
    if not files:
        raise RuntimeError(f'No .deb downloaded for {pkg}')
    return files[-1]


def cache_game(game: Game) -> None:
    package_set = closure([game.pkg])
    if not package_set:
        raise RuntimeError(f'{game.pkg} was not found in apt metadata')
    version = 'debian-bookworm-' + package_version(game.pkg)
    root = DOWNLOAD_ROOT / game.download_slug
    ver = root / version
    ver.mkdir(parents=True, exist_ok=True)
    assets = []
    for pkg in package_set:
        deb = deb_for(pkg)
        assets.append({
            'package': pkg,
            'name': deb.name,
            'size': deb.stat().st_size,
            'sha256': sha256(deb),
            'url': '../debian-bookworm-pool/' + deb.name,
        })
    manifest = {
        'title': game.title,
        'id': game.id,
        'source': game.source,
        'generatedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'seedPackages': [game.pkg],
        'packageSet': package_set,
        'assets': assets,
    }
    for p in [root / 'manifest.json', ver / 'manifest.json']:
        p.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    (ver / 'SHA256SUMS.txt').write_text(''.join(f"{a['sha256']}  {a['name']}\n" for a in assets), encoding='utf-8')
    cards = ''.join(
        f"<article><h2>{html.escape(a['package'])}</h2><p>{html.escape(a['name'])} - {hsize(a['size'])}</p>"
        f"<a href='../debian-bookworm-pool/{html.escape(a['name'])}'>Download</a></article>"
        for a in assets
    )
    page = f"""<!doctype html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>{html.escape(game.title)} Packages</title><style>body{{font-family:system-ui;background:#101316;color:#f4f8f8}}main{{max-width:1100px;margin:auto;padding:30px}}article{{border:1px solid #33424b;border-radius:8px;padding:12px;margin:10px;background:#171f25}}a{{color:#9ee6b4}}</style></head><body><main><p><a href='../../../'>Back to Arcade</a></p><h1>{html.escape(game.title)} Offline Debian Packages</h1><p>{len(assets)} files, {hsize(sum(a['size'] for a in assets))}. <a href='manifest.json'>Manifest</a> <a href='{html.escape(version)}/SHA256SUMS.txt'>SHA256SUMS</a></p>{cards}</main></body></html>"""
    root.mkdir(parents=True, exist_ok=True)
    (root / 'index.html').write_text(page, encoding='utf-8')
    latest = root / 'latest'
    if latest.exists() or latest.is_symlink():
        if latest.is_dir() and not latest.is_symlink():
            shutil.rmtree(latest)
        else:
            latest.unlink()
    latest.symlink_to(ver.name, target_is_directory=True)
    print(f'CACHE_READY {game.id} {len(assets)} {hsize(sum(a["size"] for a in assets))}')


def installed_files(pkg: str) -> list[Path]:
    cp = run(['dpkg', '-L', pkg])
    if cp.returncode != 0:
        return []
    return [Path(line) for line in cp.stdout.splitlines() if line.startswith(('/usr/games/', '/usr/bin/'))]


def find_command(game: Game) -> str | None:
    for name in game.commands:
        for candidate in [shutil.which(name), f'/usr/games/{name}', f'/usr/bin/{name}']:
            if candidate and Path(candidate).exists() and os.access(candidate, os.X_OK):
                return candidate
    for p in installed_files(game.pkg):
        if p.exists() and p.is_file() and os.access(p, os.X_OK):
            return str(p)
    return None


def png_stats(path: Path) -> tuple[bool, str]:
    if not path.exists() or path.stat().st_size < 1000:
        return False, 'missing_or_small'
    data = path.read_bytes()
    if not data.startswith(b'\x89PNG\r\n\x1a\n'):
        return False, 'not_png'
    pos = 8
    width = height = bit = ctype = None
    chunks: list[bytes] = []
    while pos < len(data):
        if pos + 8 > len(data):
            break
        length = struct.unpack('>I', data[pos:pos + 4])[0]
        pos += 4
        typ = data[pos:pos + 4]
        pos += 4
        chunk = data[pos:pos + length]
        pos += length + 4
        if typ == b'IHDR':
            width, height, bit, ctype, _, _, _ = struct.unpack('>IIBBBBB', chunk)
        elif typ == b'IDAT':
            chunks.append(chunk)
        elif typ == b'IEND':
            break
    if bit != 8 or ctype not in (2, 6) or not width or not height:
        return True, f'unsupported_png size={width}x{height} bit={bit} ctype={ctype}'
    bpp = 3 if ctype == 2 else 4
    try:
        raw = zlib.decompress(b''.join(chunks))
    except zlib.error as exc:
        return False, f'zlib_error={exc}'
    stride = width * bpp
    prev = [0] * stride
    off = 0
    colors: set[tuple[int, int, int]] = set()
    total = count = pix = 0
    step = max(1, (width * height) // 80000)
    for _y in range(height):
        filt = raw[off]
        off += 1
        cur = list(raw[off:off + stride])
        off += stride
        for i in range(stride):
            left = cur[i - bpp] if i >= bpp else 0
            up = prev[i]
            ul = prev[i - bpp] if i >= bpp else 0
            if filt == 1:
                cur[i] = (cur[i] + left) & 255
            elif filt == 2:
                cur[i] = (cur[i] + up) & 255
            elif filt == 3:
                cur[i] = (cur[i] + ((left + up) // 2)) & 255
            elif filt == 4:
                p = left + up - ul
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - ul)
                pred = left if pa <= pb and pa <= pc else (up if pb <= pc else ul)
                cur[i] = (cur[i] + pred) & 255
        for x in range(0, stride, bpp):
            rgb = tuple(cur[x:x + 3])
            total += sum(rgb)
            count += 3
            if pix % step == 0:
                colors.add(rgb)
            pix += 1
        prev = cur
    mean = total / max(1, count * 255)
    ok = (len(colors) >= 8 and mean > 0.002) or (len(colors) >= 4 and mean > 0.01)
    return ok, f'size={width}x{height} mean={mean:.6f} colors={len(colors)}'


def smoke_one(game: Game, seconds: int = 14) -> None:
    cmd = find_command(game)
    stamp = time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())
    out_dir = REPORT_ROOT / f'{game.id}-{stamp}'
    out_dir.mkdir(parents=True, exist_ok=True)
    report = out_dir / 'report.txt'
    if not cmd:
        report.write_text(f'GAME={game.id}\nSTATUS=BLOCKED\nDETAIL=No installed executable found for {game.pkg}. Install package before smoke.\n', encoding='utf-8')
        print(f'BLOCKED {game.id} no executable')
        return
    shell = f"""
set -eu
D='{out_dir}'
export HOME="$D/home"
mkdir -p "$HOME" "$HOME/.config" "$HOME/.local/share" "$D/runtime"
chmod 700 "$D/runtime"
export XDG_RUNTIME_DIR="$D/runtime"
export SDL_AUDIODRIVER=dummy
export ALSOFT_DRIVERS=null
export LIBGL_ALWAYS_SOFTWARE=1
export LANG=C
export LANGUAGE=en
{cmd!r} >"$D/stdout.log" 2>"$D/stderr.log" &
pid=$!
echo "$pid" > "$D/pid"
sleep {max(5, min(seconds, 18))}
scrot "$D/01-open.png" || true
xdotool mousemove 640 450 click 1 || true
xdotool key Return || true
sleep .5
xdotool key space || true
sleep .5
xdotool key Right Left Up Down || true
sleep .5
xdotool key Return || true
sleep 4
scrot "$D/02-after-input.png" || true
ps -eo pid,ppid,rss,vsz,comm,args > "$D/processes.txt" || true
kill "$pid" 2>/dev/null || true
sleep 1
kill -9 "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
"""
    wrapped = ['bwrap', '--unshare-net', '--dev-bind', '/', '/', 'xvfb-run', '-a', '-s', '-screen 0 1280x900x24', 'bash', '-lc', shell]
    start = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    report.write_text(f'GAME={game.id}\nSTARTED_AT={start}\nNETWORK=bwrap --unshare-net\nCOMMAND={cmd}\n', encoding='utf-8')
    try:
        cp = run(wrapped, timeout=seconds + 35)
        (out_dir / 'harness.log').write_text(cp.stdout, encoding='utf-8')
        rc = cp.returncode
    except subprocess.TimeoutExpired as exc:
        (out_dir / 'harness.log').write_text(str(exc), encoding='utf-8')
        rc = 124
    shot = out_dir / '02-after-input.png'
    ok, detail = png_stats(shot)
    status = 'PASS' if rc == 0 and ok else ('PARTIAL' if shot.exists() and ok else 'BLOCKED')
    with report.open('a', encoding='utf-8') as f:
        f.write(f'HARNESS_RC={rc}\nPNG_DETAIL={detail}\nSTATUS={status}\n')
        if status == 'PASS':
            f.write('DETAIL=No-network native launch reached a nonblank post-input screen. This is a first-play smoke, not a full completion proof.\n')
        elif status == 'PARTIAL':
            f.write('DETAIL=No-network launch produced a usable screenshot, but harness exit/input proof was imperfect. Needs human or tailored retest before calling gameplay proven.\n')
        else:
            f.write('DETAIL=No-network smoke did not produce a usable post-input screenshot.\n')
        f.write(f'FINISHED_AT={time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}\n')
    print(f'{status} {game.id} {out_dir}')


def latest_report(game_id: str) -> tuple[Path | None, dict[str, str]]:
    reports = sorted(REPORT_ROOT.glob(f'{game_id}-*/report.txt'))
    if not reports:
        return None, {}
    vals: dict[str, str] = {}
    for line in reports[-1].read_text(errors='ignore').splitlines():
        if '=' in line:
            k, v = line.split('=', 1)
            vals[k] = v
    return reports[-1].parent, vals


def package_docs(game: Game) -> tuple[list[str], list[str]]:
    docs: list[str] = []
    pdfs: list[str] = []
    for pkg in closure([game.pkg])[:12]:
        root = Path('/usr/share/doc') / pkg
        if not root.exists():
            continue
        for p in root.rglob('*'):
            if p.is_file() and p.suffix.lower() in {'.pdf', '.html', '.htm', '.txt', '.md', '.gz'}:
                docs.append(str(p))
                if p.suffix.lower() == '.pdf':
                    pages = '?'
                    if shutil.which('pdfinfo'):
                        info = run(['pdfinfo', str(p)]).stdout
                        for line in info.splitlines():
                            if line.startswith('Pages:'):
                                pages = line.split(':', 1)[1].strip()
                    pdfs.append(f'{p.name} ({pages} pages)')
    return docs[:30], pdfs


def render_page(game: Game) -> None:
    target = LOCAL_GAMES / game.id
    assets = target / 'assets'
    assets.mkdir(parents=True, exist_ok=True)
    rdir, vals = latest_report(game.id)
    status = vals.get('STATUS', 'UNTESTED').lower()
    detail = vals.get('DETAIL', 'No smoke report found yet.')
    if rdir and (rdir / '02-after-input.png').exists():
        shutil.copy2(rdir / '02-after-input.png', assets / 'play-smoke.png')
    docs, pdfs = package_docs(game)
    docs_html = ''.join(f'<li><code>{html.escape(x)}</code></li>' for x in docs[:16]) or '<li>No installed package docs found beyond Debian package metadata.</li>'
    pdf_html = ''.join(f'<li>{html.escape(x)}</li>' for x in pdfs) or '<li>No package PDF manual found.</li>'
    image = "<img src='assets/play-smoke.png' alt='No-network smoke screenshot'>" if (assets / 'play-smoke.png').exists() else f"<div class='placeholder'>{html.escape(game.icon)}</div>"
    install = "sudo apt install ./*.deb"
    page = f"""<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>{html.escape(game.title)} - LAN Arcade</title><style>:root{{color-scheme:dark;--bg:#101316;--panel:#171f25;--line:#33424b;--text:#f4f8f8;--muted:#c4d0d4;--accent:#72d39b;--warn:#f0bf5a;--bad:#ff746d}}*{{box-sizing:border-box}}body{{margin:0;font-family:system-ui,-apple-system,Segoe UI,sans-serif;background:var(--bg);color:var(--text)}}main,header{{width:min(1180px,94vw);margin:auto}}header{{padding:34px 0 18px}}h1{{font-size:clamp(34px,6vw,68px);margin:0 0 10px}}p,li{{color:var(--muted);line-height:1.55}}.grid{{display:grid;grid-template-columns:1.05fr .95fr;gap:18px}}.panel{{border:1px solid var(--line);border-radius:8px;background:var(--panel);padding:18px;margin:0 0 16px}}.hero-img{{border:1px solid var(--line);border-radius:8px;overflow:hidden;background:#06090b}}img{{width:100%;display:block}}.placeholder{{min-height:300px;display:grid;place-items:center;font-size:54px;font-weight:900;color:#4b5d67}}a.button{{display:inline-flex;margin:6px 8px 6px 0;padding:10px 13px;border-radius:8px;background:var(--accent);color:#07120d;text-decoration:none;font-weight:850}}.secondary{{background:#24313a!important;color:var(--text)!important}}.status-pass{{color:var(--accent)}}.status-partial{{color:var(--warn)}}.status-blocked,.status-untested{{color:var(--bad)}}code{{background:#090d10;border:1px solid #2b3740;border-radius:5px;padding:2px 5px;color:#ffe08a}}@media(max-width:900px){{.grid{{grid-template-columns:1fr}}}}</style></head><body><header><p><a class='button secondary' href='../games/'>Back to Arcade</a></p><h1>{html.escape(game.title)}</h1><p>{html.escape(game.description)}</p><p><strong>{html.escape(game.meta)}</strong> - {html.escape(', '.join(game.tags))}</p></header><main class='grid'><section><div class='hero-img'>{image}</div><article class='panel'><h2>QA Status</h2><p class='status-{html.escape(status)}'><strong>{html.escape(status.upper())}</strong></p><p>{html.escape(detail)}</p><p>Latest report: <code>{html.escape(str(rdir.relative_to(ROOT)) if rdir else 'not run')}</code></p></article></section><section><article class='panel'><h2>Play Offline</h2><p>This is a native Debian package game, not a browser game. The game and package closure are cached on the LAN Arcade native-downloads shelf so Linux/Raspberry Pi clients can install without internet.</p><a class='button' href='../games/downloads/native/{html.escape(game.download_slug)}/'>Open offline package shelf</a><p>Seed package: <code>{html.escape(game.pkg)}</code></p><p>Typical offline install after downloading the shelf files:</p><p><code>{install}</code></p></article><article class='panel'><h2>Manual / Docs Check</h2><p>Installed package docs were inspected on the VM. PDF manuals are counted with Poppler when present.</p><h3>PDFs</h3><ul>{pdf_html}</ul><h3>Local docs seen</h3><ul>{docs_html}</ul></article><article class='panel'><h2>Source</h2><p><a href='{html.escape(game.source)}'>{html.escape(game.source)}</a></p></article></section></main></body></html>"""
    target.mkdir(parents=True, exist_ok=True)
    (target / 'index.html').write_text(page, encoding='utf-8')
    (target / 'ATTRIBUTION.txt').write_text(f'{game.title}\nSource: {game.source}\nPackage: {game.pkg}\nQA: {status} - {detail}\n', encoding='utf-8')
    print(f'HUB_READY {game.id} {status}')


def q(value: str) -> str:
    return value.replace('\\', '\\\\').replace('"', '\\"')


def add_entries(text: str, array_name: str, entries: list[str]) -> str:
    start = text.index(f'declare -A {array_name}=(')
    end = text.index('\n)', start)
    block = text[start:end]
    missing = [line for line in entries if line.split(']="', 1)[0] not in block]
    if not missing:
        return text
    insert = '\n' + '\n'.join(missing)
    return text[:end] + insert + text[end:]


def update_metadata(items: list[Game]) -> None:
    path = ROOT / 'games.meta.sh'
    text = path.read_text(encoding='utf-8')
    game_lines = [f'  ["{q(g.id)}"]="LOCAL_DIR::local-games/{q(g.id)}"' for g in items]
    info_lines = [f'  ["{q(g.id)}"]="{q(g.title)}|{q(g.icon)}|{q(g.meta)}|{q(g.description)}|{q(g.tag_string)}"' for g in items]
    cat_lines = [f'  ["{q(g.id)}"]="{q(g.categories)}"' for g in items]
    text = add_entries(text, 'GAMES', game_lines)
    text = add_entries(text, 'GAME_INFO', info_lines)
    text = add_entries(text, 'GAME_CATEGORIES', cat_lines)
    path.write_text(text, encoding='utf-8')
    print(f'METADATA_READY {len(items)} rows')


def write_summary(items: list[Game]) -> None:
    lines = [
        '# Public Package Expansion - 2026-06-20',
        '',
        'Fifty additional Debian package games prepared for the LAN Arcade native/offline shelf. Package payloads live on the NFS-backed native downloads shelf; Git only tracks metadata, generated hub pages, QA references, and this report.',
        '',
        'These are first-play no-network smoke tests: each launch runs under `bwrap --unshare-net` with Xvfb input and a post-input screenshot check. That proves the game starts offline and renders an interactive screen; it does not prove campaign completion or multiplayer depth.',
        '',
        '| Game | Package | Status | Notes |',
        '| --- | --- | --- | --- |',
    ]
    for g in items:
        _rdir, vals = latest_report(g.id)
        lines.append(f'| {g.title} | `{g.pkg}` | {vals.get("STATUS", "UNTESTED")} | {vals.get("DETAIL", "No smoke report yet.")} |')
    DOC_PATH.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'SUMMARY_READY {DOC_PATH.relative_to(ROOT)}')


def select_items(all_items: list[Game], only: list[str]) -> list[Game]:
    if not only:
        return all_items
    wanted = set(only)
    chosen = [g for g in all_items if g.id in wanted or g.pkg in wanted]
    missing = wanted - {g.id for g in chosen} - {g.pkg for g in chosen}
    if missing:
        raise SystemExit(f'Unknown game/package: {", ".join(sorted(missing))}')
    return chosen


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('action', choices=['list', 'cache', 'smoke', 'generate', 'metadata', 'summary', 'all'])
    ap.add_argument('--only', nargs='*', default=[])
    ap.add_argument('--seconds', type=int, default=14)
    args = ap.parse_args()
    items = select_items(games(), args.only)
    if args.action == 'list':
        for g in items:
            print(f'{g.id}\t{g.pkg}\t{g.title}')
        return
    if args.action in {'cache', 'all'}:
        for g in items:
            cache_game(g)
    if args.action in {'smoke', 'all'}:
        for g in items:
            smoke_one(g, seconds=args.seconds)
    if args.action in {'generate', 'all'}:
        for g in items:
            render_page(g)
    if args.action in {'metadata', 'all'}:
        update_metadata(items)
    if args.action in {'summary', 'all'}:
        write_summary(items)


if __name__ == '__main__':
    main()
