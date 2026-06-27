#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv, hashlib, html, json, re, shutil, subprocess, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCAL_GAMES = ROOT / 'local-games'
REPORT_ROOT = ROOT / 'qa/reports/public-package-smoke'
DOWNLOAD_ROOT = Path('/var/www/html/mirrors/games/downloads/native')
POOL_ROOT = DOWNLOAD_ROOT / 'debian-bookworm-pool'
DEP_RE = re.compile(r'^\s*\|?\s*(?:Pre)?Depends:\s+([^<\s][A-Za-z0-9+_.:-]+)')

PUBLIC_GAMES = [
    dict(id='beneath-a-steel-sky-scummvm', download_slug='beneath-a-steel-sky', title='Beneath a Steel Sky', icon='SKY', meta='ScummVM Adventure - Cyberpunk Classic', description='Rights-clear ScummVM freeware adventure cached from Debian packages with no-internet title/intro smoke proof.', tags='Adventure,ScummVM,Freeware', categories='adventure,retro,scummvm,puzzle,age-13-plus', packages=['scummvm','scummvm-data','beneath-a-steel-sky'], source='https://www.scummvm.org/games/#games-sky', lede='A classic point-and-click cyberpunk adventure from Revolution Software, packaged for ScummVM and small enough for the lightweight side of the arcade.', steps=['Click inside the ScummVM window so keyboard and mouse input register.', 'Explore scenes with the mouse, inspect hotspots, and talk to characters.', 'Save often; adventure games can gate progress behind inventory and dialogue puzzles.']),
    dict(id='flight-amazon-queen-scummvm', download_slug='flight-amazon-queen', title='Flight of the Amazon Queen', icon='QUEEN', meta='ScummVM Adventure - Comedy Pulp', description='Rights-clear ScummVM freeware adventure cached from Debian packages; current smoke is partial because the screenshot needs stronger gameplay-state proof.', tags='Adventure,ScummVM,Freeware', categories='adventure,retro,scummvm,puzzle,age-10-plus', packages=['scummvm','scummvm-data','flight-of-the-amazon-queen'], source='https://www.scummvm.org/games/#games-queen', lede='A light comedy point-and-click adventure with a pulp serial feel, playable through ScummVM from Debian-packaged game data.', steps=['Start the wrapper, click inside the game window, and proceed past intro screens.', 'Use the mouse to inspect, talk, and combine inventory ideas.', 'Needs one more smoke that reaches a clearer playable scene before being marked smoke-pass.']),
    dict(id='lure-temptress-scummvm', download_slug='lure-of-the-temptress', title='Lure of the Temptress', icon='LURE', meta='ScummVM Adventure - Fantasy Classic', description='Rights-clear ScummVM freeware adventure with Debian-packaged data and PDF manuals; no-internet title/intro smoke passed.', tags='Adventure,ScummVM,Freeware', categories='adventure,retro,scummvm,puzzle,fantasy,age-10-plus', packages=['scummvm','scummvm-data','lure-of-the-temptress'], source='https://www.scummvm.org/games/#games-lure', lede='A fantasy point-and-click adventure from Revolution Software, useful for a slower story/puzzle lane in the offline arcade.', steps=['Use the English wrapper and click inside ScummVM.', 'Read the local manual notes; this package includes PDFs under Debian documentation.', 'Inspect rooms, talk to NPCs, and save when you make progress.']),
    dict(id='drascula-scummvm', download_slug='drascula', title='Drascula: The Vampire Strikes Back', icon='DRAC', meta='ScummVM Adventure - Comedy Horror', description='Rights-clear ScummVM freeware adventure with Debian-packaged data/music and no-internet title/intro smoke proof.', tags='Adventure,ScummVM,Freeware', categories='adventure,retro,scummvm,puzzle,age-13-plus', packages=['scummvm','scummvm-data','drascula','drascula-music'], source='https://www.scummvm.org/games/#games-drascula', lede='A comedy vampire point-and-click adventure. It adds a slightly spooky, old-PC adventure lane without private files.', steps=['Launch the English wrapper and click inside the game window.', 'Use mouse-driven adventure controls: look, use, talk, and inventory.', 'Best for older kids/adults because of the comedy horror theme.']),
    dict(id='freedink-lan', download_slug='freedink', title='GNU FreeDink / Dink Smallwood', icon='DINK', meta='Native RPG - Top-down Adventure', description='FreeDink native RPG package cache and partial no-internet menu/game-start smoke.', tags='RPG,Adventure,Native', categories='rpg,adventure,action,fantasy,age-10-plus', packages=['freedink','freedink-engine','freedink-data','freedink-dfarc'], source='https://packages.debian.org/bookworm/freedink', lede='A free engine/data release of the classic top-down action RPG Dink Smallwood.', steps=['Start the game and use keyboard movement with action/confirm keys.', 'Talk to NPCs and follow the early quest path.', 'Needs a stronger smoke showing player movement in the first area before full promotion.']),
    dict(id='naev-lan', download_slug='naev', title='Naev', icon='NAEV', meta='Native RPG - Space Trading Combat', description='Open-source space trading/combat RPG cached from Debian packages with partial no-internet launch smoke.', tags='RPG,Space,Native', categories='rpg,space,simulation,action,age-10-plus', packages=['naev','naev-data'], source='https://naev.org/', lede='A 2D space trading and combat RPG: create a pilot, fly missions, trade goods, upgrade ships, and fight pirates.', steps=['Create or load a pilot, then reach the first station or flight screen.', 'Use keyboard and mouse controls for map, comms, and travel.', 'Next proof should show a pilot in-flight or docked after new-game setup.']),
    dict(id='colobot-gold-lan', download_slug='colobot-gold', title='Colobot: Gold Edition', icon='BOT', meta='Native Strategy - Programming Education', description='Educational programming/RTS game cached from Debian packages with partial no-internet menu/tutorial smoke.', tags='Education,Programming,Strategy', categories='strategy,educational,simulation,science,age-10-plus', packages=['colobot','colobot-common','colobot-common-sounds','colobot-common-textures'], source='https://colobot.info/', lede='A game about commanding and programming bots to solve missions. Strong educational fit if the tutorial gameplay smoke passes.', steps=['Start a tutorial mission and follow the mission objective.', 'Use the interface to command bots or write simple programs.', 'Next proof should show a bot commanded or programmed in mission.']),
    dict(id='boswars-lan', download_slug='boswars', title='Bos Wars', icon='BOS', meta='Native RTS - Base Building', description='Small open-source RTS cached from Debian packages with partial no-internet menu/skirmish smoke.', tags='Strategy,RTS,Native', categories='strategy,simulation,action,age-10-plus', packages=['boswars','boswars-data'], source='https://packages.debian.org/bookworm/boswars', lede='A compact real-time strategy game with base building, resources, units, and AI skirmish potential.', steps=['Start a single-player or skirmish map with one AI.', 'Build economy first, then production and attack units.', 'Next proof should show a live skirmish with units under player control.']),
    dict(id='neverball-lan', download_slug='neverball', title='Neverball', icon='BALL', meta='Native Skill Puzzle - Marble Tilt', description='Open-source 3D skill/puzzle game cached from Debian packages with partial no-internet menu/level smoke.', tags='Puzzle,Arcade,Native', categories='puzzle,arcade,family,casual,age-10-plus', packages=['neverball','neverball-data','neverball-common'], source='https://packages.debian.org/bookworm/neverball', lede='Tilt the floor to guide a ball through coin and goal challenges. Short-session, skill-based, and family friendly.', steps=['Start the first level set.', 'Use mouse or keyboard tilt controls gently; overcorrecting is the real enemy.', 'Next proof should show movement inside a first playable level.']),
    dict(id='xmoto-lan', download_slug='xmoto', title='X-Moto', icon='XMOTO', meta='Native Arcade - Motocross Trials', description='2D motocross skill game cached from Debian packages; current screenshot smoke is weak and needs better launch parameters.', tags='Arcade,Racing,Native', categories='arcade,racing,platformer,action,age-10-plus', packages=['xmoto','xmoto-data'], source='https://packages.debian.org/bookworm/xmoto', lede='A physics motocross game about balancing, flipping, and surviving tough tracks.', steps=['Start a tutorial or first track.', 'Use accelerate, brake, and lean controls to control rotation.', 'Current smoke captured a weak blank-looking screen; retest before promotion.']),
    dict(id='frozen-bubble-lan', download_slug='frozen-bubble', title='Frozen Bubble', icon='BUB', meta='Native Puzzle - Bubble Shooter', description='Classic open-source bubble shooter cached from Debian packages with partial no-internet menu/gameplay smoke.', tags='Puzzle,Family,Native', categories='puzzle,arcade,family,casual,age-5-plus', packages=['frozen-bubble','frozen-bubble-data'], source='https://packages.debian.org/bookworm/frozen-bubble', lede='A familiar bubble-shooting puzzle game, good for casual play and local family sessions.', steps=['Aim and fire bubbles to make matching groups.', 'Use wall bounces for awkward angles.', 'Next proof should show bubbles fired in an active round.']),
    dict(id='fillets-ng-lan', download_slug='fillets-ng', title='Fish Fillets NG', icon='FISH', meta='Native Puzzle - Sokoban Logic', description='Open-source logic puzzle game cached from Debian packages with partial no-internet menu/puzzle smoke.', tags='Puzzle,Native', categories='puzzle,strategy,family,age-10-plus', packages=['fillets-ng','fillets-ng-data'], source='https://packages.debian.org/bookworm/fillets-ng', lede='A room-by-room puzzle game about moving fish through tight spaces without getting stuck.', steps=['Move the two fish carefully; different sizes matter.', 'Think several pushes ahead before moving heavy objects.', 'Next proof should show a first puzzle interaction.']),
    dict(id='enigma-lan', download_slug='enigma', title='Enigma', icon='ENIG', meta='Native Puzzle - Marble Logic', description='Large open-source puzzle collection with Debian packages and local HTML manual; partial no-internet menu/level smoke.', tags='Puzzle,Native', categories='puzzle,strategy,science,age-10-plus', packages=['enigma','enigma-data','enigma-doc'], source='https://packages.debian.org/bookworm/enigma', lede='A deep puzzle game inspired by Oxyd and similar marble/logic challenges, with lots of levels and local documentation.', steps=['Start early tutorial levels first.', 'Move carefully; many levels are about timing, switches, mirrors, and hazards.', 'The Debian package includes a substantial local HTML manual.']),
    dict(id='pushover-lan', download_slug='pushover', title='Pushover', icon='DOM', meta='Native Puzzle - Domino Logic', description='Domino puzzle game cached from Debian packages with partial no-internet menu/level smoke.', tags='Puzzle,Native', categories='puzzle,strategy,family,age-10-plus', packages=['pushover','pushover-data'], source='https://packages.debian.org/bookworm/pushover', lede='A domino chain-reaction puzzle where placement/order matters more than speed.', steps=['Study the domino setup before pushing.', 'Move, swap, and trigger dominoes so the chain reaches the goal.', 'Next proof should show a first move or solved active level.']),
    dict(id='micropolis-lan', download_slug='micropolis', title='Micropolis', icon='MIC', meta='Native City Builder - GPL SimCity', description='GPL SimCity-derived city builder cached from Debian packages with partial no-internet city-window smoke.', tags='City Builder,Simulation,Native', categories='simulation,management,city-builder,strategy,age-10-plus', packages=['micropolis','micropolis-data'], source='https://packages.debian.org/bookworm/micropolis', lede='The GPL release of the original SimCity lineage. This is the clean public-cache path for classic SimCity-style play.', steps=['Start a new city and place roads, zones, and power.', 'Watch funds and demand indicators; city builders fail slowly.', 'Next proof should show a placed tile or changed city state.']),
    dict(id='simutrans-lan', download_slug='simutrans', title='Simutrans', icon='SIMU', meta='Native Tycoon - Transport Logistics', description='Open-source transport tycoon/logistics sim cached from Debian packages with partial no-internet menu/map smoke.', tags='Tycoon,Transport,Native', categories='simulation,management,city-builder,strategy,age-10-plus', packages=['simutrans','simutrans-data','simutrans-pak64'], source='https://simutrans.net/', lede='A transport/logistics simulator about moving passengers, mail, and freight with roads, rail, schedules, and economic constraints.', steps=['Create a small map with pak64.', 'Build a first simple route, depot, vehicle, and schedule.', 'Next proof should show an actual route or vehicle running.']),

    dict(id='ri-li-lan', download_slug='ri-li', title='Ri-li', icon='RILI', meta='Native Arcade - Toy Train Puzzle', description='Toy-train arcade puzzle game cached from Debian packages with no-internet launch smoke.', tags='Arcade,Family,Native', categories='arcade,puzzle,family,casual,age-5-plus', packages=['ri-li','ri-li-data'], source='https://packages.debian.org/bookworm/ri-li', lede='A light train-routing arcade puzzle where you collect carriages while avoiding mistakes. Good for younger players and quick sessions.', steps=['Start a level and guide the train with the arrow keys.', 'Collect matching carriages while planning turns ahead.', 'Avoid trapping the train or missing the route.']),
    dict(id='chromium-bsu-lan', download_slug='chromium-bsu', title='Chromium B.S.U.', icon='CBSU', meta='Native Arcade - Vertical Shooter', description='Small open-source vertical shooter cached from Debian packages with no-internet launch smoke.', tags='Arcade,Shooter,Native', categories='arcade,action,age-10-plus', packages=['chromium-bsu','chromium-bsu-data'], source='https://packages.debian.org/bookworm/chromium-bsu', lede='A fast vertical arcade shooter with abstract sci-fi action, useful as a tiny native action entry.', steps=['Start a game from the menu.', 'Move, dodge, and fire continuously.', 'Treat it as a quick reflex game rather than a long campaign.']),
    dict(id='lbreakouthd-lan', download_slug='lbreakouthd', title='LBreakoutHD', icon='BRICK', meta='Native Arcade - Brick Breaker', description='Open-source brick-breaker game cached from Debian packages with no-internet launch smoke.', tags='Arcade,Puzzle,Native', categories='arcade,puzzle,family,casual,age-5-plus', packages=['lbreakouthd','lbreakouthd-data'], source='https://packages.debian.org/bookworm/lbreakouthd', lede='A familiar paddle-and-ball brick breaker, good for lightweight family arcade play.', steps=['Start a level from the main menu.', 'Move the paddle to keep the ball alive.', 'Clear bricks and watch for powerups.']),
    dict(id='kobodeluxe-lan', download_slug='kobodeluxe', title='Kobo Deluxe', icon='KOBO', meta='Native Arcade - Base Shooter', description='Classic open-source arcade shooter cached from Debian packages with no-internet launch smoke.', tags='Arcade,Shooter,Native', categories='arcade,action,retro,age-10-plus', packages=['kobodeluxe','kobodeluxe-data'], source='https://packages.debian.org/bookworm/kobodeluxe', lede='A retro arcade shooter where you fly, dodge, and destroy enemy bases in compact levels.', steps=['Start the first stage and learn the movement/fire controls.', 'Destroy base cores while avoiding enemy fire.', 'Short runs make it a good arcade cabinet-style entry.']),
    dict(id='scorched3d-lan', download_slug='scorched3d', title='Scorched3D', icon='SCORCH', meta='Native Artillery - Turn Strategy', description='3D turn-based artillery game cached from Debian packages with no-internet launch smoke.', tags='Strategy,Artillery,Native', categories='strategy,tactical,arcade,multiplayer,age-10-plus', packages=['scorched3d','scorched3d-data'], source='https://packages.debian.org/bookworm/scorched3d', lede='A 3D artillery game in the Scorched Earth tradition: choose weapons, aim shots, and manage money between rounds.', steps=['Start a local match before worrying about network play.', 'Adjust angle and power, fire, then react to terrain damage.', 'LAN/server claims need a separate two-client proof.']),
    dict(id='warmux-lan', download_slug='warmux', title='WarMUX', icon='WARM', meta='Native Artillery - Worms-like', description='Worms-like turn artillery game cached from Debian packages with no-internet launch smoke.', tags='Strategy,Artillery,Native', categories='strategy,tactical,arcade,multiplayer,family,age-10-plus', packages=['warmux','warmux-data'], source='https://packages.debian.org/bookworm/warmux', lede='A light Worms-like artillery game with teams, turn timing, weapons, and destructible terrain.', steps=['Start a local match against AI or another local player.', 'Move carefully, choose a weapon, and take the shot.', 'LAN mode should be tested separately before being promoted.']),
    dict(id='spacezero-lan', download_slug='spacezero', title='SpaceZero', icon='SZERO', meta='Native Strategy - 2D Space Combat', description='Small 2D space strategy/combat game cached from Debian packages with no-internet launch smoke.', tags='Space,Strategy,Native', categories='strategy,space,action,age-10-plus', packages=['spacezero'], source='https://packages.debian.org/bookworm/spacezero', lede='A compact space combat/strategy game with fleets and local/LAN potential if the UI proves approachable.', steps=['Start a local game first.', 'Learn movement and ship selection before testing multiplayer.', 'Promote LAN play only after a two-client smoke.']),
    dict(id='nethack-x11-lan', download_slug='nethack-x11', title='NetHack X11', icon='NH', meta='Native Roguelike - Classic Dungeon', description='Classic roguelike with X11 interface cached from Debian packages and no-internet launch smoke.', tags='Roguelike,RPG,Native', categories='roguelite,rpg,fantasy,strategy,age-13-plus', packages=['nethack-x11','nethack-common'], source='https://packages.debian.org/bookworm/nethack-x11', lede='The classic dungeon roguelike with deep systems, keyboard commands, permadeath, and lots of emergent trouble.', steps=['Create a character and enter the dungeon.', 'Use keyboard commands; this is not mouse-first despite the X11 package.', 'Read command help before judging it as a casual game.']),
    dict(id='opencity-lan', download_slug='opencity', title='OpenCity', icon='OCITY', meta='Native City Builder - 3D Retro', description='Small open-source 3D city builder cached from Debian packages with no-internet launch smoke.', tags='City Builder,Simulation,Native', categories='simulation,management,city-builder,strategy,age-10-plus', packages=['opencity','opencity-data'], source='https://packages.debian.org/bookworm/opencity', lede='An older 3D open-source city builder. It is lightweight, legal to cache, and worth testing for basic city-building value.', steps=['Start a city map and try roads, zones, and services.', 'Expect dated controls and graphics.', 'Keep Micropolis/OpenTTD as stronger city/transport references.']),
    dict(id='ufoai-lan', download_slug='ufoai', title='UFO: Alien Invasion', icon='UFO', meta='Native Tactical Strategy - Alien Defense', description='Large open-source tactical strategy game cached from Debian packages with no-internet launch smoke.', tags='Strategy,Tactical,Native', categories='strategy,tactical,simulation,science,age-13-plus', packages=['ufoai','ufoai-common','ufoai-data','ufoai-maps','ufoai-misc','ufoai-sound','ufoai-textures','ufoai-music'], source='https://packages.debian.org/bookworm/ufoai', lede='A squad tactics and base-management game inspired by classic X-COM: intercept aliens, manage bases, and fight tactical missions.', steps=['Start a campaign or skirmish from the local client.', 'Use geoscape/base screens to prepare, then tactical missions for combat.', 'Large install; keep it in the full GannanNet profile rather than Raspberry Pi profile.']),
]

