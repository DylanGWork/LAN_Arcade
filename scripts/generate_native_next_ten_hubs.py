#!/usr/bin/env python3
"""Generate LAN Arcade hub pages for the second native-game intake batch."""
from __future__ import annotations

from html import escape
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCAL_GAMES = ROOT / "local-games"
DOWNLOAD_ROOT = Path("/var/www/html/mirrors/games/downloads/native")

COMMON_CSS = """
:root { color-scheme: dark; --bg:#0c1114; --panel:#151d22; --line:#2d3b43; --text:#f2f7f8; --muted:#c0ccd1; --soft:#95a4aa; --accent:#69d9a0; --accent2:#77b7ff; --warn:#f0bf5a; --ink:#07110d; }
* { box-sizing:border-box; }
html { scroll-behavior:smooth; }
body { margin:0; font-family:Inter, ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif; background:var(--bg); color:var(--text); }
a { color:inherit; }
.hero { min-height:76vh; position:relative; display:grid; align-items:end; overflow:hidden; border-bottom:1px solid var(--line); background:linear-gradient(135deg,#0a0e11,#14221d 55%,#181b24); }
.hero.has-shot::before { content:""; position:absolute; inset:0; background:linear-gradient(90deg, rgba(8,10,12,.96) 0%, rgba(8,10,12,.76) 46%, rgba(8,10,12,.28) 100%), var(--hero) center/cover no-repeat; transform:scale(1.02); }
.hero:not(.has-shot)::before { content:""; position:absolute; inset:0; background:linear-gradient(90deg, rgba(8,10,12,.95), rgba(20,34,29,.75)), repeating-linear-gradient(90deg, rgba(255,255,255,.035) 0 1px, transparent 1px 54px), repeating-linear-gradient(0deg, rgba(255,255,255,.028) 0 1px, transparent 1px 54px); }
.hero-inner { position:relative; width:min(1180px,94vw); margin:0 auto; padding:34px 0 64px; }
.eyebrow { color:var(--accent); font-size:12px; font-weight:850; text-transform:uppercase; letter-spacing:.08em; }
h1 { margin:12px 0; max-width:980px; font-size:clamp(38px,7vw,80px); line-height:.95; letter-spacing:0; }
.lede { max-width:850px; margin:0; color:#f7fbfc; font-size:clamp(18px,2.2vw,23px); line-height:1.43; }
.quick,.nav { display:flex; flex-wrap:wrap; gap:10px; }
.quick { margin-top:22px; }
.pill { border:1px solid rgba(255,255,255,.24); background:rgba(0,0,0,.44); border-radius:8px; padding:9px 11px; font-size:13px; font-weight:850; }
.nav { margin-top:26px; }
.nav a,.button { display:inline-flex; align-items:center; justify-content:center; min-height:42px; border-radius:8px; padding:10px 13px; font-weight:850; text-decoration:none; background:var(--accent); color:var(--ink); }
.nav a.secondary,.button.secondary { background:rgba(255,255,255,.08); color:var(--text); border:1px solid rgba(255,255,255,.2); }
.nav a.warn,.button.warn { background:rgba(240,191,90,.16); color:#ffe4a6; border:1px solid rgba(240,191,90,.42); }
main { background:linear-gradient(180deg,var(--bg),#11171b); }
.band { border-bottom:1px solid rgba(255,255,255,.08); }
.wrap { width:min(1180px,94vw); margin:0 auto; padding:42px 0; }
.section-head { display:flex; justify-content:space-between; gap:24px; align-items:end; margin-bottom:18px; }
h2 { margin:0; font-size:clamp(25px,3vw,38px); letter-spacing:0; }
.section-head p { margin:0; max-width:700px; color:var(--muted); line-height:1.55; }
.grid { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:14px; min-width:0; }
.two { grid-template-columns:repeat(2,minmax(0,1fr)); }
.panel { min-width:0; overflow-wrap:anywhere; background:rgba(255,255,255,.055); border:1px solid var(--line); border-radius:8px; padding:18px; }
.panel h3 { margin:0 0 8px; color:var(--accent); font-size:18px; }
.panel p,.panel li { color:var(--muted); line-height:1.58; }
.panel p { margin:0 0 10px; }
.panel ul,.panel ol { margin:0; padding-left:21px; }
.downloads { display:grid; grid-template-columns:repeat(auto-fit,minmax(238px,1fr)); gap:14px; }
.download-card { display:grid; gap:8px; align-content:start; }
.download-card .button { justify-self:start; }
.manual { display:grid; grid-template-columns:minmax(0,.9fr) minmax(0,1.1fr); gap:18px; }
.steps { counter-reset:step; display:grid; gap:10px; }
.step { display:grid; grid-template-columns:38px minmax(0,1fr); gap:12px; }
.step::before { counter-increment:step; content:counter(step); width:32px; height:32px; border-radius:50%; display:grid; place-items:center; background:var(--accent2); color:#061019; font-weight:900; }
.step h3 { margin:2px 0 4px; color:var(--text); font-size:17px; }
.step p { margin:0; color:var(--muted); line-height:1.5; }
figure { margin:0; border:1px solid var(--line); border-radius:8px; overflow:hidden; background:#080c0e; }
figure img { display:block; width:100%; min-height:260px; object-fit:cover; }
.placeholder { min-height:260px; display:grid; place-items:center; color:var(--muted); background:linear-gradient(135deg,#10171c,#17231e); padding:24px; text-align:center; }
figcaption { border-top:1px solid rgba(255,255,255,.08); padding:10px 12px; color:var(--muted); font-size:13px; }
.status strong { display:block; color:var(--text); font-size:20px; }
code { display:inline-block; max-width:100%; overflow-wrap:anywhere; white-space:normal; color:#ffe08a; background:#090d10; border:1px solid rgba(255,255,255,.1); padding:3px 6px; border-radius:5px; }
footer { width:min(1180px,94vw); margin:0 auto; padding:24px 0 36px; color:var(--soft); font-size:13px; }
@media (max-width:900px) { .hero { min-height:70vh; } .section-head { display:block; } .section-head p { margin-top:10px; } .grid,.two,.manual { grid-template-columns:minmax(0,1fr); } figure img,.placeholder { min-height:190px; } }
"""

