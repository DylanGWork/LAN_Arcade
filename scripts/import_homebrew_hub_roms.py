#!/usr/bin/env python3
"""Import selected Homebrew Hub ROM entries into LAN Arcade.

Usage:
  scripts/import_homebrew_hub_roms.py slug:game-id [slug:game-id ...]
"""
from __future__ import annotations

import hashlib
import html
import json
import re
import sys
import urllib.request
from pathlib import Path
from urllib.parse import quote, urlparse

ROOT = Path(__file__).resolve().parents[1]
API_BASE = "https://hh3.gbdev.io/api"
HEADERS = {"User-Agent": "LAN Arcade Homebrew Hub importer"}

CORE_BY_PLATFORM = {"GB": "gb", "GBC": "gb", "GBA": "gba", "NES": "nes"}
ROM_EXTS = (".gb", ".gbc", ".gba", ".nes")
BLOCKED_SLUGS = {
    "airaki": "blocked after manual QA: ROM displays an anti-emulator profanity screen and is not playable in EmulatorJS",
}



def fetch_bytes(url: str) -> bytes:
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def fetch_json(url: str) -> dict:
    return json.loads(fetch_bytes(url).decode("utf-8"))



def entry_file_url(entry: dict, filename: str) -> str:
    baserepo = entry.get("baserepo") or ""
    parsed = urlparse(baserepo)
    if parsed.netloc != "github.com":
        raise ValueError(f"Unsupported baserepo for direct import: {baserepo}")
    parts = parsed.path.strip("/").split("/")
    if len(parts) < 2:
        raise ValueError(f"Unexpected baserepo path: {baserepo}")
    owner, repo = parts[0], parts[1]
    slug = entry["slug"]
    quoted_file = "/".join(quote(part) for part in filename.split("/"))
    return f"https://raw.githubusercontent.com/{owner}/{repo}/master/entries/{quote(slug)}/{quoted_file}"

def safe_filename(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "-", name).strip("-") or "file"


def first_playable_file(entry: dict) -> dict:
    files = entry.get("files") or []
    playable = [f for f in files if f.get("playable") and f.get("filename", "").lower().endswith(ROM_EXTS)]
    if playable:
        return next((f for f in playable if f.get("default")), playable[0])
    roms = [f for f in files if f.get("filename", "").lower().endswith(ROM_EXTS)]
    if roms:
        return next((f for f in roms if f.get("default")), roms[0])
    raise ValueError(f"No playable ROM file found for {entry.get('slug')}")