def run(cmd, **kw): return subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, **kw)
def package_exists(pkg): return run(['apt-cache','show',pkg]).returncode == 0
def package_version(pkg):
    for line in run(['apt-cache','policy',pkg]).stdout.splitlines():
        line=line.strip()
        if line.startswith('Candidate:'): return line.split(':',1)[1].strip().replace(':','_').replace('/','_')
    return 'unknown'
def dependencies(pkg):
    out=set()
    for line in run(['apt-cache','depends',pkg]).stdout.splitlines():
        m=DEP_RE.match(line)
        if m:
            dep=m.group(1).split(':',1)[0]
            if package_exists(dep): out.add(dep)
    return out
def closure(seed):
    seen=set(); q=list(seed)
    while q:
        p=q.pop(0)
        if p in seen or not package_exists(p): continue
        seen.add(p); q.extend(d for d in sorted(dependencies(p)) if d not in seen)
    return sorted(seen)
def sha256(p):
    h=hashlib.sha256()
    with Path(p).open('rb') as f:
        for c in iter(lambda:f.read(1024*1024), b''): h.update(c)
    return h.hexdigest()
def hsize(n):
    n=float(n)
    for u in ['B','KB','MB','GB']:
        if n < 1024 or u == 'GB': return f'{n:.1f} {u}' if u != 'B' else f'{int(n)} B'
        n/=1024