GAMES = {
    "supertuxkart-lan": {
        "title": "SuperTuxKart LAN Hub", "eyebrow": "Native racing intake", "download_slug": "supertuxkart", "site": "../supertuxkart-site/", "source": "https://supertuxkart.net/ and https://github.com/supertuxkart/stk-code",
        "lede": "A bright kart racer with local races, battle modes, online/LAN options, controller-friendly play, and an Android build for tablets.",
        "facts": ["Kart racing", "Family friendly", "Android APK cached", "VM launch smoke"],
        "cards": [("Why play", "This fills the Mario Kart-style slot: fast to understand, good for mixed ages, and much more approachable than the heavier FPS/RTS games."), ("Offline plan", "Install from the local shelf, run local races immediately, then prove a LAN race/join loop with two devices."), ("Version note", "The shelf stores upstream 1.5 packages. Debian's VM smoke package is 1.4, so the page records both instead of pretending they are identical.")],
        "steps": [("Pick a kart", "Start with single-player races and unlock-free testing if you just want to learn tracks."), ("Use assists", "Lower difficulty and steering assists make it comfortable for kids and casual players."), ("Try battle modes", "Races are not the only mode; arenas and soccer-style modes are good LAN party options."), ("LAN proof next", "Host/join should be tested with real devices after client installs are confirmed.")],
        "status": [("Downloads", "Upstream 1.5 cached"), ("Client launch", "VM smoke target"), ("Service", "Client-hosted/LAN"), ("Next gate", "Race start + LAN join")],
    },
    "xonotic-lan": {
        "title": "Xonotic LAN Hub", "eyebrow": "Arena FPS intake", "download_slug": "xonotic", "site": "../xonotic-site/", "source": "https://xonotic.org/",
        "lede": "A full Quake-style arena shooter with movement, bots, weapons, maps, and a complete all-platform release ZIP.",
        "facts": ["Arena FPS", "All-platform ZIP", "Bot match target", "High-skill LAN"],
        "cards": [("Why play", "This is the serious arena FPS lane: fast, competitive, skill-heavy, and a good benchmark for whether the garage-tier arcade can host real shooters."), ("Offline plan", "The upstream ZIP contains clients/server assets, so it is a clean single-shelf offline package."), ("Test caution", "It is not in Debian here; VM smoke launches from the cached ZIP rather than apt packages.")],
        "steps": [("Start with bots", "Use a local bot match before LAN play so new players learn movement and weapons."), ("Movement first", "Bunny hopping, strafing, and weapon switching matter as much as aim."), ("LAN server", "Next gate should start a local dedicated server and connect one client."), ("Hardware tier", "Expect this to need better hardware than OpenArena/BZFlag.")],
        "status": [("Downloads", "0.8.6 ZIP cached"), ("Client launch", "ZIP smoke target"), ("Server", "Pending"), ("Next gate", "Bot match screenshot")],
    },
    "redeclipse-lan": {
        "title": "Red Eclipse LAN Hub", "eyebrow": "Movement FPS intake", "download_slug": "redeclipse", "site": "../redeclipse-site/", "source": "https://www.redeclipse.net/ and https://github.com/redeclipse/base",
        "lede": "A movement-heavy arena shooter built around agility, mutators, parkour-ish combat, and LAN-friendly FPS sessions.",
        "facts": ["Arena FPS", "Parkour movement", "Official 2.0.0 cached", "VM package 1.6"],
        "cards": [("Why play", "It gives the arcade another FPS flavour: more acrobatic and modern-feeling than OpenArena, less huge than some commercial shooters."), ("Offline plan", "Cache official 2.0.0 archives and use Debian 1.6 for launch proof on this VM."), ("Test caution", "The version mismatch is deliberate and visible: launch smoke proves the engine family, not the exact cached 2.0.0 binary.")],
        "steps": [("Use offline practice", "Start a local match and learn movement before hosting a LAN game."), ("Mutators matter", "Red Eclipse has many game options; pick simple deathmatch first."), ("LAN server", "Next gate is dedicated server smoke plus one client join."), ("Compare FPS options", "Keep this alongside Xonotic/OpenArena, then let playtests decide which stays prominent.")],
        "status": [("Downloads", "2.0.0 cached"), ("Client launch", "Debian 1.6 smoke target"), ("Server", "Pending"), ("Next gate", "LAN deathmatch proof")],
    },
    "openarena-lan": {
        "title": "OpenArena LAN Hub", "eyebrow": "Lightweight arena FPS", "download_slug": "openarena", "site": "../openarena-site/", "source": "https://openarena.ws/ and SourceForge oarena",
        "lede": "A free Quake III Arena-style shooter with bots, maps, and relatively modest hardware needs compared with newer FPS games.",
        "facts": ["Classic FPS", "Bots", "Smallish client", "LAN server candidate"],
        "cards": [("Why play", "This should be the lightweight FPS lane: simple deathmatch, bots, and a familiar old-school feel."), ("Offline plan", "The full 0.8.8 ZIP is cached, and Debian packages provide VM smoke and server binaries."), ("What to prove", "A bot match screenshot and a dedicated-server join test are the key gates.")],
        "steps": [("Start bot match", "Use single-player/skirmish to confirm controls, maps, and FPS feel."), ("Keep it simple", "Deathmatch and capture-the-flag are the first modes to try."), ("LAN host", "OpenArena can use ioquake3/openarena server tooling; prove one local join before promoting."), ("Raspberry Pi question", "This might be a better low-tier FPS candidate than newer shooters, but it still needs real hardware proof.")],
        "status": [("Downloads", "0.8.8 ZIP cached"), ("Client launch", "VM smoke target"), ("Server", "Pending"), ("Next gate", "Bot match + LAN join")],
    },
    "freedoom-lan": {
        "title": "Freedoom LAN Hub", "eyebrow": "Free Doom-compatible FPS", "download_slug": "freedoom", "site": "../freedoom-site/", "source": "https://freedoom.github.io/ and Chocolate Doom/PrBoom+ releases",
        "lede": "Fully free Doom-compatible game data paired with open-source engines, giving the arcade a safe retro FPS without commercial WADs.",
        "facts": ["Retro FPS", "Fully free IWADs", "Tiny downloads", "Low-resource"],
        "cards": [("Why play", "This is the legally clean Doom lane: quick, brutal, tiny, and likely suitable for weak hardware."), ("Offline plan", "Cache Freedoom/FreeDM plus Chocolate Doom and PrBoom+ engine packages for common desktops."), ("What to prove", "The VM should launch a real level using Freedoom IWADs and capture a nonblank gameplay screenshot.")],
        "steps": [("Choose engine", "Use Chocolate Doom for vanilla feel or PrBoom+/DSDA for more modern conveniences."), ("Choose IWAD", "Freedoom Phase 1/2 are campaigns; FreeDM is deathmatch-focused."), ("Start level", "Launch the engine with the local IWAD and confirm controls."), ("LAN later", "Deathmatch hosting is possible, but first gate is a playable local level.")],
        "status": [("Downloads", "Freedoom + engines cached"), ("Client launch", "VM level smoke target"), ("Server", "Deathmatch pending"), ("Next gate", "Level start screenshot")],
    },
    "bzflag-lan": {
        "title": "BZFlag LAN Hub", "eyebrow": "3D tank combat intake", "download_slug": "bzflag", "site": "../bzflag-site/", "source": "https://www.bzflag.org/",
        "lede": "A classic multiplayer 3D tank game with capture-the-flag, ricochet shots, team play, and lightweight dedicated servers.",
        "facts": ["Tank combat", "Dedicated server", "Small downloads", "LAN classic"],
        "cards": [("Why play", "It is simple to explain, tiny compared with modern shooters, and naturally LAN-oriented."), ("Offline plan", "Cache official 2.4.30 Windows/macOS/source packages and use Debian server/client for VM smoke."), ("Service rule", "The Debian service was disabled after install. BZFlag should be started only for smoke/play sessions.")],
        "steps": [("Learn movement", "Drive, jump if enabled, and use the radar as much as the main view."), ("Flags change everything", "Good/bad flags alter weapons, speed, visibility, and survival."), ("Host locally", "Use bzfs for a LAN server, then connect clients to 192.168.1.106."), ("First proof", "Server listen + one client screenshot is the promotion gate.")],
        "status": [("Downloads", "2.4.30 cached"), ("Client launch", "VM smoke target"), ("Server", "bzfs smoke target"), ("Next gate", "Join local server")],
    },
    "freeorion-lan": {
        "title": "FreeOrion LAN Hub", "eyebrow": "Space 4X intake", "download_slug": "freeorion", "site": "../freeorion-site/", "source": "https://freeorion.org/ and GitHub releases",
        "lede": "A turn-based space empire game about exploration, research, colonisation, fleets, species, and galactic strategy.",
        "facts": ["4X strategy", "Space empire", "Turn-based", "Deep replay"],
        "cards": [("Why play", "This is the deeper space-strategy lane: closer to Civilization-in-space than an arcade shooter."), ("Offline plan", "Cache official 0.5.1.2 Windows/macOS/source packages and use Debian 0.4.10.2 for VM smoke."), ("What to prove", "New-game creation and first-turn interaction matter more than just a menu screenshot.")],
        "steps": [("Start small", "Use a small galaxy and fewer AIs while learning the interface."), ("Scout early", "Explore systems, colonise carefully, and watch supply lines."), ("Research direction", "Pick techs that match your species and map position."), ("LAN later", "FreeOrion supports multiplayer, but the first proof should be a local new game.")],
        "status": [("Downloads", "0.5.1.2 cached"), ("Client launch", "VM smoke target"), ("Server", "Multiplayer pending"), ("Next gate", "New game proof")],
    },
    "endless-sky-lan": {
        "title": "Endless Sky LAN Hub", "eyebrow": "Space RPG intake", "download_slug": "endless-sky", "site": "../endless-sky-site/", "source": "https://endless-sky.github.io/ and GitHub releases",
        "lede": "A single-player space trading and combat RPG inspired by Escape Velocity: trade, fight, upgrade ships, hire escorts, and follow storylines.",
        "facts": ["Space RPG", "Single-player", "Low server burden", "Long campaign"],
        "cards": [("Why play", "This gives the arcade a proper solo adventure that does not require running a server."), ("Offline plan", "Cache official Windows, macOS, and Linux AppImage packages, then prove new pilot/first flight."), ("Arcade role", "A great long-haul offline game for one person at a time, not a LAN party title.")],
        "steps": [("Create pilot", "Start a new pilot and read the starting job/tutorial prompts."), ("Trade first", "Cargo runs are safer than early combat and teach the map."), ("Upgrade ship", "Earn money, improve engines/weapons/cargo, then branch into storylines."), ("Proof gate", "A screenshot after creating a pilot or entering space is the real smoke target.")],
        "status": [("Downloads", "0.10.16 cached"), ("Client launch", "VM smoke target"), ("Server", "Not needed"), ("Next gate", "Create pilot")],
    },
    "cataclysm-dda-lan": {
        "title": "Cataclysm DDA LAN Hub", "eyebrow": "Survival roguelike intake", "download_slug": "cataclysm-dda", "site": "../cataclysm-dda-site/", "source": "https://cataclysmdda.org/ and CleverRaven releases",
        "lede": "A huge post-apocalyptic survival roguelike where you scavenge, craft, mutate, build vehicles, and usually die in educational ways.",
        "facts": ["Survival roguelike", "Huge replay", "No server burden", "Low-resource option"],
        "cards": [("Why play", "This is deep, weird, punishing, and very offline-friendly. It can entertain one determined player for a long time."), ("Offline plan", "Cache stable 0.I graphics/sounds packages plus terminal and Android options."), ("Expectation", "It is not pick-up-and-play. The hub needs manuals and beginner guidance more than flashy marketing.")],
        "steps": [("Use preset start", "Pick a beginner-friendly scenario before experimenting with harsh starts."), ("Scavenge first", "Food, water, clothing, light, and a safe place matter before heroics."), ("Craft gradually", "The crafting tree is enormous; start with basic tools and storage."), ("Proof gate", "Create world/survivor and show the first map view without crashes.")],
        "status": [("Downloads", "0.I cached"), ("Client launch", "VM smoke target"), ("Server", "Not needed"), ("Next gate", "Create survivor")],
    },
    "manaplus-lan": {
        "title": "ManaPlus / The Mana World Hub", "eyebrow": "2D MMORPG pathfinder", "download_slug": "manaplus", "site": "../manaplus-site/", "source": "https://manaplus.org/ and https://www.themanaworld.org/",
        "lede": "A 2D MMORPG client for The Mana World, Evol Online, and compatible servers. This is the light MMO path before heavier 3D worlds.",
        "facts": ["2D MMORPG", "Client cached partly", "Server research", "Binary blocker noted"],
        "cards": [("Why play", "It is a much lighter MMO direction than Veloren/RuneScape-like servers and may suit an offline community server."), ("Offline plan", "Cache source and Debian packages now; keep chasing official Windows/macOS binaries or a clean replacement client path."), ("Honest blocker", "The official binary download host timed out from the VM, so this is not yet a complete multi-platform offline client shelf.")],
        "steps": [("Launch client", "Use the Debian client on the VM for first smoke and config screenshots."), ("Server question", "The real work is choosing/cache-testing a compatible local server and data set."), ("Avoid fake readiness", "Do not call this playable until a local account/login/map loop works offline."), ("Research next", "Compare The Mana World, Evol, tmwAthena/Hercules paths, and licensing before promotion.")],
        "status": [("Downloads", "Source + Debian packages cached"), ("Client launch", "VM smoke target"), ("Server", "Research pending"), ("Next gate", "Local login path")],
    },
}


