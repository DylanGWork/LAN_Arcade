#!/usr/bin/env python3
"""Build the VM-local private EmulatorJS ROM vault.

The script contains no ROM content. It reads Dylan's private archive on the VM
and writes the playable shelf under /var/www/html/mirrors/private-rom-vault.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import shutil
import time
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ARCHIVE = ROOT / "tmp/private-rom-intake/gbc-smdb-2022-05-12.zip"
DEFAULT_DEST = Path("/var/www/html/mirrors/private-rom-vault")
ROM_EXTS = {".gb": ("Game Boy", "gb"), ".gbc": ("Game Boy Color", "gb"), ".gba": ("Game Boy Advance", "gba")}
SKIP_RE = re.compile(r"(bios|diagnostic|test cart|service test|sample|prototype|proto|beta|debug|kiosk|demo|xploder|gameshark|action replay|cheat)", re.I)
REGIONS = ["USA", "Europe", "World", "Australia", "Japan", "Germany", "France", "Spain", "Italy", "Netherlands", "UK"]
LANGS = ["En", "Fr", "De", "Es", "It", "Nl", "Ja", "Pt"]


def slugify(text: str) -> str:
    text = re.sub(r"&", " and ", text.lower())
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return re.sub(r"-+", "-", text).strip("-") or "rom"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_data(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def clean_title(filename: str) -> str:
    stem = Path(filename).stem
    stem = re.sub(r"\[[^\]]*\]", "", stem)
    stem = re.sub(r"\([^)]*\)", "", stem)
    stem = re.sub(r"\s+", " ", stem).strip()
    return stem or Path(filename).stem


def title_key(title: str, system: str) -> str:
    key = title.lower()
    key = re.sub(r"\b(the|a|an)\b", "", key)
    key = re.sub(r"[^a-z0-9]+", "", key)
    return f"{system}:{key}"


def tags(filename: str) -> list[str]:
    out: list[str] = []
    for hit in re.findall(r"\(([^)]*)\)|\[([^\]]*)\]", Path(filename).name):
        value = hit[0] or hit[1]
        out.extend(x.strip() for x in re.split(r",|;", value) if x.strip())
    return out


def detect_regions(filename: str, tag_list: list[str]) -> list[str]:
    text = f"{filename} {' '.join(tag_list)}"
    found = [r for r in REGIONS if re.search(rf"\b{re.escape(r)}\b", text, re.I)]
    if "USA" not in found and re.search(r"\bUS\b|GBC US|GB US", text, re.I):
        found.insert(0, "USA")
    return found


def detect_languages(filename: str, tag_list: list[str], regions: list[str]) -> list[str]:
    tag_text = " ".join(tag_list)
    found = [l for l in LANGS if re.search(rf"\b{re.escape(l)}\b", tag_text)]
    if not found and any(r in regions for r in ["USA", "UK", "Australia", "World"]):
        found.append("En")
    if not found and "Europe" in regions and not any(r in regions for r in ["Germany", "France", "Spain", "Italy", "Netherlands"]):
        found.append("En")
    return found


def english_friendly(filename: str, regions: list[str], languages: list[str]) -> bool:
    if "En" in languages:
        return True
    if any(r in regions for r in ["USA", "UK", "Australia", "World"]):
        return True
    if "Europe" in regions and not any(r in regions for r in ["Germany", "France", "Spain", "Italy", "Netherlands"]):
        return True
    if "japan" in filename.lower():
        return False
    return False


def score(filename: str, regions: list[str], languages: list[str]) -> int:
    text = filename.lower()
    value = 0
    if "USA" in regions:
        value += 120
    if "World" in regions:
        value += 110
    if "Australia" in regions:
        value += 95
    if "Europe" in regions:
        value += 80
    if "En" in languages:
        value += 60
    if "gbc us" in text or "gb us" in text:
        value += 35
    if "rev" in text:
        value += 5
    if "japan" in text and "En" not in languages:
        value -= 150
    if any(x in text for x in ["germany", "france", "spain", "italy", "netherlands"]):
        value -= 40
    if SKIP_RE.search(filename):
        value -= 200
    return value


def genres(title: str, filename: str) -> list[str]:
    text = f"{title} {filename}".lower()
    guesses: list[str] = []
    rules = [
        (r"pokemon|dragon warrior|zelda|azure dreams|quest|rpg", "RPG"),
        (r"tetris|puzzle|picross|word|mahjong", "Puzzle"),
        (r"mario|kirby|sonic|rayman|wario|mega man", "Platformer"),
        (r"tony hawk|skate|racing|racer|kart|f1|nascar|motocross", "Sports/Racing"),
        (r"baseball|football|soccer|tennis|golf|basketball|hockey", "Sports"),
        (r"army|war|command|conquer|risk|battleship|chess", "Strategy"),
        (r"pinball|pac-man|asteroids|arcade", "Arcade"),
        (r"barbie|dora|arthur|sesame|disney|dalmatians|kids", "Kids"),
    ]
    for pattern, label in rules:
        if re.search(pattern, text, re.I):
            guesses.append(label)
    return guesses or ["Unsorted"]


def read_candidates(archive: Path) -> list[dict]:
    out: list[dict] = []
    with zipfile.ZipFile(archive) as zf:
        for info in zf.infolist():
            ext = Path(info.filename).suffix.lower()
            if info.is_dir() or ext not in ROM_EXTS:
                continue
            system, core = ROM_EXTS[ext]
            tag_list = tags(info.filename)
            region_list = detect_regions(info.filename, tag_list)
            language_list = detect_languages(info.filename, tag_list, region_list)
            title = clean_title(info.filename)
            out.append({
                "info": info,
                "title": title,
                "system": system,
                "core": core,
                "regions": region_list,
                "languages": language_list,
                "genres": genres(title, info.filename),
                "english": english_friendly(info.filename, region_list, language_list),
                "skip": bool(SKIP_RE.search(info.filename)),
                "score": score(info.filename, region_list, language_list),
                "key": title_key(title, system),
            })
    return out


def select(candidates: list[dict], profile: str) -> list[dict]:
    if profile == "all":
        chosen = candidates
    elif profile == "english":
        chosen = [c for c in candidates if c["english"] and not c["skip"]]
    elif profile == "selected":
        best: dict[str, dict] = {}
        for c in candidates:
            if not c["english"] or c["skip"]:
                continue
            old = best.get(c["key"])
            if old is None or c["score"] > old["score"] or (c["score"] == old["score"] and c["info"].file_size > old["info"].file_size):
                best[c["key"]] = c
        chosen = list(best.values())
    else:
        raise SystemExit(f"unknown profile: {profile}")
    return sorted(chosen, key=lambda c: (c["system"], c["title"].lower(), c["info"].filename.lower()))


def safe_dest(dest: Path) -> None:
    allowed = Path("/var/www/html/mirrors/private-rom-vault").resolve()
    resolved = dest.resolve()
    if resolved != allowed and allowed not in resolved.parents:
        raise SystemExit(f"Refusing destination outside private vault: {dest}")


def write_play(dest: Path) -> None:
    page = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Private ROM Player</title>
  <style>
    :root{color-scheme:dark;--bg:#080d12;--panel:#121922;--line:#314357;--text:#eef6ff;--muted:#a8b8cc;--accent:#63d38f;--warn:#facc15}
    *{box-sizing:border-box}html,body{min-height:100%}body{margin:0;background:var(--bg);color:var(--text);font-family:system-ui,-apple-system,Segoe UI,sans-serif;overflow-x:hidden}main{width:min(1280px,96vw);margin:0 auto;padding:18px 0 28px}.top{display:flex;align-items:start;justify-content:space-between;gap:12px;margin-bottom:12px}h1{margin:0;font-size:clamp(24px,3vw,38px);letter-spacing:0}.back{color:var(--text);background:#182230;border:1px solid var(--line);border-radius:7px;padding:9px 11px;text-decoration:none;font-weight:800;white-space:nowrap}.layout{display:grid;grid-template-columns:minmax(0,1fr) 280px;gap:14px;align-items:start}.player{overflow:hidden;min-height:0;background:#030609;border:1px solid var(--line);border-radius:8px;box-shadow:0 18px 55px rgba(0,0,0,.35)}#game{width:100%;height:min(74vh,720px);min-height:430px;background:#020617}.panel{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:14px}p,li{color:var(--muted);line-height:1.45}.status{color:var(--warn);font-weight:800}.key{border:1px solid var(--line);border-radius:7px;padding:8px;margin:6px 0;background:#0e151f}@media(max-width:900px){main{width:min(100vw,100%);padding:8px}.layout{grid-template-columns:1fr}#game{height:62vh;min-height:360px}.top{align-items:flex-start}}@media(max-width:560px){.top{display:block}.back{display:block;text-align:center;margin-top:10px}#game{height:58vh;min-height:310px}}
  </style>
</head>
<body>
  <main>
    <div class="top"><div><h1 id="title">Private ROM Player</h1><p id="meta"></p></div><a class="back" href="./">Back to Vault</a></div>
    <div class="layout">
      <section class="player" aria-label="Emulator"><div id="game"></div></section>
      <aside class="panel">
        <h2>Controls</h2>
        <div class="key"><b>Arrow keys</b><br>D-pad</div>
        <div class="key"><b>Z / A</b><br>A button</div>
        <div class="key"><b>X / S</b><br>B button</div>
        <div class="key"><b>Enter</b><br>Start</div>
        <div class="key"><b>Right Shift</b><br>Select</div>
        <p class="status">Click the player first if keys do not register.</p>
      </aside>
    </div>
  </main>
  <script>
    const id = new URLSearchParams(location.search).get('id');
    const gameEl = document.getElementById('game');
    window.addEventListener('unhandledrejection', (event) => {
      if (String(event.reason && (event.reason.message || event.reason)).includes('Wake Lock')) event.preventDefault();
    });
    try {
      if ('wakeLock' in navigator) Object.defineProperty(navigator, 'wakeLock', { value: undefined, configurable: true });
    } catch (error) {}
    fetch('manifest.json').then((r) => r.json()).then((m) => {
      const g = m.games.find((x) => x.id === id) || m.games[0];
      if (!g) { gameEl.textContent = 'No game found'; return; }
      document.title = g.title + ' - Private ROM Player';
      title.textContent = g.title;
      meta.textContent = `${g.system} | ${(g.regions || []).join(', ') || 'region unknown'} | ${(g.languages || []).join(', ') || 'language unknown'}`;
      window.EJS_player = '#game';
      window.EJS_core = g.core || 'gb';
      window.EJS_gameName = g.title;
      window.EJS_gameUrl = g.rom;
      window.EJS_pathtodata = '../emulatorjs-runtime/4.2.3/data/';
      window.EJS_startOnLoaded = true;
      window.EJS_language = 'en-US';
      window.EJS_disableAutoLang = false;
      window.EJS_backgroundColor = '#020617';
      window.EJS_color = '#63d38f';
      window.EJS_allowUpdateCheck = false;
      const s = document.createElement('script');
      s.src = '../emulatorjs-runtime/4.2.3/data/loader.js';
      document.body.append(s);
    }).catch((error) => { gameEl.textContent = 'Failed to load manifest: ' + error; });
  </script>
</body>
</html>"""
    (dest / "play.html").write_text(page, encoding="utf-8")

