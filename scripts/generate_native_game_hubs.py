#!/usr/bin/env python3
"""Generate native-game LAN Arcade hub pages for the next intake batch."""
from __future__ import annotations

from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCAL_GAMES = ROOT / "local-games"

COMMON_CSS = """
:root { color-scheme: dark; --bg:#101416; --panel:#1b2428; --line:#34444b; --text:#f2f7f8; --muted:#c4d1d5; --soft:#98a8ad; --accent:#74d39b; --accent2:#6db6ff; --ink:#07110c; }
* { box-sizing:border-box; }
html { scroll-behavior:smooth; }
body { margin:0; font-family:Inter, ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif; background:var(--bg); color:var(--text); }
a { color:inherit; }
.hero { min-height:78vh; position:relative; display:grid; align-items:end; overflow:hidden; border-bottom:1px solid var(--line); }
.hero::before { content:""; position:absolute; inset:0; background:linear-gradient(90deg, rgba(8,10,12,.96) 0%, rgba(8,10,12,.72) 46%, rgba(8,10,12,.22) 100%), var(--hero) center/cover no-repeat; transform:scale(1.02); }
.hero-inner { position:relative; width:min(1180px,94vw); margin:0 auto; padding:34px 0 68px; }
.eyebrow { color:var(--accent); font-size:12px; font-weight:850; text-transform:uppercase; }
h1 { margin:12px 0; max-width:920px; font-size:clamp(40px,8vw,86px); line-height:.94; letter-spacing:0; }
.lede { max-width:820px; margin:0; color:#f7fbfc; font-size:clamp(18px,2.2vw,24px); line-height:1.42; }
.quick,.nav { display:flex; flex-wrap:wrap; gap:10px; }
.quick { margin-top:22px; }
.pill { border:1px solid rgba(255,255,255,.24); background:rgba(0,0,0,.46); border-radius:8px; padding:9px 11px; font-size:13px; font-weight:850; }
.nav { margin-top:26px; }
.nav a,.button { display:inline-flex; align-items:center; justify-content:center; min-height:42px; border-radius:8px; padding:10px 13px; font-weight:850; text-decoration:none; background:var(--accent); color:var(--ink); }
.nav a.secondary,.button.secondary { background:rgba(255,255,255,.08); color:var(--text); border:1px solid rgba(255,255,255,.2); }
main { background:linear-gradient(180deg,var(--bg),#11171b); }
.band { border-bottom:1px solid rgba(255,255,255,.08); }
.wrap { width:min(1180px,94vw); margin:0 auto; padding:42px 0; }
.section-head { display:flex; justify-content:space-between; gap:24px; align-items:end; margin-bottom:18px; }
h2 { margin:0; font-size:clamp(25px,3vw,38px); letter-spacing:0; }
.section-head p { margin:0; max-width:680px; color:var(--muted); line-height:1.55; }
.grid { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:14px; min-width:0; }
.two { grid-template-columns:repeat(2,minmax(0,1fr)); }
.panel { min-width:0; overflow-wrap:anywhere; background:rgba(255,255,255,.055); border:1px solid var(--line); border-radius:8px; padding:18px; }
.panel h3 { margin:0 0 8px; color:var(--accent); font-size:18px; }
.panel p,.panel li { color:var(--muted); line-height:1.58; }
.panel p { margin:0 0 10px; }
.panel ul,.panel ol { margin:0; padding-left:21px; }
.downloads { display:grid; grid-template-columns:repeat(auto-fit,minmax(230px,1fr)); gap:14px; }
.download-card { display:grid; gap:10px; align-content:start; }
.download-card .button { justify-self:start; }
.manual { display:grid; grid-template-columns:minmax(0,.9fr) minmax(0,1.1fr); gap:18px; }
.steps { counter-reset:step; display:grid; gap:10px; }
.step { display:grid; grid-template-columns:38px minmax(0,1fr); gap:12px; }
.step::before { counter-increment:step; content:counter(step); width:32px; height:32px; border-radius:50%; display:grid; place-items:center; background:var(--accent2); color:#061019; font-weight:900; }
.step h3 { margin:2px 0 4px; color:var(--text); font-size:17px; }
.step p { margin:0; color:var(--muted); line-height:1.5; }
figure { margin:0; border:1px solid var(--line); border-radius:8px; overflow:hidden; background:#080c0e; }
figure img { display:block; width:100%; min-height:260px; object-fit:cover; }
figcaption { border-top:1px solid rgba(255,255,255,.08); padding:10px 12px; color:var(--muted); font-size:13px; }
.status strong { display:block; color:var(--text); font-size:20px; }
code { display:inline-block; max-width:100%; overflow-wrap:anywhere; white-space:normal; color:#ffe08a; background:#090d10; border:1px solid rgba(255,255,255,.1); padding:3px 6px; border-radius:5px; }
footer { width:min(1180px,94vw); margin:0 auto; padding:24px 0 36px; color:var(--soft); font-size:13px; }
@media (max-width:900px) { .hero { min-height:72vh; } .section-head { display:block; } .section-head p { margin-top:10px; } .grid,.two,.manual { grid-template-columns:minmax(0,1fr); } figure img { min-height:190px; } }
"""

