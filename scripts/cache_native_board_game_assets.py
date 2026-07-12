#!/usr/bin/env python3
"""Cache native board-game package shelves and minimal offline docs."""
from __future__ import annotations

import argparse, hashlib, html, json, os, re, shutil, subprocess, tempfile, time
from pathlib import Path
from validate_staging_root import replace_latest_symlink, require_local_staging_root
from native_board_game_data import BOARD_GAMES, BY_DOWNLOAD_SLUG

DOWNLOAD_ROOT = Path(os.environ.get('LAN_ARCADE_NATIVE_DOWNLOAD_ROOT', '/var/www/html/mirrors/games/downloads/native')).expanduser().resolve()
DOCS_ROOT = Path(os.environ.get('LAN_ARCADE_DOCS_ROOT', '/var/www/html/mirrors')).expanduser().resolve()
DEP_RE = re.compile(r'^\s*\|?\s*(?:Pre)?Depends:\s+([^<\s][A-Za-z0-9+_.:-]+)')
UA = 'LAN-Arcade-Board-Game-Cache/1.0'

def run(cmd, **kw):
    return subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, **kw)

def package_exists(pkg: str) -> bool:
    return run(['apt-cache', 'show', pkg]).returncode == 0

def package_version(pkg: str) -> str:
    out = run(['apt-cache', 'policy', pkg]).stdout
    for line in out.splitlines():
        line = line.strip()
        if line.startswith('Candidate:'):
            return line.split(':', 1)[1].strip().replace(':', '_')
    return 'unknown'

def dependencies(pkg: str) -> set[str]:
    deps = set()
    for line in run(['apt-cache', 'depends', pkg]).stdout.splitlines():
        m = DEP_RE.match(line)
        if m:
            name = m.group(1).split(':', 1)[0]
            if package_exists(name):
                deps.add(name)
    return deps

def closure(seed: list[str]) -> list[str]:
    seen, queue = set(), list(seed)
    while queue:
        pkg = queue.pop(0)
        if pkg in seen or not package_exists(pkg):
            continue
        seen.add(pkg)
        queue.extend(dep for dep in sorted(dependencies(pkg)) if dep not in seen)
    return sorted(seen)

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def hsize(size: int) -> str:
    v = float(size)
    for unit in ['B', 'KB', 'MB', 'GB']:
        if v < 1024 or unit == 'GB':
            return f'{v:.1f} {unit}' if unit != 'B' else f'{int(v)} B'
        v /= 1024
    return str(size)

def apt_download(pkg: str, target: Path) -> Path:
    target.mkdir(parents=True, exist_ok=True)
    existing = sorted(target.glob(f'{pkg}_*.deb'))
    if existing:
        return existing[-1]
    cached = sorted(Path('/var/cache/apt/archives').glob(f'{pkg}_*.deb'))
    if cached:
        dest = target / cached[-1].name
        shutil.copy2(cached[-1], dest)
        return dest
    print(f'APT_DOWNLOAD {pkg}', flush=True)
    subprocess.run(['apt-get', 'download', pkg], cwd=target, check=True)
    files = sorted(target.glob(f'{pkg}_*.deb'))
    if not files:
        raise RuntimeError(f'no package downloaded for {pkg}')
    return files[-1]