def write_index(dest: Path, manifest: dict) -> None:
    data = json.dumps(manifest, separators=(",", ":"))
    page = """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Private Emulator Vault</title><style>body{margin:0;background:#090d12;color:#eef6ff;font-family:system-ui}main{width:min(1440px,95vw);margin:0 auto;padding:28px 0 50px}.top{display:flex;justify-content:space-between;gap:14px}.back,.button{border:1px solid #314357;border-radius:7px;background:#182230;color:#eef6ff;text-decoration:none;font-weight:800;padding:10px 12px}.hero,.card{border:1px solid #314357;border-radius:8px;background:#121922;padding:14px}.stats,.filters,.tags{display:flex;flex-wrap:wrap;gap:8px}.pill,.tag{border:1px solid #314357;border-radius:999px;background:#0e151f;padding:6px 9px}.filters{position:sticky;top:0;background:#090d12;padding:12px 0;margin:14px 0}input,select{min-height:42px;border:1px solid #314357;border-radius:7px;background:#0e151f;color:#eef6ff;padding:8px 10px}input{flex:1;min-width:min(460px,100%)}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:12px}.card h2{font-size:17px;margin:0;overflow-wrap:anywhere}.play{display:grid;place-items:center;min-height:38px;border-radius:7px;background:#35d07f;color:#06110d;font-weight:900;text-decoration:none}.small,p{color:#a8b8cc}.meta{font-size:12px;color:#a8b8cc;text-transform:uppercase}@media(max-width:720px){.top{display:block}.filters{position:static}}</style></head><body><main><div class="top"><div><h1>Private Emulator Vault</h1><p>Bulk VM-local emulator shelf, kept separate from the main arcade grid.</p></div><a class="back" href="../games/">Back to Arcade</a></div><section class="hero"><div class="stats" id="stats"></div><p><a class="button" href="reports/latest.html">Latest QA Report</a> <a class="button" href="reports/qa-summary.html">QA Summary</a></p><p class="small">Generated __GENERATED__ from profile <b>__PROFILE__</b>. ROM files are private VM-local content and must not be committed to GitHub.</p></section><section class="filters"><input id="q" type="search" placeholder="Search title, genre, region..."><select id="system"><option value="">All systems</option></select><select id="status"><option value="">All QA statuses</option><option>playable-smoke</option><option>needs-manual-input</option><option>playable-language-review</option><option>needs-review</option><option>failed</option><option>error</option></select></section><section class="grid" id="grid"></section></main><script>window.VAULT_MANIFEST=__DATA__;</script><script>const manifest=window.VAULT_MANIFEST,games=manifest.games||[],statusById=new Map();function esc(s){return String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}async function loadReport(){try{const r=await fetch('reports/latest.json');if(r.ok){const d=await r.json();for(const item of d.results||[])statusById.set(item.id,item.verdict);}}catch{}}function text(g){return [g.title,g.system,(g.regions||[]).join(' '),(g.languages||[]).join(' '),(g.genres||[]).join(' '),g.originalPath].join(' ').toLowerCase();}function renderStats(list){const systems=new Map();for(const g of games)systems.set(g.system,(systems.get(g.system)||0)+1);stats.innerHTML=[`<span class="pill"><b>${games.length}</b> total</span>`,`<span class="pill"><b>${list.length}</b> shown</span>`,...[...systems].map(([k,v])=>`<span class="pill"><b>${v}</b> ${esc(k)}</span>`)].join('');}function renderSystems(){for(const s of [...new Set(games.map(g=>g.system))].sort())system.insertAdjacentHTML('beforeend',`<option>${esc(s)}</option>`);}function render(){const query=q.value.trim().toLowerCase(),sys=system.value,st=status.value;const list=games.filter(g=>(!sys||g.system===sys)&&(!st||statusById.get(g.id)===st)&&(!query||text(g).includes(query)));renderStats(list);grid.innerHTML=list.map(g=>{const st=statusById.get(g.id)||'untested';const tags=[g.system,...(g.genres||[]).slice(0,2),...(g.regions||[]).slice(0,1),st].map(t=>`<span class="tag">${esc(t)}</span>`).join('');return `<article class="card"><div class="meta">${esc(g.system)} | ${esc((g.languages||[]).join(', ')||'language unknown')}</div><h2>${esc(g.title)}</h2><div class="tags">${tags}</div><a class="play" href="play.html?id=${encodeURIComponent(g.id)}">Play</a><div class="small">${esc(g.originalPath)}</div></article>`;}).join('')||'<p>No matching games.</p>';}loadReport().then(()=>{renderSystems();render();for(const id of ['q','system','status'])document.getElementById(id).addEventListener('input',render);});</script></body></html>"""
    page = page.replace("__DATA__", data).replace("__GENERATED__", html.escape(manifest["generatedAt"])).replace("__PROFILE__", html.escape(manifest["profile"]))
    (dest / "index.html").write_text(page, encoding="utf-8")


