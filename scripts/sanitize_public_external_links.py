#!/usr/bin/env python3
"""Remove public external navigation and runtime references from deployed mirrors.

LAN Arcade is an offline appliance. Public HTML should never send a player to an
internet URL or load internet media. This post-deploy guard rewrites remaining
external refs to local placeholders/offline notices, while preserving source URLs
in non-public manifests/operator notes.
"""
from __future__ import annotations

import argparse
import json
import re
import time
import urllib.parse
from pathlib import Path

ATTR_RE = re.compile(r"(<(?P<tag>[a-zA-Z0-9:-]+)\b[^>]*?\s)(?P<attr>href|src|action|poster|data-[a-zA-Z0-9:-]*(?:href|src))=(?P<quote>['\"])(?P<value>(?:https?:)?//(?:(?!(?P=quote)).)+)(?P=quote)", re.I)
SRCSET_RE = re.compile(r"(<(?P<tag>[a-zA-Z0-9:-]+)\b[^>]*?\s)(?P<attr>srcset|data-[a-zA-Z0-9:-]*srcset)=(?P<quote>['\"])(?P<value>[^'\"]*https?://[^'\"]+|[^'\"]*//[^'\"]+)(?P=quote)", re.I)
CSS_URL_RE = re.compile(r"url\((?P<quote>['\"]?)(https?://[^)'\"]+|//[^)'\"]+)(?P=quote)\)", re.I)
SCAN_SUFFIXES = {'.html', '.htm', '.css'}
INTERNAL_HOSTS = {'127.0.0.1', 'localhost', '192.168.1.106', 'gannannet.local', 'gannan.home.arpa', 'lan-arcade.invalid'}


def ensure_assets(root: Path) -> None:
    assets = root / '_offline_assets'
    assets.mkdir(parents=True, exist_ok=True)
    (assets / 'blank.css').write_text('/* LAN Arcade offline placeholder */\n', encoding='utf-8')
    (assets / 'offline-shims.js').write_text('// LAN Arcade offline placeholder\n', encoding='utf-8')
    (assets / 'placeholder.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360"><rect width="640" height="360" fill="#101820"/><text x="50%" y="48%" fill="#d7e7f2" text-anchor="middle" font-family="Arial" font-size="28">Saved media needed</text><text x="50%" y="58%" fill="#92a7b5" text-anchor="middle" font-family="Arial" font-size="18">Ask the arcade to save this image or video locally.</text></svg>\n', encoding='utf-8')
    games = root / 'games'
    games.mkdir(parents=True, exist_ok=True)
    offline_html = """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Offline page not saved yet</title><style>:root{color-scheme:dark}body{margin:0;background:#090d12;color:#eef6ff;font-family:system-ui,-apple-system,Segoe UI,sans-serif}main{width:min(760px,92vw);margin:10vh auto}.panel{border:1px solid #314357;background:#121922;border-radius:8px;padding:20px}a{color:#eef6ff;background:#182230;border:1px solid #314357;border-radius:7px;padding:9px 11px;text-decoration:none;font-weight:800;display:inline-flex}p{color:#a8b8cc;line-height:1.5}</style></head><body><main><div class="panel"><h1>This page is not saved on the arcade yet</h1><p>LAN Arcade is offline-first, so public links stay on this server. The original site or media reference has been kept in operator records for future saving, but it is not opened from here.</p><p>Ask the arcade operator to save the website, guide, screenshot, or video locally if it would be useful for this game.</p><a href="/mirrors/games/">Back to Game Library</a></div></main></body></html>"""
    (games / 'offline-link.html').write_text(offline_html, encoding='utf-8')


def is_internal(value: str) -> bool:
    normalized = value if not value.startswith('//') else 'http:' + value
    parsed = urllib.parse.urlparse(normalized)
    return (parsed.hostname or '').lower() in INTERNAL_HOSTS


