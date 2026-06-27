#!/usr/bin/env python3
"""Polish public LAN Arcade launcher pages so they read like a player library.

This is a post-generation cleanup for older hub generators that still expose
operator/intake wording. It deliberately targets top-level public launcher HTML
only, not mirrored upstream sites or game source trees.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

TEXT_REPLACEMENTS = [
    ("in a offline test mode", "in offline test mode"),
    ("pass a offline play check", "pass an offline play check"),
    ("Ready status needs a first action of placing a first path or ride", "Ready status needs a placed path or ride"),
    ("QA Evidence", "Test Notes"),
    ("QA Status", "Play Check"),
    ("QA Result", "Play Check"),
    ("Arcade QA Status", "Arcade Play Check"),
    ("Regression Status", "Play Check"),
    ("QA screenshot", "play test screenshot"),
    ("QA PASS", "READY"),
    ("QA PARTIAL", "PARTIALLY TESTED"),
    ("QA BLOCKED", "NEEDS SETUP"),
    ("QA UNTESTED", "NEEDS TESTING"),
    ("VM launch smoke screenshot", "launch test screenshot"),
    ("VM launch smoke", "launch test"),
    ("no-internet smoke tests", "offline play checks"),
    ("no-internet smoke test", "offline play check"),
    ("no-internet smoke", "offline play check"),
    ("No-network smoke", "Offline play check"),
    ("No-network native launch", "Offline launch"),
    ("actual VM smoke tests", "actual offline play checks"),
    ("VM smoke tests", "offline play checks"),
    ("Partial smoke", "Partially tested"),
    ("partial smoke", "partially tested"),
    ("What the smoke proved", "What the test showed"),
    ("What the smoke showed", "What the test showed"),
    ("The smoke did not", "The test did not"),
    ("Smoke-pass requires proof", "Ready status needs a completed first action"),
    ("Offline play smoke", "Offline play check"),
    ("None during smoke", "None during test"),
    ("bwrap no-internet namespace", "offline test mode"),
    ("bwrap --unshare-net", "offline test mode"),
    ("Manual / PDF Check", "Manuals and Guides"),
    ("Manual / Docs Check", "Manuals and Guides"),
    ("This is a first-play smoke, not a full completion proof.", "This is a first-play check, not a full completion run."),
    ("first-play smoke", "first-play check"),
    ("launch smoke", "launch check"),
    ("no-internet launch smoke", "offline launch check"),
    ("No-internet smoke passed", "Offline play check passed"),
    ("playable smoke passed", "ready to play"),
    ("offline test mode smoke", "offline play check"),
    ("Open offline package shelf", "Open offline downloads"),
    ("offline package shelf", "offline downloads"),
    ("cached on the LAN Arcade offline download shelf", "stored on the LAN Arcade offline download shelf"),
    ("cached on the LAN Arcade", "stored on the LAN Arcade"),
    ("cached from Debian packages", "stored from Debian packages"),
    ("proof is still pending", "check is still pending"),
    ("proof should", "check should"),
    ("proof", "check"),
    ("Package docs were inspected on the VM.", "Available local notes and manuals were checked."),
    ("First path/ride placement proof", "First path/ride placement check"),
    ("current proof", "current check"),
    ("experimental tycoon candidate", "experimental tycoon option"),
    ("cached from the official", "stored from the official"),
    ("cached locally", "stored locally"),
    ("no-internet namespace", "offline test mode"),
    ("LAN Arcade native board-game intake", "LAN Arcade native board game page"),
    ("LAN Arcade native board-game setup", "LAN Arcade native board game page"),
    ("LAN Arcade native game page. See", "LAN Arcade native game page. See"),
    ("HTTP 200 does not count as gameplay proof.", "Opening the page is not enough; we test a real first action before calling it ready."),
    ("Packages live on the NFS-backed native shelf, not in Git.", "Installers are stored on the arcade's local download shelf."),
    ("Stored on the NFS-backed native shelf, not in Git.", "Installers are stored on the arcade's local download shelf."),
    ("Cached from Debian packages onto the NFS-backed native shelf.", "Stored in the arcade's local offline download shelf."),
    ("Cached on the NFS-backed LAN Arcade native shelf.", "Stored on the arcade's local offline download shelf."),
    ("NFS-backed native shelf", "local download shelf"),
    ("native-downloads shelf", "offline download shelf"),
    ("package cache has not been generated yet", "offline game files are not ready yet"),
    ("cache script has not created the manifest yet", "offline game files are not ready yet"),
    ("manifest and SHA256 sums", "file details and checksums"),
    ("manifest and SHA256 checksums", "file details and checksums"),
    ("Open package shelf", "Open downloads"),
    ("Open shelf", "Open downloads"),
    ("Download shelf pending", "Needs game files"),
    ("Debian package shelf", "Offline downloads"),
    ("Offline package shelf", "Offline downloads"),
    ("Download Packages", "Download Clients"),
    ("Promotion gate", "Next check"),
    ("promotion gate", "next check"),
    ("Next proof", "Next check"),
    ("proof gate", "ready check"),
]

REGEX_REPLACEMENTS = [
    (re.compile(r"<p>Latest report: <code>.*?</code></p>"), "<p>Detailed test logs are kept for operators.</p>"),
    (re.compile(r"<p>Evidence folder is recorded in <code>.*?</code>\.</p>"), "<p>Detailed test notes are kept for operators.</p>"),
    (re.compile(r"(?:Installed package docs|Package docs) were inspected on the VM\. PDF manuals are (?:checked|counted) with Poppler when present\."), "Available local notes and manuals found for this game."),
    (re.compile(r"This is a Linux/Debian-first native setup page\. It explains the game and stores local packages, but it is not marked ready until gameplay play check passes\."), "This page explains what the game is, how to install it offline, and what still needs to be tested before it is marked ready."),
    (re.compile(r"This is a Linux/Debian-first native game page\. It explains the game and stores local packages, but it is not promoted to play-ready until gameplay test passes\."), "This page explains what the game is, how to install it offline, and what still needs to be tested before it is marked ready."),
]

TARGET_NAMES = {"index.html", "play.html"}
SKIP_DIRS = {"private-rom-wave-1", "private-gbc-vault"}


def candidate_files(root: Path):
    if not root.exists():
        return
    for child in sorted(root.iterdir()):
        if not child.is_dir() or child.name in SKIP_DIRS:
            continue
        for name in TARGET_NAMES:
            path = child / name
            if path.exists():
                yield path


def polish(text: str) -> str:
    out = text
    for old, new in TEXT_REPLACEMENTS:
        out = out.replace(old, new)
    for pattern, new in REGEX_REPLACEMENTS:
        out = pattern.sub(new, out)
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description="Polish public launcher wording")
    parser.add_argument("--root", action="append", type=Path, default=[], help="root containing one directory per launcher")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    roots = args.root or [ROOT / "local-games"]
    changed: list[Path] = []
    for root in roots:
        root = root if root.is_absolute() else ROOT / root
        for path in candidate_files(root):
            text = path.read_text(encoding="utf-8", errors="ignore")
            updated = polish(text)
            if updated != text:
                changed.append(path)
                if not args.dry_run:
                    path.write_text(updated, encoding="utf-8")

    for path in changed:
        print(path)
    print(f"changed={len(changed)} dry_run={args.dry_run}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
