#!/usr/bin/env python3
"""Download and rewrite remote media URLs left inside a saved website mirror."""
from __future__ import annotations

import argparse
import hashlib
import json
import mimetypes
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

URL_RE = re.compile(r"https?://[^\s\"'<>)]*(?:\)|[^\s\"'<>),.])")
MEDIA_EXTS = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.avif', '.ico', '.woff', '.woff2', '.ttf', '.eot', '.otf'}
SCAN_EXTS = {'.html', '.htm', '.css'}


def is_media_url(url: str) -> bool:
    parsed = urllib.parse.urlparse(url)
    path = urllib.parse.unquote(parsed.path)
    ext = Path(path).suffix.lower()
    if ext in MEDIA_EXTS:
        return True
    if parsed.netloc in {'fonts.googleapis.com', 'fonts.gstatic.com'}:
        return True
    if '/uploads/' in path and ext:
        return True
    return False


def local_name(url: str, content_type: str = '') -> str:
    parsed = urllib.parse.urlparse(url)
    name = Path(urllib.parse.unquote(parsed.path)).name or 'asset'
    name = re.sub(r'[^A-Za-z0-9._-]+', '-', name).strip('-') or 'asset'
    suffix = Path(name).suffix
    if not suffix and content_type:
        suffix = mimetypes.guess_extension(content_type.split(';', 1)[0].strip()) or ''
    digest = hashlib.sha256(url.encode('utf-8')).hexdigest()[:14]
    stem = name[:-len(Path(name).suffix)] if Path(name).suffix else name
    return f'{digest}-{stem[:70]}{suffix}'


def rel_url(from_file: Path, target: Path) -> str:
    return Path('../' * (len(from_file.parent.relative_to(from_file.parents[-1]).parts))).as_posix()


def relative_reference(file_path: Path, asset_path: Path, root: Path) -> str:
    rel = asset_path.relative_to(file_path.parent).as_posix() if asset_path.is_relative_to(file_path.parent) else None
    if rel:
        return rel
    return Path('../../').as_posix()


def main() -> int:
    parser = argparse.ArgumentParser(description='Repair remote media URLs in an offline mirror')
    parser.add_argument('--mirror-root', required=True, type=Path)
    parser.add_argument('--asset-dir', default='LAN_ARCADE_EXTERNAL_ASSETS')
    parser.add_argument('--report', type=Path)
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--timeout', type=float, default=20)
    args = parser.parse_args()

    root = args.mirror_root.resolve()
    if not root.exists() or not root.is_dir():
        raise SystemExit(f'mirror root not found: {root}')
    assets_root = root / args.asset_dir
    report = {
        'mirrorRoot': str(root),
        'generatedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'dryRun': args.dry_run,
        'downloaded': [],
        'rewrittenFiles': [],
        'failed': [],
        'remainingMediaUrls': [],
    }

    files = [p for p in root.rglob('*') if p.is_file() and p.suffix.lower() in SCAN_EXTS]
    all_urls: dict[str, Path] = {}
    for path in files:
        text = path.read_text(encoding='utf-8', errors='ignore')
        for url in sorted(set(URL_RE.findall(text))):
            url = url.rstrip('.,;')
            if is_media_url(url):
                all_urls.setdefault(url, path)

    replacements: dict[str, Path] = {}
    opener = urllib.request.build_opener()
    opener.addheaders = [('User-Agent', 'LAN-Arcade-offline-media-repair/1.0')]
    for url in sorted(all_urls):
        try:
            with opener.open(url, timeout=args.timeout) as response:
                data = response.read()
                content_type = response.headers.get('content-type', '')
            target = assets_root / urllib.parse.urlparse(url).netloc / local_name(url, content_type)
            replacements[url] = target
            if not args.dry_run:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
            report['downloaded'].append({'url': url, 'path': str(target.relative_to(root)), 'bytes': len(data)})
        except Exception as exc:
            report['failed'].append({'url': url, 'error': str(exc)[:300]})

    for path in files:
        text = path.read_text(encoding='utf-8', errors='ignore')
        updated = text
        for url, target in replacements.items():
            if url not in updated:
                continue
            replacement = urllib.parse.quote(target.relative_to(path.parent).as_posix(), safe='/._-') if target.is_relative_to(path.parent) else urllib.parse.quote(target.relative_to(root).as_posix(), safe='/._-')
            if not target.is_relative_to(path.parent):
                replacement = urllib.parse.quote(Path(*(['..'] * len(path.parent.relative_to(root).parts))).joinpath(target.relative_to(root)).as_posix(), safe='/._-')
            updated = updated.replace(url, replacement)
        if updated != text:
            report['rewrittenFiles'].append(str(path.relative_to(root)))
            if not args.dry_run:
                path.write_text(updated, encoding='utf-8')

    for path in files:
        text = path.read_text(encoding='utf-8', errors='ignore')
        for url in sorted(set(URL_RE.findall(text))):
            url = url.rstrip('.,;')
            if is_media_url(url):
                report['remainingMediaUrls'].append({'file': str(path.relative_to(root)), 'url': url})
                if len(report['remainingMediaUrls']) >= 200:
                    break
        if len(report['remainingMediaUrls']) >= 200:
            break

    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: len(v) if isinstance(v, list) else v for k, v in report.items() if k in {'downloaded','rewrittenFiles','failed','remainingMediaUrls'}}, indent=2))
    return 0 if not report['remainingMediaUrls'] else 2


if __name__ == '__main__':
    raise SystemExit(main())
