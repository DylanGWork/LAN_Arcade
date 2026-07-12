#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import time
from pathlib import Path

from validate_staging_root import require_local_staging_root

EXPECTED_DEST = Path('/srv/lan-arcade/native-downloads')
SAFE_NAME = re.compile(r'^[A-Za-z0-9][A-Za-z0-9._-]*$')


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def nfs_mount(path: Path) -> str:
    probe = subprocess.run(
        ['findmnt', '-n', '-o', 'FSTYPE', '-T', str(path)],
        text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if probe.returncode != 0:
        raise SystemExit(f'cannot determine destination filesystem: {path}')
    fstypes = {line.strip() for line in probe.stdout.splitlines() if line.strip()}
    if not fstypes.intersection({'nfs', 'nfs4'}):
        detail = ','.join(sorted(fstypes)) or 'unknown'
        raise SystemExit(f'destination is not NFS: {path} ({detail})')
    return ','.join(sorted(fstypes))


def inventory(root: Path, names: list[str]) -> dict:
    files: dict[str, dict] = {}
    for name in names:
        base = root / name
        if not base.exists():
            raise SystemExit(f'missing selected payload: {base}')
        for path in sorted(base.rglob('*')):
            rel = path.relative_to(root).as_posix()
            if path.is_symlink():
                files[rel] = {'kind': 'symlink', 'target': os.readlink(path)}
                continue
            if path.is_dir():
                continue
            if path.name.endswith(('.part', '.tmp', '.download')):
                raise SystemExit(f'incomplete download found: {path}')
            files[rel] = {'kind': 'file', 'size': path.stat().st_size, 'sha256': sha256(path)}
    return files


def verify_existing(dest: Path, expected: dict) -> None:
    for rel, record in expected.items():
        target = dest / rel
        if not target.exists() and not target.is_symlink():
            continue
        if record['kind'] == 'symlink':
            if not target.is_symlink() or os.readlink(target) != record['target']:
                raise SystemExit(f'destination conflict: {target}')
            continue
        if not target.is_file() or target.is_symlink():
            raise SystemExit(f'destination conflict: {target}')
        if target.stat().st_size != record['size'] or sha256(target) != record['sha256']:
            raise SystemExit(f'destination file differs; refusing overwrite: {target}')


def verify_promoted(dest: Path, expected: dict) -> None:
    for rel, record in expected.items():
        target = dest / rel
        if record['kind'] == 'symlink':
            if not target.is_symlink() or os.readlink(target) != record['target']:
                raise SystemExit(f'promoted symlink mismatch: {target}')
            continue
        if not target.is_file() or target.stat().st_size != record['size']:
            raise SystemExit(f'promoted file missing or wrong size: {target}')
        if sha256(target) != record['sha256']:
            raise SystemExit(f'promoted checksum mismatch: {target}')


def main() -> int:
    parser = argparse.ArgumentParser(description='Copy verified native payloads from local staging to NFS without deletion')
    parser.add_argument('--source-root', required=True)
    parser.add_argument('--dest-root', required=True)
    parser.add_argument('--only', nargs='+', required=True)
    parser.add_argument('--receipt', required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()

    source = require_local_staging_root(args.source_root, label='native payload promotion')
    dest = Path(args.dest_root).expanduser().resolve(strict=True)
    if dest != EXPECTED_DEST:
        raise SystemExit(f'refusing unexpected destination: {dest}')
    fstype = nfs_mount(dest)

    names = sorted(set(args.only))
    for name in names:
        if not SAFE_NAME.fullmatch(name) or name in {'.zfs', 'lost+found'}:
            raise SystemExit(f'unsafe payload name: {name!r}')

    expected = inventory(source, names)
    verify_existing(dest, expected)
    total_bytes = sum(record.get('size', 0) for record in expected.values())
    summary = {
        'source': str(source),
        'destination': str(dest),
        'destinationFilesystem': fstype,
        'payloads': names,
        'filesAndLinks': len(expected),
        'bytes': total_bytes,
        'mode': 'apply' if args.apply else 'dry-run',
        'generatedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
    }
    print(json.dumps(summary, indent=2))
    if not args.apply:
        return 0

    for name in names:
        subprocess.run(['rsync', '-a', '--', str(source / name) + '/', str(dest / name) + '/'], check=True)

    verify_promoted(dest, expected)
    receipt = Path(args.receipt)
    receipt.parent.mkdir(parents=True, exist_ok=True)
    receipt.write_text(json.dumps({**summary, 'mode': 'applied', 'inventory': expected}, indent=2) + '\n')
    print(f'PROMOTION_PASS receipt={receipt}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
