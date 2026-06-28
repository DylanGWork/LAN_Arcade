#!/usr/bin/env python3
"""Plan easy-launcher work for games that are not one-click playable yet.

This consumes the generated launcher adapter audit and produces a practical
queue for turning package/client hubs into normal player launch flows.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CATALOG = Path('/var/www/html/mirrors/games/catalog.json')
DEFAULT_LAUNCHERS = ROOT / 'config/launcher-adapters.json'
DEFAULT_DOS_MANIFEST = Path('/var/www/html/mirrors/private-dos-vault/manifest.json')
DEFAULT_OUTPUT = ROOT / 'config/easy-launcher-queue.json'
DEFAULT_REPORT_DIR = ROOT / 'qa/reports/easy-launcher-queue/latest'

SETUP_ADAPTERS = {'linux-package', 'desktop-client', 'setup-needed', 'research-shelf', 'needs-setup'}
HIGH_VALUE_TERMS = {
    'sim', 'city', 'transport', 'railroad', 'rpg', 'strategy', 'tactical', 'arcade',
    'family', 'puzzle', 'scummvm', 'adventure', 'roguelike', 'space', 'builder',
    'shooter', 'artillery', 'management', 'multiplayer', 'freeware'
}
KNOWN_HIGH_PRIORITY_IDS = {
    'beneath-a-steel-sky-scummvm', 'drascula-scummvm', 'flight-amazon-queen-scummvm',
    'lure-temptress-scummvm', 'freedink-lan', 'nethack-x11-lan', 'micropolis-lan',
    'lincity-ng-lan', 'freecol-lan', 'freedoom-lan', 'freeorion-lan', 'hedgewars-lan',
    'warmux-lan', 'scorched3d-lan', 'opencity-lan', 'ufoai-lan', 'naev-lan',
}


def as_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item).strip() for item in value if str(item).strip()]


def slug_text(value: str) -> str:
    return str(value or '').strip().lower().replace(' ', '-')


def text_blob(game: dict[str, Any], launcher: dict[str, Any]) -> str:
    parts = [
        game.get('id', ''), game.get('title', ''), game.get('meta', ''), game.get('description', ''),
        ' '.join(as_list(game.get('tags'))), ' '.join(as_list(game.get('categories'))),
        launcher.get('adapter', ''), launcher.get('reason', ''), launcher.get('statusLabel', ''),
    ]
    return ' '.join(str(part) for part in parts).lower()


def load_json(path: Path, fallback: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except Exception:
        return fallback


def indexed_catalog(path: Path) -> dict[str, dict[str, Any]]:
    raw = load_json(path, {'games': []})
    games = raw.get('games') if isinstance(raw, dict) else []
    return {str(game.get('id')): game for game in games if isinstance(game, dict) and game.get('id')}


def dos_stats(path: Path) -> dict[str, Any]:
    raw = load_json(path, {})
    games = raw.get('games') if isinstance(raw, dict) else []
    playable = [g for g in games if isinstance(g, dict) and (g.get('bundleUrl') or g.get('packageUrl'))]
    return {
        'listed': len(games) if isinstance(games, list) else 0,
        'playable': len(playable),
        'waiting': max(0, (len(games) if isinstance(games, list) else 0) - len(playable)),
        'samplePlayable': [str(g.get('title') or g.get('id')) for g in playable[:12]],
    }


def recommend(game: dict[str, Any], launcher: dict[str, Any]) -> dict[str, Any]:
    game_id = str(game.get('id') or '')
    title = str(game.get('title') or game_id)
    adapter = str(launcher.get('adapter') or '')
    text = text_blob(game, launcher)
    categories = set(as_list(game.get('categories')))
    tags = set(as_list(game.get('tags')))

    if 'scummvm' in text or 'scummvm' in categories:
        return {
            'recommendedAdapter': 'browser-emulator',
            'fallbackAdapter': 'desktop-client',
            'priority': 'high',
            'effort': 'medium',
            'nextAction': 'Build a ScummVM browser/player adapter or one-click ScummVM bundle; keep Linux package files as fallback.',
            'playerProblem': 'The game page is understandable, but normal players still cannot just click Play from a browser.',
        }

    if adapter == 'desktop-client':
        flagship = game_id in KNOWN_HIGH_PRIORITY_IDS or game_id in {'zero-ad-lan', 'wesnoth-lan', 'cataclysm-dda-lan'}
        priority = 'high' if flagship else 'medium'
        return {
            'recommendedAdapter': 'desktop-client',
            'fallbackAdapter': 'browser-stream',
            'priority': priority,
            'effort': 'medium',
            'nextAction': 'Replace raw download choices with one clear Windows/Linux install path, then smoke test first playable action.',
            'playerProblem': 'Client downloads exist, but the page does not yet behave like a simple launcher.',
        }

    if adapter == 'linux-package':
        high_words = [term for term in HIGH_VALUE_TERMS if term in text]
        priority = 'high' if game_id in KNOWN_HIGH_PRIORITY_IDS else ('medium' if len(high_words) >= 2 else 'low')
        if any(term in text for term in ['arcade', 'puzzle', 'shooter', 'family', 'casual', 'brick', 'train']):
            effort = 'medium'
        elif any(term in text for term in ['3d', 'large', 'ufo', 'space', 'strategy', 'rpg']):
            effort = 'high'
        else:
            effort = 'medium'
        return {
            'recommendedAdapter': 'browser-stream',
            'fallbackAdapter': 'linux-package',
            'priority': priority,
            'effort': effort,
            'nextAction': 'Pilot browser-streamed VM session for this Linux game, or demote it to install notes until a simple launcher exists.',
            'playerProblem': 'Only Debian/Linux offline install files are available; this is not a normal guest launch flow.',
        }

    if adapter == 'research-shelf':
        return {
            'recommendedAdapter': 'collection',
            'fallbackAdapter': 'research-shelf',
            'priority': 'low',
            'effort': 'high',
            'nextAction': 'Keep as a research shelf until individual games have rules, player counts, and table/start guidance.',
            'playerProblem': 'This is useful reference material, not a playable launcher yet.',
        }

    return {
        'recommendedAdapter': 'setup-needed',
        'fallbackAdapter': adapter or 'unknown',
        'priority': 'low',
        'effort': 'unknown',
        'nextAction': 'Inspect manually and assign a real adapter.',
        'playerProblem': 'The current launch state is ambiguous.',
    }


def build_queue(catalog_path: Path, launchers_path: Path, dos_manifest_path: Path) -> dict[str, Any]:
    catalog = indexed_catalog(catalog_path)
    audit = load_json(launchers_path, {'games': {}})
    launchers = audit.get('games') if isinstance(audit, dict) else {}
    rows: list[dict[str, Any]] = []
    for game_id, launcher in sorted(launchers.items()):
        if not isinstance(launcher, dict):
            continue
        adapter = str(launcher.get('adapter') or '')
        if adapter not in SETUP_ADAPTERS and adapter not in {'linux-package', 'desktop-client'}:
            continue
        game = catalog.get(game_id, {'id': game_id, 'title': game_id, 'tags': [], 'categories': []})
        rec = recommend(game, launcher)
        rows.append({
            'id': game_id,
            'title': str(game.get('title') or game_id),
            'currentAdapter': adapter,
            'recommendedAdapter': rec['recommendedAdapter'],
            'fallbackAdapter': rec['fallbackAdapter'],
            'priority': rec['priority'],
            'effort': rec['effort'],
            'readyNow': bool(launcher.get('readyNow')),
            'primaryAction': str(launcher.get('primaryAction') or launcher.get('playerAction') or ''),
            'path': str(game.get('path') or ''),
            'tags': as_list(game.get('tags')),
            'categories': as_list(game.get('categories')),
            'playerProblem': rec['playerProblem'],
            'nextAction': rec['nextAction'],
        })
    priority_order = {'high': 0, 'medium': 1, 'low': 2}
    effort_order = {'low': 0, 'medium': 1, 'high': 2, 'unknown': 3}
    rows.sort(key=lambda r: (priority_order.get(r['priority'], 9), effort_order.get(r['effort'], 9), r['title'].lower()))
    counts: dict[str, dict[str, int]] = {'byCurrentAdapter': {}, 'byRecommendedAdapter': {}, 'byPriority': {}, 'byEffort': {}}
    for row in rows:
        for key, field in [('byCurrentAdapter', 'currentAdapter'), ('byRecommendedAdapter', 'recommendedAdapter'), ('byPriority', 'priority'), ('byEffort', 'effort')]:
            value = str(row[field])
            counts[key][value] = counts[key].get(value, 0) + 1
    return {
        'generatedAt': dt.datetime.now(dt.timezone.utc).isoformat(),
        'catalog': str(catalog_path),
        'launcherAdapters': str(launchers_path),
        'classicPcShelf': dos_stats(dos_manifest_path),
        'counts': counts,
        'total': len(rows),
        'queue': rows,
    }


def markdown(data: dict[str, Any]) -> str:
    lines = [
        '# Easy Launcher Queue',
        '',
        f"Generated: `{data['generatedAt']}`",
        f"Remaining non-easy top-level games: **{data['total']}**",
        '',
        '## Summary',
        '',
    ]
    for section, values in data['counts'].items():
        lines.append(f'### {section}')
        for key, count in sorted(values.items(), key=lambda kv: (-kv[1], kv[0])):
            lines.append(f'- `{key}`: {count}')
        lines.append('')
    dos = data.get('classicPcShelf') or {}
    lines += [
        '## Classic PC Nested Shelf',
        '',
        f"Classic PC is already nested: **{dos.get('playable', 0)} playable** of **{dos.get('listed', 0)} listed**.",
        'Search should surface those nested playable games directly; the shelf stays compact on the home page.',
        '',
        '## Highest Priority Next Batch',
        '',
    ]
    for row in data['queue'][:30]:
        lines.append(f"- `{row['id']}` - **{row['title']}**: {row['currentAdapter']} -> {row['recommendedAdapter']} ({row['priority']}, {row['effort']}). {row['nextAction']}")
    lines += ['', '## Rule', '', 'Do not mark a row Ready now until a normal player can complete the first meaningful action without reading package/dependency lists.']
    return '\n'.join(lines).rstrip() + '\n'


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = ['id', 'title', 'currentAdapter', 'recommendedAdapter', 'fallbackAdapter', 'priority', 'effort', 'readyNow', 'primaryAction', 'path', 'playerProblem', 'nextAction']
    with path.open('w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction='ignore')
        w.writeheader()
        for row in rows:
            w.writerow(row)


def main() -> int:
    parser = argparse.ArgumentParser(description='Plan easy launcher work for remaining LAN Arcade games.')
    parser.add_argument('--catalog', type=Path, default=DEFAULT_CATALOG)
    parser.add_argument('--launchers', type=Path, default=DEFAULT_LAUNCHERS)
    parser.add_argument('--dos-manifest', type=Path, default=DEFAULT_DOS_MANIFEST)
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument('--report-dir', type=Path, default=DEFAULT_REPORT_DIR)
    args = parser.parse_args()

    data = build_queue(args.catalog, args.launchers, args.dos_manifest)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    args.report_dir.mkdir(parents=True, exist_ok=True)
    (args.report_dir / 'report.json').write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    (args.report_dir / 'REPORT.md').write_text(markdown(data), encoding='utf-8')
    write_csv(args.report_dir / 'queue.csv', data['queue'])
    print(markdown(data))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