GAMES = {
    "teeworlds-ddnet-lan": {
        "title": "Teeworlds / DDNet LAN Hub",
        "eyebrow": "Native action intake",
        "lede": "Fast 2D arena movement with grappling hooks, lightweight clients, and a proper LAN server path. Use DDNet for co-op race maps or vanilla Teeworlds for classic small-team shooting.",
        "facts": ["2D action", "LAN server smoke passed", "Android APK cached", "Pi-friendly candidate"],
        "download_slug": "teeworlds-ddnet",
        "source": "https://ddnet.org/downloads/ and https://github.com/teeworlds/teeworlds",
        "license": "DDNet and Teeworlds are open-source Teeworlds-family projects; see upstream repositories for exact license files.",
        "docs": [("Local DDNet downloads mirror", "../teeworlds-ddnet-docs/downloads/"), ("Offline download shelf", "../games/downloads/native/teeworlds-ddnet/")],
        "cards": [
            ("Why play", "Tiny download size, quick rounds, high skill movement, and a real dedicated server that can run briefly for LAN sessions."),
            ("What is cached", "DDNet 19.8.2 Windows, Linux, macOS, Android and source, plus Teeworlds 0.7.5 Windows, Linux, macOS and source."),
            ("What is not proven", "A full two-client join/play loop is still pending. The server only proved that it starts and listens on UDP 8303."),
        ],
        "downloads": [
            ("DDNet Windows", "../games/downloads/native/teeworlds-ddnet/latest/DDNet-19.8.2-win64.zip"),
            ("DDNet Android", "../games/downloads/native/teeworlds-ddnet/latest/DDNet-19.8.2.apk"),
            ("DDNet Linux", "../games/downloads/native/teeworlds-ddnet/latest/DDNet-19.8.2-linux_x86_64.tar.xz"),
            ("Teeworlds Windows", "../games/downloads/native/teeworlds-ddnet/latest/teeworlds-0.7.5-win64.zip"),
        ],
        "steps": [
            ("Start simple", "Open DDNet, use Play or LAN browser, and join the GannanNet server when it is running."),
            ("Movement matters", "The hook is the core skill. Practice hooking walls, pulling yourself through corners, and recovering after jumps."),
            ("Server address", "When the service is started manually, use 192.168.1.106:8303 unless the admin changes the port."),
            ("Lightweight lane", "This is one of the best candidates for Raspberry Pi or camping builds because the server and clients are small."),
        ],
        "status": [("Downloads", "Cached locally"), ("Server smoke", "Passed UDP 8303"), ("Client launch", "Passed on VM"), ("Next gate", "Two-client join/play")],
    },
    "hedgewars-lan": {
        "title": "Hedgewars LAN Hub",
        "eyebrow": "Turn-based artillery intake",
        "lede": "A Worms-like artillery game with teams, destructible terrain, weird weapons, hotseat play, and multiplayer options. It is slower and more social than the real-time action games.",
        "facts": ["Turn-based", "Hotseat friendly", "VM launch passed", "Family/casual lane"],
        "download_slug": "hedgewars",
        "source": "https://www.hedgewars.org/download.html",
        "license": "Open-source Hedgewars project; Debian package and upstream source archives are cached for inspection.",
        "docs": [("Local Hedgewars docs", "../hedgewars-docs/"), ("Offline download shelf", "../games/downloads/native/hedgewars/")],
        "cards": [
            ("Why play", "It gives the arcade a party strategy game: take turns, plan shots, laugh when the physics goes sideways, and pass the keyboard around."),
            ("What is cached", "Official Windows and macOS packages from the Hedgewars download page, plus 1.0.3 source and server-source archives."),
            ("What is not proven", "A real LAN lobby/game has not been played yet. Current proof is package install plus native client launch screenshot."),
        ],
        "downloads": [
            ("Windows installer", "../games/downloads/native/hedgewars/latest/Hedgewars-1.0.0.exe"),
            ("macOS DMG", "../games/downloads/native/hedgewars/latest/Hedgewars-1.0.0.dmg"),
            ("Source archive", "../games/downloads/native/hedgewars/latest/hedgewars-src-1.0.3.tar.bz2"),
            ("Server source", "../games/downloads/native/hedgewars/latest/hedgewars-src-server-1.0.3.tar.bz2"),
        ],
        "steps": [
            ("Create teams", "Each player needs a hedgehog team. For hotseat, create several teams on the same machine."),
            ("Pick weapons", "Bazooka, grenades, ropes, and utility tools all behave differently. Wind affects some shots."),
            ("Use terrain", "High ground, cover, and tunnel angles matter because the world is destructible."),
            ("LAN next", "The next proof should create a local multiplayer room and complete at least one turn from two clients."),
        ],
        "status": [("Downloads", "Cached locally"), ("Server smoke", "Client-hosted/pending"), ("Client launch", "Passed on VM"), ("Next gate", "Hotseat or LAN match")],
    },
    "widelands-lan": {
        "title": "Widelands LAN Hub",
        "eyebrow": "Economy RTS intake",
        "lede": "A Settlers-inspired economy strategy game about supply chains, roads, workers, buildings, resources, territory, and long-form multiplayer development.",
        "facts": ["Economy RTS", "Official 1.3.1 files cached", "VM launch passed", "Long-session game"],
        "download_slug": "widelands",
        "source": "https://github.com/widelands/widelands/releases/tag/v1.3.1",
        "license": "Open-source Widelands project; official release assets and checksums are cached locally.",
        "docs": [("Offline download shelf", "../games/downloads/native/widelands/"), ("Original release", "https://github.com/widelands/widelands/releases/tag/v1.3.1")],
        "cards": [
            ("Why play", "This is a thinking game for people who like production chains more than click speed. It should appeal to OpenTTD/RTS players."),
            ("What is cached", "All official 1.3.1 release assets listed in the cache manifest: Windows x64/x86/ARM, Linux AppImage, macOS Intel/ARM, and checksums."),
            ("Docs caveat", "The Widelands website/wiki showed an anti-bot page during intake, so this hub uses curated local notes until a cleaner mirror source is found."),
        ],
        "downloads": [
            ("Windows x64", "../games/downloads/native/widelands/latest/Widelands-1.3.1-x64.exe"),
            ("Linux AppImage", "../games/downloads/native/widelands/latest/Widelands-1.3.1-x86_64.AppImage"),
            ("macOS Intel", "../games/downloads/native/widelands/latest/Widelands-1.3.1-macOS12_x86.dmg"),
            ("macOS ARM", "../games/downloads/native/widelands/latest/Widelands-1.3.1-macOS12_arm64.dmg"),
        ],
        "steps": [
            ("Roads first", "Workers move goods along roads, so road layout and flag placement decide whether the economy breathes or clogs."),
            ("Build chains", "Wood, stone, food, tools, mines, military sites, and warehouses depend on each other."),
            ("Expand carefully", "Territory comes from military buildings, but over-expansion can starve the supply chain."),
            ("LAN next", "The next proof should host from a client, join from another client, and play until both economies produce basic goods."),
        ],
        "status": [("Downloads", "Cached locally"), ("Server smoke", "Client-hosted"), ("Client launch", "Passed on VM"), ("Next gate", "Two-client economy start")],
    },
    "warzone2100-lan": {
        "title": "Warzone 2100 LAN Hub",
        "eyebrow": "3D RTS intake",
        "lede": "A full 3D real-time strategy game with base building, research, vehicle design, artillery, campaign play, skirmish, and multiplayer hosting.",
        "facts": ["3D RTS", "Official 4.6.3 files cached", "VM launch passed", "Garage-tier candidate"],
        "download_slug": "warzone2100",
        "source": "https://wz2100.net/ and https://github.com/Warzone2100/warzone2100/releases/tag/4.6.3",
        "license": "Open-source Warzone 2100 project; official release assets are cached locally.",
        "docs": [("Local Warzone site mirror", "../warzone2100-site/"), ("Offline download shelf", "../games/downloads/native/warzone2100/")],
        "cards": [
            ("Why play", "This is a more serious RTS than the browser games: research, unit design, base defense, and skirmish pressure."),
            ("What is cached", "Windows installer/portable, macOS no-video package, Ubuntu 22.04/24.04 packages, Linux Flatpak, and source/data archive."),
            ("What is not proven", "A headless/autohost game needs saved settings and a join test. Current proof is VM native client launch."),
        ],
        "downloads": [
            ("Windows installer", "../games/downloads/native/warzone2100/latest/warzone2100_win_installer.exe"),
            ("Windows portable", "../games/downloads/native/warzone2100/latest/warzone2100_win_x64_archive.zip"),
            ("macOS no-video", "../games/downloads/native/warzone2100/latest/warzone2100_macOS_universal_novideos.zip"),
            ("Linux Flatpak", "../games/downloads/native/warzone2100/latest/warzone2100_linux_x86_64.flatpak"),
        ],
        "steps": [
            ("Start skirmish", "Learn the tech tree and vehicle design against AI before expecting a good LAN match."),
            ("Research matters", "Weapon bodies, propulsion, sensors, repair, artillery, and defenses all come from research."),
            ("Design units", "The game is about designing the right vehicles for terrain and enemy composition."),
            ("LAN next", "Create a saved autohost profile, start headless or host from client, then prove a second client can join."),
        ],
        "status": [("Downloads", "Cached locally"), ("Server smoke", "Autohost pending"), ("Client launch", "Passed on VM"), ("Next gate", "Skirmish/join proof")],
    },
    "luanti-lan": {
        "title": "Luanti LAN Hub",
        "eyebrow": "Voxel sandbox intake",
        "lede": "The open-source voxel sandbox formerly known as Minetest: host local worlds, build together, explore, survive, and eventually add carefully cached mods/games.",
        "facts": ["Voxel sandbox", "Android APKs cached", "Server smoke passed", "Family/community lane"],
        "download_slug": "luanti",
        "source": "https://www.luanti.org/en/downloads/ and https://github.com/luanti-org/luanti",
        "license": "Open-source Luanti project; official release assets are cached locally.",
        "docs": [("Local Luanti docs", "../luanti-docs/"), ("Offline download shelf", "../games/downloads/native/luanti/")],
        "cards": [
            ("Why play", "This gives the arcade a Minecraft-like local world that can run without internet and works on phones, laptops, and desktops."),
            ("What is cached", "Luanti 5.16.1 Windows installer/ZIPs, macOS builds, and Android APKs for ARM and x86 devices."),
            ("What is not proven", "A real phone/laptop join into the GannanNet world is still pending. The server only proved it starts and listens on UDP 30000."),
        ],
        "downloads": [
            ("Windows installer", "../games/downloads/native/luanti/latest/luanti-5.16.1.exe"),
            ("Windows portable", "../games/downloads/native/luanti/latest/luanti-5.16.1-win64.zip"),
            ("Android ARM64", "../games/downloads/native/luanti/latest/luanti-5.16.1-arm64-v8a.apk"),
            ("macOS ARM", "../games/downloads/native/luanti/latest/luanti_5.16.1-macos12.3_arm64.zip"),
        ],
        "steps": [
            ("Install client", "Use the local installer/APK. No internet should be needed once the files are cached here."),
            ("Start server", "Admin starts the Luanti service/world on the arcade box. Default smoke port is UDP 30000."),
            ("Join world", "In the client, use server 192.168.1.106 and port 30000 when the service is running."),
            ("Mods later", "Only add mods/games after they are cached, licensed, and tested offline as their own bundle."),
        ],
        "status": [("Downloads", "Cached locally"), ("Server smoke", "Passed UDP 30000"), ("Client launch", "Passed on VM"), ("Next gate", "Real device join")],
    },
}

