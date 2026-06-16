#!/usr/bin/env python3
"""Cache native game clients, server artifacts, and docs for LAN Arcade.

Large binaries are written to the deployed mirror tree instead of Git. Each game
gets a local download shelf with a manifest, SHA256 sums, and a stable latest/
symlink when versioned.
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
import urllib.request

USER_AGENT = "LAN-Arcade-Native-Cache/1.0"
DOWNLOAD_ROOT = Path("/var/www/html/mirrors/games/downloads/native")
DOCS_ROOT = Path("/var/www/html/mirrors")

GAMES = {
    "mindustry": {
        "title": "Mindustry",
        "version": "v157.4",
        "source": "https://github.com/Anuken/Mindustry/releases/tag/v157.4",
        "notes": "Server-compatible stable artifacts for the current LAN Arcade Mindustry service. The stable GitHub release does not ship a matching Android APK.",
        "assets": [
            {"name": "Mindustry.jar", "label": "Desktop client JAR", "platform": "Windows / Linux / macOS with Java", "url": "https://github.com/Anuken/Mindustry/releases/download/v157.4/Mindustry.jar", "note": "Run with Java 17+. Use this with the current LAN Arcade server build."},
            {"name": "server-release.jar", "label": "Dedicated server JAR", "platform": "Server admins", "url": "https://github.com/Anuken/Mindustry/releases/download/v157.4/server-release.jar", "note": "Cached so the server image can be rebuilt or repaired offline."},
            {"name": "dependencies.jar", "label": "Dependency bundle", "platform": "Advanced repair", "url": "https://github.com/Anuken/Mindustry/releases/download/v157.4/dependencies.jar", "note": "Upstream dependency artifact from the matching release."},
        ],
        "docs": {"url": "https://mindustrygame.github.io/wiki/", "dest": "mindustry-docs", "source_subdir": "mindustrygame.github.io/wiki"},
    },
    "openttd": {
        "title": "OpenTTD",
        "version": "15.3",
        "source": "https://www.openttd.org/downloads/openttd-releases/latest",
        "notes": "Includes OpenTTD clients plus OpenGFX, OpenSFX, and OpenMSX base sets so first launch does not need internet for core free assets.",
        "assets": [
            {"name": "openttd-15.3-windows-win64.exe", "label": "Windows installer", "platform": "Windows 64-bit", "url": "https://cdn.openttd.org/openttd-releases/15.3/openttd-15.3-windows-win64.exe", "note": "Default Windows install path."},
            {"name": "openttd-15.3-windows-win64.zip", "label": "Windows portable ZIP", "platform": "Windows 64-bit", "url": "https://cdn.openttd.org/openttd-releases/15.3/openttd-15.3-windows-win64.zip", "note": "Portable fallback if installing is not wanted."},
            {"name": "openttd-15.3-linux-generic-amd64.tar.xz", "label": "Linux generic archive", "platform": "Linux x86_64", "url": "https://cdn.openttd.org/openttd-releases/15.3/openttd-15.3-linux-generic-amd64.tar.xz", "note": "Generic Linux client/server archive."},
            {"name": "openttd-15.3-macos-universal.dmg", "label": "macOS universal DMG", "platform": "macOS", "url": "https://cdn.openttd.org/openttd-releases/15.3/openttd-15.3-macos-universal.dmg", "note": "Universal macOS package."},
            {"name": "opengfx-8.0-all.zip", "label": "OpenGFX base graphics", "platform": "OpenTTD data", "url": "https://cdn.openttd.org/opengfx-releases/8.0/opengfx-8.0-all.zip", "note": "Free base graphics set."},
            {"name": "opensfx-1.0.3-all.zip", "label": "OpenSFX sound effects", "platform": "OpenTTD data", "url": "https://cdn.openttd.org/opensfx-releases/1.0.3/opensfx-1.0.3-all.zip", "note": "Free sound effects set."},
            {"name": "openmsx-0.4.2-all.zip", "label": "OpenMSX music", "platform": "OpenTTD data", "url": "https://cdn.openttd.org/openmsx-releases/0.4.2/openmsx-0.4.2-all.zip", "note": "Free music set."},
        ],
        "docs": {"dest": "openttd-wiki", "source_subdir": "wiki.openttd.org", "pages": ["https://wiki.openttd.org/en/Manual/", "https://wiki.openttd.org/en/Manual/Main%20Page", "https://wiki.openttd.org/en/Manual/Installation", "https://wiki.openttd.org/en/Manual/Tutorial/", "https://wiki.openttd.org/en/Manual/Game%20interface", "https://wiki.openttd.org/en/Manual/Railway%20construction", "https://wiki.openttd.org/en/Manual/Signals", "https://wiki.openttd.org/en/Manual/Roadway%20construction", "https://wiki.openttd.org/en/Manual/Vehicles", "https://wiki.openttd.org/en/Manual/Orders", "https://wiki.openttd.org/en/Manual/Multiplayer", "https://wiki.openttd.org/en/Manual/Hotkeys"]},
    },
    "freeciv": {
        "title": "Freeciv",
        "version": "3.2.4",
        "source": "https://www.freeciv.org/download.html",
        "notes": "Caches a default Windows GTK4 installer, Linux AppImage, source archive, and upstream checksums.",
        "assets": [
            {"name": "Freeciv-3.2.4-msys2-win64-10-gtk4-setup.exe", "label": "Windows GTK4 installer", "platform": "Windows 10/11 64-bit", "url": "https://files.freeciv.org/packages/windows/Freeciv-3.2.4-msys2-win64-10-gtk4-setup.exe", "note": "Recommended Windows client/server installer."},
            {"name": "Freeciv-gtk4-3.2.4-x86_64.AppImage", "label": "Linux AppImage", "platform": "Linux x86_64", "url": "https://files.freeciv.org/packages/appimage/Freeciv-gtk4-3.2.4-x86_64.AppImage", "note": "Portable Linux client."},
            {"name": "freeciv-3.2.4.tar.xz", "label": "Source archive", "platform": "Build/repair", "url": "https://files.freeciv.org/stable/freeciv-3.2.4.tar.xz", "note": "Source archive for offline rebuilding if needed."},
            {"name": "SHA256SUM", "label": "Upstream SHA256SUM", "platform": "Integrity", "url": "https://files.freeciv.org/stable/SHA256SUM", "note": "Official upstream checksums."},
        ],
        "docs": {"dest": "freeciv-docs", "source_subdir": "www.freeciv.org", "pages": ["https://www.freeciv.org/", "https://www.freeciv.org/download.html"]},
    },
    "freecol": {
        "title": "FreeCol",
        "version": "1.2.0",
        "source": "https://www.freecol.org/download.html",
        "notes": "Official FreeCol 1.2.0 release files from SourceForge. The Windows bundle includes Java.",
        "assets": [
            {"name": "freecol-1.2.0-with-java.exe", "label": "Windows bundle with Java", "platform": "Windows", "url": "https://downloads.sourceforge.net/project/freecol/freecol/freecol-1.2.0/freecol-1.2.0-with-java.exe", "note": "Best Windows default because it includes Java."},
            {"name": "FreeCol-1.2.0.dmg", "label": "macOS Apple Silicon DMG", "platform": "macOS Apple Silicon", "url": "https://downloads.sourceforge.net/project/freecol/freecol/freecol-1.2.0/FreeCol-1.2.0.dmg", "note": "macOS package."},
            {"name": "FreeCol-intel-1.2.0.dmg", "label": "macOS Intel DMG", "platform": "macOS Intel", "url": "https://downloads.sourceforge.net/project/freecol/freecol/freecol-1.2.0/FreeCol-intel-1.2.0.dmg", "note": "macOS Intel package."},
            {"name": "freecol-1.2.0-installer.jar", "label": "Java installer JAR", "platform": "Java-capable desktops", "url": "https://downloads.sourceforge.net/project/freecol/freecol/freecol-1.2.0/freecol-1.2.0-installer.jar", "note": "Cross-platform Java installer."},
            {"name": "freecol-1.2.0.zip", "label": "Portable ZIP", "platform": "Java-capable desktops", "url": "https://downloads.sourceforge.net/project/freecol/freecol/freecol-1.2.0/freecol-1.2.0.zip", "note": "Extract-and-run fallback."},
        ],
    },
    "stendhal": {
        "title": "Stendhal",
        "version": "1.49",
        "source": "https://stendhalgame.org/download.html",
        "notes": "Official Stendhal client, Android APK, and server ZIP from the Arianne project downloads.",
        "assets": [
            {"name": "stendhal-1.49.zip", "label": "Java client ZIP", "platform": "Java-capable desktops", "url": "https://arianne-project.org/download/stendhal.zip", "note": "Desktop client ZIP."},
            {"name": "org.stendhalgame.client-1.49.apk", "label": "Android APK", "platform": "Android", "url": "https://arianne-project.org/download/org.stendhalgame.client.apk", "note": "Android client APK."},
            {"name": "stendhal-server-1.49.zip", "label": "Server ZIP", "platform": "Server admins", "url": "https://arianne-project.org/download/stendhal-server.zip", "note": "Server bundle for future local MMO smoke."},
        ],
    },
    "wesnoth": {
        "title": "Battle for Wesnoth",
        "version": "1.18.7",
        "source": "https://wiki.wesnoth.org/Download",
        "notes": "Stable 1.18.7 desktop clients plus upstream SHA256 files. Linux package installs are documented in the local wiki mirror.",
        "assets": [
            {"name": "wesnoth-1.18.7-win64.exe", "label": "Windows installer", "platform": "Windows 64-bit", "url": "https://downloads.sourceforge.net/project/wesnoth/wesnoth-1.18/wesnoth-1.18.7/wesnoth-1.18.7-win64.exe", "note": "Stable Windows package."},
            {"name": "Wesnoth_1.18.7.dmg", "label": "macOS DMG", "platform": "macOS", "url": "https://downloads.sourceforge.net/project/wesnoth/wesnoth-1.18/wesnoth-1.18.7/Wesnoth_1.18.7.dmg", "note": "Stable macOS package."},
            {"name": "wesnoth-1.18.7-win64.exe.sha256", "label": "Windows SHA256", "platform": "Integrity", "url": "https://files.wesnoth.org/releases/wesnoth-1.18.7-win64.exe.sha256", "note": "Official upstream checksum."},
            {"name": "Wesnoth_1.18.7.dmg.sha256", "label": "macOS SHA256", "platform": "Integrity", "url": "https://files.wesnoth.org/releases/Wesnoth_1.18.7.dmg.sha256", "note": "Official upstream checksum."},
        ],
    },
    "zero-ad": {
        "title": "0 A.D.",
        "version": "0.28.0",
        "source": "https://releases.wildfiregames.com/",
        "notes": "Release 28: Boiorix platform packages from Wildfire Games. These are large by design; keep them outside Git.",
        "assets": [
            {"name": "0ad-0.28.0-win64.exe", "label": "Windows 64-bit installer", "platform": "Windows 10/11", "url": "https://releases.wildfiregames.com/0ad-0.28.0-win64.exe", "note": "Primary Windows installer."},
            {"name": "0ad-0.28.0-x86_64.AppImage", "label": "Linux AppImage", "platform": "Linux x86_64", "url": "https://releases.wildfiregames.com/0ad-0.28.0-x86_64.AppImage", "note": "Portable Linux build."},
            {"name": "0ad-0.28.0-macos-aarch64.dmg", "label": "macOS Apple Silicon DMG", "platform": "macOS Apple Silicon", "url": "https://releases.wildfiregames.com/0ad-0.28.0-macos-aarch64.dmg", "note": "Apple Silicon package."},
            {"name": "0ad-0.28.0-macos-x86_64.dmg", "label": "macOS Intel DMG", "platform": "macOS Intel", "url": "https://releases.wildfiregames.com/0ad-0.28.0-macos-x86_64.dmg", "note": "Intel Mac package."},
        ],
    },
    "veloren": {
        "title": "Veloren / Airshipper",
        "version": "v0.17.0",
        "source": "https://gitlab.com/veloren/airshipper/-/releases/v0.17.0",
        "notes": "Airshipper launchers and server binary are cached, but the full Veloren game profile still needs an offline-cached path before this can be marked play-ready.",
        "assets": [
            {"name": "airshipper-installer.exe", "label": "Windows installer", "platform": "Windows", "url": "https://gitlab.com/veloren/airshipper/-/releases/v0.17.0/downloads/binaries/windows-installer-x86_64", "note": "Airshipper installer, not a complete offline game pack by itself."},
            {"name": "airshipper.exe", "label": "Windows client", "platform": "Windows", "url": "https://gitlab.com/veloren/airshipper/-/releases/v0.17.0/downloads/binaries/windows-client-x86_64", "note": "Portable Airshipper client."},
            {"name": "airshipper-linux.zip", "label": "Linux client ZIP", "platform": "Linux x86_64", "url": "https://gitlab.com/veloren/airshipper/-/releases/v0.17.0/downloads/binaries/linux-client-x86_64.zip", "note": "Known Debian 12 glibc blocker on the VM."},
            {"name": "airshipper-server", "label": "Linux server binary", "platform": "Linux x86_64 server", "url": "https://gitlab.com/veloren/airshipper/-/releases/v0.17.0/downloads/binaries/linux-server-x86_64", "note": "Server launcher; full server/game asset workflow still pending."},
            {"name": "airshipper-macos-x86_64.zip", "label": "macOS Intel ZIP", "platform": "macOS Intel", "url": "https://gitlab.com/veloren/airshipper/-/releases/v0.17.0/downloads/binaries/macos-client-x86_64.zip", "note": "Airshipper launcher."},
            {"name": "airshipper-macos-aarch64.zip", "label": "macOS Apple Silicon ZIP", "platform": "macOS Apple Silicon", "url": "https://gitlab.com/veloren/airshipper/-/releases/v0.17.0/downloads/binaries/macos-client-aarch64.zip", "note": "Airshipper launcher."},
        ],
        "docs": {"url": "https://book.veloren.net/", "dest": "veloren-book", "source_subdir": "book.veloren.net"},
    },
    "teeworlds-ddnet": {
        "title": "Teeworlds / DDNet",
        "version": "ddnet-19.8.2-teeworlds-0.7.5",
        "source": "https://ddnet.org/downloads/",
        "notes": "Caches current DDNet builds for co-op/race servers plus vanilla Teeworlds 0.7.5 builds for classic arena play.",
        "assets": [
            {"name": "DDNet-19.8.2-win64.zip", "label": "DDNet Windows 64-bit ZIP", "platform": "Windows 64-bit", "url": "https://ddnet.org/downloads/DDNet-19.8.2-win64.zip", "note": "Current DDNet client/server bundle from the official DDNet downloads page."},
            {"name": "DDNet-19.8.2-linux_x86_64.tar.xz", "label": "DDNet Linux x86_64", "platform": "Linux x86_64", "url": "https://ddnet.org/downloads/DDNet-19.8.2-linux_x86_64.tar.xz", "note": "Portable Linux DDNet archive."},
            {"name": "DDNet-19.8.2-macos.dmg", "label": "DDNet macOS universal DMG", "platform": "macOS arm64 / x86_64", "url": "https://ddnet.org/downloads/DDNet-19.8.2-macos.dmg", "note": "Official macOS DDNet package."},
            {"name": "DDNet-19.8.2.apk", "label": "DDNet Android APK", "platform": "Android", "url": "https://ddnet.org/downloads/DDNet-19.8.2.apk", "note": "Android APK for phone/tablet LAN play."},
            {"name": "DDNet-19.8.2.tar.xz", "label": "DDNet source", "platform": "Build/repair", "url": "https://ddnet.org/downloads/DDNet-19.8.2.tar.xz", "note": "Official DDNet source archive."},
            {"name": "teeworlds-0.7.5-win64.zip", "label": "Teeworlds Windows 64-bit ZIP", "platform": "Windows 64-bit", "url": "https://github.com/teeworlds/teeworlds/releases/download/0.7.5/teeworlds-0.7.5-win64.zip", "note": "Vanilla Teeworlds client/server package."},
            {"name": "teeworlds-0.7.5-linux_x86_64.tar.gz", "label": "Teeworlds Linux x86_64", "platform": "Linux x86_64", "url": "https://github.com/teeworlds/teeworlds/releases/download/0.7.5/teeworlds-0.7.5-linux_x86_64.tar.gz", "note": "Vanilla Teeworlds Linux package."},
            {"name": "teeworlds-0.7.5-osx.dmg", "label": "Teeworlds macOS DMG", "platform": "macOS", "url": "https://github.com/teeworlds/teeworlds/releases/download/0.7.5/teeworlds-0.7.5-osx.dmg", "note": "Vanilla Teeworlds macOS package."},
            {"name": "teeworlds-0.7.5-src.tar.gz", "label": "Teeworlds source", "platform": "Build/repair", "url": "https://github.com/teeworlds/teeworlds/releases/download/0.7.5/teeworlds-0.7.5-src.tar.gz", "note": "Official Teeworlds source archive."},
        ],
        "docs": {"dest": "teeworlds-ddnet-docs", "source_subdir": "ddnet.org", "pages": ["https://ddnet.org/downloads/"]},
    },
    "hedgewars": {
        "title": "Hedgewars",
        "version": "1.0.3-source-1.0.0-desktop",
        "source": "https://www.hedgewars.org/download.html",
        "notes": "Hedgewars upstream currently lists 1.0.0 desktop packages and 1.0.3 source/server source. Debian 12 provides 1.0.2 for VM launch smoke.",
        "assets": [
            {"name": "Hedgewars-1.0.0.exe", "label": "Windows installer", "platform": "Windows", "url": "https://www.hedgewars.org/download/releases/Hedgewars-1.0.0.exe", "note": "Official Windows installer linked from the Hedgewars download page."},
            {"name": "Hedgewars-1.0.0.dmg", "label": "macOS DMG", "platform": "macOS", "url": "https://www.hedgewars.org/download/releases/Hedgewars-1.0.0.dmg", "note": "Official macOS package linked from the Hedgewars download page."},
            {"name": "hedgewars-src-1.0.3.tar.bz2", "label": "Source archive", "platform": "Build/repair", "url": "https://www.hedgewars.org/download/releases/hedgewars-src-1.0.3.tar.bz2", "note": "Official 1.0.3 source archive."},
            {"name": "hedgewars-src-server-1.0.3.tar.bz2", "label": "Server source archive", "platform": "Server admins", "url": "https://www.hedgewars.org/download/releases/hedgewars-src-server-1.0.3.tar.bz2", "note": "Official server-only source archive."},
        ],
        "docs": {"dest": "hedgewars-docs", "source_subdir": "www.hedgewars.org", "pages": ["https://www.hedgewars.org/download.html", "https://www.hedgewars.org/media.html", "https://www.hedgewars.org/kb.html", "https://www.hedgewars.org/faq.html"]},
    },
    "widelands": {
        "title": "Widelands",
        "version": "1.3.1",
        "source": "https://github.com/widelands/widelands/releases/tag/v1.3.1",
        "notes": "Official Widelands 1.3.1 release files. The Widelands website/wiki was protected by an anti-bot page during intake, so local hub/manual notes are curated from release and project metadata.",
        "assets": [
            {"name": "Checksums-and-Signatures.zip", "label": "Checksums and signatures", "platform": "Integrity", "url": "https://github.com/widelands/widelands/releases/download/v1.3.1/Checksums-and-Signatures.zip", "note": "Official release integrity bundle."},
            {"name": "Widelands-1.3.1-x64.exe", "label": "Windows 64-bit installer", "platform": "Windows 64-bit", "url": "https://github.com/widelands/widelands/releases/download/v1.3.1/Widelands-1.3.1-x64.exe", "note": "Recommended Windows desktop package."},
            {"name": "Widelands-1.3.1-x86.exe", "label": "Windows 32-bit installer", "platform": "Windows 32-bit", "url": "https://github.com/widelands/widelands/releases/download/v1.3.1/Widelands-1.3.1-x86.exe", "note": "Fallback for older Windows hardware."},
            {"name": "Widelands-1.3.1-arm64.exe", "label": "Windows ARM installer", "platform": "Windows ARM64", "url": "https://github.com/widelands/widelands/releases/download/v1.3.1/Widelands-1.3.1-arm64.exe", "note": "Windows ARM build."},
            {"name": "Widelands-1.3.1-x86_64.AppImage", "label": "Linux AppImage", "platform": "Linux x86_64", "url": "https://github.com/widelands/widelands/releases/download/v1.3.1/Widelands-1.3.1-x86_64.AppImage", "note": "Portable Linux build."},
            {"name": "Widelands-1.3.1-macOS12_x86.dmg", "label": "macOS Intel DMG", "platform": "macOS Intel", "url": "https://github.com/widelands/widelands/releases/download/v1.3.1/Widelands-1.3.1-macOS12_x86.dmg", "note": "macOS Intel package."},
            {"name": "Widelands-1.3.1-macOS12_arm64.dmg", "label": "macOS Apple Silicon DMG", "platform": "macOS Apple Silicon", "url": "https://github.com/widelands/widelands/releases/download/v1.3.1/Widelands-1.3.1-macOS12_arm64.dmg", "note": "macOS ARM package."},
        ],
    },
    "warzone2100": {
        "title": "Warzone 2100",
        "version": "4.6.3",
        "source": "https://github.com/Warzone2100/warzone2100/releases/tag/4.6.3",
        "notes": "Official Warzone 2100 4.6.3 stable release files for common LAN Arcade targets. Debug symbol packages are intentionally not cached.",
        "assets": [
            {"name": "warzone2100_win_installer.exe", "label": "Windows installer", "platform": "Windows 7-11+", "url": "https://github.com/Warzone2100/warzone2100/releases/download/4.6.3/warzone2100_win_installer.exe", "note": "Primary Windows installer."},
            {"name": "warzone2100_win_x64_archive.zip", "label": "Windows x64 portable ZIP", "platform": "Windows 64-bit", "url": "https://github.com/Warzone2100/warzone2100/releases/download/4.6.3/warzone2100_win_x64_archive.zip", "note": "Portable Windows build."},
            {"name": "warzone2100_macOS_universal_novideos.zip", "label": "macOS universal no-video ZIP", "platform": "macOS 10.14+", "url": "https://github.com/Warzone2100/warzone2100/releases/download/4.6.3/warzone2100_macOS_universal_novideos.zip", "note": "Smaller macOS package without campaign videos."},
            {"name": "warzone2100_ubuntu22.04_amd64.deb", "label": "Ubuntu 22.04 DEB", "platform": "Ubuntu 22.04 x86_64", "url": "https://github.com/Warzone2100/warzone2100/releases/download/4.6.3/warzone2100_ubuntu22.04_amd64.deb", "note": "Official Ubuntu 22.04 package."},
            {"name": "warzone2100_ubuntu24.04_amd64.deb", "label": "Ubuntu 24.04+ DEB", "platform": "Ubuntu 24.04+ x86_64", "url": "https://github.com/Warzone2100/warzone2100/releases/download/4.6.3/warzone2100_ubuntu24.04_amd64.deb", "note": "Official Ubuntu 24.04 package."},
            {"name": "warzone2100_linux_x86_64.flatpak", "label": "Linux Flatpak", "platform": "Linux x86_64", "url": "https://github.com/Warzone2100/warzone2100/releases/download/4.6.3/warzone2100_linux_x86_64.flatpak", "note": "Self-contained Linux Flatpak bundle."},
            {"name": "warzone2100_src.tar.xz", "label": "Source/data archive", "platform": "Build/repair", "url": "https://github.com/Warzone2100/warzone2100/releases/download/4.6.3/warzone2100_src.tar.xz", "note": "Official source and data tarball."},
        ],
        "docs": {"dest": "warzone2100-site", "source_subdir": "wz2100.net", "pages": ["https://wz2100.net/", "https://wz2100.net/download/"]},
    },
    "luanti": {
        "title": "Luanti",
        "version": "5.16.1",
        "source": "https://www.luanti.org/en/downloads/",
        "notes": "Official Luanti 5.16.1 desktop and Android packages. Debian still names the VM smoke package minetest/minetest-server.",
        "assets": [
            {"name": "luanti-5.16.1.exe", "label": "Windows installer", "platform": "Windows 64-bit", "url": "https://github.com/luanti-org/luanti/releases/download/5.16.1/luanti-5.16.1.exe", "note": "Recommended Windows installer."},
            {"name": "luanti-5.16.1-win64.zip", "label": "Windows portable 64-bit", "platform": "Windows 64-bit", "url": "https://github.com/luanti-org/luanti/releases/download/5.16.1/luanti-5.16.1-win64.zip", "note": "Portable Windows build."},
            {"name": "luanti-5.16.1-win32.zip", "label": "Windows portable 32-bit", "platform": "Windows 32-bit", "url": "https://github.com/luanti-org/luanti/releases/download/5.16.1/luanti-5.16.1-win32.zip", "note": "Fallback for older Windows hardware."},
            {"name": "luanti_5.16.1-macos12.3_arm64.zip", "label": "macOS Apple Silicon app", "platform": "macOS 12.3+ Apple Silicon", "url": "https://github.com/luanti-org/luanti/releases/download/5.16.1/luanti_5.16.1-macos12.3_arm64.zip", "note": "Signed macOS ARM app."},
            {"name": "luanti_5.16.1-macos12.3_x86_64.zip", "label": "macOS Intel app", "platform": "macOS 12.3+ Intel", "url": "https://github.com/luanti-org/luanti/releases/download/5.16.1/luanti_5.16.1-macos12.3_x86_64.zip", "note": "Signed macOS Intel app."},
            {"name": "luanti-5.16.1-arm64-v8a.apk", "label": "Android ARM 64-bit APK", "platform": "Android ARM64", "url": "https://github.com/luanti-org/luanti/releases/download/5.16.1/luanti-5.16.1-arm64-v8a.apk", "note": "Recommended Android APK for most modern phones/tablets."},
            {"name": "luanti-5.16.1-armeabi-v7a.apk", "label": "Android ARM 32-bit APK", "platform": "Android ARM 32-bit", "url": "https://github.com/luanti-org/luanti/releases/download/5.16.1/luanti-5.16.1-armeabi-v7a.apk", "note": "Fallback Android APK for older ARM devices."},
            {"name": "luanti-5.16.1-x86_64.apk", "label": "Android x86_64 APK", "platform": "Android x86_64", "url": "https://github.com/luanti-org/luanti/releases/download/5.16.1/luanti-5.16.1-x86_64.apk", "note": "Android x86_64 build."},
            {"name": "luanti-5.16.1-x86.apk", "label": "Android x86 APK", "platform": "Android x86", "url": "https://github.com/luanti-org/luanti/releases/download/5.16.1/luanti-5.16.1-x86.apk", "note": "Android x86 build."},
        ],
        "docs": {"dest": "luanti-docs", "source_subdir": "docs.luanti.org", "pages": ["https://docs.luanti.org/for-players/getting-started/", "https://docs.luanti.org/for-players/playing/", "https://docs.luanti.org/for-server-hosts/setting-up-a-server/", "https://www.luanti.org/en/downloads/"]},
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


def download(url: str, target: Path) -> tuple[str, int]:
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and target.stat().st_size > 0:
        return sha256_file(target), target.stat().st_size
    tmp = target.with_suffix(target.suffix + ".tmp")
    tmp.unlink(missing_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=240) as response, tmp.open("wb") as out:
        shutil.copyfileobj(response, out)
    tmp.replace(target)
    return sha256_file(target), target.stat().st_size


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
    page = f"""<!doctype html>
