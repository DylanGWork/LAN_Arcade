#!/usr/bin/env python3
"""Generate LAN Arcade hub pages for native intake batch three."""
from __future__ import annotations

from html import escape
from pathlib import Path

from native_batch_three_data import BATCH_THREE

ROOT = Path(__file__).resolve().parents[1]
LOCAL_GAMES = ROOT / 'local-games'

COMMON_CSS = """
:root { color-scheme: dark; --bg:#0d1215; --panel:#172026; --line:#30414a; --text:#f4f8f9; --muted:#c5d1d6; --soft:#99a9ae; --accent:#74d39b; --accent2:#76b8ff; --warn:#f0bf5a; --ink:#07110d; }
* { box-sizing:border-box; }
html { scroll-behavior:smooth; }
body { margin:0; font-family:Inter, ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif; background:var(--bg); color:var(--text); }
a { color:inherit; }
.hero { min-height:72vh; position:relative; display:grid; align-items:end; overflow:hidden; border-bottom:1px solid var(--line); background:linear-gradient(135deg,#0a0f12,#14241e 54%,#17202a); }
.hero::before { content:""; position:absolute; inset:0; background:linear-gradient(90deg, rgba(7,10,12,.96) 0%, rgba(7,10,12,.76) 48%, rgba(7,10,12,.30) 100%), repeating-linear-gradient(90deg, rgba(255,255,255,.04) 0 1px, transparent 1px 58px), repeating-linear-gradient(0deg, rgba(255,255,255,.03) 0 1px, transparent 1px 58px); }
.hero::after { content:attr(data-mark); position:absolute; right:clamp(16px,7vw,96px); top:clamp(90px,16vw,160px); font-size:clamp(54px,12vw,156px); font-weight:950; color:rgba(255,255,255,.08); letter-spacing:0; }
.hero-inner { position:relative; width:min(1180px,94vw); margin:0 auto; padding:34px 0 64px; z-index:1; }
.eyebrow { color:var(--accent); font-size:12px; font-weight:850; text-transform:uppercase; letter-spacing:.08em; }
h1 { margin:12px 0; max-width:980px; font-size:clamp(38px,7vw,80px); line-height:.95; letter-spacing:0; }
.lede { max-width:860px; margin:0; color:#f7fbfc; font-size:clamp(18px,2.2vw,23px); line-height:1.43; }
.quick,.nav { display:flex; flex-wrap:wrap; gap:10px; }
.quick { margin-top:22px; }
.pill { border:1px solid rgba(255,255,255,.24); background:rgba(0,0,0,.44); border-radius:8px; padding:9px 11px; font-size:13px; font-weight:850; }
.nav { margin-top:26px; }
.nav a,.button { display:inline-flex; align-items:center; justify-content:center; min-height:42px; border-radius:8px; padding:10px 13px; font-weight:850; text-decoration:none; background:var(--accent); color:var(--ink); }
.nav a.secondary,.button.secondary { background:rgba(255,255,255,.08); color:var(--text); border:1px solid rgba(255,255,255,.2); }
.nav a.warn { background:rgba(240,191,90,.16); color:#ffe4a6; border:1px solid rgba(240,191,90,.42); }
main { background:linear-gradient(180deg,var(--bg),#11181c); }
.band { border-bottom:1px solid rgba(255,255,255,.08); }
.wrap { width:min(1180px,94vw); margin:0 auto; padding:42px 0; }
.section-head { display:flex; justify-content:space-between; gap:24px; align-items:end; margin-bottom:18px; }
h2 { margin:0; font-size:clamp(25px,3vw,38px); letter-spacing:0; }
.section-head p { margin:0; max-width:720px; color:var(--muted); line-height:1.55; }
.grid { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:14px; min-width:0; }
.two { grid-template-columns:repeat(2,minmax(0,1fr)); }
.panel { min-width:0; overflow-wrap:anywhere; background:rgba(255,255,255,.055); border:1px solid var(--line); border-radius:8px; padding:18px; }
.panel h3 { margin:0 0 8px; color:var(--accent); font-size:18px; }
.panel p,.panel li { color:var(--muted); line-height:1.58; }
.panel p { margin:0 0 10px; }
.panel ul,.panel ol { margin:0; padding-left:21px; }
.downloads { display:grid; grid-template-columns:repeat(auto-fit,minmax(238px,1fr)); gap:14px; }
.manual { display:grid; grid-template-columns:minmax(0,.9fr) minmax(0,1.1fr); gap:18px; }
.steps { counter-reset:step; display:grid; gap:10px; }
.step { display:grid; grid-template-columns:38px minmax(0,1fr); gap:12px; }
.step::before { counter-increment:step; content:counter(step); width:32px; height:32px; border-radius:50%; display:grid; place-items:center; background:var(--accent2); color:#061019; font-weight:900; }
.step h3 { margin:2px 0 4px; color:var(--text); font-size:17px; }
.step p { margin:0; color:var(--muted); line-height:1.5; }
.status strong { display:block; color:var(--text); font-size:20px; }
.preview { min-height:270px; display:grid; place-items:center; text-align:center; border:1px solid var(--line); border-radius:8px; background:radial-gradient(circle at 25% 20%, rgba(116,211,155,.22), transparent 28%), radial-gradient(circle at 78% 70%, rgba(118,184,255,.18), transparent 30%), #0a0f12; padding:24px; }
.preview strong { font-size:clamp(30px,7vw,74px); color:rgba(255,255,255,.22); }
code { display:inline-block; max-width:100%; overflow-wrap:anywhere; white-space:normal; color:#ffe08a; background:#090d10; border:1px solid rgba(255,255,255,.1); padding:3px 6px; border-radius:5px; }
footer { width:min(1180px,94vw); margin:0 auto; padding:24px 0 36px; color:var(--soft); font-size:13px; }
@media (max-width:900px) { .hero { min-height:68vh; } .section-head { display:block; } .section-head p { margin-top:10px; } .grid,.two,.manual { grid-template-columns:minmax(0,1fr); } .preview { min-height:190px; } }
"""


