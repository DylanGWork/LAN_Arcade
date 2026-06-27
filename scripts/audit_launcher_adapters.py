#!/usr/bin/env python3
"""Audit LAN Arcade games into player-facing launcher adapters.

This produces a small JSON file consumed by the public library. It separates
"has local files" from "a normal person can click and play".
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any

DEFAULT_CATALOG = Path('/var/www/html/mirrors/games/catalog.json')
DEFAULT_MIRRORS = Path('/var/www/html/mirrors')
DEFAULT_OUTPUT = Path('config/launcher-adapters.json')
DEFAULT_REPORT = Path('qa/reports/launcher-adapter-audit/latest')

COLLECTION_IDS = {
    'emulator-library',
    'private-gbc-vault',
    'private-dos-classics',
    'private-rom-wave-1',
    'board-games-wave-1',
    'retro-emulator-lab',
}
READY_COLLECTION_IDS = {
    'emulator-library',
    'private-gbc-vault',
    'private-dos-classics',
    'private-rom-wave-1',
    'retro-emulator-lab',
}
RESEARCH_COLLECTION_IDS = {'board-games-wave-1'}
HOSTED_SERVICE_IDS = {
    'pillage-first-lan',
    'travianz-lan',
    'unciv-lan',
    'mindustry-lan',
    'luanti-lan',
    'lan-tank-arena',
    'teeworlds-ddnet-lan',
    'openarena-lan',
    'bzflag-lan',
    'xonotic-lan',
    'freeciv-lan',
    'openttd-lan',
    'veloren-lan',
    'stendhal-lan',
    'manaplus-lan',
}


def as_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item).strip() for item in value if str(item).strip()]


def blob(game: dict[str, Any], page_text: str = '') -> str:
    return ' '.join([
        str(game.get('id', '')),
        str(game.get('title', '')),
        str(game.get('meta', '')),
        str(game.get('description', '')),
        ' '.join(as_list(game.get('categories'))),
        ' '.join(as_list(game.get('tags'))),
        page_text[:20000],
    ]).lower()


def has_any(game: dict[str, Any], cats: set[str]) -> bool:
    return any(cat in as_list(game.get('categories')) for cat in cats)


def game_path(catalog_path: Path, mirrors_root: Path, game: dict[str, Any]) -> Path | None:
    href = str(game.get('path') or '')
    if not href or href.startswith(('http://', 'https://')):
        return None
    target = (catalog_path.parent / href).resolve()
    if target.is_dir():
        return target / 'index.html'
    return target


def read_page(catalog_path: Path, mirrors_root: Path, game: dict[str, Any]) -> tuple[str, str]:
    target = game_path(catalog_path, mirrors_root, game)
    if not target:
        return '', ''
    try:
        return target.read_text(encoding='utf-8', errors='ignore'), str(target)
    except OSError:
        return '', str(target)


def adapter_for(game: dict[str, Any], page_text: str) -> dict[str, Any]:
    game_id = str(game.get('id') or '')
    text = blob(game, page_text)
    categories = set(as_list(game.get('categories')))

    def result(adapter: str, readiness: str, action: str, status: str, device: str, hint: str,
               ready: bool, reason: str, guest: bool = False) -> dict[str, Any]:
        return {
            'adapter': adapter,
            'readiness': readiness,
            'primaryAction': action,
            'statusLabel': status,
            'deviceLabel': device,
            'launchHint': hint,
            'readyNow': ready,
            'guestReady': guest,
            'reason': reason,
        }

    if game_id in RESEARCH_COLLECTION_IDS:
        return result('research-shelf', 'Needs curation', 'Open research shelf', 'Research shelf', 'Shelf', 'research notes', False, 'Board-game wave is mostly metadata/research rows.', False)

    if game_id in READY_COLLECTION_IDS or game_id in COLLECTION_IDS:
        return result('collection', 'Collection ready', 'Open collection', 'Collection', 'Shelf', 'collection', True, 'Large nested collection; individual entries handle playability.', game_id != 'private-dos-classics')

    if game_id in HOSTED_SERVICE_IDS or any(s in text for s in ['lan service', 'lan server', 'hosted service', 'dedicated server', 'start / join']):
        return result('hosted-lan', 'Start on demand', 'Start / join', 'LAN service', 'LAN/browser or client', 'local server', True, 'Hosted LAN service or local persistent game.', 'age-13-plus' not in categories)

    is_native_download = 'games/downloads/native/' in text or '../games/downloads/native/' in text or 'downloads/native/' in text
    is_deb_only = any(s in text for s in ['sudo apt install ./*.deb', 'debian package', 'package closure', 'seed package', 'offline package shelf'])
    has_desktop_bundle = any(s in text for s in ['windows', '.exe', 'appimage', 'macos', 'mac os', '.dmg', 'download clients'])
    is_scummvm_deb = 'scummvm' in text and is_deb_only

    if is_native_download and (is_deb_only or is_scummvm_deb) and not has_desktop_bundle:
        return result('linux-package', 'Needs easy launcher', 'Setup notes', 'Needs launcher', 'Linux package only', 'advanced install only', False, 'Only a Debian/Linux package shelf is present; no browser/Windows/simple launcher path yet.', False)

    if is_native_download and has_desktop_bundle:
        return result('desktop-client', 'Installable', 'Install / play', 'Desktop client', 'Windows/Linux client', 'desktop install', False, 'Has client downloads but still needs a one-click launcher or clearer install flow.', False)

    if any(s in text for s in ['candidate', 'blocked', 'waiting for files', 'restore needed', 'not yet', 'needs qa']):
        return result('needs-setup', 'Needs setup', 'View details', 'Needs setup', 'Setup needed', 'not ready', False, 'Page text indicates files/testing/setup are incomplete.', False)

    if 'emulator' in text or any(cat in categories for cat in ['retro', 'emulator']) and any(s in text for s in ['game boy', 'gba', 'gbc', 'dosbox', 'js-dos']):
        return result('browser-emulator', 'Ready offline', 'Play', 'Emulator', 'Browser emulator', 'browser play', True, 'Browser emulator path is available.', True)

    if any(cat in categories for cat in ['mobile-friendly', 'family', 'casual', 'puzzle', 'age-5-plus']):
        guest = True
    else:
        guest = 'age-13-plus' not in categories
    return result('browser', 'Ready offline', 'Play', 'Browser ready', 'Browser', 'browser play', True, 'Default local browser game or wrapper.', guest)


def audit(catalog_path: Path, mirrors_root: Path) -> dict[str, Any]:
    catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
    games = catalog.get('games') if isinstance(catalog.get('games'), list) else []
    adapters: dict[str, dict[str, Any]] = {}
    counts: dict[str, int] = {}
    needs_easy_launcher: list[dict[str, str]] = []
    missing_targets: list[dict[str, str]] = []
    for game in games:
        page_text, target = read_page(catalog_path, mirrors_root, game)
        info = adapter_for(game, page_text)
        info['target'] = target
        adapters[str(game.get('id') or '')] = info
        counts[info['adapter']] = counts.get(info['adapter'], 0) + 1
        if info['adapter'] in {'linux-package', 'desktop-client'}:
            needs_easy_launcher.append({'id': str(game.get('id') or ''), 'title': str(game.get('title') or ''), 'adapter': info['adapter'], 'reason': info['reason']})
        if target and not Path(target).exists():
            missing_targets.append({'id': str(game.get('id') or ''), 'title': str(game.get('title') or ''), 'target': target})
    return {
        'generatedAt': dt.datetime.now(dt.timezone.utc).isoformat(),
        'catalog': str(catalog_path),
        'total': len(games),
        'counts': dict(sorted(counts.items())),
        'games': adapters,
        'needsEasyLauncher': needs_easy_launcher,
        'missingTargets': missing_targets,
    }


def report_markdown(result: dict[str, Any]) -> str:
    lines = [
        '# Launcher Adapter Audit',
        '',
        f"Generated: `{result['generatedAt']}`",
        f"Top-level cards audited: **{result['total']}**",
        '',
        '## Adapter Counts',
        '',
    ]
    for key, value in result['counts'].items():
        lines.append(f'- `{key}`: {value}')
    lines += ['', '## Needs Easy Launcher', '']
    if not result['needsEasyLauncher']:
        lines.append('None.')
    else:
        for item in result['needsEasyLauncher'][:80]:
            lines.append(f"- `{item['id']}` - {item['title']} ({item['adapter']}): {item['reason']}")
        if len(result['needsEasyLauncher']) > 80:
            lines.append(f"- ... {len(result['needsEasyLauncher']) - 80} more")
    lines += ['', '## Missing Targets', '']
    if not result['missingTargets']:
        lines.append('None.')
    else:
        for item in result['missingTargets']:
            lines.append(f"- `{item['id']}` - {item['title']}: `{item['target']}`")
    lines += ['', '## Rule', '', 'Games with `linux-package` or `desktop-client` adapters are not shown as Ready now until they get a browser launcher, a simple desktop launcher bundle, or a server-streamed play path.']
    return '\n'.join(lines).rstrip() + '\n'


def main() -> int:
    parser = argparse.ArgumentParser(description='Audit LAN Arcade launcher adapters.')
    parser.add_argument('--catalog', default=str(DEFAULT_CATALOG))
    parser.add_argument('--mirrors-root', default=str(DEFAULT_MIRRORS))
    parser.add_argument('--output', default=str(DEFAULT_OUTPUT))
    parser.add_argument('--report-dir', default=str(DEFAULT_REPORT))
    args = parser.parse_args()

    result = audit(Path(args.catalog), Path(args.mirrors_root))
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    report_dir = Path(args.report_dir)
    report_dir.mkdir(parents=True, exist_ok=True)
    (report_dir / 'report.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    (report_dir / 'REPORT.md').write_text(report_markdown(result), encoding='utf-8')
    print(report_markdown(result))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
