#!/usr/bin/env python3
"""Rewrite native download shelves into player-facing pages.

This is a fast deployed-output polish pass. It does not download packages; it
uses existing manifest.json files under /mirrors/games/downloads/native.
"""
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DOWNLOAD_ROOT = Path('/var/www/html/mirrors/games/downloads/native')
DEFAULT_LOCAL_GAMES = ROOT / 'local-games'

CSS = """:root{color-scheme:dark;--bg:#101316;--panel:#171f25;--line:#33424b;--text:#f4f8f8;--muted:#c4d0d4;--accent:#72d39b;--ink:#06110d;--warn:#f0bf5a}*{box-sizing:border-box}body{margin:0;font-family:system-ui,-apple-system,Segoe UI,sans-serif;background:var(--bg);color:var(--text)}main{width:min(1120px,94vw);margin:auto;padding:30px 0 50px}a{color:#9ee6b4}.button{display:inline-flex;align-items:center;justify-content:center;margin:6px 8px 6px 0;padding:10px 12px;border-radius:8px;background:var(--accent);color:var(--ink);font-weight:850;text-decoration:none}.secondary{background:#22303a;color:var(--text);border:1px solid rgba(255,255,255,.12)}.panel,article{border:1px solid var(--line);border-radius:8px;background:var(--panel);padding:16px;margin:12px 0}h1{margin:18px 0 8px;font-size:clamp(32px,5vw,56px);letter-spacing:0}h2{margin:0 0 10px;font-size:24px}h3{margin:0 0 7px}p,li{color:var(--muted);line-height:1.52}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(245px,1fr));gap:12px}.download-card{display:grid;align-content:start;gap:4px}.download-card p{margin:0 0 6px}.badge{display:inline-flex;width:max-content;border:1px solid rgba(255,255,255,.16);border-radius:8px;padding:5px 8px;color:#d8e5e8;background:rgba(255,255,255,.06);font-size:12px;font-weight:800}.warn{color:#ffe0a3}.summary-row{display:flex;flex-wrap:wrap;gap:8px;margin:10px 0}.summary-row span{border:1px solid rgba(255,255,255,.15);border-radius:999px;padding:6px 9px;color:#d9e5e8;background:rgba(255,255,255,.055);font-size:13px}summary{cursor:pointer;font-weight:850;font-size:18px;margin:8px 0}code{background:#090d10;border:1px solid rgba(255,255,255,.12);border-radius:5px;padding:2px 5px}.small{font-size:14px}.advanced-list{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:10px}.advanced-list article{margin:0}.muted{color:var(--muted)}@media(max-width:740px){main{padding-top:18px}.button{width:100%}.summary-row span{width:100%}}"""


def hsize(size: int | float | str | None) -> str:
    try:
        value = float(size or 0)
    except (TypeError, ValueError):
        return 'size unknown'
    for unit in ['B', 'KB', 'MB', 'GB']:
        if value < 1024 or unit == 'GB':
            return f'{value:.1f} {unit}' if unit != 'B' else f'{int(value)} B'
        value /= 1024
    return 'size unknown'


def load_json(path: Path) -> dict | None:
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except Exception:
        return None


def find_game_links(local_games: Path) -> dict[str, str]:
    links: dict[str, str] = {}
    if not local_games.exists():
        return links
    for index in local_games.glob('*/index.html'):
        try:
            text = index.read_text(encoding='utf-8', errors='ignore')
        except OSError:
            continue
        for marker in ['downloads/native/', '../games/downloads/native/']:
            start = 0
            while True:
                pos = text.find(marker, start)
                if pos < 0:
                    break
                slug_start = pos + len(marker)
                slug_end = slug_start
                while slug_end < len(text) and text[slug_end] not in "'\"?#/< ":
                    slug_end += 1
                slug = text[slug_start:slug_end].strip('/')
                if slug and slug not in links:
                    links[slug] = index.parent.name
                start = slug_end + 1
    return links


def asset_name(asset: dict) -> str:
    return str(asset.get('name') or asset.get('file') or asset.get('package') or 'download')


def asset_label(asset: dict) -> str:
    return str(asset.get('label') or asset.get('package') or asset_name(asset))


def asset_platform(asset: dict) -> str:
    value = asset.get('platform') or asset.get('source') or ''
    if not value and asset_name(asset).endswith('.deb'):
        value = 'Debian/Linux package'
    return str(value)


