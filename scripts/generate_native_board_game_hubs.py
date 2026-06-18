#!/usr/bin/env python3
"""Generate LAN Arcade hub pages for native board-game intake."""
from __future__ import annotations

from html import escape
import json
import shutil
from pathlib import Path

from native_board_game_data import BOARD_GAMES

ROOT = Path(__file__).resolve().parents[1]
LOCAL_GAMES = ROOT / 'local-games'
DOWNLOAD_ROOT = Path('/var/www/html/mirrors/games/downloads/native')

CSS = """
:root{color-scheme:dark;--bg:#101316;--panel:#171f25;--line:#33424b;--text:#f4f8f8;--muted:#c4d0d4;--accent:#72d39b;--accent2:#7cb7ff;--warn:#f0bf5a;--bad:#ff746d;--ink:#06110d}*{box-sizing:border-box}body{margin:0;font-family:Inter,ui-sans-serif,system-ui,-apple-system,Segoe UI,sans-serif;background:var(--bg);color:var(--text)}a{color:inherit}.hero{min-height:72vh;position:relative;display:grid;align-items:end;overflow:hidden;border-bottom:1px solid var(--line);background:#0a0e10}.hero:before{content:"";position:absolute;inset:0;background:linear-gradient(90deg,rgba(7,10,12,.95),rgba(7,10,12,.72) 45%,rgba(7,10,12,.25)),var(--hero) center/cover no-repeat;transform:scale(1.02)}.hero.no-shot:before{background:linear-gradient(120deg,#0a0e10,#15211d 58%,#171b24)}.hero-inner{position:relative;z-index:1;width:min(1180px,94vw);margin:0 auto;padding:34px 0 60px}.eyebrow{color:var(--accent);font-size:12px;font-weight:850;text-transform:uppercase;letter-spacing:.08em}h1{margin:12px 0;max-width:1000px;font-size:clamp(38px,7vw,78px);line-height:.96;letter-spacing:0}.lede{max-width:880px;margin:0;color:#f7fbfc;font-size:clamp(18px,2.2vw,23px);line-height:1.43}.quick,.nav{display:flex;flex-wrap:wrap;gap:10px}.quick{margin-top:22px}.pill{border:1px solid rgba(255,255,255,.24);background:rgba(0,0,0,.45);border-radius:8px;padding:9px 11px;font-size:13px;font-weight:850}.nav{margin-top:26px}.button,.nav a{display:inline-flex;align-items:center;justify-content:center;min-height:42px;border-radius:8px;padding:10px 13px;font-weight:850;text-decoration:none;background:var(--accent);color:var(--ink)}.button.secondary,.nav a.secondary{background:rgba(255,255,255,.08);color:var(--text);border:1px solid rgba(255,255,255,.2)}.status-pass{color:var(--accent)}.status-partial{color:var(--warn)}.status-blocked{color:var(--bad)}.band{border-bottom:1px solid rgba(255,255,255,.08)}.wrap{width:min(1180px,94vw);margin:0 auto;padding:42px 0}.section-head{display:flex;justify-content:space-between;gap:24px;align-items:end;margin-bottom:18px}h2{margin:0;font-size:clamp(25px,3vw,38px);letter-spacing:0}.section-head p{margin:0;max-width:720px;color:var(--muted);line-height:1.55}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px;min-width:0}.two{grid-template-columns:repeat(2,minmax(0,1fr))}.panel{min-width:0;overflow-wrap:anywhere;background:rgba(255,255,255,.055);border:1px solid var(--line);border-radius:8px;padding:18px}.panel h3{margin:0 0 8px;color:var(--accent);font-size:18px}.panel p,.panel li{color:var(--muted);line-height:1.58}.panel p{margin:0 0 10px}.panel ul,.panel ol{margin:0;padding-left:21px}.downloads{display:grid;grid-template-columns:repeat(auto-fit,minmax(238px,1fr));gap:14px}.manual{display:grid;grid-template-columns:minmax(0,.9fr) minmax(0,1.1fr);gap:18px}.steps{counter-reset:step;display:grid;gap:10px}.step{display:grid;grid-template-columns:38px minmax(0,1fr);gap:12px}.step:before{counter-increment:step;content:counter(step);width:32px;height:32px;border-radius:50%;display:grid;place-items:center;background:var(--accent2);color:#061019;font-weight:900}.step h3{margin:2px 0 4px;color:var(--text);font-size:17px}.step p{margin:0;color:var(--muted);line-height:1.5}figure{margin:0;border:1px solid var(--line);border-radius:8px;overflow:hidden;background:#070b0d}figure img{display:block;width:100%;min-height:260px;object-fit:cover}figcaption{border-top:1px solid rgba(255,255,255,.08);padding:10px 12px;color:var(--muted);font-size:13px}code{display:inline-block;max-width:100%;overflow-wrap:anywhere;white-space:normal;color:#ffe08a;background:#090d10;border:1px solid rgba(255,255,255,.1);padding:3px 6px;border-radius:5px}footer{width:min(1180px,94vw);margin:0 auto;padding:24px 0 36px;color:#97a6ab;font-size:13px}@media(max-width:900px){.hero{min-height:66vh}.section-head{display:block}.section-head p{margin-top:10px}.grid,.two,.manual{grid-template-columns:minmax(0,1fr)}figure img{min-height:190px}}
"""

def read_manifest(slug: str) -> dict | None:
    path = DOWNLOAD_ROOT / slug / 'manifest.json'
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except Exception:
        return None