def blocks(items):
    return ''.join(f"<article class='panel'><h3>{escape(title)}</h3><p>{escape(body)}</p></article>" for title, body in items)


def steps(items):
    return ''.join(f"<div class='step'><div><h3>{escape(title)}</h3><p>{escape(body)}</p></div></div>" for title, body in items)


def statuses(items):
    return ''.join(f"<article class='panel status'><h3>{escape(label)}</h3><strong>{escape(value)}</strong></article>" for label, value in items)


def render(game: dict) -> str:
    facts = ''.join(f"<span class='pill'>{escape(f)}</span>" for f in game['facts'])
    docs_url = f"../{escape(game['docs']['dest'])}/"
    shelf_url = f"../games/downloads/native/{escape(game['download_slug'])}/"
    package_list = ', '.join(game['packages'])
    return f"""<!doctype html>
<html lang='en'>
<head>
  <meta charset='utf-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1'>
  <title>{escape(game['title'])} - LAN Arcade</title>
  <style>{COMMON_CSS}</style>
</head>
<body>
  <header class='hero' data-mark='{escape(game['icon'])}'><div class='hero-inner'>
    <div class='eyebrow'>{escape(game['eyebrow'])}</div>
    <h1>{escape(game['title'])}</h1>
    <p class='lede'>{escape(game['lede'])}</p>
    <div class='quick'>{facts}</div>
    <nav class='nav' aria-label='Page sections'><a href='#downloads'>Download Packages</a><a class='secondary' href='#manual'>Quick Manual</a><a class='secondary' href='#qa'>QA Status</a><a class='secondary' href='../games/'>Back to Arcade</a></nav>
  </div></header>
  <main>
    <section class='band'><div class='wrap'><div class='section-head'><h2>Should You Play?</h2><p>This is a Linux/Debian-first native intake page. It explains the game and stores local packages, but it is not promoted to play-ready until gameplay smoke passes.</p></div><div class='grid'>{blocks(game['cards'])}</div></div></section>
    <section class='band' id='downloads'><div class='wrap'><div class='section-head'><h2>Offline Downloads</h2><p>Stored on the NFS-backed native shelf, not in Git. Package seed: <code>{escape(package_list)}</code>.</p></div><div class='downloads'><article class='panel'><h3>Debian package shelf</h3><p>Primary game packages plus resolved Debian dependencies for GannanNet-style Linux installs.</p><a class='button' href='{shelf_url}'>Open downloads</a></article><article class='panel'><h3>Local docs mirror</h3><p>Official pages mirrored where wget could capture them; if blocked, the page records that honestly.</p><a class='button secondary' href='{docs_url}'>Open docs</a></article><article class='panel'><h3>Original source</h3><p>Use upstream for license/source context and future non-Linux installers.</p><a class='button secondary' href='{escape(game['source'])}'>Open upstream</a></article></div></div></section>
    <section class='band'><div class='wrap two grid'><div class='preview'><div><strong>{escape(game['icon'])}</strong><p>Gameplay screenshot pending. The next QA gate is a real client launch/play capture, not just this hub page.</p></div></div><article class='panel'><h3>Current Platform Scope</h3><p>This batch caches Debian/Linux package sets first so the VM can install/test games without the internet. Windows/macOS/Android installers should be added per game when an official, license-clean release path is verified.</p><p>Download shelf: <code>/var/www/html/mirrors/games/downloads/native/{escape(game['download_slug'])}/</code></p></article></div></section>
    <section class='band' id='manual'><div class='wrap manual'><div><h2>Quick Manual</h2><p class='panel'>Enough to orient a new player before deeper docs or a real playtest.</p></div><div class='steps'>{steps(game['steps'])}</div></div></section>
    <section class='band' id='qa'><div class='wrap'><div class='section-head'><h2>Arcade QA Status</h2><p>Native games move through gates: cached artifacts, client launch, real gameplay, LAN join where relevant, then real-device smoke.</p></div><div class='grid'>{statuses(game['status'])}</div></div></section>
  </main>
  <footer>LAN Arcade native batch three page. See <a href='ATTRIBUTION.txt'>ATTRIBUTION.txt</a> for source notes.</footer>
</body>
</html>
"""


def main() -> int:
    for game in BATCH_THREE:
        target = LOCAL_GAMES / game['id']
        target.mkdir(parents=True, exist_ok=True)
        (target / 'index.html').write_text(render(game), encoding='utf-8')
        (target / 'ATTRIBUTION.txt').write_text(f"{game['title']}\n\nSource: {game['source']}\n\nDebian package seed: {', '.join(game['packages'])}\n\nLAN Arcade status: native batch three Linux/Debian-first cache and hub page. Not play-ready until client/gameplay smoke is recorded.\n", encoding='utf-8')
        print(f'HUB_READY={target}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