def local_href(root: Path, manifest: dict, asset: dict) -> str:
    name = asset_name(asset)
    raw = str(asset.get('url') or '')
    if raw and not raw.startswith(('http://', 'https://')):
        return raw
    version = str(manifest.get('version') or '')
    candidates = []
    if version:
        candidates.append((root / version / name, f'{version}/{name}'))
    candidates.append((root / 'latest' / name, f'latest/{name}'))
    candidates.append((root / name, name))
    for path, href in candidates:
        if path.exists():
            return href
    return f'latest/{name}'


def classify_assets(assets: list[dict]) -> dict[str, list[dict]]:
    groups = {'windows': [], 'android': [], 'mac': [], 'linux': [], 'server': [], 'other': []}
    for asset in assets:
        hay = f"{asset_name(asset)} {asset_label(asset)} {asset_platform(asset)}".lower()
        if 'server' in hay or 'dedicated' in hay:
            groups['server'].append(asset)
        elif 'windows' in hay or hay.endswith('.exe') or 'win64' in hay or 'win32' in hay:
            groups['windows'].append(asset)
        elif 'android' in hay or hay.endswith('.apk'):
            groups['android'].append(asset)
        elif 'macos' in hay or 'mac os' in hay or hay.endswith('.dmg'):
            groups['mac'].append(asset)
        elif 'linux' in hay or 'appimage' in hay or hay.endswith('.deb') or '.tar.' in hay:
            groups['linux'].append(asset)
        else:
            groups['other'].append(asset)
    return groups


def primary_cards(root: Path, manifest: dict, assets: list[dict]) -> str:
    groups = classify_assets(assets)
    cards: list[str] = []
    labels = [
        ('windows', 'Windows'),
        ('android', 'Android'),
        ('mac', 'macOS'),
        ('linux', 'Linux'),
        ('server', 'Server / host'),
        ('other', 'Other downloads'),
    ]
    for key, title in labels:
        selected = groups[key]
        if not selected:
            continue
        show = selected[:3]
        buttons = ''.join(
            f"<a class='button secondary small' href='{html.escape(local_href(root, manifest, a))}'>{html.escape(asset_label(a))}</a>"
            for a in show
        )
        more = ''
        if len(selected) > len(show):
            more = f"<p class='small muted'>Plus {len(selected) - len(show)} more in the advanced file list.</p>"
        cards.append(f"<article class='download-card'><span class='badge'>{html.escape(title)}</span><h3>{html.escape(asset_label(show[0]))}</h3><p>{html.escape(show[0].get('note') or asset_platform(show[0]) or 'Local offline download.')}</p>{buttons}{more}</article>")
    return ''.join(cards)


def advanced_cards(root: Path, manifest: dict, assets: list[dict]) -> str:
    cards = []
    for asset in assets:
        name = asset_name(asset)
        cards.append(
            f"<article><h3>{html.escape(asset_label(asset))}</h3>"
            f"<p>{html.escape(name)} - {html.escape(hsize(asset.get('size')))}</p>"
            f"<p class='small'>{html.escape(asset_platform(asset) or asset.get('note') or '')}</p>"
            f"<a class='small' href='{html.escape(local_href(root, manifest, asset))}'>Download this file</a></article>"
        )
    return ''.join(cards)


def checksum_href(root: Path, manifest: dict) -> str | None:
    version = str(manifest.get('version') or '')
    candidates = []
    if version:
        candidates.append((root / version / 'SHA256SUMS.txt', f'{version}/SHA256SUMS.txt'))
    candidates.extend([
        (root / 'latest' / 'SHA256SUMS.txt', 'latest/SHA256SUMS.txt'),
        (root / 'SHA256SUMS.txt', 'SHA256SUMS.txt'),
    ])
    for path, href in candidates:
        if path.exists():
            return href
    return None