def link_list(items):
    return "".join(f"<li><a href='{escape(url)}'>{escape(label)}</a></li>" for label, url in items)

def cards(items):
    return "".join(f"<article class='panel'><h3>{escape(title)}</h3><p>{escape(body)}</p></article>" for title, body in items)

def downloads(items):
    return "".join(f"<article class='panel download-card'><h3>{escape(label)}</h3><a class='button' href='{escape(url)}'>Download</a></article>" for label, url in items)

def steps(items):
    return "".join(f"<div class='step'><div><h3>{escape(title)}</h3><p>{escape(body)}</p></div></div>" for title, body in items)

def statuses(items):
    return "".join(f"<article class='panel status'><h3>{escape(label)}</h3><strong>{escape(value)}</strong></article>" for label, value in items)

def render(slug, game):
    facts = "".join(f"<span class='pill'>{escape(fact)}</span>" for fact in game['facts'])
    html = f"""<!doctype html>
<html lang='en'>
<head>
  <meta charset='utf-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1'>
  <title>{escape(game['title'])} - LAN Arcade</title>
  <style>{COMMON_CSS}</style>
</head>
<body style="--hero:url('assets/client-launch.png')">
  <header class='hero'><div class='hero-inner'>
    <div class='eyebrow'>{escape(game['eyebrow'])}</div>
    <h1>{escape(game['title'])}</h1>
    <p class='lede'>{escape(game['lede'])}</p>
    <div class='quick'>{facts}</div>
    <nav class='nav' aria-label='Page sections'><a href='#downloads'>Download Clients</a><a class='secondary' href='#manual'>Quick Manual</a><a class='secondary' href='#qa'>QA Status</a><a class='secondary' href='../games/'>Back to Arcade</a></nav>
  </div></header>
  <main>
    <section class='band'><div class='wrap'><div class='section-head'><h2>Should You Play?</h2><p>These notes are written for someone deciding what to launch from the LAN Arcade while offline.</p></div><div class='grid'>{cards(game['cards'])}</div></div></section>
    <section class='band' id='downloads'><div class='wrap'><div class='section-head'><h2>Download Clients</h2><p>Installers and archives are served from GannanNet. The download shelf includes a manifest and SHA256 checksums.</p></div><div class='downloads'>{downloads(game['downloads'])}<article class='panel download-card'><h3>All files and hashes</h3><a class='button secondary' href='../games/downloads/native/{escape(game['download_slug'])}/'>Open shelf</a></article></div></div></section>
    <section class='band'><div class='wrap two grid'><figure><img src='assets/client-launch.png' alt='{escape(game['title'])} VM launch screenshot'><figcaption>VM launch smoke screenshot captured under Xvfb. This proves the native client renders a nonblank window; it does not prove a full game session yet.</figcaption></figure><article class='panel'><h3>Local Links</h3><ul>{link_list(game['docs'])}</ul><p>Original source: {escape(game['source'])}</p></article></div></section>
    <section class='band' id='manual'><div class='wrap manual'><div><h2>Quick Manual</h2><p class='panel'>Enough to orient a new player before the deeper manual or a real playtest.</p></div><div class='steps'>{steps(game['steps'])}</div></div></section>
    <section class='band' id='qa'><div class='wrap'><div class='section-head'><h2>Arcade QA Status</h2><p>Native games are promoted in gates: cached artifacts, service smoke, client launch, join/play, then real LAN device smoke.</p></div><div class='grid'>{statuses(game['status'])}</div></div></section>
  </main>
  <footer>LAN Arcade native intake page. See <a href='ATTRIBUTION.txt'>ATTRIBUTION.txt</a> for source and license notes.</footer>
</body>
</html>
"""
    return html


def main():
    for slug, game in GAMES.items():
        target = LOCAL_GAMES / slug
        target.mkdir(parents=True, exist_ok=True)
        (target / "index.html").write_text(render(slug, game), encoding="utf-8")
        attribution = f"""{game['title']}

Source:
{game['source']}

License/source note:
{game['license']}

LAN Arcade note:
This hub links to cached release files under /mirrors/games/downloads/native/{game['download_slug']}/ and uses the VM launch-smoke screenshot in assets/client-launch.png.
"""
        (target / "ATTRIBUTION.txt").write_text(attribution, encoding="utf-8")

if __name__ == "__main__":
    main()