def write_index(game: dict, assets: list[dict], package_set: list[str], version: str) -> None:
    slug, root = game['download_slug'], DOWNLOAD_ROOT / game['download_slug']
    version_dir = root / version
    version_dir.mkdir(parents=True, exist_ok=True)
    cards = []
    for a in assets:
        cards.append(f"<article class='card'><h2>{html.escape(a['package'])}</h2><p>{html.escape(a['name'])}</p><a class='button' href='{html.escape(version)}/{html.escape(a['name'])}'>Download package</a><p>{hsize(a['size'])} - SHA256 <code>{a['sha256'][:16]}...</code></p></article>")
    page = f"""<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'><title>{html.escape(game['title'])} Offline Packages</title><style>:root{{color-scheme:dark;--bg:#101316;--panel:#171f25;--line:#33424b;--text:#f4f8f8;--muted:#c4d0d4;--accent:#72d39b;--ink:#06110d}}*{{box-sizing:border-box}}body{{margin:0;font-family:system-ui,-apple-system,Segoe UI,sans-serif;background:var(--bg);color:var(--text)}}main{{width:min(1120px,94vw);margin:0 auto;padding:34px 0 48px}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(245px,1fr));gap:14px}}.card,.panel{{border:1px solid var(--line);border-radius:8px;padding:16px;background:var(--panel)}}p,li{{color:var(--muted);line-height:1.5}}.button{{display:inline-block;margin:8px 0;padding:10px 12px;border-radius:8px;background:var(--accent);color:var(--ink);font-weight:850;text-decoration:none}}code{{background:#090d10;border:1px solid rgba(255,255,255,.12);border-radius:5px;padding:2px 5px}}</style></head><body><main><h1>{html.escape(game['title'])} Offline Packages</h1><p>Version set <strong>{html.escape(version)}</strong>. Cached on the NFS-backed LAN Arcade native shelf.</p><p><a class='button' href='../../../../games/'>Back to Arcade</a> <a class='button' href='{html.escape(version)}/SHA256SUMS.txt'>SHA256SUMS</a> <a class='button' href='manifest.json'>Manifest</a></p><section class='panel'><h2>Install Note</h2><p>On matching Debian 12 clients, copy this version folder locally and run <code>sudo apt install ./*.deb</code>. Package set: {html.escape(', '.join(package_set))}</p></section><section class='grid'>{''.join(cards)}</section></main></body></html>"""
    root.mkdir(parents=True, exist_ok=True)
    (root / 'index.html').write_text(page, encoding='utf-8')
    (version_dir / 'index.html').write_text(page.replace(f"href='{html.escape(version)}/", "href='"), encoding='utf-8')
    manifest = dict(title=game['title'], version=version, source=game['source'], seed_packages=game['packages'], package_set=package_set, assets=assets, generated_at=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()))
    for p in [root / 'manifest.json', version_dir / 'manifest.json']:
        p.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    (version_dir / 'SHA256SUMS.txt').write_text(''.join(f"{a['sha256']}  {a['name']}\n" for a in assets), encoding='utf-8')
    latest = root / 'latest'
    replace_latest_symlink(latest, version_dir.name, DOWNLOAD_ROOT)
    print(f'DOWNLOADS_READY={root} packages={len(package_set)}', flush=True)

def cache_game(game: dict) -> None:
    version = 'debian-bookworm-' + '-'.join(package_version(pkg) for pkg in game['packages'][:2]).replace('/', '_')
    version_dir = DOWNLOAD_ROOT / game['download_slug'] / version
    assets = []
    package_set = closure(game['packages'])
    for pkg in package_set:
        path = apt_download(pkg, version_dir)
        assets.append(dict(package=pkg, name=path.name, sha256=sha256_file(path), size=path.stat().st_size, source=f'apt:{pkg}'))
    # Preserve manually cached TripleA map assets in the top-level shelf.
    write_index(game, assets, package_set, version)

def docs_root_index(dest: Path, game: dict, source_pages: list[str]) -> None:
    html_pages = sorted(x.relative_to(dest).as_posix() for x in dest.rglob('*.html') if x.name != 'index.html' or x.parent != dest)
    links = ''.join(f"<li><a href='{html.escape(page)}'>{html.escape(page)}</a></li>" for page in html_pages[:80])
    if not links:
        links = '<li>No mirrored HTML pages were found.</li>'
    pages_text = ', '.join(source_pages)
    (dest / 'index.html').write_text(f"""<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'><title>{html.escape(game['title'])} Docs Mirror</title><style>body{{margin:0;font-family:system-ui;background:#101316;color:#f4f8f8}}main{{max-width:980px;margin:0 auto;padding:42px 20px}}a{{color:#9ec9ff}}li,p{{color:#c4d0d4;line-height:1.55}}.panel{{border:1px solid #33424b;border-radius:8px;background:#171f25;padding:18px}}</style></head><body><main><p><a href='../games/'>Back to Arcade</a></p><h1>{html.escape(game['title'])} Docs Mirror</h1><div class='panel'><p>This root page was generated because the mirrored site landed under a nested host folder. Source pages: {html.escape(pages_text)}</p></div><h2>Available Offline Pages</h2><ul>{links}</ul></main></body></html>""", encoding='utf-8')