def deb_for(pkg, target):
    POOL_ROOT.mkdir(parents=True, exist_ok=True)
    ex=sorted(POOL_ROOT.glob(f'{pkg}_*.deb'))
    if ex: return ex[-1]
    cached=sorted(Path('/var/cache/apt/archives').glob(f'{pkg}_*.deb'))
    if cached:
        dest=POOL_ROOT/cached[-1].name
        if not dest.exists(): shutil.copy2(cached[-1], dest)
        return dest
    subprocess.run(['apt-get','download',pkg], cwd=POOL_ROOT, check=True)
    files=sorted(POOL_ROOT.glob(f'{pkg}_*.deb'))
    if not files: raise RuntimeError(f'No .deb downloaded for {pkg}')
    return files[-1]
def cache_game(g):
    version='debian-bookworm-' + '-'.join(package_version(p) for p in g['packages'][:2])
    root=DOWNLOAD_ROOT/g['download_slug']; ver=root/version
    ver.mkdir(parents=True, exist_ok=True)
    pkgs=closure(g['packages']); assets=[]
    for pkg in pkgs:
        p=deb_for(pkg, ver); assets.append(dict(package=pkg, name=p.name, size=p.stat().st_size, sha256=sha256(p), url='../debian-bookworm-pool/' + p.name))
    (ver/'SHA256SUMS.txt').write_text(''.join(f"{a['sha256']}  {a['name']}\n" for a in assets))
    manifest=dict(title=g['title'], id=g['id'], source=g['source'], generatedAt=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), seedPackages=g['packages'], packageSet=pkgs, assets=assets)
    for p in [root/'manifest.json', ver/'manifest.json']:
        p.parent.mkdir(parents=True, exist_ok=True); p.write_text(json.dumps(manifest, indent=2)+'\n')
    cards=''.join(f"<article><h3>{html.escape(a['package'])}</h3><p>{html.escape(a['name'])} - {hsize(a['size'])}</p><a class='small' href='../debian-bookworm-pool/{html.escape(a['name'])}'>Download this file</a></article>" for a in assets[:160])
    game_url = f'../../../../{g["id"]}/'
    total_size = hsize(sum(a['size'] for a in assets))
    page=f"""<!doctype html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>{html.escape(g['title'])} Offline Downloads</title><style>:root{{color-scheme:dark;--bg:#101316;--panel:#171f25;--line:#33424b;--text:#f4f8f8;--muted:#c4d0d4;--accent:#72d39b;--ink:#06110d}}*{{box-sizing:border-box}}body{{margin:0;font-family:system-ui,-apple-system,Segoe UI,sans-serif;background:var(--bg);color:var(--text)}}main{{width:min(1100px,94vw);margin:auto;padding:30px 0 48px}}a{{color:#9ee6b4}}.button{{display:inline-flex;margin:6px 8px 6px 0;padding:10px 12px;border-radius:8px;background:var(--accent);color:var(--ink);font-weight:850;text-decoration:none}}.secondary{{background:#22303a;color:var(--text)}}.panel,article{{border:1px solid var(--line);border-radius:8px;background:var(--panel);padding:16px;margin:12px 0}}p,li{{color:var(--muted);line-height:1.5}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:12px}}summary{{cursor:pointer;font-weight:850;font-size:18px;margin:8px 0}}code{{background:#090d10;border:1px solid rgba(255,255,255,.12);border-radius:5px;padding:2px 5px}}.small{{font-size:14px}}</style></head><body><main><p><a class='button secondary' href='../../../'>Back to Game Library</a> <a class='button secondary' href='{html.escape(game_url)}'>Back to game page</a></p><h1>{html.escape(g['title'])} Offline Downloads</h1><section class='panel'><h2>For players</h2><p>Use the game page first. It explains what the game is and how to start it. This page keeps the Linux offline install files for computers that need them.</p><p><a class='button' href='{html.escape(game_url)}'>Open game page</a></p></section><section class='panel'><h2>Linux offline install</h2><p>This download set contains {len(assets)} Debian package files, about {total_size}. On a matching Debian 12 computer, download or copy this version folder, then install from that folder:</p><p><code>sudo apt install ./*.deb</code></p><p><a class='button secondary' href='manifest.json'>File details</a> <a class='button secondary' href='{html.escape(version)}/SHA256SUMS.txt'>Checksums</a></p></section><details class='panel'><summary>Advanced file list</summary><p>Most players do not need to choose individual files. These are the package pieces that make the offline install possible.</p><section class='grid'>{cards}</section></details></main></body></html>"""
    root.mkdir(parents=True, exist_ok=True); (root/'index.html').write_text(page)
    latest=root/'latest'
    if latest.exists() or latest.is_symlink(): latest.unlink() if latest.is_symlink() or latest.is_file() else shutil.rmtree(latest)
    latest.symlink_to(ver.name, target_is_directory=True)
    print('CACHE_READY', g['id'], len(assets), hsize(sum(a['size'] for a in assets)))
