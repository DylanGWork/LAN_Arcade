#!/usr/bin/env python3
from __future__ import annotations

import subprocess
from pathlib import Path


def require_local_staging_root(value: str | None, *, label: str) -> Path:
    if not value:
        raise SystemExit(f'{label} requires an explicit staging root')
    root = Path(value).expanduser().resolve(strict=True)
    if not root.is_dir():
        raise SystemExit(f'{label} staging root is not a directory: {root}')
    for forbidden in (Path('/var/www'), Path('/srv')):
        if root == forbidden or forbidden in root.parents:
            raise SystemExit(f'{label} refuses live or shared storage: {root}')
    probe = subprocess.run(
        ['findmnt', '-n', '-o', 'FSTYPE', '-T', str(root)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if probe.returncode != 0:
        raise SystemExit(f'{label} could not determine staging filesystem: {root}')
    if probe.stdout.strip() in {'nfs', 'nfs4'}:
        raise SystemExit(f'{label} refuses NFS staging storage: {root}')
    return root


def replace_latest_symlink(latest: Path, target_name: str, root: Path) -> None:
    latest_resolved_parent = latest.parent.resolve(strict=True)
    root_resolved = root.resolve(strict=True)
    if latest_resolved_parent != root_resolved and root_resolved not in latest_resolved_parent.parents:
        raise RuntimeError(f'latest link escaped staging root: {latest}')
    if latest.exists() and not latest.is_symlink():
        raise RuntimeError(f'refusing to replace non-symlink latest path: {latest}')
    if latest.is_symlink():
        latest.unlink()
    latest.symlink_to(target_name, target_is_directory=True)