def cards(items):
    return ''.join(f"<article class='panel'><h3>{escape(t)}</h3><p>{escape(b)}</p></article>" for t, b in items)

def steps(items):
    return ''.join(f"<div class='step'><div><h3>{escape(t)}</h3><p>{escape(b)}</p></div></div>" for t, b in items)

def statuses(items):
    return ''.join(f"<article class='panel'><h3>{escape(k)}</h3><p><strong>{escape(v)}</strong></p></article>" for k, v in items)

def downloads(game):
    slug = game['download_slug']
    manifest = read_manifest(slug)
    shelf = f"../games/downloads/native/{escape(slug)}/"
    if not manifest:
        return f"<article class='panel'><h3>Download shelf pending</h3><p>The package cache has not been generated yet.</p><a class='button secondary' href='{shelf}'>Open shelf</a></article>"
    assets = manifest.get('assets', [])
    size = sum(int(a.get('size', 0)) for a in assets)
    size_text = f"{size / (1024*1024):.1f} MB" if size else 'size unknown'
    return f"<article class='panel'><h3>Offline package shelf</h3><p>{len(assets)} cached files, {escape(size_text)} total, with manifest and SHA256 sums.</p><a class='button' href='{shelf}'>Open downloads</a></article><article class='panel'><h3>Install note</h3><p>On matching Debian 12 clients, copy the version folder and run <code>sudo apt install ./*.deb</code>. Non-Linux clients need per-game official packages when available.</p></article>"

def render(game: dict) -> str:
    target = LOCAL_GAMES / game['id']
    shot_name = 'assets/play-smoke.png'
    shot = target / shot_name
    hero_cls = 'hero' if shot.exists() else 'hero no-shot'
    hero_style = f" style=\"--hero:url('{shot_name}')\"" if shot.exists() else ''
    facts = ''.join(f"<span class='pill'>{escape(f)}</span>" for f in game['facts'])
    label = game['status_class'].upper()
    docs_url = f"../{escape(game['docs']['dest'])}/"
    packages = ', '.join(game['packages'])
    return f"""<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'><title>{escape(game['title'])} - LAN Arcade</title><style>{CSS}</style></head><body><header class='{hero_cls}'{hero_style}><div class='hero-inner'><div class='eyebrow'>{escape(game['eyebrow'])}</div><h1>{escape(game['title'])}</h1><p class='lede'>{escape(game['lede'])}</p><div class='quick'>{facts}<span class='pill status-{escape(game['status_class'])}'>QA {escape(label)}</span></div><nav class='nav' aria-label='Page sections'><a href='#downloads'>Download Clients</a><a class='secondary' href='{docs_url}'>Manual / Docs</a><a class='secondary' href='#qa'>QA Evidence</a><a class='secondary' href='../games/'>Back to Arcade</a></nav></div></header><main><section class='band'><div class='wrap'><div class='section-head'><h2>Should You Play?</h2><p>These notes are based on actual VM smoke tests. HTTP 200 does not count as gameplay proof.</p></div><div class='grid'>{cards(game['cards'])}</div></div></section><section class='band' id='downloads'><div class='wrap'><div class='section-head'><h2>Offline Downloads</h2><p>Packages live on the NFS-backed native shelf, not in Git. Seed packages: <code>{escape(packages)}</code>.</p></div><div class='downloads'>{downloads(game)}<article class='panel'><h3>Official mirror/manual</h3><p>Open the locally cached official site/manual or blocker note.</p><a class='button secondary' href='{docs_url}'>Open docs</a></article><article class='panel'><h3>Original source</h3><p>{escape(game['source'])}</p><a class='button secondary' href='{escape(game['source'])}'>Open upstream</a></article></div></div></section><section class='band'><div class='wrap two grid'><figure><img src='{shot_name}' alt='{escape(game['title'])} QA screenshot'><figcaption>{escape(game['qa_summary'])}</figcaption></figure><article class='panel'><h3>QA Result</h3><p class='status-{escape(game['status_class'])}'><strong>{escape(label)}</strong></p><p>{escape(game['qa_summary'])}</p><p>Evidence folder is recorded in <code>docs/BOARD_GAME_INTAKE_2026-06-19.md</code>.</p></article></div></section><section class='band' id='manual'><div class='wrap manual'><div><h2>Quick Manual</h2><p class='panel'>A short offline orientation for first play. Use the docs mirror for deeper rules/manuals where available.</p></div><div class='steps'>{steps(game['steps'])}</div></div></section><section class='band' id='qa'><div class='wrap'><div class='section-head'><h2>Regression Status</h2><p>Playable entries must pass a no-internet namespace smoke that reaches a meaningful game state.</p></div><div class='grid'>{statuses(game['status'])}</div></div></section></main><footer>LAN Arcade native board-game intake. See <a href='ATTRIBUTION.txt'>ATTRIBUTION.txt</a> for source and package notes.</footer></body></html>"""

def main() -> int:
    for game in BOARD_GAMES:
        target = LOCAL_GAMES / game['id']
        assets = target / 'assets'
        assets.mkdir(parents=True, exist_ok=True)
        src = ROOT / game['screenshot']
        if src.exists():
            shutil.copy2(src, assets / 'play-smoke.png')
        (target / 'index.html').write_text(render(game), encoding='utf-8')
        (target / 'ATTRIBUTION.txt').write_text(f"{game['title']}\n\nSource: {game['source']}\n\nDebian package seed: {', '.join(game['packages'])}\n\nLAN Arcade QA: {game['qa_summary']}\n", encoding='utf-8')
        print(f'HUB_READY={target}')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