def read_manifest(download_slug: str) -> dict | None:
    path = DOWNLOAD_ROOT / download_slug / "manifest.json"
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def link_list(items):
    return "".join(f"<li><a href='{escape(url)}'>{escape(label)}</a></li>" for label, url in items)


def cards(items):
    return "".join(f"<article class='panel'><h3>{escape(title)}</h3><p>{escape(body)}</p></article>" for title, body in items)


def steps(items):
    return "".join(f"<div class='step'><div><h3>{escape(title)}</h3><p>{escape(body)}</p></div></div>" for title, body in items)


def statuses(items):
    return "".join(f"<article class='panel status'><h3>{escape(label)}</h3><strong>{escape(value)}</strong></article>" for label, value in items)


def downloads(game):
    manifest = read_manifest(game["download_slug"])
    if not manifest:
        return "<article class='panel download-card'><h3>Download shelf pending</h3><p>The cache script has not created the manifest yet.</p></article>"
    version = manifest.get("version", "latest")
    items = []
    for asset in manifest.get("assets", []):
        name = asset.get("name", "download")
        label = asset.get("label", name)
        platform = asset.get("platform", "Offline client")
        note = asset.get("note", "Cached local release file.")
        size = asset.get("size", 0)
        size_text = f"{size / (1024*1024):.1f} MB" if size else "size unknown"
        items.append(f"<article class='panel download-card'><h3>{escape(label)}</h3><p>{escape(platform)}</p><p>{escape(note)}</p><a class='button' href='../games/downloads/native/{escape(game['download_slug'])}/{escape(version)}/{escape(name)}'>Download</a><p>{escape(size_text)}</p></article>")
    blocked = manifest.get("blocked_assets", [])
    if blocked:
        items.append("<article class='panel download-card'><h3>Blocked upstream files</h3><ul>" + "".join(f"<li>{escape(x)}</li>" for x in blocked) + "</ul></article>")
    items.append(f"<article class='panel download-card'><h3>All files and hashes</h3><p>Open the full shelf with manifests and SHA256 sums.</p><a class='button secondary' href='../games/downloads/native/{escape(game['download_slug'])}/'>Open shelf</a></article>")
    return "".join(items)


