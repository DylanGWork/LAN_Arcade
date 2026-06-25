#!/usr/bin/env python3
"""Import Dylan-provided old PC game ZIPs into the private DOS intake cache.

This script intentionally keeps game archives outside Git. It copies files from
/srv/lan-arcade/native-downloads/intake/private-tycoon/_incoming into each
per-game raw/ folder and prepares a DOS root for browser packaging when the ZIP
contains a directly launchable DOS game.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import time
import zipfile
from pathlib import Path

SRC = Path('/srv/lan-arcade/native-downloads/intake/private-tycoon')
INCOMING = SRC / '_incoming'

# Direct launch targets. ISO/Win3x/install-only packages are copied to raw/ but
# left un-packaged until they get a game-specific recipe.
GAMES = {
    'simcity-classic-dos-ma': dict(file='SimCity_DOS_EN_Version-20-Quaders-Release.zip', cmd='SIMCITY.EXE'),
    'sim-farm-dos-ma': dict(file='Sim-Farm_DOS_EN.zip', cmd='SIMFARM.EXE'),
    'railroad-tycoon-deluxe-dos-ma': dict(file='Sid-Meiers-Railroad-Tycoon-Deluxe_DOS_EN.zip', cmd='RRT.EXE', root_prefix='rrt-direct'),
    'firestorm-review': dict(file='Firestorm-The-Forest-Fire-Simulation-Program_DOS_EN.zip', raw_only=True),
    'a-train-dos-ma': dict(file='A-Train_DOS_EN.zip', cmd='AT.EXE'),
    'black-gold-dos-ma': dict(file='Black-Gold_DOS_EN.zip', cmd='BLKGOLD.EXE'),
    'incredible-machine-1-ma': dict(file='The-Incredible-Machine_DOS_EN.zip', cmd='TIM.EXE'),
    'oregon-trail-deluxe-ma': dict(file='Oregon-Trail-Deluxe_DOS_EN.zip', cmd='OREGON.EXE'),
    'prince-of-persia-ma': dict(file='Prince-of-Persia_DOS_EN_v10.zip', cmd='PRINCE.EXE'),
    'lemmings-ma': dict(file='Lemmings_DOS_EN.zip', cmd='LEMMINGS.BAT'),
    'dune-ii-ma': dict(file='Dune-II-The-Building-of-a-Dynasty_DOS_EN.zip', cmd='DUNE2.EXE'),
    'simant-ma': dict(file='SimAnt-The-Electronic-Ant-Colony_DOS_EN.zip', cmd='SIMANT.EXE'),
    'rogue-ma': dict(file='Rogue_DOS_EN.zip', cmd='ROGUE.EXE'),
    'railroad-tycoon-dos-ma': dict(file='Sid-Meiers-Railroad-Tycoon_DOS_EN_Pre-Installed.zip', cmd='RAILS.BAT'),
    'railroad-empire-dos-ma': dict(file='Railroad-Empire_DOS_EN.zip', cmd='RE.EXE'),
    'gta-london-1961-ma': dict(file='Grand-Theft-Auto-Mission-Pack-2-London-1961_DOS_EN.zip', cmd='LONDON61.BAT'),
}

RAW_ONLY = {
    'civilization-1-ma': 'Sid-Meier-s-Civilization_DOS_EN_ISO-Version-47403.zip',
    'mario-teaches-typing-ma': 'Mario-Teaches-Typing_DOS_EN_Original-disk.zip',
    'road-rash-ma': 'Road-Rash_Win_EN-FR-ES-DE-IT_ISO-Version-1997-Rerelease.zip',
    'championship-manager-9798-ma': 'Championship-Manager-Season-9798_DOS_EN_ISO-Version-281.zip',
    'incredible-machine-2-ma': 'The-Incredible-Machine-2_DOS_EN-FR-ES-DE_ISO-Version.zip',
    'gta-london-1969-ma': 'Grand-Theft-Auto-Mission-Pack-1-London-1969_DOS_EN_ISO-Version.zip',
    'take-a-train-iv-dos-ma': 'Take-the-A-Train-IV_Win-3x_KO.zip',
    'corporate-pursuit-win3x-ma': 'Corporate-Pursuit_Win-3x_EN_Win3xO-release.zip',
}

EXCLUDE_NAMES = {'dosbox.exe'}
EXCLUDE_SUFFIXES = {'.dll'}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def copy_raw(game_id: str, filename: str) -> tuple[Path | None, dict]:
    src = INCOMING / filename
    record = dict(id=game_id, file=filename, imported=False, packagePrepared=False, reason='')
    if not src.exists():
        record['reason'] = 'incoming ZIP not found'
        return None, record
    raw = SRC / game_id / 'raw'
    raw.mkdir(parents=True, exist_ok=True)
    target = raw / filename
    if not target.exists() or target.stat().st_size != src.stat().st_size:
        shutil.copy2(src, target)
    record.update(imported=True, bytes=target.stat().st_size, sha256=sha256(target), rawPath=str(target))
    return target, record


def find_launch_dir(extract_dir: Path, command: str) -> Path | None:
    wanted = command.lower()
    matches = [p for p in extract_dir.rglob('*') if p.is_file() and p.name.lower() == wanted]
    if not matches:
        return None
    matches.sort(key=lambda p: (len(p.relative_to(extract_dir).parts), str(p).lower()))
    return matches[0].parent


def copy_tree_filtered(src: Path, dst: Path) -> None:
    if dst.exists():
        shutil.rmtree(dst)
    dst.mkdir(parents=True)
    for item in src.iterdir():
        if item.name.lower() in EXCLUDE_NAMES or item.suffix.lower() in EXCLUDE_SUFFIXES:
            continue
        target = dst / item.name
        if item.is_dir():
            shutil.copytree(item, target, ignore=shutil.ignore_patterns('__MACOSX'))
        else:
            shutil.copy2(item, target)


def write_play_files(root: Path, command: str) -> None:
    (root / 'PLAY.BAT').write_text('@echo off\r\n' + command + '\r\n', encoding='ascii', errors='ignore')
    conf_lines = [
        '[sdl]', 'autolock=false',
        '[dosbox]', 'machine=svga_s3', 'memsize=32',
        '[render]', 'aspect=true',
        '[cpu]', 'core=auto', 'cycles=auto',
        '[autoexec]', '@echo off', 'mount c .', 'c:', 'PLAY.BAT',
    ]
    (root / 'dosbox.conf').write_text('\r\n'.join(conf_lines) + '\r\n', encoding='ascii')


def prepare_dosroot(game_id: str, archive: Path, command: str, root_prefix: str, stamp: str) -> dict:
    work = SRC / game_id / 'work'
    extract_dir = work / f'import-extract-{stamp}'
    dosroot = work / f'{root_prefix}-{stamp}'
    work.mkdir(parents=True, exist_ok=True)
    if extract_dir.exists():
        shutil.rmtree(extract_dir)
    extract_dir.mkdir(parents=True)
    with zipfile.ZipFile(archive) as z:
        z.extractall(extract_dir)
    launch_dir = find_launch_dir(extract_dir, command)
    if not launch_dir:
        return dict(packagePrepared=False, reason=f'launch command not found: {command}')
    copy_tree_filtered(launch_dir, dosroot)
    write_play_files(dosroot, command)
    return dict(packagePrepared=True, command=command, dosroot=str(dosroot), launchSource=str(launch_dir))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--games', nargs='*', help='Optional game ids to import')
    args = ap.parse_args()
    selected = set(args.games or [])
    stamp = time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())
    records = []

    for game_id, cfg in GAMES.items():
        if selected and game_id not in selected:
            continue
        archive, record = copy_raw(game_id, cfg['file'])
        if archive and not cfg.get('raw_only'):
            record.update(prepare_dosroot(game_id, archive, cfg['cmd'], cfg.get('root_prefix', 'start-dosroot'), stamp))
        elif archive:
            record.update(packagePrepared=False, reason='raw archive copied; existing builder handles this recipe')
        records.append(record)

    for game_id, filename in RAW_ONLY.items():
        if selected and game_id not in selected:
            continue
        _archive, record = copy_raw(game_id, filename)
        if record.get('imported'):
            record.update(packagePrepared=False, reason='raw-only for now: ISO, Win3x, installer-only, or needs game-specific recipe')
        records.append(record)

    out = SRC / f'import-manifest-{stamp}.json'
    out.write_text(json.dumps(dict(generatedAt=stamp, records=records), indent=2), encoding='utf-8')
    print(f'wrote {out}')
    for r in records:
        status = 'prepared' if r.get('packagePrepared') else ('raw' if r.get('imported') else 'missing')
        print(f'{status:8} {r["id"]} {r["file"]} {r.get("reason", "")}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