def docs_fallback(dest: Path, game: dict, detail: str) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    (dest / 'LAN_ARCADE_DOCS_BLOCKED.txt').write_text(detail, encoding='utf-8')
    step_items = ''.join(f"<li><strong>{html.escape(t)}</strong>: {html.escape(b)}</li>" for t, b in game['steps'])
    (dest / 'index.html').write_text(f"""<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'><title>{html.escape(game['title'])} Offline Notes</title><style>body{{margin:0;font-family:system-ui;background:#101316;color:#f4f8f8}}main{{max-width:900px;margin:0 auto;padding:42px 20px}}a{{color:#9ec9ff}}.panel{{border:1px solid #33424b;border-radius:8px;background:#171f25;padding:18px}}li,p{{color:#c4d0d4;line-height:1.55}}code{{white-space:pre-wrap;color:#ffe08a}}</style></head><body><main><p><a href='../games/'>Back to Arcade</a></p><h1>{html.escape(game['title'])} Offline Notes</h1><div class='panel'><h2>Mirror Status</h2><p>The official docs mirror was blocked or minimal. The quick manual is retained here so the arcade remains useful offline.</p><code>{html.escape(detail)}</code></div><h2>Quick Manual</h2><ol>{step_items}</ol><p>Original source: <a href='{html.escape(game['source'])}'>{html.escape(game['source'])}</a></p></main></body></html>""", encoding='utf-8')

def make_browser_readable(dest: Path) -> None:
    for path in [dest, *dest.rglob('*')]:
        try:
            mode = path.stat().st_mode
            if path.is_dir():
                path.chmod(mode | 0o755)
            else:
                path.chmod(mode | 0o644)
        except OSError:
            pass


def mirror_docs(game: dict) -> None:
    docs = game.get('docs') or {}; pages = docs.get('pages') or []
    dest = DOCS_ROOT / docs.get('dest', f"{game['download_slug']}-site")
    if not pages:
        docs_fallback(dest, game, 'No source pages configured.\n'); return
    with tempfile.TemporaryDirectory(prefix=f"{game['download_slug']}-docs-") as tmp_name:
        tmp = Path(tmp_name)
        cmd = ['wget', '--quiet', '--convert-links', '--adjust-extension', '--page-requisites', '--recursive', '--level', '1', '--timeout=20', '--tries=2', '--user-agent', UA, '--reject-regex', r'(logout|login|signup|register|action=edit|Special:|printable=yes)', '--directory-prefix', str(tmp), *pages]
        print('DOCS_MIRROR', game['download_slug'], flush=True)
        proc = subprocess.run(cmd, check=False)
        if proc.returncode != 0 or not list(tmp.rglob('*.html')):
            docs_fallback(dest, game, f"wget_status={proc.returncode}\nSource pages: {', '.join(pages)}\nChecked {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\n")
            make_browser_readable(dest)
            print(f"DOCS_BLOCKED={game['download_slug']} status={proc.returncode}", flush=True); return
        if dest.exists(): shutil.rmtree(dest)
        shutil.copytree(tmp, dest, dirs_exist_ok=True)
        if not (dest / 'index.html').exists():
            docs_root_index(dest, game, pages)
        (dest / 'LAN_ARCADE_SOURCE.txt').write_text('Mirrored for LAN Arcade native board-game intake.\n', encoding='utf-8')
        make_browser_readable(dest)
        print(f'DOCS_READY={dest}', flush=True)

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('games', nargs='*', help='Download slugs; default all')
    ap.add_argument('--skip-downloads', action='store_true')
    ap.add_argument('--skip-docs', action='store_true')
    args = ap.parse_args()
    if not args.skip_downloads:
        validated = require_local_staging_root(os.environ.get('LAN_ARCADE_NATIVE_DOWNLOAD_ROOT'), label='native board-game cache')
        if validated != DOWNLOAD_ROOT:
            raise SystemExit(f'native board-game cache root mismatch: {validated} != {DOWNLOAD_ROOT}')
    if not args.skip_docs:
        validated_docs = require_local_staging_root(os.environ.get('LAN_ARCADE_DOCS_ROOT'), label='board-game docs cache')
        if validated_docs != DOCS_ROOT:
            raise SystemExit(f'board-game docs root mismatch: {validated_docs} != {DOCS_ROOT}')
    selected = [BY_DOWNLOAD_SLUG[x] for x in args.games] if args.games else BOARD_GAMES
    for game in selected:
        if not args.skip_downloads: cache_game(game)
        if not args.skip_docs: mirror_docs(game)
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
