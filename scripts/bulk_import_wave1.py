#!/usr/bin/env python3
"""Build Bulk Import Wave 1 shelves from approved local intake plans.

This script imports metadata/wrappers only. It does not download games, ROMs,
board-game assets, or commercial packages.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import re
import shutil
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROM_PLAN = ROOT / "docs/BULK_IMPORT_WAVE_1_PLAN_2026-06-21.md"
BOARD_PLAN = ROOT / "game-intake/board-games-wave-1-import-plan-2026-06-21.md"
PRIVATE_ROM_MANIFEST = Path("/var/www/html/mirrors/private-rom-vault/manifest.json")
DEFAULT_OUTPUT_ROOT = ROOT / "local-games"

ROM_SECTIONS = ["Game Boy Candidates", "Game Boy Color Candidates"]

BOARD_IMPLEMENTATIONS = {
    "Catan": ("analog-local", "Open Pioneers, the source-clear Catan-like LAN implementation.", "../pioneers-lan/"),
    "Go": ("playable-local", "Open Kigo + GNU Go, already no-internet smoke-passed.", "../kigo-lan/"),
    "Backgammon": ("playable-local", "Open GNU Backgammon, already no-internet smoke-passed.", "../gnubg-lan/"),
    "Reversi / Othello-style": ("playable-local", "Open KReversi, already no-internet smoke-passed.", "../kreversi-lan/"),
    "Connect Four-style": ("playable-local", "Open KFourInLine, already no-internet smoke-passed.", "../kfourinline-lan/"),
    "Gomoku / Five in a Row": ("playable-local", "Open Bovo Gomoku, already no-internet smoke-passed.", "../bovo-lan/"),
    "Nine Men's Morris": ("playable-local", "Open Nine Men's Morris native hub.", "../morris-lan/"),
    "Battleship-style": ("partial-local", "Open KNavalBattle; setup works but firing-turn proof is still partial.", "../knavalbattle-lan/"),
    "Ticket to Ride": ("metadata-only", "Official/private implementation required before offline play.", ""),
    "Carcassonne": ("metadata-only", "Official/private implementation required before offline play.", ""),
    "Azul": ("metadata-only", "Official/private implementation required before offline play.", ""),
    "Pandemic": ("metadata-only", "Official/private implementation required before offline play.", ""),
    "Codenames": ("metadata-only", "Needs source-clear prompt/card implementation or authorized app.", ""),
}

CATEGORY_LANES = {
    "Children's Games": "rights-review-private-or-source-clear",
    "Family Games": "rights-review-private-or-official-app",
    "Party Games": "source-clear-prompt-deck-or-authorized-app",
    "Cooperative Games": "rights-review-private-or-authorized-app",
    "Classic Board Games": "source-clear-generic-implementation-target",
    "Gateway Strategy Games": "rights-review-private-or-source-clear-analog",
    "Medium-Weight Strategy Games": "authorized-module-or-private-owned-needed",
    "Trading And Economic Games": "authorized-module-or-private-owned-needed",
    "Tile And Engine-Building Games": "authorized-module-or-private-owned-needed",
    "Deduction And Social Deduction Games": "authorized-module-source-clear-or-private-needed",
    "Card-Driven Board Games": "authorized-card-engine-or-private-owned-needed",
    "Educational, History, And Science-Themed Games": "authorized-app-module-or-private-owned-needed",
}

ROM_HTML = """<!doctype html>
<html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>__TITLE__</title><style>
:root{color-scheme:dark;--bg:#090d12;--panel:#121922;--line:#314357;--text:#eef6ff;--muted:#a8b8cc;--green:#35d07f;--amber:#ffca55;--blue:#5dc8ff}*{box-sizing:border-box}body{margin:0;background:#090d12;color:var(--text);font-family:system-ui,-apple-system,Segoe UI,sans-serif}main{width:min(1440px,95vw);margin:0 auto;padding:28px 0 48px}.top{display:flex;justify-content:space-between;gap:14px;align-items:flex-start}h1{margin:0;font-size:clamp(30px,5vw,56px);letter-spacing:0}p{color:var(--muted);line-height:1.5}.back,.button{border:1px solid var(--line);border-radius:7px;background:#182230;color:var(--text);text-decoration:none;font-weight:850;padding:10px 12px;display:inline-flex;align-items:center;justify-content:center}.hero{border:1px solid var(--line);border-radius:8px;background:#121922;padding:16px;margin:16px 0}.stats,.filters,.tags{display:flex;flex-wrap:wrap;gap:8px}.pill,.tag{border:1px solid var(--line);border-radius:999px;background:#0e151f;padding:6px 9px}.filters{position:sticky;top:0;background:#090d12;padding:12px 0;margin:14px 0;z-index:2}input,select{min-height:42px;border:1px solid var(--line);border-radius:7px;background:#0e151f;color:var(--text);padding:8px 10px}input{flex:1;min-width:min(460px,100%)}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:12px}.card{border:1px solid var(--line);border-radius:8px;background:#121922;padding:14px;min-width:0}.card h2{font-size:17px;margin:0 0 8px;overflow-wrap:anywhere}.meta{font-size:12px;color:#bdd2e8;text-transform:uppercase;letter-spacing:.08em}.play{display:grid;place-items:center;min-height:38px;border-radius:7px;background:var(--green);color:#06110d;font-weight:900;text-decoration:none;margin-top:10px}.small{font-size:12px;color:var(--muted);overflow-wrap:anywhere}@media(max-width:720px){.top{display:block}.back{width:100%;margin-top:10px}.filters{position:static}.button{width:100%}}
</style></head><body><main><div class=\"top\"><div><h1>__HEADING__</h1><p>Curated Wave 1 Game Boy/Game Boy Color imports from the existing private vault. No ROM files are stored in Git.</p></div><a class=\"back\" href=\"../games/\">Back to Arcade</a></div><section class=\"hero\"><div class=\"stats\" id=\"stats\"></div><p class=\"small\">Generated from <code>docs/BULK_IMPORT_WAVE_1_PLAN_2026-06-21.md</code> and <code>/var/www/html/mirrors/private-rom-vault/manifest.json</code>. Play links use the existing private vault payloads.</p></section><section class=\"filters\"><input id=\"q\" type=\"search\" placeholder=\"Search title, platform, genre...\"><select id=\"system\"><option value=\"\">All systems</option></select><select id=\"genre\"><option value=\"\">All genres</option></select></section><section class=\"grid\" id=\"grid\"></section></main><script>window.WAVE_MANIFEST=__DATA__;</script><script>
const manifest=window.WAVE_MANIFEST,games=manifest.games||[],qInput=document.getElementById('q'),systemSelect=document.getElementById('system'),genreSelect=document.getElementById('genre'),statsEl=document.getElementById('stats'),gridEl=document.getElementById('grid');function esc(s){return String(s??'').replace(/[&<>\"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',"'":'&#39;'}[c]));}function text(g){return [g.title,g.system,(g.genres||[]).join(' '),g.sourceTitle,g.originalPath].join(' ').toLowerCase();}function renderStats(list){const systems=new Map();for(const g of games)systems.set(g.system,(systems.get(g.system)||0)+1);statsEl.innerHTML=[`<span class=\"pill\"><b>${games.length}</b> imported</span>`,`<span class=\"pill\"><b>${list.length}</b> shown</span>`,...[...systems].map(([k,v])=>`<span class=\"pill\"><b>${v}</b> ${esc(k)}</span>`)].join('');}function opts(){for(const s of [...new Set(games.map(g=>g.system))].sort())systemSelect.insertAdjacentHTML('beforeend',`<option>${esc(s)}</option>`);for(const g of [...new Set(games.flatMap(g=>g.genres||[]))].sort())genreSelect.insertAdjacentHTML('beforeend',`<option>${esc(g)}</option>`);}function render(){const query=qInput.value.trim().toLowerCase(),sys=systemSelect.value,gen=genreSelect.value;const list=games.filter(g=>(!sys||g.system===sys)&&(!gen||(g.genres||[]).includes(gen))&&(!query||text(g).includes(query)));renderStats(list);gridEl.innerHTML=list.map(g=>{const tags=[g.system,...(g.genres||[]).slice(0,2),'Wave 1'].map(t=>`<span class=\"tag\">${esc(t)}</span>`).join('');return `<article class=\"card\"><div class=\"meta\">${esc(g.system)} | ${esc((g.languages||[]).join(', ')||'language unknown')}</div><h2>${esc(g.title)}</h2><div class=\"tags\">${tags}</div><a class=\"play\" href=\"play.html?id=${encodeURIComponent(g.id)}\">Play</a><p class=\"small\">${esc(g.originalPath)}</p></article>`;}).join('')||'<p>No matching games.</p>';}opts();render();for(const el of [qInput,systemSelect,genreSelect])el.addEventListener('input',render);
</script></body></html>"""

ROM_PLAY_HTML = """<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>Game Boy Wave 1 Player</title><style>
:root{color-scheme:dark;--bg:#080d12;--panel:#121922;--line:#314357;--text:#eef6ff;--muted:#a8b8cc;--accent:#63d38f;--warn:#facc15}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font-family:system-ui,-apple-system,Segoe UI,sans-serif}main{width:min(1280px,96vw);margin:0 auto;padding:18px 0 28px}.top{display:flex;align-items:start;justify-content:space-between;gap:12px;margin-bottom:12px}h1{margin:0;font-size:clamp(24px,3vw,38px);letter-spacing:0}.back{color:var(--text);background:#182230;border:1px solid var(--line);border-radius:7px;padding:9px 11px;text-decoration:none;font-weight:800;white-space:nowrap}.layout{display:grid;grid-template-columns:minmax(0,1fr) 280px;gap:14px}.player{overflow:hidden;background:#030609;border:1px solid var(--line);border-radius:8px}#game{width:100%;height:min(74vh,720px);min-height:430px;background:#020617}.panel{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:14px}p{color:var(--muted);line-height:1.45}.status{color:var(--warn);font-weight:800}.key{border:1px solid var(--line);border-radius:7px;padding:8px;margin:6px 0;background:#0e151f}@media(max-width:900px){main{width:min(100vw,100%);padding:8px}.layout{grid-template-columns:1fr}#game{height:62vh;min-height:360px}.top{display:block}.back{display:block;text-align:center;margin-top:10px}}
</style></head><body><main><div class=\"top\"><div><h1 id=\"title\">Game Boy Wave 1 Player</h1><p id=\"meta\"></p></div><a class=\"back\" href=\"./\">Back to Wave 1</a></div><div class=\"layout\"><section class=\"player\"><div id=\"game\"></div></section><aside class=\"panel\"><h2>Controls</h2><div class=\"key\"><b>Arrow keys</b><br>D-pad</div><div class=\"key\"><b>Z / A</b><br>A button</div><div class=\"key\"><b>X / S</b><br>B button</div><div class=\"key\"><b>Enter</b><br>Start</div><div class=\"key\"><b>Right Shift</b><br>Select</div><p class=\"status\">Click the player first if keys do not register.</p></aside></div></main><script>
const id=new URLSearchParams(location.search).get('id'),gameEl=document.getElementById('game');window.addEventListener('unhandledrejection',event=>{if(String(event.reason&&(event.reason.message||event.reason)).includes('Wake Lock'))event.preventDefault();});try{if('wakeLock'in navigator)Object.defineProperty(navigator,'wakeLock',{value:undefined,configurable:true});}catch(e){}fetch('manifest.json').then(r=>r.json()).then(m=>{const g=m.games.find(x=>x.id===id)||m.games[0];if(!g){gameEl.textContent='No game found';return;}document.title=g.title+' - Game Boy Wave 1';title.textContent=g.title;meta.textContent=`${g.system} | ${(g.regions||[]).join(', ')||'region unknown'} | ${(g.languages||[]).join(', ')||'language unknown'}`;window.EJS_player='#game';window.EJS_core=g.core||'gb';window.EJS_gameName=g.title;window.EJS_gameUrl=g.rom;window.EJS_pathtodata='../emulatorjs-runtime/4.2.3/data/';window.EJS_startOnLoaded=true;window.EJS_language='en-US';window.EJS_disableAutoLang=false;window.EJS_backgroundColor='#020617';window.EJS_color='#63d38f';window.EJS_allowUpdateCheck=false;const s=document.createElement('script');s.src='../emulatorjs-runtime/4.2.3/data/loader.js';document.body.append(s);}).catch(error=>{gameEl.textContent='Failed to load manifest: '+error;});
</script></body></html>"""

BOARD_HTML = """<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>__TITLE__</title><style>
:root{color-scheme:dark;--bg:#0b1114;--panel:#141d21;--line:#33434a;--text:#f4f8f8;--muted:#c2ced2;--green:#72d39b;--amber:#f0bf5a;--blue:#7cb7ff;--bad:#ff746d}*{box-sizing:border-box}body{margin:0;background:#0b1114;color:var(--text);font-family:system-ui,-apple-system,Segoe UI,sans-serif}main{width:min(1480px,95vw);margin:auto;padding:28px 0 50px}.top{display:flex;justify-content:space-between;gap:14px;align-items:flex-start}.back,.button{border:1px solid var(--line);border-radius:7px;background:#1b252b;color:var(--text);text-decoration:none;font-weight:850;padding:10px 12px;display:inline-flex}h1{font-size:clamp(30px,5vw,56px);margin:0;letter-spacing:0}p{color:var(--muted);line-height:1.5}.hero{border:1px solid var(--line);border-radius:8px;background:#141d21;padding:16px;margin:16px 0}.stats,.filters,.tags{display:flex;flex-wrap:wrap;gap:8px}.pill,.tag{border:1px solid var(--line);border-radius:999px;background:#0e171c;padding:6px 9px}.filters{position:sticky;top:0;background:#0b1114;padding:12px 0;margin:14px 0;z-index:2}input,select{min-height:42px;border:1px solid var(--line);border-radius:7px;background:#0e171c;color:var(--text);padding:8px 10px}input{flex:1;min-width:min(460px,100%)}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:12px}.card{border:1px solid var(--line);border-radius:8px;background:#141d21;padding:14px;min-width:0}.card h2{font-size:18px;margin:0 0 8px;overflow-wrap:anywhere}.meta{font-size:12px;color:#bdd2e8;text-transform:uppercase;letter-spacing:.08em}.status{font-weight:900}.playable-local{color:var(--green)}.analog-local,.partial-local{color:var(--amber)}.metadata-only{color:var(--blue)}.blocked{color:var(--bad)}.action{margin-top:10px}.small{font-size:12px;color:var(--muted);overflow-wrap:anywhere}@media(max-width:760px){.top{display:block}.back{width:100%;margin-top:10px}.filters{position:static}.button{width:100%;justify-content:center}}
</style></head><body><main><div class=\"top\"><div><h1>Board Games Wave 1</h1><p>Two hundred board-game intake entries from the approved Wave 1 list. Source-clear local implementations are linked where they already exist; the rest are metadata-only until rights and offline assets are approved.</p></div><a class=\"back\" href=\"../games/\">Back to Arcade</a></div><section class=\"hero\"><div class=\"stats\" id=\"stats\"></div><p class=\"small\">Generated from <code>game-intake/board-games-wave-1-import-plan-2026-06-21.md</code>. This shelf deliberately avoids importing commercial board-game art, scans, modules, or app payloads without approval.</p></section><section class=\"filters\"><input id=\"q\" type=\"search\" placeholder=\"Search title, category, source lane...\"><select id=\"category\"><option value=\"\">All categories</option></select><select id=\"status\"><option value=\"\">All statuses</option></select></section><section class=\"grid\" id=\"grid\"></section></main><script>window.BOARD_MANIFEST=__DATA__;</script><script>
const manifest=window.BOARD_MANIFEST,games=manifest.games||[],qInput=document.getElementById('q'),categorySelect=document.getElementById('category'),statusSelect=document.getElementById('status'),statsEl=document.getElementById('stats'),gridEl=document.getElementById('grid');function esc(s){return String(s??'').replace(/[&<>\"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',"'":'&#39;'}[c]));}function text(g){return [g.title,g.category,g.status,g.sourceLane,g.notes].join(' ').toLowerCase();}function renderStats(list){const counts=new Map();for(const g of games)counts.set(g.status,(counts.get(g.status)||0)+1);statsEl.innerHTML=[`<span class=\"pill\"><b>${games.length}</b> imported</span>`,`<span class=\"pill\"><b>${list.length}</b> shown</span>`,...[...counts].map(([k,v])=>`<span class=\"pill\"><b>${v}</b> ${esc(k)}</span>`)].join('');}function opts(){for(const c of [...new Set(games.map(g=>g.category))].sort())categorySelect.insertAdjacentHTML('beforeend',`<option>${esc(c)}</option>`);for(const s of [...new Set(games.map(g=>g.status))].sort())statusSelect.insertAdjacentHTML('beforeend',`<option>${esc(s)}</option>`);}function render(){const query=qInput.value.trim().toLowerCase(),cat=categorySelect.value,st=statusSelect.value;const list=games.filter(g=>(!cat||g.category===cat)&&(!st||g.status===st)&&(!query||text(g).includes(query)));renderStats(list);gridEl.innerHTML=list.map(g=>{const tags=[g.category,g.sourceLane,g.status].map(t=>`<span class=\"tag\">${esc(t)}</span>`).join('');const action=g.url?`<p class=\"action\"><a class=\"button\" href=\"${esc(g.url)}\">Open local implementation</a></p>`:'<p class=\"small\">No offline payload imported yet.</p>';return `<article class=\"card\"><div class=\"meta\">${esc(g.category)}</div><h2>${esc(g.title)}</h2><p class=\"status ${esc(g.status)}\">${esc(g.status)}</p><div class=\"tags\">${tags}</div><p>${esc(g.notes)}</p>${action}</article>`;}).join('')||'<p>No matching games.</p>';}opts();render();for(const el of [qInput,categorySelect,statusSelect])el.addEventListener('input',render);
</script></body></html>"""


def utc() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def slugify(text: str) -> str:
    text = re.sub(r"&", " and ", text.lower())
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return re.sub(r"-+", "-", text).strip("-") or "item"


def norm(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", text.lower())


def read(path: Path) -> str:
    if not path.exists():
        raise SystemExit(f"missing required source list: {path}")
    return path.read_text(encoding="utf-8")


def parse_rom_titles(text: str) -> list[str]:
    titles: list[str] = []
    current = None
    for line in text.splitlines():
        if line.startswith("### "):
            current = re.sub(r"\s*\(\d+\)\s*$", "", line[4:].strip())
            continue
        if current in ROM_SECTIONS:
            m = re.match(r"^\d+\.\s+(.+?)\s*$", line)
            if m:
                titles.append(m.group(1))
    return titles


def parse_board_titles(text: str) -> list[dict]:
    rows: list[dict] = []
    in_library = False
    current = None
    for line in text.splitlines():
        if line.startswith("## Board Games Wave 1 Candidate Library"):
            in_library = True
            continue
        if in_library and line.startswith("## Essential"):
            break
        if not in_library:
            continue
        if line.startswith("### "):
            heading = line[4:].strip()
            current = re.sub(r"\s+-\s+\d+\s*$", "", heading).strip()
            continue
        if current:
            m = re.match(r"^\d+\.\s+(.+?)\s*$", line)
            if m:
                rows.append({"title": m.group(1), "category": current})
    return rows


def dedupe_rows(rows: list, key_func, list_name: str, attempts: list[dict]) -> list:
    seen = set()
    out = []
    for row in rows:
        key = key_func(row)
        title = row if isinstance(row, str) else row.get("title", "")
        if key in seen:
            attempts.append({"list": list_name, "title": title, "status": "skipped_duplicate", "reason": "duplicate normalized title", "target": ""})
            continue
        seen.add(key)
        out.append(row)
    return out


def load_private_roms() -> dict[str, dict]:
    data = json.loads(PRIVATE_ROM_MANIFEST.read_text(encoding="utf-8"))
    by_title: dict[str, dict] = {}
    for game in data.get("games", []):
        by_title[game["title"]] = game
    return by_title


def build_rom_games(titles: list[str], attempts: list[dict], limit: int = 0) -> list[dict]:
    by_title = load_private_roms()
    games = []
    for title in titles[: limit or None]:
        source = by_title.get(title)
        if not source:
            attempts.append({"list": "gameboy-wave-1", "title": title, "status": "failed", "reason": "title not found in private ROM manifest", "target": ""})
            continue
        if "En" not in source.get("languages", []):
            attempts.append({"list": "gameboy-wave-1", "title": title, "status": "skipped_non_english", "reason": "source manifest does not mark title English", "target": ""})
            continue
        game = dict(source)
        game["sourceTitle"] = source["title"]
        game["rom"] = "../private-rom-vault/" + source["rom"]
        game["playUrl"] = f"play.html?id={game['id']}"
        game["importedAt"] = utc()
        games.append(game)
        attempts.append({"list": "gameboy-wave-1", "title": title, "status": "imported", "reason": "validated against private selected ROM manifest", "target": f"private-rom-wave-1:{game['id']}"})
    return games


def board_status(row: dict) -> tuple[str, str, str]:
    title = row["title"]
    if title in BOARD_IMPLEMENTATIONS:
        return BOARD_IMPLEMENTATIONS[title]
    lane = CATEGORY_LANES.get(row["category"], "metadata-only-rights-review")
    if row["category"] == "Classic Board Games":
        return "metadata-only", "Source-clear implementation still needed before offline play.", ""
    if "Party" in row["category"]:
        return "metadata-only", "Needs source-clear prompt deck or authorized digital implementation.", ""
    return "metadata-only", "Rights/offline implementation review required before importing playable assets.", ""


def build_board_games(rows: list[dict], attempts: list[dict], limit: int = 0) -> list[dict]:
    games = []
    for idx, row in enumerate(rows[: limit or None], 1):
        status, notes, url = board_status(row)
        lane = CATEGORY_LANES.get(row["category"], "metadata-only-rights-review")
        item = {
            "id": slugify(row["title"]),
            "title": row["title"],
            "category": row["category"],
            "sourceLane": lane,
            "status": status,
            "notes": notes,
            "url": url,
            "importedAt": utc(),
            "sourcePlan": str(BOARD_PLAN),
        }
        games.append(item)
        attempts.append({"list": "board-games-wave-1", "title": row["title"], "status": "imported", "reason": status, "target": f"board-games-wave-1:{item['id']}"})
    return games


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def write_rom_shelf(dest: Path, games: list[dict], test: bool) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    manifest = {
        "name": "Game Boy Wave 1" + (" Test" if test else ""),
        "kind": "private-rom-wave-1",
        "generatedAt": utc(),
        "sourcePlan": str(ROM_PLAN),
        "sourceManifest": str(PRIVATE_ROM_MANIFEST),
        "selectionPolicy": "Curated Wave 1 allowlist. One English-friendly selected private-vault version per title; no ROM files copied into Git.",
        "counts": {
            "selected": len(games),
            "systems": {system: sum(1 for g in games if g.get("system") == system) for system in sorted({g.get("system") for g in games})},
        },
        "games": games,
    }
    write_json(dest / "manifest.json", manifest)
    page = ROM_HTML.replace("__TITLE__", html.escape(manifest["name"]))\
        .replace("__HEADING__", html.escape(manifest["name"]))\
        .replace("__DATA__", json.dumps(manifest, separators=(",", ":")))
    (dest / "index.html").write_text(page, encoding="utf-8")
    (dest / "play.html").write_text(ROM_PLAY_HTML, encoding="utf-8")
    (dest / "ATTRIBUTION.txt").write_text("Game Boy Wave 1 uses Dylan-provided private ROM files from /var/www/html/mirrors/private-rom-vault. No ROM files are stored here.\n", encoding="utf-8")


def write_board_shelf(dest: Path, games: list[dict], test: bool) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    counts = {}
    for g in games:
        counts[g["status"]] = counts.get(g["status"], 0) + 1
    manifest = {
        "name": "Board Games Wave 1" + (" Test" if test else ""),
        "kind": "board-games-wave-1",
        "generatedAt": utc(),
        "sourcePlan": str(BOARD_PLAN),
        "selectionPolicy": "Metadata/import shelf from approved board-game Wave 1 list. Playable payloads are linked only when source-clear local implementations already exist.",
        "counts": counts,
        "games": games,
    }
    write_json(dest / "manifest.json", manifest)
    page = BOARD_HTML.replace("__TITLE__", html.escape(manifest["name"]))\
        .replace("__DATA__", json.dumps(manifest, separators=(",", ":")))
    (dest / "index.html").write_text(page, encoding="utf-8")
    (dest / "ATTRIBUTION.txt").write_text("Board Games Wave 1 is a metadata/source-lane shelf. Commercial board-game art, scans, modules, and app payloads are not imported without approval.\n", encoding="utf-8")


def write_attempts(log_dir: Path, attempts: list[dict], summary: dict) -> None:
    log_dir.mkdir(parents=True, exist_ok=True)
    fields = ["list", "title", "status", "reason", "target"]
    with (log_dir / "attempts.csv").open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields)
        writer.writeheader()
        writer.writerows(attempts)
    write_json(log_dir / "summary.json", summary)
    lines = [f"{utc()} Bulk Import Wave 1", ""]
    for key, value in summary.items():
        lines.append(f"{key}: {value}")
    (log_dir / "import.log").write_text("\n".join(lines) + "\n", encoding="utf-8")


def update_games_meta() -> None:
    meta = ROOT / "games.meta.sh"
    text = meta.read_text(encoding="utf-8")
    entries = {
        "GAMES": [
            '  ["private-rom-wave-1"]="LOCAL_DIR::local-games/private-rom-wave-1"',
            '  ["board-games-wave-1"]="LOCAL_DIR::local-games/board-games-wave-1"',
        ],
        "GAME_INFO": [
            '  ["private-rom-wave-1"]="Game Boy Wave 1|GB1|Private Retro Shelf - 201 Curated Titles|Curated Wave 1 Game Boy and Game Boy Color imports from the private VM vault, with title-level search and play links.|Retro,Emulator,Game Boy,GBC,Private,Curated,Searchable"',
            '  ["board-games-wave-1"]="Board Games Wave 1|BOARD|Board Game Intake - 200 Titles|Searchable board-game intake shelf with local playable links where source-clear implementations exist and metadata-only rows where rights review is still required.|Board Game,Family,Strategy,Party,Metadata,Searchable"',
        ],
        "GAME_CATEGORIES": [
            '  ["private-rom-wave-1"]="retro,arcade,emulator,private,family,casual,age-10-plus"',
            '  ["board-games-wave-1"]="board-game,strategy,multiplayer,family,casual,age-10-plus"',
        ],
    }
    for array, new_lines in entries.items():
        pattern = re.compile(rf"(declare -A {array}=\([\s\S]*?)(\n\))", re.M)
        for line in new_lines:
            key = re.search(r'\["([^"]+)"\]', line).group(1)
            match = pattern.search(text)
            if not match:
                raise SystemExit(f"could not find {array} block in games.meta.sh")
            if f'["{key}"]=' in match.group(1):
                continue
            text = text[: match.start(2)] + "\n" + line + text[match.start(2):]
    meta.write_text(text, encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--output-root", default=str(DEFAULT_OUTPUT_ROOT))
    ap.add_argument("--log-dir", required=True)
    ap.add_argument("--rom-limit", type=int, default=0)
    ap.add_argument("--board-limit", type=int, default=0)
    ap.add_argument("--rom-name", default="private-rom-wave-1")
    ap.add_argument("--board-name", default="board-games-wave-1")
    ap.add_argument("--test", action="store_true")
    ap.add_argument("--update-games-meta", action="store_true")
    args = ap.parse_args()

    attempts: list[dict] = []
    rom_titles = dedupe_rows(parse_rom_titles(read(ROM_PLAN)), lambda x: norm(x), "gameboy-wave-1", attempts)
    board_rows = dedupe_rows(parse_board_titles(read(BOARD_PLAN)), lambda x: norm(x["title"]), "board-games-wave-1", attempts)
    rom_games = build_rom_games(rom_titles, attempts, args.rom_limit)
    board_games = build_board_games(board_rows, attempts, args.board_limit)

    output_root = Path(args.output_root)
    rom_dest = output_root / args.rom_name
    board_dest = output_root / args.board_name
    write_rom_shelf(rom_dest, rom_games, args.test)
    write_board_shelf(board_dest, board_games, args.test)
    if args.update_games_meta:
        update_games_meta()

    status_counts = {}
    for row in attempts:
        status_counts[row["status"]] = status_counts.get(row["status"], 0) + 1
    summary = {
        "generated_at": utc(),
        "mode": "test" if args.test else "full",
        "source_rom_titles": len(rom_titles),
        "source_board_titles": len(board_rows),
        "rom_imported": len(rom_games),
        "board_imported": len(board_games),
        "total_attempted": len(attempts),
        "status_counts": status_counts,
        "rom_output": str(rom_dest),
        "board_output": str(board_dest),
        "games_meta_updated": bool(args.update_games_meta),
    }
    write_attempts(Path(args.log_dir), attempts, summary)
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