def latest_report(game_id):
    reports=sorted(REPORT_ROOT.glob(f'{game_id}-*/report.txt'))
    if not reports: return None, {}
    vals={}
    for line in reports[-1].read_text(errors='ignore').splitlines():
        if '=' in line:
            k,v=line.split('=',1); vals[k]=v
    return reports[-1].parent, vals
def package_docs(g):
    found=[]; pdf=[]
    for pkg in g['packages']:
        d=Path('/usr/share/doc')/pkg
        if not d.exists(): continue
        for p in d.rglob('*'):
            if p.is_file() and p.suffix.lower() in {'.pdf','.html','.txt','.gz'}:
                found.append(str(p))
                if p.suffix.lower()=='.pdf':
                    pages='?'; info=run(['pdfinfo',str(p)]).stdout if shutil.which('pdfinfo') else ''
                    for line in info.splitlines():
                        if line.startswith('Pages:'): pages=line.split(':',1)[1].strip()
                    pdf.append(f'{p.name} ({pages} pages)')
    return found[:30], pdf
def render(g):
    target=LOCAL_GAMES/g['id']; assets=target/'assets'; assets.mkdir(parents=True, exist_ok=True)
    rdir, vals=latest_report(g['id']); status=vals.get('STATUS','untested').lower(); detail=vals.get('DETAIL','No smoke report found yet.')
    if rdir and (rdir/'02-after-input.png').exists(): shutil.copy2(rdir/'02-after-input.png', assets/'play-smoke.png')
    docs,pdfs=package_docs(g)
    docs_html=''.join(f'<li>{html.escape(x)}</li>' for x in docs[:16]) or '<li>No package docs found beyond Debian metadata.</li>'
    pdf_html=''.join(f'<li>{html.escape(x)}</li>' for x in pdfs) or '<li>No package PDF manuals found.</li>'
    steps=''.join(f'<li>{html.escape(s)}</li>' for s in g['steps'])
    img="<img src='assets/play-smoke.png' alt='QA screenshot'>" if (assets/'play-smoke.png').exists() else '<div class=placeholder>QA</div>'
    pkgset=', '.join(g['packages']); dl=f'../games/downloads/native/{html.escape(g["download_slug"])}/'
    page=f"""<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>{html.escape(g['title'])} - LAN Arcade</title><style>:root{{color-scheme:dark;--bg:#101316;--panel:#171f25;--line:#33424b;--text:#f4f8f8;--muted:#c4d0d4;--accent:#72d39b;--warn:#f0bf5a;--bad:#ff746d}}*{{box-sizing:border-box}}body{{margin:0;font-family:system-ui,-apple-system,Segoe UI,sans-serif;background:var(--bg);color:var(--text)}}main,header{{width:min(1180px,94vw);margin:auto}}header{{padding:34px 0 22px}}h1{{font-size:clamp(34px,6vw,72px);margin:0 0 10px}}p,li{{color:var(--muted);line-height:1.55}}.grid{{display:grid;grid-template-columns:1.05fr .95fr;gap:18px}}.panel{{border:1px solid var(--line);border-radius:8px;background:var(--panel);padding:18px;margin:0 0 16px}}.hero-img{{border:1px solid var(--line);border-radius:8px;overflow:hidden;background:#06090b}}img{{width:100%;display:block}}.placeholder{{min-height:300px;display:grid;place-items:center;font-size:54px;font-weight:900;color:#445563}}a.button{{display:inline-flex;margin:6px 8px 6px 0;padding:10px 13px;border-radius:8px;background:var(--accent);color:#07120d;text-decoration:none;font-weight:850}}.secondary{{background:#24313a!important;color:var(--text)!important}}.status-pass{{color:var(--accent)}}.status-partial{{color:var(--warn)}}.status-blocked{{color:var(--bad)}}code{{background:#090d10;border:1px solid #2b3740;border-radius:5px;padding:2px 5px;color:#ffe08a}}@media(max-width:900px){{.grid{{grid-template-columns:1fr}}}}</style></head><body><header><p><a class='button secondary' href='../games/'>Back to Arcade</a></p><h1>{html.escape(g['title'])}</h1><p>{html.escape(g['lede'])}</p><p><strong>{html.escape(g['meta'])}</strong> - {html.escape(g['tags'])}</p></header><main class='grid'><section><div class='hero-img'>{img}</div><article class='panel'><h2>QA Status</h2><p class='status-{html.escape(status)}'><strong>{html.escape(status.upper())}</strong></p><p>{html.escape(detail)}</p><p>Latest report: <code>{html.escape(str(rdir.relative_to(ROOT)) if rdir else 'not run')}</code></p></article><article class='panel'><h2>Offline Downloads</h2><p>Cached from Debian packages onto the NFS-backed native shelf. Seed packages: <code>{html.escape(pkgset)}</code>.</p><a class='button' href='{dl}'>Open package shelf</a></article></section><section><article class='panel'><h2>What It Is</h2><p>{html.escape(g['description'])}</p><p>Source: <a href='{html.escape(g['source'])}'>{html.escape(g['source'])}</a></p></article><article class='panel'><h2>Quick Manual</h2><ol>{steps}</ol></article><article class='panel'><h2>Manual / PDF Check</h2><p>Package docs were inspected on the VM. PDF manuals are checked with Poppler when present.</p><h3>PDFs</h3><ul>{pdf_html}</ul><h3>Local docs seen</h3><ul>{docs_html}</ul></article></section></main></body></html>"""
    target.mkdir(parents=True, exist_ok=True); (target/'index.html').write_text(page); (target/'ATTRIBUTION.txt').write_text(f"{g['title']}\nSource: {g['source']}\nPackages: {pkgset}\nQA: {status} - {detail}\n")
    print('HUB_READY', g['id'], status)