def game_page(entry: dict, game_id: str, rom_name: str, core: str) -> str:
    title = entry.get("title") or game_id
    platform = entry.get("platform", "")
    license_name = entry.get("license") or "See upstream"
    description = entry.get("description") or "Homebrew Hub entry imported for offline LAN Arcade play."
    tags = ", ".join(entry.get("tags") or [])
    repository = entry.get("repository") or ""
    screenshots = sorted((Path("assets") / safe_filename(s)).as_posix() for s in entry.get("screenshots") or [])
    hero = screenshots[0] if screenshots else ""
    hero_css = f', url("{hero}") center / cover no-repeat' if hero else ''
    gallery = "\n".join(
        f'<figure><img src="{html.escape(src)}" alt="{html.escape(title)} screenshot"><figcaption>{html.escape(title)} screenshot</figcaption></figure>'
        for src in screenshots[:4]
    )
    if not gallery:
        gallery = '<p class="empty">No upstream screenshots were available in the manifest.</p>'
    repo_link = f'<a href="{html.escape(repository)}">Upstream source</a>' if repository else 'Upstream source not listed'
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(title)} - LAN Arcade</title>
  <style>
    :root {{ color-scheme: dark; --bg:#08111f; --panel:#111827; --panel2:#182235; --line:#314158; --text:#eef6ff; --muted:#aab8cc; --accent:#4ade80; --accent2:#38bdf8; --warn:#facc15; }}
    * {{ box-sizing:border-box; }} html,body {{ height:100%; }}
    body {{ margin:0; font-family:system-ui,-apple-system,Segoe UI,sans-serif; background:#08111f; color:var(--text); overflow-x:hidden; }}
    body::before {{ content:""; position:fixed; inset:0; pointer-events:none; background:linear-gradient(135deg,rgba(20,83,45,.36),transparent 38%), linear-gradient(315deg,rgba(14,116,144,.28),transparent 42%){hero_css}, #08111f; opacity:.95; }}
    main {{ position:relative; z-index:1; width:min(1180px,96vw); margin:0 auto; padding:14px 0 22px; min-height:100%; display:grid; grid-template-rows:auto 1fr; gap:12px; }}
    header {{ display:flex; align-items:center; justify-content:space-between; gap:12px; min-height:44px; }}
    h1 {{ margin:0; font-size:clamp(21px,3vw,34px); line-height:1.05; letter-spacing:0; }}
    .topline {{ display:flex; align-items:center; gap:10px; flex-wrap:wrap; }}
    .badge {{ border:1px solid var(--line); background:rgba(17,24,39,.86); color:var(--accent); border-radius:999px; padding:6px 9px; font-weight:800; font-size:12px; }}
    .back {{ color:var(--text); background:rgba(17,24,39,.9); border:1px solid var(--line); border-radius:7px; padding:9px 11px; text-decoration:none; font-weight:800; white-space:nowrap; }}
    .layout {{ display:grid; grid-template-columns:minmax(0,1fr) 330px; gap:12px; align-items:start; }}
    .player-panel,.side,.gallery {{ border:1px solid var(--line); background:rgba(9,16,29,.92); border-radius:8px; box-shadow:0 18px 55px rgba(0,0,0,.35); }}
    .player-panel {{ overflow:hidden; min-height:0; }} #game {{ width:100%; height:min(74vh,720px); min-height:430px; background:#020617; }}
    .side {{ padding:14px; display:grid; gap:12px; }} h2 {{ margin:0 0 8px; font-size:16px; color:#c7e0ff; }}
    p {{ margin:0 0 8px; color:var(--muted); line-height:1.45; }} .status {{ color:var(--warn); font-weight:800; }}
    .controls {{ display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:8px; }} .key {{ border:1px solid var(--line); background:rgba(24,34,53,.88); border-radius:6px; padding:8px; min-height:56px; }} .key strong {{ display:block; color:var(--text); font-size:13px; margin-bottom:3px; }} .key span {{ display:block; color:var(--muted); font-size:12px; line-height:1.25; }}
    .meta {{ border-top:1px solid var(--line); padding-top:12px; font-size:13px; color:var(--muted); }} .meta a {{ color:#93c5fd; }}
    .gallery {{ grid-column:1 / -1; padding:12px; display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); gap:10px; }} figure {{ margin:0; border:1px solid var(--line); border-radius:7px; overflow:hidden; background:#020617; }} figure img {{ width:100%; height:150px; object-fit:contain; display:block; background:#020617; }} figcaption {{ color:var(--muted); font-size:12px; padding:8px; border-top:1px solid var(--line); }} .empty {{ grid-column:1 / -1; }}
    @media (max-width:900px) {{ main {{ width:min(100vw,100%); padding:8px; }} header {{ align-items:flex-start; }} .layout {{ grid-template-columns:1fr; }} #game {{ height:62vh; min-height:360px; }} .side {{ grid-template-columns:1fr 1fr; }} .meta {{ grid-column:1 / -1; }} .gallery {{ grid-template-columns:repeat(2,minmax(0,1fr)); }} }}
    @media (max-width:560px) {{ header {{ flex-direction:column; }} .topline,.back {{ width:100%; }} .back {{ text-align:center; }} #game {{ height:58vh; min-height:310px; }} .side,.controls,.gallery {{ grid-template-columns:1fr; }} }}
  </style>
</head>
<body>
  <main>
    <header><div class="topline"><h1>{html.escape(title)}</h1><span class="badge">{html.escape(platform)} homebrew ROM</span></div><a class="back" href="../games/">Back to Arcade</a></header>
    <div class="layout">
      <section class="player-panel" aria-label="{html.escape(title)} emulator"><div id="game"></div></section>
      <aside class="side">
        <section><h2>Ready</h2><p>{html.escape(description)}</p><p><span class="status">Click the player if keys do not register.</span></p></section>
        <section><h2>Controls</h2><div class="controls"><div class="key"><strong>Arrow keys</strong><span>D-pad</span></div><div class="key"><strong>Z / A</strong><span>A button</span></div><div class="key"><strong>X / S</strong><span>B button</span></div><div class="key"><strong>Enter</strong><span>Start</span></div><div class="key"><strong>Right Shift</strong><span>Select</span></div><div class="key"><strong>A / S</strong><span>L / R on GBA</span></div></div></section>
        <section class="meta"><h2>Source</h2><p>Imported from Homebrew Hub. License: {html.escape(license_name)}. Tags: {html.escape(tags)}.</p><p><a href="ATTRIBUTION.txt">Attribution</a> ? <a href="manifest.json">Manifest</a> ? {repo_link}</p></section>
      </aside>
      <section class="gallery" aria-label="Screenshots">{gallery}</section>
    </div>
  </main>
  <script>
    window.addEventListener('unhandledrejection', (event) => {{ if (String(event.reason && (event.reason.message || event.reason)).includes('Wake Lock')) event.preventDefault(); }});
    try {{ if ('wakeLock' in navigator) Object.defineProperty(navigator, 'wakeLock', {{ value: undefined, configurable: true }}); }} catch (error) {{}}
    window.EJS_player = '#game';
    window.EJS_core = '{core}';
    window.EJS_gameName = {json.dumps(title)};
    window.EJS_gameUrl = 'roms/{quote(rom_name)}';
    window.EJS_pathtodata = '../emulatorjs-runtime/4.2.3/data/';
    window.EJS_startOnLoaded = true;
    window.EJS_language = 'en-US';
    window.EJS_disableAutoLang = false;
    window.EJS_backgroundColor = '#020617';
    window.EJS_color = '#4ade80';
    window.EJS_allowUpdateCheck = false;
  </script>
  <script src="../emulatorjs-runtime/4.2.3/data/loader.js"></script>
</body>
</html>
"""


def import_entry(slug: str, game_id: str) -> dict:
    entry = fetch_json(f"{API_BASE}/entry/{quote(slug)}.json")
    platform = entry.get("platform")
    core = CORE_BY_PLATFORM.get(platform)
    if not core:
        raise ValueError(f"Unsupported platform {platform!r} for {slug}")
    rom = first_playable_file(entry)
    filename = rom["filename"]
    local_rom = safe_filename(filename)
    game_dir = ROOT / "local-games" / game_id
    rom_dir = game_dir / "roms"
    assets_dir = game_dir / "assets"
    rom_dir.mkdir(parents=True, exist_ok=True)
    assets_dir.mkdir(parents=True, exist_ok=True)

    rom_bytes = fetch_bytes(entry_file_url(entry, filename))
    (rom_dir / local_rom).write_bytes(rom_bytes)
    sha = hashlib.sha256(rom_bytes).hexdigest()

    for shot in entry.get("screenshots") or []:
        try:
            data = fetch_bytes(entry_file_url(entry, shot))
            (assets_dir / safe_filename(shot)).write_bytes(data)
        except Exception as exc:
            print(f"WARN screenshot {slug}/{shot}: {exc}", file=sys.stderr)

    (game_dir / "manifest.json").write_text(json.dumps(entry, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    title = entry.get("title") or slug
    (game_dir / "ATTRIBUTION.txt").write_text(
        f"{title}\n\n"
        f"Homebrew Hub slug: {slug}\n"
        f"Homebrew Hub manifest: {API_BASE}/entry/{slug}.json\n"
        f"Platform: {platform}\n"
        f"Developer: {entry.get('developer','')}\n"
        f"License: {entry.get('license','See manifest')}\n"
        f"Repository: {entry.get('repository','')}\n"
        f"ROM file: roms/{local_rom}\n"
        f"ROM SHA-256: {sha}\n\n"
        "Imported from Homebrew Hub for offline LAN Arcade play. Homebrew Hub metadata says each entry and asset has its own license; verify the manifest and upstream repository before treating an entry as redistributable beyond personal LAN/offline use.\n",
        encoding="utf-8",
    )
    (game_dir / "index.html").write_text(game_page(entry, game_id, local_rom, core), encoding="utf-8")
    return {"slug": slug, "game_id": game_id, "title": title, "platform": platform, "license": entry.get("license"), "rom": local_rom, "sha256": sha}


def main(argv: list[str]) -> int:
    if not argv or argv == ["--help"] or argv == ["-h"]:
        print(__doc__)
        return 0 if argv else 2
    imported = []
    for spec in argv:
        if ":" not in spec:
            raise SystemExit(f"Expected slug:game-id, got {spec}")
        slug, game_id = spec.split(":", 1)
        slug = slug.strip()
        game_id = game_id.strip()
        if slug in BLOCKED_SLUGS:
            raise SystemExit(f"Blocked Homebrew Hub slug {slug!r}: {BLOCKED_SLUGS[slug]}")
        imported.append(import_entry(slug, game_id))
    print(json.dumps({"imported": imported}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
