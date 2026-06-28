#!/usr/bin/env python3
"""Build the VM-local Lemmings browser adapter.

This publishes Lemmings.ts plus Dylan-provided original Lemmings data files to
/var/www/html/mirrors/lemmings. The engine is cached from the MIT-licensed
Lemmings.ts release; original game data stays outside Git under the private NFS
intake cache.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import tempfile
import time
import urllib.request
import zipfile
from pathlib import Path

VERSION = "1.1.0"
RELEASE_URL = "https://github.com/tomsoftware/Lemmings.ts/releases/download/1.1.0/Lemmings.ts.zip"
CACHE = Path("/srv/lan-arcade/native-downloads/runtimes/lemmings-ts") / VERSION / "Lemmings.ts.zip"
DATA_ROOT = Path("/srv/lan-arcade/native-downloads/intake/private-tycoon/lemmings-ma")
DEST = Path("/var/www/html/mirrors/lemmings")
PUBLIC_BASE = "/mirrors/lemmings/"
REQUIRED_DATA = [
    "ADLIB.DAT",
    "GROUND0O.DAT", "GROUND1O.DAT", "GROUND2O.DAT", "GROUND3O.DAT", "GROUND4O.DAT",
    "LEVEL000.DAT", "LEVEL001.DAT", "LEVEL002.DAT", "LEVEL003.DAT", "LEVEL004.DAT",
    "LEVEL005.DAT", "LEVEL006.DAT", "LEVEL007.DAT", "LEVEL008.DAT", "LEVEL009.DAT",
    "MAIN.DAT", "ODDTABLE.DAT",
    "VGAGR0.DAT", "VGAGR1.DAT", "VGAGR2.DAT", "VGAGR3.DAT", "VGAGR4.DAT",
    "VGASPEC0.DAT", "VGASPEC1.DAT", "VGASPEC2.DAT", "VGASPEC3.DAT",
]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def ensure_cache() -> None:
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    if CACHE.exists() and CACHE.stat().st_size > 100_000:
        return
    tmp = CACHE.with_suffix(".download")
    with urllib.request.urlopen(RELEASE_URL, timeout=60) as response, tmp.open("wb") as out:
        shutil.copyfileobj(response, out)
    tmp.replace(CACHE)


def latest_data_root() -> Path:
    hits = sorted(
        (DATA_ROOT / "work").glob("start-dosroot-*"),
        key=lambda p: (p.stat().st_mtime, str(p)),
    )
    if not hits:
        raise SystemExit(f"No Lemmings DOS data root found under {DATA_ROOT / 'work'}")
    return hits[-1]


def patch_index(app_root: Path) -> None:
    index = app_root / "index.html"
    text = index.read_text(encoding="utf-8")
    replacements = {
        'href="/favicon.ico"': f'href="{PUBLIC_BASE}favicon.ico"',
        'href="/css/': f'href="{PUBLIC_BASE}css/',
        'href=/css/': f'href={PUBLIC_BASE}css/',
        'src="/js/': f'src="{PUBLIC_BASE}js/',
        'src=/js/': f'src={PUBLIC_BASE}js/',
        'href="/js/': f'href="{PUBLIC_BASE}js/',
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    index.write_text(text, encoding="utf-8")


def patch_app_bundle(app_root: Path) -> None:
    data_base = PUBLIC_BASE.rstrip("/") + "/data"
    required_replacements = {
        'history:Object(a["b"])("/")': f'history:Object(a["b"])("{PUBLIC_BASE}")',
        'new Ae("/data")': f'new Ae("{data_base}")',
        'new Ae("./data")': f'new Ae("{data_base}")',
        't.count=function(){return 7}': 't.count=function(){return 2}',
    }
    remaining = set(required_replacements)
    for bundle in (app_root / "js").glob("app.*.js"):
        text = bundle.read_text(encoding="utf-8")
        changed = False
        for old, replacement in required_replacements.items():
            if old in text:
                text = text.replace(old, replacement)
                remaining.discard(old)
                changed = True
        if changed:
            bundle.write_text(text, encoding="utf-8")
    if remaining:
        raise SystemExit("Could not patch Lemmings.ts app bundle markers: " + ", ".join(sorted(remaining)))


def limit_to_original_lemmings(app_root: Path) -> None:
    config = app_root / "data" / "config.json"
    games = json.loads(config.read_text(encoding="utf-8"))
    games = [game for game in games if game.get("path") == "lemmings"]
    if len(games) != 1:
        raise SystemExit("Could not limit Lemmings.ts config to original Lemmings data")
    config.write_text(json.dumps(games, indent=2) + "\n", encoding="utf-8")


def write_history_fallbacks(app_root: Path) -> None:
    fallback = app_root / "game" / "1" / "index.html"
    fallback.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(app_root / "index.html", fallback)


def copy_data(app_root: Path, source: Path) -> list[dict[str, str | int]]:
    dest = app_root / "data" / "lemmings"
    dest.mkdir(parents=True, exist_ok=True)
    by_lower = {p.name.lower(): p for p in source.iterdir() if p.is_file()}
    copied = []
    missing = []
    for name in REQUIRED_DATA:
        src = by_lower.get(name.lower())
        if not src:
            missing.append(name)
            continue
        target = dest / name
        shutil.copy2(src, target)
        copied.append({"name": name, "bytes": target.stat().st_size, "sha256": sha256(target)})
    if missing:
        raise SystemExit("Missing required Lemmings data files: " + ", ".join(missing))
    return copied


def write_metadata(app_root: Path, copied: list[dict[str, str | int]]) -> None:
    meta = {
        "name": "Lemmings Browser Edition",
        "engine": "Lemmings.ts",
        "engineVersion": VERSION,
        "engineLicense": "MIT with LGPL OPL emulator component; see LICENSE in cached source",
        "dataSource": "Dylan-provided DOS Lemmings files from private NFS intake cache",
        "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "dataFiles": copied,
        "offline": True,
        "publicExternalLinks": False,
    }
    (app_root / "lan-arcade-lemmings.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    (app_root / "README-LAN-ARCADE.txt").write_text(
        "Lemmings Browser Edition for LAN Arcade\n"
        "Built from cached Lemmings.ts plus private local game data.\n"
        "No internet is required after this directory is published.\n",
        encoding="utf-8",
    )
    license_path = app_root / "LICENSE"
    if not license_path.exists():
        license_path.write_text(
            "Lemmings.ts engine license: MIT. OPL emulator component: LGPL 2.1+.\n"
            "See upstream release/source cache for full notices.\n",
            encoding="utf-8",
        )


def publish(staged: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    backup = dest.parent / f".{dest.name}.previous-{int(time.time())}"
    if dest.exists():
        dest.rename(backup)
    try:
        staged.rename(dest)
    except Exception:
        if backup.exists():
            backup.rename(dest)
        raise
    if backup.exists():
        shutil.rmtree(backup)


def build(dest: Path) -> None:
    ensure_cache()
    data_root = latest_data_root()
    with tempfile.TemporaryDirectory(prefix="lemmings-ts-") as tmp_name:
        tmp = Path(tmp_name)
        with zipfile.ZipFile(CACHE) as archive:
            archive.extractall(tmp)
        extracted = tmp / "Lemmings.ts"
        if not extracted.exists():
            raise SystemExit("Unexpected Lemmings.ts release layout")
        patch_index(extracted)
        patch_app_bundle(extracted)
        limit_to_original_lemmings(extracted)
        write_history_fallbacks(extracted)
        copied = copy_data(extracted, data_root)
        write_metadata(extracted, copied)
        publish(extracted, dest)
    print(f"Built Lemmings browser adapter at {dest}")
    print(f"Engine cache: {CACHE}")
    print(f"Data source: {data_root}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the LAN Arcade Lemmings.ts adapter")
    parser.add_argument("--dest", type=Path, default=DEST)
    args = parser.parse_args()
    build(args.dest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
