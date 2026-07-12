#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import time
from pathlib import Path, PurePosixPath

from promote_native_payloads import EXPECTED_DEST, nfs_mount
from validate_staging_root import require_local_staging_root

ALLOWED_SUFFIXES = {'.html', '.htm', '.css'}
EXPECTED_BACKUP_PARENT = Path('/home/dylan/LAN_Arcade/tmp/metadata-backups')


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def require_safe_relative(value: str) -> Path:
    pure = PurePosixPath(value)
    if pure.is_absolute() or not pure.parts or any(part in {'', '.', '..'} for part in pure.parts):
        raise SystemExit(f'unsafe metadata path: {value!r}')
    path = Path(*pure.parts)
    if path.suffix.lower() not in ALLOWED_SUFFIXES:
        raise SystemExit(f'non-metadata path refused: {value!r}')
    return path


def resolve_within(root: Path, path: Path, *, label: str) -> Path:
    resolved = path.resolve(strict=True)
    if resolved != root and not resolved.is_relative_to(root):
        raise SystemExit(f'{label} escaped its root: {path} -> {resolved}')
    return resolved


def require_local_backup_root(value: str) -> Path:
    root = Path(value).expanduser().resolve()
    parent = EXPECTED_BACKUP_PARENT.resolve()
    if root == parent or not root.is_relative_to(parent):
        raise SystemExit(f'backup root must be a timestamped child of {parent}: {root}')
    root.mkdir(parents=True, exist_ok=True)
    probe = subprocess.run(
        ['findmnt', '-n', '-o', 'FSTYPE', '-T', str(root)],
        text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if probe.returncode != 0 or any(line.strip() in {'nfs', 'nfs4'} for line in probe.stdout.splitlines()):
        raise SystemExit(f'backup root must be VM-local: {root}')
    return root


def load_paths(report_path: Path) -> list[Path]:
    report = json.loads(report_path.read_text(encoding='utf-8'))
    raw_paths = report.get('filesChanged')
    if not isinstance(raw_paths, list) or not raw_paths:
        raise SystemExit(f'no filesChanged paths in report: {report_path}')
    paths = sorted({require_safe_relative(str(value)) for value in raw_paths})
    if len(paths) > 500:
        raise SystemExit(f'unexpected metadata replacement count: {len(paths)}')
    return paths


def main() -> int:
    parser = argparse.ArgumentParser(
        description='Atomically replace only approved native shelf metadata, with VM-local backups'
    )
    parser.add_argument('--source-root', required=True)
    parser.add_argument('--dest-root', required=True)
    parser.add_argument('--paths-report', required=True)
    parser.add_argument('--backup-root', required=True)
    parser.add_argument('--receipt', required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()

    source = require_local_staging_root(args.source_root, label='native metadata promotion')
    dest = Path(args.dest_root).expanduser().resolve(strict=True)
    if dest != EXPECTED_DEST:
        raise SystemExit(f'refusing unexpected destination: {dest}')
    fstype = nfs_mount(dest)
    backup = require_local_backup_root(args.backup_root)
    paths = load_paths(Path(args.paths_report))

    records: dict[str, dict[str, object]] = {}
    physical_targets: set[Path] = set()
    for rel in paths:
        source_path = resolve_within(source, source / rel, label='source metadata')
        dest_path = resolve_within(dest, dest / rel, label='destination metadata')
        if dest_path in physical_targets:
            raise SystemExit(f'duplicate physical metadata target: {dest_path}')
        physical_targets.add(dest_path)
        if not source_path.is_file() or source_path.is_symlink():
            raise SystemExit(f'source metadata missing or unsafe: {source_path}')
        if not dest_path.is_file() or dest_path.is_symlink():
            raise SystemExit(f'destination metadata missing or unsafe: {dest_path}')
        source_hash = sha256(source_path)
        dest_hash = sha256(dest_path)
        records[rel.as_posix()] = {
            'sourceSha256': source_hash,
            'previousSha256': dest_hash,
            'changed': source_hash != dest_hash,
            'bytes': source_path.stat().st_size,
        }

    summary = {
        'source': str(source),
        'destination': str(dest),
        'destinationFilesystem': fstype,
        'backup': str(backup),
        'filesSelected': len(paths),
        'filesChanged': sum(1 for record in records.values() if record['changed']),
        'mode': 'apply' if args.apply else 'dry-run',
        'generatedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
    }
    print(json.dumps(summary, indent=2))
    if not args.apply:
        return 0

    for rel in paths:
        record = records[rel.as_posix()]
        if not record['changed']:
            continue
        source_path = resolve_within(source, source / rel, label='source metadata')
        dest_path = resolve_within(dest, dest / rel, label='destination metadata')
        backup_path = backup / rel
        backup_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(dest_path, backup_path)
        if sha256(backup_path) != record['previousSha256']:
            raise SystemExit(f'backup verification failed: {backup_path}')

        temp_path = dest_path.with_name(f'.{dest_path.name}.lan-arcade-metadata-{os.getpid()}')
        try:
            shutil.copy2(source_path, temp_path)
            if sha256(temp_path) != record['sourceSha256']:
                raise SystemExit(f'temporary metadata verification failed: {temp_path}')
            os.replace(temp_path, dest_path)
        finally:
            temp_path.unlink(missing_ok=True)
        if sha256(dest_path) != record['sourceSha256']:
            raise SystemExit(f'promoted metadata verification failed: {dest_path}')

    receipt = Path(args.receipt)
    receipt.parent.mkdir(parents=True, exist_ok=True)
    receipt.write_text(
        json.dumps({**summary, 'mode': 'applied', 'inventory': records}, indent=2) + '\n',
        encoding='utf-8',
    )
    print(f'METADATA_PROMOTION_PASS receipt={receipt}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