def replacement_for(tag: str, attr: str, value: str) -> str:
    tag = tag.lower()
    attr = attr.lower()
    if attr.endswith('href'):
        attr = 'href'
    elif attr.endswith('src'):
        attr = 'src'
    if tag in {'a', 'area'} and attr == 'href':
        return ''
    if attr == 'action':
        return '/mirrors/games/offline-link.html'
    if tag == 'link' and attr == 'href':
        return '/mirrors/_offline_assets/blank.css'
    if tag == 'script' and attr == 'src':
        return '/mirrors/_offline_assets/offline-shims.js'
    if tag in {'img', 'source', 'video', 'audio', 'iframe', 'embed', 'object'} or attr in {'src', 'poster'}:
        return '/mirrors/_offline_assets/placeholder.svg'
    return '/mirrors/games/offline-link.html'


def sanitize_text(text: str, stats: dict[str, int]) -> str:
    def attr_repl(match: re.Match[str]) -> str:
        value = match.group('value')
        if is_internal(value):
            return match.group(0)
        stats['attributeRefs'] += 1
        repl = replacement_for(match.group('tag'), match.group('attr'), value)
        if match.group('tag').lower() in {'a', 'area'} and match.group('attr').lower() == 'href':
            return (
                f"{match.group(1)}aria-disabled=\"true\" "
                'data-arcade-external-removed="true" title="Not available offline"'
            )
        return f"{match.group(1)}{match.group('attr')}={match.group('quote')}{repl}{match.group('quote')} data-arcade-external-removed=\"true\""

    def srcset_repl(match: re.Match[str]) -> str:
        value = match.group('value')
        refs = [part.strip().split()[0] for part in value.split(',') if part.strip()]
        externals = [ref for ref in refs if ref.startswith(('http://', 'https://', '//'))]
        if externals and all(is_internal(ref) for ref in externals):
            return match.group(0)
        if not externals:
            return match.group(0)
        stats['srcsetRefs'] += 1
        return f"{match.group(1)}{match.group('attr')}={match.group('quote')}/mirrors/_offline_assets/placeholder.svg{match.group('quote')} data-arcade-external-removed=\"true\""

    def css_repl(match: re.Match[str]) -> str:
        value = match.group(2)
        if is_internal(value):
            return match.group(0)
        stats['cssRefs'] += 1
        return 'url(/mirrors/_offline_assets/placeholder.svg)'

    out = text
    while True:
        updated = ATTR_RE.sub(attr_repl, out)
        if updated == out:
            break
        out = updated
    while True:
        updated = SRCSET_RE.sub(srcset_repl, out)
        if updated == out:
            break
        out = updated
    out = CSS_URL_RE.sub(css_repl, out)
    out = re.sub(
        r'href=[\"\']/mirrors/games/offline-link\.html[\"\']\s+data-arcade-external-removed=[\"\']true[\"\']',
        'aria-disabled="true" data-arcade-external-removed="true" title="Not available offline"',
        out,
        flags=re.I,
    )

    return out


def main() -> int:
    parser = argparse.ArgumentParser(description='Sanitize public external links/media from LAN Arcade HTML')
    parser.add_argument('--root', type=Path, default=Path('/var/www/html/mirrors'))
    parser.add_argument('--report', type=Path)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    root = args.root.resolve()
    if not root.exists():
        raise SystemExit(f'root not found: {root}')
    ensure_assets(root)
    report = {'root': str(root), 'generatedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), 'dryRun': args.dry_run, 'filesChanged': [], 'counts': {'attributeRefs': 0, 'srcsetRefs': 0, 'cssRefs': 0, 'rawRefs': 0}}
    for path in sorted(p for p in root.rglob('*') if p.is_file() and p.suffix.lower() in SCAN_SUFFIXES):
        text = path.read_text(encoding='utf-8', errors='ignore')
        updated = sanitize_text(text, report['counts'])
        if updated != text:
            report['filesChanged'].append(str(path.relative_to(root)))
            if not args.dry_run:
                path.write_text(updated, encoding='utf-8')
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'filesChanged': len(report['filesChanged']), **report['counts']}, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
