#!/usr/bin/env python3
"""Cache Travian-like strategy game source archives for LAN Arcade."""
from __future__ import annotations

import hashlib
import html
import json
import subprocess
import time
from pathlib import Path

DOWNLOAD_ROOT = Path('/var/www/html/mirrors/games/downloads/native/travian-like')
USER_AGENT = 'LAN-Arcade-Travian-Like-Cache/1.0'

CANDIDATES = [
    {
        'slug': 'pillage-first',
        'title': 'Pillage First! (Ask Questions Later)',
        'repo': 'https://github.com/jurerotar/Pillage-First-Ask-Questions-Later',
        'commit': '54451093040b3934382fa585be2b61f26a653bfb',
        'license': 'AGPL-3.0-or-later',
        'status': 'Live static mirror at /mirrors/pillage-first/. Single-player, offline-first browser strategy.',
        'notes': 'Best fit for the Travian-like request. Built and deployed as the only live game in this batch.',
    },
    {
        'slug': 'vallorium',
        'title': 'Vallorium',
        'repo': 'https://github.com/Pierre-Alexandre35/vallorium',
        'commit': 'a1ab83d6646b1526cd5760bb41c00a2e3253b0ce',
        'license': 'MIT',
        'status': 'Candidate only. Backend still in development upstream; do not keep running by default.',
        'notes': 'Persistent browser multiplayer strategy inspired by Travian. Requires Docker, FastAPI, and PostgreSQL-style stack work before LAN play.',
    },
    {
        'slug': 'travianz',
        'title': 'TravianZ',
        'repo': 'https://github.com/shadowss/travianz',
        'commit': 'd00826167857df55dc213d46a61de171397feecc',
        'license': 'GPL-3.0',
        'status': 'Candidate only. PHP and MariaDB Docker stack, install flow, and legal/branding review needed before live arcade exposure.',
        'notes': 'Closest classic Travian-like multiplayer clone. Keep behind the lab until a one-at-a-time container smoke is done.',
    },
    {
        'slug': 'freeciv-web',
        'title': 'Freeciv-web',
        'repo': 'https://github.com/freeciv/freeciv-web',
        'commit': 'c19ce060fadc99663f8aba3652ca94b07174467c',
        'license': 'GPL family, inspect source archive before redistribution claims',
        'status': 'Candidate only. Related browser 4X service; native Freeciv hub already exists separately.',
        'notes': 'Not a Travian clone, but useful as a larger web strategy service candidate.',
    },
    {
        'slug': 'unknown-horizons',
        'title': 'Unknown Horizons',
        'repo': 'https://github.com/unknown-horizons/unknown-horizons',
        'commit': 'af9c8ef5c7f6cf9ec0b8c9e7d172c555f2793615',
        'license': 'GPL family, inspect source archive before redistribution claims',
        'status': 'Candidate only. Native settlement/economy game, not a browser-first service.',
        'notes': 'Related city/economy progression candidate for the larger arcade library.',
    },
]


def run(cmd: list[str], *, cwd: Path | None = None) -> str:
    return subprocess.check_output(cmd, cwd=cwd, text=True).strip()


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
    return f'{size} B'


def default_commit(repo: str) -> str:
    return run(['git', 'ls-remote', f'{repo}.git', 'HEAD']).split()[0]


def download(url: str, target: Path) -> None:
    if target.exists() and target.stat().st_size > 0:
        return
    part = target.with_suffix(target.suffix + '.part')
    subprocess.run([
        'wget', '-c', '--tries=3', '--timeout=90', '--read-timeout=90',
        '--user-agent', USER_AGENT, '-O', str(part), url,
    ], check=True)
    if not part.exists() or part.stat().st_size == 0:
        raise RuntimeError(f'empty download: {url}')
    part.replace(target)


