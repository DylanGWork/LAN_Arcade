#!/usr/bin/env python3
"""Fail if public LAN Arcade HTML/CSS still references internet URLs."""
from __future__ import annotations

import argparse
import json
import re
import urllib.parse
from pathlib import Path

HTML_REF_RE = re.compile(
    r"\b(?P<attr>href|src|action|poster|srcset)\s*=\s*"
    r"(?:\"(?P<double>[^\"]*)\"|'(?P<single>[^']*)'|(?P<bare>[^\s>]+))",
    re.I,
)
URL_TOKEN_RE = re.compile(r"(?:https?:)?//[^\s,'\")>]+", re.I)
CSS_URL_RE = re.compile(
    r"url\((?P<quote>['\"]?)(?P<value>(?:https?:)?//[^)'\"]+)(?P=quote)\)",
    re.I,
)
SCAN_SUFFIXES = {'.html', '.htm', '.css'}
INTERNAL_HOSTS = {'127.0.0.1', 'localhost', '192.168.1.106', 'gannannet.local', 'gannan.home.arpa', 'lan-arcade.invalid'}


def is_internal(value: str) -> bool:
    normalized = value if not value.startswith('//') else 'http:' + value
    parsed = urllib.parse.urlparse(normalized)
    return (parsed.hostname or '').lower() in INTERNAL_HOSTS


def main() -> int:
    parser = argparse.ArgumentParser(description='Audit public arcade HTML/CSS for external URLs')
    parser.add_argument('--root', type=Path, default=Path('/var/www/html/mirrors'))
    parser.add_argument('--limit', type=int, default=80)
    parser.add_argument('--json', type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    if not root.exists():
        raise SystemExit(f'root not found: {root}')
    findings = []
    for path in sorted(p for p in root.rglob('*') if p.is_file() and p.suffix.lower() in SCAN_SUFFIXES):
        text = path.read_text(encoding='utf-8', errors='ignore')
        references = []
        if path.suffix.lower() == '.css':
            references.extend((match.start(), match.group('value'), 'css-url') for match in CSS_URL_RE.finditer(text))
        else:
            for match in HTML_REF_RE.finditer(text):
                value = match.group('double') or match.group('single') or match.group('bare') or ''
                for token in URL_TOKEN_RE.finditer(value):
                    references.append((match.start() + token.start(), token.group(0), match.group('attr').lower()))
        for position, url, kind in references:
            url = url.rstrip('.,;')
            if is_internal(url):
                continue
            line = text.count('\n', 0, position) + 1
            findings.append({
                'file': str(path.relative_to(root)),
                'line': line,
                'kind': kind,
                'url': url[:260],
            })
            if len(findings) >= args.limit:
                break
        if len(findings) >= args.limit:
            break
    result = {'root': str(root), 'externalUrlCountShown': len(findings), 'findings': findings}
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    if findings:
        print('External public URLs remain:')
        for item in findings:
            print(f"- {item['file']}:{item['line']} {item['url']}")
        return 2
    print('No public external URLs found in HTML/CSS.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
