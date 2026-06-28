#!/usr/bin/env python3
"""Audit or hide blocked docs mirrors from player-facing LAN Arcade pages.

Docs mirror blocker pages are useful for operators, but launcher pages should
not present them as normal guides/manuals. This script finds folders containing
LAN_ARCADE_DOCS_BLOCKED.txt and fails if top-level game hub pages link to them.
Use --fix to rewrite those hub links into user-facing "guide unavailable" copy
and to soften direct blocker pages.
"""
from __future__ import annotations

import argparse
import html
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MIRRORS_ROOT = Path("/var/www/html/mirrors")
DEFAULT_LOCAL_ROOT = REPO_ROOT / "local-games"

BLOCKER_NAME = "LAN_ARCADE_DOCS_BLOCKED.txt"


def blocked_dirs(root: Path) -> set[str]:
    if not root.exists():
        return set()
    return {path.parent.name for path in root.glob(f"*/{BLOCKER_NAME}")}


def candidate_hub_pages(root: Path, blocked: set[str]):
    if not root.exists():
        return
    for path in sorted(root.glob("*/index.html")):
        name = path.parent.name
        if name in blocked or name.endswith("-site") or name in {"games"}:
            continue
        yield path


def disabled_button(label: str = "Guide unavailable") -> str:
    return f"<span class='button secondary' aria-disabled='true'>{label}</span>"


def patch_hub_for_blocked_dir(text: str, site_dir: str) -> str:
    href = re.escape(f"../{site_dir}/")
    original = text

    text = re.sub(
        rf"<a href=['\"]{href}['\"]>(?:Official Mirror|Open offline website|Offline website|Guide|Manual)</a>",
        "<a class='warn' href='#manual'>Guide unavailable</a>",
        text,
    )

    text = re.sub(
        rf"<section class='band'><div class='wrap'><div class='section-head'><h2>Official Offline Site</h2><p>.*?</p></div><div class='grid two'><article class='panel'><h3>Open (?:the )?(?:offline website|mirror)</h3><p>.*?</p><a class='button' href=['\"]{href}['\"]>Open (?:offline website|official mirror)</a></article>",
        "<section class='band'><div class='wrap'><div class='section-head'><h2>Offline Guide</h2><p>A saved website or manual is not available for this game yet. The downloads and quick-start notes below are still available offline.</p></div><div class='grid two'><article class='panel'><h3>Guide not available yet</h3><p>We could not save a useful copy of the official website/wiki. This link is hidden from the normal player flow until the guide is fixed.</p>" + disabled_button() + "</article>",
        text,
        flags=re.S,
    )

    text = re.sub(
        rf"<li><a href=['\"]{href}['\"]>(?:Offline website/manual|Official site/manual mirror|Offline manuals and guides|Official Mirror)</a></li>",
        "<li>Offline guide: not available yet</li>",
        text,
    )

    text = re.sub(
        rf"<article class='panel'><h3>Offline manuals and guides</h3><p>.*?</p><a class='button secondary' href=['\"]{href}['\"]>Open guides</a></article>",
        "<article class='panel'><h3>Offline guide not available yet</h3><p>We could not save a useful website/manual for this game yet. Use the quick-start notes on this page for now.</p>" + disabled_button(),
        text,
        flags=re.S,
    )

    text = re.sub(
        rf"<a class='button(?: secondary)?' href=['\"]{href}['\"]>Open (?:offline website|official mirror|guide|manual|guides)</a>",
        disabled_button(),
        text,
    )

    # Last-resort guard for older hub templates: keep the user on this page
    # rather than linking them into a known blocker folder.
    text = text.replace(f"href='../{site_dir}/'", "href='#manual'")
    text = text.replace(f'href="../{site_dir}/"', 'href="#manual"')

    text = text.replace(
        "Use the saved official site/manual for deeper instructions when available.",
        "Use the quick steps below; a fuller offline guide still needs to be saved.",
    )
    text = text.replace(
        "Use the mirrored official site/manual for deeper instructions when available.",
        "Use the quick steps below; a fuller offline guide still needs to be saved.",
    )

    return text if text != original else original