def write_index(records: list[dict]) -> None:
    rows = []
    for record in records:
        slug = html.escape(record['slug'])
        rows.append(f"""
        <article>
          <h2>{html.escape(record['title'])}</h2>
          <p>{html.escape(record['status'])}</p>
          <dl>
            <dt>License</dt><dd>{html.escape(record['license'])}</dd>
            <dt>Commit</dt><dd><code>{html.escape(record['commit'])}</code></dd>
            <dt>Archive</dt><dd><a href="{slug}/{html.escape(record['archive'])}">{html.escape(record['archive'])}</a> ({html.escape(record['size_human'])})</dd>
            <dt>Upstream</dt><dd><a href="{html.escape(record['repo'])}">{html.escape(record['repo'])}</a></dd>
          </dl>
          <p>{html.escape(record['notes'])}</p>
        </article>""")
    page = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Travian-like Source Shelf - LAN Arcade</title>
<style>
:root {{ color-scheme: dark; --bg:#111513; --panel:#19211d; --line:#314238; --text:#f4f7ef; --muted:#c4cebf; --accent:#83d77c; }}
* {{ box-sizing:border-box; }}
body {{ margin:0; font-family:Inter, system-ui, sans-serif; background:var(--bg); color:var(--text); }}
a {{ color:var(--accent); }}
main {{ width:min(1120px,94vw); margin:0 auto; padding:36px 0 54px; }}
h1 {{ margin:0 0 8px; font-size:clamp(32px,6vw,64px); }}
p {{ color:var(--muted); line-height:1.55; }}
article {{ border:1px solid var(--line); background:var(--panel); border-radius:8px; padding:18px; margin:14px 0; }}
dt {{ color:var(--accent); font-weight:800; margin-top:8px; }}
dd {{ margin:2px 0 0; color:var(--muted); overflow-wrap:anywhere; }}
code {{ color:#ffe28a; }}
</style>
</head>
<body><main>
<h1>Travian-like Source Shelf</h1>
<p>Offline source archives for the Travian-like strategy intake batch. Pillage First is the only game kept live from this batch; the other entries are cached for later one-at-a-time service testing.</p>
{''.join(rows)}
</main></body></html>
"""
    (DOWNLOAD_ROOT / 'index.html').write_text(page)


def main() -> None:
    DOWNLOAD_ROOT.mkdir(parents=True, exist_ok=True)
    records: list[dict] = []
    checksums: list[str] = []
    cached_at = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    for candidate in CANDIDATES:
        slug = candidate['slug']
        commit = candidate.get('commit') or default_commit(candidate['repo'])
        target_dir = DOWNLOAD_ROOT / slug
        target_dir.mkdir(parents=True, exist_ok=True)
        archive = f'{slug}-{commit[:12]}.tar.gz'
        url = f"{candidate['repo']}/archive/{commit}.tar.gz"
        target = target_dir / archive
        print(f'DOWNLOAD {slug} {commit[:12]}')
        download(url, target)
        digest = sha256_file(target)
        size = target.stat().st_size
        (target_dir / 'SOURCE.txt').write_text(
            f"{candidate['title']}\n"
            f"Upstream: {candidate['repo']}\n"
            f"Commit: {commit}\n"
            f"License: {candidate['license']}\n"
            f"Status: {candidate['status']}\n"
            f"Notes: {candidate['notes']}\n"
            f"Cached: {cached_at}\n"
        )
        records.append({**candidate, 'commit': commit, 'archive': archive, 'sha256': digest, 'size': size, 'size_human': human_size(size), 'cached_at': cached_at})
        checksums.append(f'{digest}  {slug}/{archive}')
    (DOWNLOAD_ROOT / 'SOURCE_MANIFEST.json').write_text(json.dumps(records, indent=2) + '\n')
    (DOWNLOAD_ROOT / 'SHA256SUMS.txt').write_text('\n'.join(checksums) + '\n')
    write_index(records)
    print(f'WROTE {DOWNLOAD_ROOT}')


if __name__ == '__main__':
    main()
