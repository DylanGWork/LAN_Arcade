#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

from sanitize_public_external_links import sanitize_text
from validate_staging_root import require_local_staging_root

SKIP_TOP_LEVEL = {'browser-stream', 'debian-bookworm-pool', 'intake', 'runtimes'}


def main() -> int:
    parser = argparse.ArgumentParser(description='Remove external links from generated native shelf index pages in local staging')
    parser.add_argument('--root', required=True)
    parser.add_argument('--report', required=True)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()

    root = require_local_staging_root(args.root, label='native shelf sanitizer')

    def add_index(path: Path, paths: set[Path]) -> None:
        if not path.is_file():
            return
        resolved = path.resolve(strict=True)
        if resolved != root and not resolved.is_relative_to(root):
            raise SystemExit(f'native shelf index escaped staging root: {path} -> {resolved}')
        paths.add(resolved)

    paths: set[Path] = set()
    for shelf in root.iterdir():
        if not shelf.is_dir() or shelf.name in SKIP_TOP_LEVEL:
            continue
        add_index(shelf / 'index.html', paths)
        for child in shelf.iterdir():
            if child.is_dir():
                add_index(child / 'index.html', paths)

    stats = {'attributeRefs': 0, 'srcsetRefs': 0, 'cssRefs': 0, 'rawRefs': 0}
    changed: list[str] = []
    for path in sorted(paths):
        original = path.read_text(encoding='utf-8', errors='ignore')
        updated = sanitize_text(original, stats)
        if updated == original:
            continue
        changed.append(path.relative_to(root).as_posix())
        if not args.dry_run:
            path.write_text(updated, encoding='utf-8')

    report = {
        'root': str(root),
        'dryRun': args.dry_run,
        'generatedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'filesChanged': changed,
        'counts': stats,
    }
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'filesChanged': len(changed), **stats}, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