def patch_blocker_page(path: Path, root: Path) -> bool:
    site_dir = path.parent.name
    detail_path = path.parent / BLOCKER_NAME
    detail = detail_path.read_text(encoding="utf-8", errors="ignore") if detail_path.exists() else "No operator detail recorded."
    public_detail = re.sub(r"https?://\S+", "[source URL saved for operators]", detail)
    game_name = site_dir.removesuffix("-site").replace("-", " ").title()
    hub = site_dir.removesuffix("-site") + "-lan"
    hub_href = f"../{hub}/" if (root / hub / "index.html").exists() else "../games/"
    hub_label = f"Back to {game_name}" if hub_href != "../games/" else "Back to Game Library"
    page = f"""<!doctype html>
<html lang='en'>
<head>
  <meta charset='utf-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1'>
  <title>{html.escape(game_name)} guide not available yet</title>
  <style>
    body{{margin:0;font-family:system-ui,Segoe UI,sans-serif;background:#0c1114;color:#f2f7f8}}
    main{{max-width:880px;margin:0 auto;padding:44px 20px}}
    a{{color:#77b7ff}}
    .panel{{border:1px solid #2d3b43;border-radius:8px;background:#151d22;padding:20px}}
    p{{line-height:1.55;color:#d4dee3}}
    code{{white-space:pre-wrap;color:#ffe08a}}
    details{{margin-top:16px;color:#cbd6db}}
  </style>
</head>
<body><main>
  <p><a href='{hub_href}'>{html.escape(hub_label)}</a></p>
  <div class='panel'>
    <h1>Offline guide not available yet</h1>
    <p>The game files or local hub may still be available, but the saved website/manual for {html.escape(game_name)} did not complete.</p>
    <p>This page is kept as an operator note so the guide can be repaired later. Normal player pages should send you back to the game hub instead of here.</p>
    <details><summary>Operator note</summary><p><code>{html.escape(public_detail)}</code></p></details>
  </div>
</main></body>
</html>
"""
    old = path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""
    if old == page:
        return False
    path.write_text(page, encoding="utf-8")
    return True


def audit(root: Path, local_root: Path, fix: bool) -> tuple[list[dict], list[str]]:
    blocked = blocked_dirs(root)
    changes: list[str] = []
    findings: list[dict] = []

    for scan_root in [local_root, root]:
        if not scan_root.exists():
            continue
        for path in candidate_hub_pages(scan_root, blocked):
            text = path.read_text(encoding="utf-8", errors="ignore")
            updated = text
            linked = []
            for site_dir in sorted(blocked):
                if f"../{site_dir}/" in updated or f"/mirrors/{site_dir}/" in updated:
                    linked.append(site_dir)
                    if fix:
                        updated = patch_hub_for_blocked_dir(updated, site_dir)
            if linked:
                if fix and updated != text:
                    path.write_text(updated, encoding="utf-8")
                    changes.append(str(path))
                else:
                    findings.append({"file": str(path), "blockedGuides": linked})

    if fix and root.exists():
        for site_dir in sorted(blocked):
            path = root / site_dir / "index.html"
            if path.exists() and patch_blocker_page(path, root):
                changes.append(str(path))

    if fix:
        return audit(root, local_root, False)[0], changes
    return findings, changes


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit player-facing links to blocked offline guide mirrors")
    parser.add_argument("--root", type=Path, default=DEFAULT_MIRRORS_ROOT, help="deployed mirrors root")
    parser.add_argument("--local-root", type=Path, default=DEFAULT_LOCAL_ROOT, help="repo local-games root")
    parser.add_argument("--fix", action="store_true", help="rewrite hub pages and direct blocker pages")
    args = parser.parse_args()

    findings, changes = audit(args.root.resolve(), args.local_root.resolve(), args.fix)
    for change in changes:
        print(f"changed: {change}")
    if findings:
        print("Player-facing pages still link to blocked offline guides:")
        for item in findings:
            print(f"- {item['file']}: {', '.join(item['blockedGuides'])}")
        return 2
    print("No player-facing links to blocked offline guide pages found.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
