#!/usr/bin/env python3
"""Cache the second native-game intake batch for LAN Arcade.

The binary shelves live under /var/www/html/mirrors/games/downloads/native,
which is backed by NFS on GannanNet. Hub pages and metadata stay in Git.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

USER_AGENT = "LAN-Arcade-Native-Cache/1.1"
DOWNLOAD_ROOT = Path("/var/www/html/mirrors/games/downloads/native")
DOCS_ROOT = Path("/var/www/html/mirrors")

GAMES = {
    "supertuxkart": {
        "title": "SuperTuxKart",
        "version": "1.5",
        "source": "https://github.com/supertuxkart/stk-code/releases/tag/1.5",
        "notes": "Official SuperTuxKart 1.5 platform packages. Debian 12 VM launch smoke uses packaged 1.4, while the offline shelf stores current upstream 1.5 clients.",
        "assets": [
            {"name": "SuperTuxKart-1.5-installer-x86_64.exe", "label": "Windows 64-bit installer", "platform": "Windows 10/11 64-bit", "url": "https://github.com/supertuxkart/stk-code/releases/download/1.5/SuperTuxKart-1.5-installer-x86_64.exe", "note": "Recommended Windows desktop installer."},
            {"name": "SuperTuxKart-1.5-linux-x86_64.tar.gz", "label": "Linux x86_64 archive", "platform": "Linux x86_64", "url": "https://github.com/supertuxkart/stk-code/releases/download/1.5/SuperTuxKart-1.5-linux-x86_64.tar.gz", "note": "Portable Linux build from upstream."},
            {"name": "SuperTuxKart-1.5-mac-signed.zip", "label": "macOS signed app ZIP", "platform": "macOS", "url": "https://github.com/supertuxkart/stk-code/releases/download/1.5/SuperTuxKart-1.5-mac-signed.zip", "note": "Signed macOS package."},
            {"name": "SuperTuxKart-1.5.apk", "label": "Android APK", "platform": "Android", "url": "https://github.com/supertuxkart/stk-code/releases/download/1.5/SuperTuxKart-1.5.apk", "note": "Android build for tablets/phones."},
        ],
        "docs": {"dest": "supertuxkart-site", "source_subdir": "supertuxkart.net", "pages": ["https://supertuxkart.net/Main_Page", "https://supertuxkart.net/Discover", "https://supertuxkart.net/FAQ", "https://supertuxkart.net/Download"]},
    },
    "xonotic": {
        "title": "Xonotic",
        "version": "0.8.6",
        "source": "https://xonotic.org/download/",
        "notes": "Official all-platform Xonotic 0.8.6 ZIP and source ZIP from dl.xonotic.org.",
        "assets": [
            {"name": "xonotic-0.8.6.zip", "label": "All-platform game ZIP", "platform": "Windows / Linux / macOS", "url": "https://dl.xonotic.org/xonotic-0.8.6.zip", "note": "Complete upstream release ZIP with clients/server assets."},
            {"name": "xonotic-0.8.6-source.zip", "label": "Source ZIP", "platform": "Build/repair", "url": "https://dl.xonotic.org/xonotic-0.8.6-source.zip", "note": "Small source archive for reference and license inspection."},
        ],
        "docs": {"dest": "xonotic-site", "source_subdir": "xonotic.org", "pages": ["https://xonotic.org/", "https://xonotic.org/download/", "https://xonotic.org/guide/", "https://xonotic.org/faq/"]},
    },
    "redeclipse": {
        "title": "Red Eclipse",
        "version": "2.0.0",
        "source": "https://github.com/redeclipse/base/releases/tag/v2.0.0",
        "notes": "Official Red Eclipse 2.0.0 Jupiter Edition release assets. Debian 12 VM launch smoke uses packaged 1.6.0.",
        "assets": [
            {"name": "redeclipse_2.0.0_combined.tar.bz2", "label": "Combined release archive", "platform": "Cross-platform archive", "url": "https://github.com/redeclipse/base/releases/download/v2.0.0/redeclipse_2.0.0_combined.tar.bz2", "note": "Large combined upstream archive for offline repair/use."},
            {"name": "redeclipse_2.0.0_win.exe", "label": "Windows installer", "platform": "Windows", "url": "https://github.com/redeclipse/base/releases/download/v2.0.0/redeclipse_2.0.0_win.exe", "note": "Windows installer from the official release."},
            {"name": "redeclipse_2.0.0_nix.tar.bz2", "label": "Linux archive", "platform": "Linux", "url": "https://github.com/redeclipse/base/releases/download/v2.0.0/redeclipse_2.0.0_nix.tar.bz2", "note": "Linux package from the official release."},
        ],
        "docs": {"dest": "redeclipse-site", "source_subdir": "www.redeclipse.net", "pages": ["https://www.redeclipse.net/", "https://www.redeclipse.net/docs/", "https://www.redeclipse.net/download/"]},
    },
    "openarena": {
        "title": "OpenArena",
        "version": "0.8.8",
        "source": "https://sourceforge.net/projects/oarena/files/openarena-0.8.8.zip/download",
        "notes": "OpenArena 0.8.8 full ZIP from the official SourceForge project plus Debian VM client/server packages for smoke testing.",
        "assets": [
            {"name": "openarena-0.8.8.zip", "label": "OpenArena full ZIP", "platform": "Windows / Linux / macOS data bundle", "url": "https://downloads.sourceforge.net/project/oarena/openarena-0.8.8.zip", "note": "Official 0.8.8 full release ZIP."},
        ],
        "docs": {"dest": "openarena-site", "source_subdir": "openarena.ws", "pages": ["https://openarena.ws/", "https://openarena.ws/download.php"]},
    },
    "freedoom": {
        "title": "Freedoom + Doom Engines",
        "version": "freedoom-0.13.0-engines-2026-06",
        "source": "https://github.com/freedoom/freedoom/releases/tag/v0.13.0",
        "notes": "Fully free Doom-compatible IWADs plus open-source Doom engine builds for common desktop targets.",
        "assets": [
            {"name": "freedoom-0.13.0.zip", "label": "Freedoom phase 1/2 ZIP", "platform": "Game data", "url": "https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip", "note": "Free Doom-compatible single-player campaigns."},
            {"name": "freedm-0.13.0.zip", "label": "FreeDM ZIP", "platform": "Deathmatch data", "url": "https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedm-0.13.0.zip", "note": "Free deathmatch-oriented IWAD."},
            {"name": "freedoom-0.13.0-CHECKSUM", "label": "Freedoom checksums", "platform": "Integrity", "url": "https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0-CHECKSUM", "note": "Official checksum file."},
            {"name": "chocolate-doom-3.1.1-win64.zip", "label": "Chocolate Doom Windows", "platform": "Windows 64-bit", "url": "https://github.com/chocolate-doom/chocolate-doom/releases/download/chocolate-doom-3.1.1/chocolate-doom-3.1.1-win64.zip", "note": "Vanilla-compatible Windows engine."},
            {"name": "chocolate-doom-3.1.1-arm64.dmg", "label": "Chocolate Doom macOS ARM", "platform": "macOS Apple Silicon", "url": "https://github.com/chocolate-doom/chocolate-doom/releases/download/chocolate-doom-3.1.1/chocolate-doom-3.1.1-arm64.dmg", "note": "macOS Apple Silicon engine."},
            {"name": "chocolate-doom-3.1.1-x86.dmg", "label": "Chocolate Doom macOS Intel", "platform": "macOS Intel", "url": "https://github.com/chocolate-doom/chocolate-doom/releases/download/chocolate-doom-3.1.1/chocolate-doom-3.1.1-x86.dmg", "note": "macOS Intel engine."},
            {"name": "prboom-plus-2666-ucrt64.zip", "label": "PrBoom+ Windows", "platform": "Windows 64-bit", "url": "https://github.com/coelckers/prboom-plus/releases/download/v2.6.66/prboom-plus-2666-ucrt64.zip", "note": "Modern Doom-compatible Windows engine."},
        ],
        "docs": {"dest": "freedoom-site", "source_subdir": "freedoom.github.io", "pages": ["https://freedoom.github.io/", "https://freedoom.github.io/download.html"]},
    },
    "bzflag": {
        "title": "BZFlag",
        "version": "2.4.30",
        "source": "https://www.bzflag.org/downloads/",
        "notes": "Official BZFlag 2.4.30 Windows/macOS/source packages. Debian 12 VM smoke uses packaged 2.4.26.",
        "assets": [
            {"name": "bzflag-2.4.30.exe", "label": "Windows installer", "platform": "Windows", "url": "https://download.bzflag.org/bzflag/windows/2.4.30/bzflag-2.4.30.exe", "note": "Official Windows installer."},
            {"name": "BZFlag-2.4.30-macOS.zip", "label": "macOS ZIP", "platform": "macOS", "url": "https://download.bzflag.org/bzflag/macos/2.4.30/BZFlag-2.4.30-macOS.zip", "note": "Official macOS package."},
            {"name": "bzflag-2.4.30.tar.bz2", "label": "Source tarball", "platform": "Build/repair", "url": "https://download.bzflag.org/bzflag/source/2.4.30/bzflag-2.4.30.tar.bz2", "note": "Official source tarball."},
            {"name": "bzflag-2.4.30.zip", "label": "Source ZIP", "platform": "Build/repair", "url": "https://download.bzflag.org/bzflag/source/2.4.30/bzflag-2.4.30.zip", "note": "Official source ZIP."},
        ],
        "docs": {"dest": "bzflag-site", "source_subdir": "www.bzflag.org", "pages": ["https://www.bzflag.org/", "https://www.bzflag.org/downloads/", "https://www.bzflag.org/getting-started/"]},
    },
    "freeorion": {
        "title": "FreeOrion",
        "version": "v0.5.1.2",
        "source": "https://github.com/freeorion/freeorion/releases/tag/v0.5.1.2",
        "notes": "Official FreeOrion 0.5.1.2 release files. Debian 12 VM launch smoke uses packaged 0.4.10.2.",
        "assets": [
            {"name": "FreeOrion_v0.5.1.2_Win32_Setup.exe", "label": "Windows installer", "platform": "Windows", "url": "https://github.com/freeorion/freeorion/releases/download/v0.5.1.2/FreeOrion_v0.5.1.2_Win32_Setup.exe", "note": "Official Windows installer."},
            {"name": "FreeOrion_v0.5.1.2_MacOSX_10.15_x86_64.dmg", "label": "macOS Intel DMG", "platform": "macOS Intel", "url": "https://github.com/freeorion/freeorion/releases/download/v0.5.1.2/FreeOrion_v0.5.1.2_MacOSX_10.15_x86_64.dmg", "note": "Official Intel macOS package."},
            {"name": "FreeOrion_v0.5.1.2_MacOSX_10.15_arm64.dmg", "label": "macOS ARM DMG", "platform": "macOS Apple Silicon", "url": "https://github.com/freeorion/freeorion/releases/download/v0.5.1.2/FreeOrion_v0.5.1.2_MacOSX_10.15_arm64.dmg", "note": "Official Apple Silicon package."},
            {"name": "FreeOrion-v0.5.1.2_Source.tar.gz", "label": "Source archive", "platform": "Build/repair", "url": "https://github.com/freeorion/freeorion/releases/download/v0.5.1.2/FreeOrion-v0.5.1.2_Source.tar.gz", "note": "Official source archive."},
        ],
        "docs": {"dest": "freeorion-site", "source_subdir": "freeorion.org", "pages": ["https://freeorion.org/", "https://freeorion.org/index.php/Main_Page", "https://freeorion.org/index.php/Quick_Play_Guide"]},
    },
    "endless-sky": {
        "title": "Endless Sky",
        "version": "v0.10.16",
        "source": "https://github.com/endless-sky/endless-sky/releases/tag/v0.10.16",
        "notes": "Official Endless Sky 0.10.16 Windows/macOS/Linux release packages.",
        "assets": [
            {"name": "EndlessSky-v0.10.16-win64-setup.exe", "label": "Windows 64-bit installer", "platform": "Windows 64-bit", "url": "https://github.com/endless-sky/endless-sky/releases/download/v0.10.16/EndlessSky-v0.10.16-win64-setup.exe", "note": "Recommended Windows installer."},
            {"name": "EndlessSky-win64-v0.10.16.zip", "label": "Windows 64-bit ZIP", "platform": "Windows portable", "url": "https://github.com/endless-sky/endless-sky/releases/download/v0.10.16/EndlessSky-win64-v0.10.16.zip", "note": "Portable Windows package."},
            {"name": "Endless_Sky-v0.10.16-x86_64.AppImage", "label": "Linux AppImage", "platform": "Linux x86_64", "url": "https://github.com/endless-sky/endless-sky/releases/download/v0.10.16/Endless_Sky-v0.10.16-x86_64.AppImage", "note": "Portable Linux build."},
            {"name": "Endless-Sky-v0.10.16.dmg", "label": "macOS DMG", "platform": "macOS", "url": "https://github.com/endless-sky/endless-sky/releases/download/v0.10.16/Endless-Sky-v0.10.16.dmg", "note": "Official macOS package."},
        ],
        "docs": {"dest": "endless-sky-site", "source_subdir": "endless-sky.github.io", "pages": ["https://endless-sky.github.io/", "https://endless-sky.github.io/manual.html"]},
    },
    "cataclysm-dda": {
        "title": "Cataclysm: Dark Days Ahead",
        "version": "0.I-2026-06-06",
        "source": "https://github.com/CleverRaven/Cataclysm-DDA/releases/tag/0.I",
        "notes": "Cataclysm DDA stable 0.I Ito release assets from 2026-06-06.",
        "assets": [
            {"name": "cdda-windows-with-graphics-and-sounds-x64-2026-06-06-1535.zip", "label": "Windows graphics+sounds ZIP", "platform": "Windows x64", "url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.I/cdda-windows-with-graphics-and-sounds-x64-2026-06-06-1535.zip", "note": "Recommended rich Windows package."},
            {"name": "cdda-linux-with-graphics-and-sounds-x64-2026-06-06-1535.tar.gz", "label": "Linux graphics+sounds", "platform": "Linux x64", "url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.I/cdda-linux-with-graphics-and-sounds-x64-2026-06-06-1535.tar.gz", "note": "Recommended Linux graphics package."},
            {"name": "cdda-linux-terminal-only-x64-2026-06-06-1535.tar.gz", "label": "Linux terminal build", "platform": "Low-resource Linux", "url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.I/cdda-linux-terminal-only-x64-2026-06-06-1535.tar.gz", "note": "Low-resource terminal package."},
            {"name": "cdda-android-x64-2026-06-06-1535.apk", "label": "Android x64 APK", "platform": "Android x64", "url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.I/cdda-android-x64-2026-06-06-1535.apk", "note": "Android x64 package."},
            {"name": "cdda-osx-with-graphics-universal-2026-06-06-1535.dmg", "label": "macOS graphics universal", "platform": "macOS universal", "url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.I/cdda-osx-with-graphics-universal-2026-06-06-1535.dmg", "note": "macOS graphics build."},
        ],
        "docs": {"dest": "cataclysm-dda-site", "source_subdir": "cataclysmdda.org", "pages": ["https://cataclysmdda.org/", "https://cataclysmdda.org/releases/", "https://cataclysmdda.org/design-doc/"]},
    },
    "manaplus": {
        "title": "The Mana World / ManaPlus",
        "version": "2.1.3.17",
        "source": "https://manaplus.org/",
        "notes": "ManaPlus 2.1.3.17 source and Debian VM packages. The official binary download host timed out from the VM during intake, so Windows/macOS upstream binaries are recorded as blocked for now.",
        "assets": [
            {"name": "ManaPlus-2.1.3.17.tar.gz", "label": "ManaPlus source tarball", "platform": "Build/repair", "url": "https://github.com/ManaPlus/ManaPlus/archive/refs/tags/v2.1.3.17.tar.gz", "note": "GPL source archive from the official GitHub mirror tag."},
        ],
        "apt_assets": ["manaplus", "manaplus-data"],
        "docs": {"dest": "manaplus-site", "source_subdir": "manaplus.org", "pages": ["https://manaplus.org/", "https://manaplus.org/changelog", "https://manaplus.org/player"]},
        "blocked_assets": [
            "http://download.evolonline.org/manaplus/download/manaplus-win32.exe timed out from the VM",
            "http://download.evolonline.org/manaplus/download/manaplus-win64.exe timed out from the VM",
            "http://download.evolonline.org/manaplus/download/mana.dmg timed out from the VM",
        ],
    },
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def human_size(size: int) -> str:
    value = float(size)
    for unit in ["B", "KB", "MB", "GB"]:
        if value < 1024 or unit == "GB":
            return f"{value:.1f} {unit}" if unit != "B" else f"{int(value)} B"
        value /= 1024
    return f"{size} B"


def download_url(url: str, target: Path) -> tuple[str, int]:
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and target.stat().st_size > 0:
        return sha256_file(target), target.stat().st_size
    part = target.with_suffix(target.suffix + ".part")
    cmd = [
        "wget", "-c", "--tries=3", "--timeout=90", "--read-timeout=90",
        "--progress=dot:giga", "--user-agent", USER_AGENT, "-O", str(part), url,
    ]
    print("DOWNLOAD", target.name, url, flush=True)
    subprocess.run(cmd, check=True)
    if not part.exists() or part.stat().st_size == 0:
        raise RuntimeError(f"download failed or empty: {url}")
    part.replace(target)
    return sha256_file(target), target.stat().st_size


def download_apt_package(pkg: str, version_dir: Path) -> dict:
    version_dir.mkdir(parents=True, exist_ok=True)
    before = {p.name for p in version_dir.glob("*.deb")}
    print(f"APT_DOWNLOAD {pkg}", flush=True)
    subprocess.run(["apt-get", "download", pkg], cwd=version_dir, check=True)
    candidates = [p for p in version_dir.glob(f"{pkg}_*.deb") if p.name not in before or p.stat().st_size > 0]
    if not candidates:
        candidates = list(version_dir.glob(f"{pkg}_*.deb"))
    if not candidates:
        raise RuntimeError(f"apt-get download did not create package for {pkg}")
    path = max(candidates, key=lambda p: p.stat().st_mtime)
    return {
        "name": path.name,
        "label": f"Debian package: {pkg}",
        "platform": "Debian/Ubuntu-style Linux",
        "url": f"apt:{pkg}",
        "note": "Cached from the Debian repository configured on GannanNet for offline Linux repair/install.",
        "sha256": sha256_file(path),
        "size": path.stat().st_size,
    }


def write_index(slug: str, game: dict, assets: list[dict]) -> None:
    root = DOWNLOAD_ROOT / slug
    version = game["version"]
    version_dir = root / version
    cards = []
    for asset in assets:
        cards.append(
            "<article class='card'>"
            f"<h2>{html.escape(asset['label'])}</h2>"
            f"<p class='audience'>{html.escape(asset['platform'])}</p>"
            f"<p>{html.escape(asset['note'])}</p>"
            f"<a class='button' href='{html.escape(version)}/{html.escape(asset['name'])}'>Download {html.escape(asset['name'])}</a>"
            f"<p class='meta'>{human_size(asset['size'])} - SHA256 <code>{asset['sha256'][:16]}...</code></p>"
            "</article>"
        )
    blocked = "".join(f"<li>{html.escape(item)}</li>" for item in game.get("blocked_assets", []))
    blocked_html = f"<section class='blocked'><h2>Blocked / Not Cached Yet</h2><ul>{blocked}</ul></section>" if blocked else ""
    page = f"""<!doctype html>