def render(slug, game):
    target = LOCAL_GAMES / slug
    shot = target / "assets" / "client-launch.png"
    hero_class = "hero has-shot" if shot.exists() else "hero"
    hero_style = " style=\"--hero:url('assets/client-launch.png')\"" if shot.exists() else ""
    shot_html = "<img src='assets/client-launch.png' alt='VM launch screenshot'>" if shot.exists() else "<div class='placeholder'>VM launch screenshot pending. This page will show the smoke-test screenshot after native launch proof is captured.</div>"
    facts = "".join(f"<span class='pill'>{escape(fact)}</span>" for fact in game["facts"])
    local_links = [("Official site/manual mirror", game["site"]), ("Offline download shelf", f"../games/downloads/native/{game['download_slug']}/"), ("Back to Arcade", "../games/")]
    return f"""<!doctype html>
<html lang='en'>
<head>
  <meta charset='utf-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1'>
  <title>{escape(game['title'])} - LAN Arcade</title>
  <style>{COMMON_CSS}</style>
</head>
<body>
  <header class='{hero_class}'{hero_style}><div class='hero-inner'>
    <div class='eyebrow'>{escape(game['eyebrow'])}</div>
    <h1>{escape(game['title'])}</h1>
    <p class='lede'>{escape(game['lede'])}</p>
    <div class='quick'>{facts}</div>
    <nav class='nav' aria-label='Page sections'><a href='{escape(game['site'])}'>Official Mirror</a><a class='secondary' href='#downloads'>Download Clients</a><a class='secondary' href='#manual'>Quick Manual</a><a class='secondary' href='#qa'>QA Status</a><a class='secondary' href='../games/'>Back to Arcade</a></nav>
  </div></header>
  <main>
    <section class='band'><div class='wrap'><div class='section-head'><h2>Official Offline Site</h2><p>Where an upstream site, wiki, or manual exists, this hub links to the local mirrored copy first. If mirroring failed, the mirror folder records the blocker instead of hiding it.</p></div><div class='grid two'><article class='panel'><h3>Open the mirror</h3><p>The source website/manual is cached under <code>/mirrors/</code> for offline browsing where wget could fetch it cleanly.</p><a class='button' href='{escape(game['site'])}'>Open official mirror</a></article><article class='panel'><h3>Source and licensing</h3><p>{escape(game['source'])}</p><p>Use the upstream license files and cached source/download manifests for exact attribution.</p></article></div></div></section>
    <section class='band'><div class='wrap'><div class='section-head'><h2>Should You Play?</h2><p>Plain-language notes for someone deciding what to install or launch from the LAN Arcade.</p></div><div class='grid'>{cards(game['cards'])}</div></div></section>
    <section class='band' id='downloads'><div class='wrap'><div class='section-head'><h2>Download Clients</h2><p>Installers and archives are served locally from GannanNet. The shelf includes manifests and SHA256 sums.</p></div><div class='downloads'>{downloads(game)}</div></div></section>
    <section class='band'><div class='wrap two grid'><figure>{shot_html}<figcaption>VM launch smoke screenshot. It proves a native window rendered under Xvfb; full gameplay/join proof is a separate gate.</figcaption></figure><article class='panel'><h3>Local links</h3><ul>{link_list(local_links)}</ul></article></div></section>
    <section class='band' id='manual'><div class='wrap manual'><div><h2>Quick Manual</h2><p class='panel'>Short orientation only. Use the mirrored official site/manual for deeper instructions when available.</p></div><div class='steps'>{steps(game['steps'])}</div></div></section>
    <section class='band' id='qa'><div class='wrap'><div class='section-head'><h2>Arcade QA Status</h2><p>Native entries move through cache, page smoke, VM launch, service/join, and real-device proof. HTTP 200 alone is not gameplay proof.</p></div><div class='grid'>{statuses(game['status'])}</div></div></section>
  </main>
  <footer>LAN Arcade native intake page. See <a href='ATTRIBUTION.txt'>ATTRIBUTION.txt</a> for source and license notes.</footer>
</body>
</html>
"""


def main():
    for slug, game in GAMES.items():
        target = LOCAL_GAMES / slug
        target.mkdir(parents=True, exist_ok=True)
        (target / "assets").mkdir(exist_ok=True)
        (target / "index.html").write_text(render(slug, game), encoding="utf-8")
        attribution = f"""{game['title']}

Source:
{game['source']}

LAN Arcade note:
This hub links to cached release files under /mirrors/games/downloads/native/{game['download_slug']}/ and the mirrored official site/manual at {game['site']} where available. Native gameplay is promoted only after separate smoke/play evidence.
"""
        (target / "ATTRIBUTION.txt").write_text(attribution, encoding="utf-8")


if __name__ == "__main__":
    main()