def update_candidates():
    path=ROOT/'game-intake/candidates.csv'
    if not path.exists(): return
    rows=list(csv.DictReader(path.open(newline=''))); by={g['id']:g for g in PUBLIC_GAMES}
    for row in rows:
        if row.get('id') not in by: continue
        _, vals=latest_report(row['id']); st=vals.get('STATUS','').lower()
        row['download_status']='download-cached'; row['intake_status']='smoke-pass' if st=='pass' else ('partial' if st=='partial' else row.get('intake_status','hub-draft'))
        addition=f"2026-06-20 promoted to public package hub; latest smoke {st or 'not-run'}: {vals.get('DETAIL','')}"
        notes=row.get('notes','').strip()
        if addition not in notes:
            row['notes']=(notes + ' ' + addition).strip()
    with path.open('w', newline='') as f:
        w=csv.DictWriter(f, fieldnames=rows[0].keys(), quoting=csv.QUOTE_ALL); w.writeheader(); w.writerows(rows)
def write_summary():
    lines=['# Public Package Intake - 2026-06-20','', 'Batch promoted from packageable/license-clear intake rows. Large package files are cached on the NFS native shelf, not Git.','']
    for g in PUBLIC_GAMES:
        _, vals=latest_report(g['id']); lines.append(f"- `{g['id']}`: {vals.get('STATUS','UNTESTED')} - {vals.get('DETAIL','No report')}")
    (ROOT/'docs/PUBLIC_PACKAGE_INTAKE_2026-06-20.md').write_text('\n'.join(lines)+'\n')
def main():
    ap=argparse.ArgumentParser(); ap.add_argument('action', choices=['cache','generate','all','candidates'], nargs='?', default='all'); args=ap.parse_args()
    if args.action in {'cache','all'}:
        for g in PUBLIC_GAMES: cache_game(g)
    if args.action in {'generate','all'}:
        for g in PUBLIC_GAMES: render(g)
        update_candidates(); write_summary()
    if args.action=='candidates': update_candidates(); write_summary()
if __name__ == '__main__': main()