<html lang='en'>
<head>
  <meta charset='utf-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1'>
  <title>{html.escape(game['title'])} Offline Downloads</title>
  <style>
    :root {{ color-scheme: dark; --bg:#10131a; --card:#1b2330; --line:#344055; --text:#f4f7fb; --muted:#c3cedf; --accent:#69d4a3; --ink:#06110c; --warn:#f0be5a; }}
    * {{ box-sizing:border-box; }} body {{ margin:0; font-family:system-ui,-apple-system,Segoe UI,sans-serif; background:var(--bg); color:var(--text); }}
    main {{ width:min(1120px,94vw); margin:0 auto; padding:34px 0 48px; }} h1 {{ margin:0 0 8px; font-size:clamp(30px,5vw,58px); line-height:1; }}
    .lede {{ color:var(--muted); max-width:880px; line-height:1.5; }} .grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(260px,1fr)); gap:14px; margin-top:22px; }}
    .card,.blocked {{ border:1px solid var(--line); border-radius:8px; padding:16px; background:var(--card); }} .card h2,.blocked h2 {{ margin:0 0 5px; font-size:20px; }}
    .audience,.meta,.blocked li {{ color:var(--muted); }} .button {{ display:inline-block; margin:8px 0; padding:10px 12px; border-radius:8px; background:var(--accent); color:var(--ink); font-weight:850; text-decoration:none; }}
    code {{ background:#090d12; border:1px solid rgba(255,255,255,.12); border-radius:5px; padding:2px 5px; }} .links {{ display:flex; flex-wrap:wrap; gap:10px; margin-top:18px; }}
    .links a {{ color:var(--text); border:1px solid var(--line); border-radius:8px; padding:9px 10px; text-decoration:none; }} .blocked {{ margin-top:18px; border-color:rgba(240,190,90,.5); }}
  </style>
</head>
<body>
  <main>
    <h1>{html.escape(game['title'])} Offline Downloads</h1>
    <p class='lede'>Version <strong>{html.escape(version)}</strong>. {html.escape(game.get('notes', 'Official release files cached for LAN Arcade.'))}</p>
    <div class='links'><a href='../../../../games/'>Back to Arcade</a><a href='{html.escape(version)}/SHA256SUMS.txt'>SHA256SUMS</a><a href='manifest.json'>Manifest JSON</a><a href='{html.escape(game.get('source', '#'))}'>Original source</a></div>
    <section class='grid'>{''.join(cards)}</section>
    {blocked_html}
  </main>
</body>
</html>
"""
    root.mkdir(parents=True, exist_ok=True)
    version_dir.mkdir(parents=True, exist_ok=True)
    (root / "index.html").write_text(page, encoding="utf-8")
    (version_dir / "index.html").write_text(page.replace(f"href='{html.escape(version)}/", "href='"), encoding="utf-8")
    manifest = {"title": game["title"], "version": version, "source": game.get("source"), "notes": game.get("notes"), "assets": assets, "blocked_assets": game.get("blocked_assets", [])}
    (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (version_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (version_dir / "SHA256SUMS.txt").write_text("".join(f"{a['sha256']}  {a['name']}\n" for a in assets), encoding="utf-8")
    latest = root / "latest"
    if latest.exists() or latest.is_symlink():
        if latest.is_dir() and not latest.is_symlink():
            shutil.rmtree(latest)
        else:
            latest.unlink()
    latest.symlink_to(version_dir.name, target_is_directory=True)


def cache_game(slug: str) -> None:
    game = GAMES[slug]
    version_dir = DOWNLOAD_ROOT / slug / game["version"]
    assets = []
    for asset in game.get("assets", []):
        print(f"Caching {slug}: {asset['name']}", flush=True)
        sha, size = download_url(asset["url"], version_dir / asset["name"])
        enriched = dict(asset)
        enriched.update({"sha256": sha, "size": size})
        assets.append(enriched)
    for pkg in game.get("apt_assets", []):
        assets.append(download_apt_package(pkg, version_dir))
    write_index(slug, game, assets)
    print(f"DOWNLOADS_READY={DOWNLOAD_ROOT / slug}", flush=True)


def write_docs_blocker(dest: Path, title: str, detail: str) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    (dest / "LAN_ARCADE_DOCS_BLOCKED.txt").write_text(detail, encoding="utf-8")
    escaped_title = html.escape(title)
    escaped_detail = html.escape(detail).replace("\n", "<br>\n")
    (dest / "index.html").write_text(f"""<!doctype html>
<html lang='en'>
<head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'><title>{escaped_title} mirror blocker</title><style>body{{margin:0;font-family:system-ui,Segoe UI,sans-serif;background:#0c1114;color:#f2f7f8}}main{{max-width:880px;margin:0 auto;padding:44px 20px}}a{{color:#77b7ff}}.panel{{border:1px solid #2d3b43;border-radius:8px;background:#151d22;padding:20px}}code{{color:#ffe08a}}</style></head>
<body><main><p><a href='../games/'>Back to Arcade</a></p><div class='panel'><h1>{escaped_title}</h1><p>The official website/wiki mirror did not complete. Downloads may still be cached locally; this page records the blocker instead of pretending a manual exists.</p><p><code>{escaped_detail}</code></p></div></main></body>
</html>
""", encoding="utf-8")


def patch_docs_for_offline(root: Path) -> None:
    for path in root.rglob("*.html"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        lines = [
            line for line in text.splitlines()
            if "googletagmanager.com" not in line
            and "google-analytics.com" not in line
            and "fonts.googleapis.com" not in line
            and "doubleclick.net" not in line
        ]
        path.write_text("\n".join(lines) + ("\n" if text.endswith("\n") else ""), encoding="utf-8")
    (root / "LAN_ARCADE_OFFLINE_PATCH.txt").write_text("Mirrored for LAN Arcade; common external tracker/font references stripped where practical.\n", encoding="utf-8")


def mirror_docs(slug: str) -> None:
    docs = GAMES[slug].get("docs")
    if not docs:
        print(f"DOCS_SKIPPED={slug}")
        return
    dest = DOCS_ROOT / docs["dest"]
    with tempfile.TemporaryDirectory(prefix=f"{slug}-docs-") as tmp_name:
        tmp = Path(tmp_name)
        page_args = docs.get("pages") or [docs["url"]]
        source_note = docs.get("url") or ", ".join(page_args)
        cmd = [
            "wget", "--quiet", "--convert-links", "--adjust-extension", "--page-requisites",
            "--recursive", "--level", str(docs.get("level", 2)),
            "--timeout=20", "--tries=2", "--user-agent", USER_AGENT,
            "--reject-regex", r"(logout|login|signup|register|action=edit|Special:|printable=yes)",
            "--directory-prefix", str(tmp),
        ]
        cmd.extend(page_args)
        print("DOCS_MIRROR", slug, flush=True)
        proc = subprocess.run(cmd, check=False)
        source = tmp / docs["source_subdir"]
        if proc.returncode != 0 or not source.exists():
            write_docs_blocker(
                dest,
                f"{GAMES[slug]['title']} docs mirror blocked",
                f"Docs mirror did not complete. wget_status={proc.returncode}\nSource pages: {source_note}\nChecked {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\n",
            )
            print(f"DOCS_BLOCKED={slug} status={proc.returncode}", flush=True)
            return
        backup = dest.with_name(dest.name + ".backup-before-refresh")
        if backup.exists():
            shutil.rmtree(backup)
        if dest.exists() and any(dest.iterdir()):
            dest.rename(backup)
        shutil.copytree(source, dest, dirs_exist_ok=True)
        patch_docs_for_offline(dest)
        (dest / "LAN_ARCADE_SOURCE.txt").write_text(f"Mirrored from {source_note}\nRefreshed {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\n", encoding="utf-8")
    print(f"DOCS_READY={dest}", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Cache next-ten native game downloads and docs for LAN Arcade")
    parser.add_argument("games", nargs="*", help="Game slugs to cache; default all")
    parser.add_argument("--skip-downloads", action="store_true")
    parser.add_argument("--skip-docs", action="store_true")
    args = parser.parse_args()
    unknown = sorted(set(args.games) - set(GAMES))
    if unknown:
        parser.error(f"unknown game slug(s): {', '.join(unknown)}")
    selected = args.games or sorted(GAMES)
    for slug in selected:
        if not args.skip_downloads:
            cache_game(slug)
        if not args.skip_docs:
            mirror_docs(slug)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