def write_report_placeholders(dest: Path) -> None:
    reports = dest / "reports"
    reports.mkdir(parents=True, exist_ok=True)
    (reports / "latest.json").write_text(json.dumps({"status": "not-run", "results": []}, indent=2) + "\n", encoding="utf-8")
    (reports / "latest.html").write_text("<h1>No QA run yet</h1><p>Run npm run rom:vault:smoke.</p>", encoding="utf-8")
    (reports / "qa-summary.html").write_text("<h1>No QA run yet</h1><p>Run npm run rom:vault:smoke.</p>", encoding="utf-8")


def build(archive: Path, dest: Path, profile: str, limit: int, dry_run: bool) -> dict:
    safe_dest(dest)
    if not archive.exists():
        raise SystemExit(f"Archive not found: {archive}")
    candidates = read_candidates(archive)
    chosen = select(candidates, profile)
    if limit:
        chosen = chosen[:limit]
    counts = {"archiveRomFiles": len(candidates), "selected": len(chosen), "systems": {}}
    for c in chosen:
        counts["systems"][c["system"]] = counts["systems"].get(c["system"], 0) + 1
    manifest = {"name": "Private Emulator Vault", "kind": "private-rom-vault", "profile": profile, "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "sourceArchive": str(archive), "sourceArchiveSha256": sha256_file(archive), "selectionPolicy": "VM-local private ROM shelf. Keep ROMs out of Git.", "counts": counts, "games": []}
    if dry_run:
        print(json.dumps({"dryRun": True, "counts": counts, "sample": [c["info"].filename for c in chosen[:20]]}, indent=2))
        return manifest
    tmp = dest.with_name(dest.name + ".tmp")
    if tmp.exists():
        shutil.rmtree(tmp)
    tmp.mkdir(parents=True)
    (tmp / "roms").mkdir()
    seen: set[str] = set()
    with zipfile.ZipFile(archive) as zf:
        for c in chosen:
            info = c["info"]
            ext = Path(info.filename).suffix.lower()
            system_slug = slugify(c["system"])
            data = zf.read(info)
            digest = sha256_data(data)
            base = slugify(c["title"])
            rom_id = base if base not in seen else f"{base}-{digest[:8]}"
            seen.add(rom_id)
            rom_dir = tmp / "roms" / system_slug
            rom_dir.mkdir(parents=True, exist_ok=True)
            rom_path = rom_dir / f"{rom_id}{ext}"
            rom_path.write_bytes(data)
            manifest["games"].append({"id": rom_id, "title": c["title"], "system": c["system"], "core": c["core"], "source": "private-archive", "selectionReason": f"profile={profile}; score={c['score']}", "regions": c["regions"], "languages": c["languages"], "genres": c["genres"], "bytes": len(data), "sha256": digest, "originalPath": info.filename, "rom": rom_path.relative_to(tmp).as_posix()})
    (tmp / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (tmp / "README.txt").write_text("Private Emulator Vault. ROM files are VM-local private content; do not commit them to Git.\n", encoding="utf-8")
    write_play(tmp)
    write_index(tmp, manifest)
    write_report_placeholders(tmp)
    if dest.exists():
        backup = dest.with_name(f"{dest.name}.backup-{time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())}")
        dest.rename(backup)
        print(f"BACKUP={backup}")
    tmp.rename(dest)
    print(f"VAULT_READY={dest}")
    print(f"SELECTED={len(manifest['games'])} ARCHIVE_ROM_FILES={len(candidates)}")
    for system, count in sorted(counts["systems"].items()):
        print(f"SYSTEM={system} COUNT={count}")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", default=str(DEFAULT_ARCHIVE))
    parser.add_argument("--dest", default=str(DEFAULT_DEST))
    parser.add_argument("--profile", choices=["selected", "english", "all"], default="selected")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    build(Path(args.archive), Path(args.dest), args.profile, args.limit, args.dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