def page_for(root: Path, manifest: dict, game_id: str | None) -> str:
    title = str(manifest.get('title') or root.name.replace('-', ' ').title())
    assets = [a for a in manifest.get('assets', []) if isinstance(a, dict)]
    total = sum(int(a.get('size') or 0) for a in assets)
    version = str(manifest.get('version') or manifest.get('generatedAt') or manifest.get('generated_at') or 'local shelf')
    seed = manifest.get('seedPackages') or manifest.get('seed_packages') or manifest.get('packages') or []
    package_set = manifest.get('packageSet') or manifest.get('package_set') or []
    mostly_debs = bool(assets) and sum(1 for a in assets if asset_name(a).endswith('.deb')) >= max(1, len(assets) // 2)
    source = str(manifest.get('source') or '')
    notes = str(manifest.get('notes') or '')
    game_link = f'../../../../{game_id}/' if game_id else '../../../'
    nav = f"<a class='button secondary' href='../../../'>Back to Game Library</a>"
    if game_id:
        nav += f" <a class='button secondary' href='{html.escape(game_link)}'>Back to game page</a>"
    checksum = checksum_href(root, manifest)
    checksum_button = f" <a class='button secondary' href='{html.escape(checksum)}'>Checksums</a>" if checksum else ''
    seed_text = ', '.join(str(x) for x in seed[:8]) if seed else ''
    package_text = ', '.join(str(x) for x in package_set[:10]) if package_set else seed_text
    if package_set and len(package_set) > 10:
        package_text += f', plus {len(package_set) - 10} more'
    player_note = 'Choose the installer or package for your computer. Start from the game page if you are not sure which one to use.'
    if mostly_debs:
        player_note = 'Most players should start from the game page. These files are for Linux installation on matching computers.'
    linux_note = ''
    if mostly_debs:
        linux_note = "<section class='panel'><h2>Linux install files</h2><p>For a matching Debian 12 computer, copy this folder, open a terminal in it, then run:</p><p><code>sudo apt install ./*.deb</code></p><p>These local files let that computer install the game without internet.</p></section>"
    elif any('linux' in f"{asset_name(a)} {asset_platform(a)}".lower() for a in assets):
        linux_note = "<section class='panel'><h2>Linux note</h2><p>Linux downloads are included where upstream provides them. For AppImages, mark the file executable before launching it.</p><p><code>chmod +x ./downloaded-file.AppImage</code></p></section>"
    if mostly_debs and assets:
        folder_href = 'latest/' if (root / 'latest').exists() else './'
        download_cards = (
            "<article class='download-card'><span class='badge'>Linux</span>"
            "<h3>Complete Linux install folder</h3>"
            "<p>This folder has the local Linux install files for a matching Debian 12 computer. Most players should use the game page first.</p>"
            f"<a class='button secondary small' href='{html.escape(folder_href)}'>Open install folder</a>"
            "<a class='button secondary small' href='manifest.json'>Technical file list</a>"
            "</article>"
        )
    else:
        download_cards = primary_cards(root, manifest, assets) if assets else "<article><h3>No files listed</h3><p>This file list needs repair before it is useful.</p></article>"
    advanced = advanced_cards(root, manifest, assets)
    source_html = f"<p>Game/project page: <a href='{html.escape(source)}'>{html.escape(source)}</a></p>" if source else ''
    notes_html = f"<p>{html.escape(notes)}</p>" if notes else ''
    package_html = f"<p class='small'>Package set: {html.escape(package_text)}</p>" if package_text else ''
    return f"""<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>{html.escape(title)} Install Files</title><style>{CSS}</style></head><body><main><p>{nav}</p><h1>{html.escape(title)} Install Files</h1><div class='summary-row'><span>{len(assets)} local file{'s' if len(assets) != 1 else ''}</span><span>{html.escape(hsize(total))}</span><span>{html.escape(version)}</span></div><section class='panel'><h2>For players</h2><p>{html.escape(player_note)}</p><p><a class='button' href='{html.escape(game_link)}'>Open game page</a><a class='button secondary' href='manifest.json'>Technical file list</a>{checksum_button}</p>{notes_html}{source_html}</section>{linux_note}<section class='panel'><h2>Recommended action</h2><div class='grid'>{download_cards}</div></section><details class='panel'><summary>Advanced technical file list</summary><p>These are the individual files stored for offline use. Most players do not need this list.</p>{package_html}<div class='advanced-list'>{advanced}</div></details></main></body></html>"""


def normalize(download_root: Path, local_games: Path, dry_run: bool) -> dict:
    links = find_game_links(local_games)
    changed = []
    skipped = []
    for manifest_path in sorted(download_root.glob('*/manifest.json')):
        root = manifest_path.parent
        manifest = load_json(manifest_path)
        if not manifest:
            skipped.append(str(root))
            continue
        html_text = page_for(root, manifest, links.get(root.name))
        index = root / 'index.html'
        if not dry_run:
            index.write_text(html_text, encoding='utf-8')
        changed.append(str(index))
    return {'rewritten': changed, 'skipped': skipped, 'gameLinks': links}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--download-root', type=Path, default=DEFAULT_DOWNLOAD_ROOT)
    parser.add_argument('--local-games', type=Path, default=DEFAULT_LOCAL_GAMES)
    parser.add_argument('--report', type=Path)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    result = normalize(args.download_root, args.local_games, args.dry_run)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(f"rewritten={len(result['rewritten'])} skipped={len(result['skipped'])} dryRun={args.dry_run}")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