<html lang='en'>
<head>
  <meta charset='utf-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1'>
  <title>{html.escape(game['title'])} Offline Downloads</title>
  <style>
    :root {{ color-scheme: dark; --bg:#10131a; --card:#1b2330; --line:#344055; --text:#f4f7fb; --muted:#c3cedf; --accent:#69d4a3; --ink:#06110c; }}
    * {{ box-sizing:border-box; }} body {{ margin:0; font-family:system-ui,-apple-system,Segoe UI,sans-serif; background:var(--bg); color:var(--text); }}
    main {{ width:min(1120px,94vw); margin:0 auto; padding:34px 0 48px; }} h1 {{ margin:0 0 8px; font-size:clamp(30px,5vw,58px); line-height:1; }}
    .lede {{ color:var(--muted); max-width:840px; line-height:1.5; }} .grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(260px,1fr)); gap:14px; margin-top:22px; }}
    .card {{ border:1px solid var(--line); border-radius:8px; padding:16px; background:var(--card); }} .card h2 {{ margin:0 0 5px; font-size:20px; }}
    .audience,.meta {{ color:var(--muted); }} .button {{ display:inline-block; margin:8px 0; padding:10px 12px; border-radius:8px; background:var(--accent); color:var(--ink); font-weight:850; text-decoration:none; }}
    code {{ background:#090d12; border:1px solid rgba(255,255,255,.12); border-radius:5px; padding:2px 5px; }} .links {{ display:flex; flex-wrap:wrap; gap:10px; margin-top:18px; }}
    .links a {{ color:var(--text); border:1px solid var(--line); border-radius:8px; padding:9px 10px; text-decoration:none; }}
  </style>
</head>
<body>
  <main>
    <h1>{html.escape(game['title'])} Offline Downloads</h1>
    <p class='lede'>Version <strong>{html.escape(version)}</strong>. {html.escape(game.get('notes', 'Official release files cached for LAN Arcade.'))}</p>
    <div class='links'><a href='../../../../games/'>Back to Arcade</a><a href='{html.escape(version)}/SHA256SUMS.txt'>SHA256SUMS</a><a href='manifest.json'>Manifest JSON</a><a href='{html.escape(game.get('source', '#'))}'>Original source</a></div>
    <section class='grid'>{''.join(cards)}</section>
  </main>
</body>
</html>
"""
    root.mkdir(parents=True, exist_ok=True)
    version_dir.mkdir(parents=True, exist_ok=True)
    (root / "index.html").write_text(page, encoding="utf-8")
    (version_dir / "index.html").write_text(page.replace(f"href='{html.escape(version)}/", "href='"), encoding="utf-8")
    manifest = {"title": game["title"], "version": version, "source": game.get("source"), "notes": game.get("notes"), "assets": assets}
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
    for asset in game["assets"]:
        print(f"Caching {slug}: {asset['name']}", flush=True)
        sha, size = download(asset["url"], version_dir / asset["name"])
        enriched = dict(asset)
        enriched.update({"sha256": sha, "size": size})
        assets.append(enriched)
    write_index(slug, game, assets)
    print(f"DOWNLOADS_READY={DOWNLOAD_ROOT / slug}")


def patch_docs_for_offline(root: Path) -> None:
    for path in root.rglob("*.html"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        lines = [line for line in text.splitlines() if "fonts.googleapis.com" not in line and "googletagmanager.com" not in line and "google-analytics.com" not in line]
        text = "\n".join(lines) + ("\n" if text.endswith("\n") else "")
        text = text.replace('data-md-component="search"', 'data-md-component="search-offline"')
        text = text.replace('data-md-component="source"', 'data-md-component="source-offline"')
        path.write_text(text, encoding="utf-8")
    (root / "LAN_ARCADE_OFFLINE_PATCH.txt").write_text("Mirrored for LAN Arcade and patched to remove common external font/tracker/search dependencies.\n", encoding="utf-8")


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
            "--timeout=20", "--tries=2", "--directory-prefix", str(tmp),
        ]
        if not docs.get("pages"):
            cmd[1:1] = ["--recursive", "--level=3", "--no-parent", "--reject-regex", "Special:|action=|oldid=|diff=|printable=|User:"]
        cmd.extend(page_args)
        subprocess.run(cmd, check=False)
        source = tmp / docs["source_subdir"]
        if not source.exists():
            raise RuntimeError(f"wget did not create expected docs mirror at {source}")
        backup = dest.with_name(dest.name + ".backup-before-refresh")
        if backup.exists():
            shutil.rmtree(backup)
        if dest.exists() and any(dest.iterdir()):
            dest.rename(backup)
        shutil.copytree(source, dest, dirs_exist_ok=True)
        patch_docs_for_offline(dest)
        (dest / "LAN_ARCADE_SOURCE.txt").write_text(f"Mirrored from {source_note}\nRefreshed {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\n", encoding="utf-8")
    print(f"DOCS_READY={dest}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Cache native game downloads and docs for LAN Arcade")
    parser.add_argument("games", nargs="*", choices=sorted(GAMES), help="Game slugs to cache; default all")
    parser.add_argument("--skip-downloads", action="store_true")
    parser.add_argument("--skip-docs", action="store_true")
    args = parser.parse_args()
    selected = args.games or sorted(GAMES)
    for slug in selected:
        if not args.skip_downloads:
            cache_game(slug)
        if not args.skip_docs:
            mirror_docs(slug)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
