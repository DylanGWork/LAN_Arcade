#!/usr/bin/env python3
"""Cache Debian-first offline package shelves and docs for native batch three."""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

from native_batch_three_data import BATCH_THREE, BY_DOWNLOAD_SLUG

DOWNLOAD_ROOT = Path('/var/www/html/mirrors/games/downloads/native')
DOCS_ROOT = Path('/var/www/html/mirrors')
USER_AGENT = 'LAN-Arcade-Native-Batch-Three/1.0'
DEP_RE = re.compile(r'^\s*\|?\s*(?:Pre)?Depends:\s+([^<\s][A-Za-z0-9+_.:-]+)')


def run(cmd: list[str], *, cwd: Path | None = None, check: bool = True, timeout: int | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, check=check, timeout=timeout, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def package_exists(pkg: str) -> bool:
    return run(['apt-cache', 'show', pkg], check=False).returncode == 0


def package_version(pkg: str) -> str:
    out = run(['apt-cache', 'policy', pkg]).stdout
    for line in out.splitlines():
        line = line.strip()
        if line.startswith('Candidate:'):
            return line.split(':', 1)[1].strip().replace(':', '_')
    return 'unknown'


def dependencies(pkg: str) -> set[str]:
    out = run(['apt-cache', 'depends', pkg], check=False).stdout
    deps: set[str] = set()
    for line in out.splitlines():
        match = DEP_RE.match(line)
        if match:
            name = match.group(1).split(':', 1)[0]
            if package_exists(name):
                deps.add(name)
    return deps


def closure(seed: list[str]) -> list[str]:
    seen: set[str] = set()
    queue = list(seed)
    while queue:
        pkg = queue.pop(0)
        if pkg in seen or not package_exists(pkg):
            continue
        seen.add(pkg)
        for dep in sorted(dependencies(pkg)):
            if dep not in seen:
                queue.append(dep)
    return sorted(seen)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def human_size(size: int) -> str:
    value = float(size)
    for unit in ['B', 'KB', 'MB', 'GB']:
        if value < 1024 or unit == 'GB':
            return f'{value:.1f} {unit}' if unit != 'B' else f'{int(value)} B'
        value /= 1024
    return str(size)


def apt_download(pkg: str, target: Path) -> Path:
    target.mkdir(parents=True, exist_ok=True)
    existing = sorted(target.glob(f'{pkg}_*.deb'))
    if existing:
        return existing[-1]
    print(f'APT_DOWNLOAD {pkg}', flush=True)
    subprocess.run(['apt-get', 'download', pkg], cwd=target, check=True)
    files = sorted(target.glob(f'{pkg}_*.deb'))
    if not files:
        raise RuntimeError(f'apt-get download produced no file for {pkg}')
    return files[-1]


def write_index(slug: str, game: dict, assets: list[dict], package_set: list[str]) -> None:
    root = DOWNLOAD_ROOT / slug
    version = game['version']
    version_dir = root / version
    cards = []
    for asset in assets:
        cards.append(
            "<article class='card'>"
            f"<h2>{html.escape(asset['package'])}</h2>"
            f"<p>{html.escape(asset['name'])}</p>"
            f"<a class='button' href='{html.escape(version)}/{html.escape(asset['name'])}'>Download package</a>"
            f"<p class='meta'>{human_size(asset['size'])} - SHA256 <code>{asset['sha256'][:16]}...</code></p>"
            "</article>"
        )
    page = f"""<!doctype html>
<html lang='en'>
<head>
  <meta charset='utf-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1'>
  <title>{html.escape(game['title'])} Offline Debian Packages</title>
  <style>
    :root {{ color-scheme: dark; --bg:#10131a; --card:#1b2330; --line:#344055; --text:#f4f7fb; --muted:#c3cedf; --accent:#69d4a3; --ink:#06110c; }}
    * {{ box-sizing:border-box; }} body {{ margin:0; font-family:system-ui,-apple-system,Segoe UI,sans-serif; background:var(--bg); color:var(--text); }}
    main {{ width:min(1120px,94vw); margin:0 auto; padding:34px 0 48px; }} h1 {{ margin:0 0 8px; font-size:clamp(30px,5vw,56px); line-height:1; }}
    .lede,.meta,li {{ color:var(--muted); line-height:1.5; }} .grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(245px,1fr)); gap:14px; margin-top:22px; }}
    .card,.panel {{ border:1px solid var(--line); border-radius:8px; padding:16px; background:var(--card); }} .card h2 {{ margin:0 0 5px; font-size:19px; }}
    .button {{ display:inline-block; margin:8px 0; padding:10px 12px; border-radius:8px; background:var(--accent); color:var(--ink); font-weight:850; text-decoration:none; }}
    code {{ background:#090d12; border:1px solid rgba(255,255,255,.12); border-radius:5px; padding:2px 5px; }} .links {{ display:flex; flex-wrap:wrap; gap:10px; margin-top:18px; }}
    .links a {{ color:var(--text); border:1px solid var(--line); border-radius:8px; padding:9px 10px; text-decoration:none; }}
  </style>
</head>
<body>
  <main>
    <h1>{html.escape(game['title'])} Offline Debian Packages</h1>
    <p class='lede'>Version set <strong>{html.escape(version)}</strong>. This is a Linux/Debian-first offline cache for GannanNet or similar machines. It contains the primary game packages plus recursive Debian dependency packages available from the configured Debian 12 repository.</p>
    <div class='links'><a href='../../../../games/'>Back to Arcade</a><a href='{html.escape(version)}/SHA256SUMS.txt'>SHA256SUMS</a><a href='manifest.json'>Manifest JSON</a><a href='{html.escape(game['source'])}'>Original source</a></div>
    <section class='panel'><h2>Install Note</h2><p class='lede'>On a matching Debian 12 system, copy this folder locally and run <code>sudo apt install ./*.deb</code> from the version directory. Native packages are not yet a universal Windows/macOS installer shelf.</p><p class='lede'>Package set: {html.escape(', '.join(package_set))}</p></section>
    <section class='grid'>{''.join(cards)}</section>
  </main>
</body>
</html>
"""
    root.mkdir(parents=True, exist_ok=True)
    version_dir.mkdir(parents=True, exist_ok=True)
    (root / 'index.html').write_text(page, encoding='utf-8')
    (version_dir / 'index.html').write_text(page.replace(f"href='{html.escape(version)}/", "href='"), encoding='utf-8')
    manifest = {'title': game['title'], 'version': version, 'source': game['source'], 'notes': 'Debian/Linux package set cached for LAN Arcade native batch three.', 'seed_packages': game['packages'], 'package_set': package_set, 'assets': assets}
    (root / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    (version_dir / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    (version_dir / 'SHA256SUMS.txt').write_text(''.join(f"{a['sha256']}  {a['name']}\n" for a in assets), encoding='utf-8')
    latest = root / 'latest'
    if latest.exists() or latest.is_symlink():
        if latest.is_dir() and not latest.is_symlink():
            shutil.rmtree(latest)
        else:
            latest.unlink()
    latest.symlink_to(version_dir.name, target_is_directory=True)


def cache_game(game: dict) -> None:
    slug = game['download_slug']
    seed_versions = [package_version(pkg) for pkg in game['packages']]
    game['version'] = 'debian-bookworm-' + '-'.join(seed_versions[:2]).replace('/', '_')
    version_dir = DOWNLOAD_ROOT / slug / game['version']
    package_set = closure(game['packages'])
    assets = []
    for pkg in package_set:
        path = apt_download(pkg, version_dir)
        assets.append({'package': pkg, 'name': path.name, 'sha256': sha256_file(path), 'size': path.stat().st_size, 'source': f'apt:{pkg}'})
    write_index(slug, game, assets, package_set)
    print(f'DOWNLOADS_READY={DOWNLOAD_ROOT / slug} packages={len(package_set)}', flush=True)


def write_docs_blocker(dest: Path, title: str, detail: str) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    (dest / 'LAN_ARCADE_DOCS_BLOCKED.txt').write_text(detail, encoding='utf-8')
    (dest / 'index.html').write_text(f"""<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'><title>{html.escape(title)}</title><style>body{{margin:0;font-family:system-ui;background:#0c1114;color:#f2f7f8}}main{{max-width:880px;margin:0 auto;padding:44px 20px}}a{{color:#77b7ff}}.panel{{border:1px solid #2d3b43;border-radius:8px;background:#151d22;padding:20px}}code{{color:#ffe08a;white-space:pre-wrap}}</style></head><body><main><p><a href='../games/'>Back to Arcade</a></p><div class='panel'><h1>{html.escape(title)}</h1><p>The official docs mirror did not complete. The arcade hub still includes curated play notes and local package downloads.</p><code>{html.escape(detail)}</code></div></main></body></html>""", encoding='utf-8')


def patch_docs(root: Path) -> None:
    for path in root.rglob('*.html'):
        text = path.read_text(encoding='utf-8', errors='ignore')
        lines = [line for line in text.splitlines() if all(blocked not in line for blocked in ['googletagmanager.com', 'google-analytics.com', 'fonts.googleapis.com', 'doubleclick.net'])]
        path.write_text('\n'.join(lines) + ('\n' if text.endswith('\n') else ''), encoding='utf-8')
    (root / 'LAN_ARCADE_SOURCE.txt').write_text('Mirrored for LAN Arcade native batch three. Common tracker/font references stripped where practical.\n', encoding='utf-8')


def mirror_docs(game: dict) -> None:
    docs = game.get('docs')
    if not docs:
        return
    dest = DOCS_ROOT / docs['dest']
    with tempfile.TemporaryDirectory(prefix=f"{game['download_slug']}-docs-") as tmp_name:
        tmp = Path(tmp_name)
        pages = docs['pages']
        cmd = ['wget', '--quiet', '--convert-links', '--adjust-extension', '--page-requisites', '--recursive', '--level', '1', '--timeout=20', '--tries=2', '--user-agent', USER_AGENT, '--reject-regex', r'(logout|login|signup|register|action=edit|Special:|printable=yes)', '--directory-prefix', str(tmp), *pages]
        print('DOCS_MIRROR', game['download_slug'], flush=True)
        proc = subprocess.run(cmd, check=False)
        source = tmp / docs['source_subdir']
        if proc.returncode != 0 or not source.exists():
            write_docs_blocker(dest, f"{game['title']} docs mirror blocked", f"wget_status={proc.returncode}\nSource pages: {', '.join(pages)}\nChecked {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\n")
            print(f"DOCS_BLOCKED={game['download_slug']} status={proc.returncode}", flush=True)
            return
        backup = dest.with_name(dest.name + '.backup-before-refresh')
        if backup.exists():
            shutil.rmtree(backup)
        if dest.exists() and any(dest.iterdir()):
            dest.rename(backup)
        shutil.copytree(source, dest, dirs_exist_ok=True)
        patch_docs(dest)
    print(f'DOCS_READY={dest}', flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description='Cache native batch three Debian package sets and docs')
    parser.add_argument('games', nargs='*', help='Download slugs to cache; default all')
    parser.add_argument('--skip-downloads', action='store_true')
    parser.add_argument('--skip-docs', action='store_true')
    args = parser.parse_args()
    selected = [BY_DOWNLOAD_SLUG[x] for x in args.games] if args.games else BATCH_THREE
    for game in selected:
        if not args.skip_downloads:
            cache_game(game)
        if not args.skip_docs:
            mirror_docs(game)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
