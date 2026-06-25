#!/usr/bin/env python3
"""Build the VM-local classic PC games shelf.

No game data lives in Git. This reads Dylan's private NFS intake shelf and
writes generated packages/pages under /var/www/html/mirrors/private-dos-vault.
"""
from pathlib import Path
import argparse, csv, hashlib, html, json, shutil, tempfile, time, zipfile

ROOT = Path(__file__).resolve().parents[1]
SRC = Path('/srv/lan-arcade/native-downloads/intake/private-tycoon')
DEST = Path('/var/www/html/mirrors/private-dos-vault')
REPORTS = ROOT / 'qa/reports/private-tycoon'

GAMES = [
    dict(id='simcity-classic-dos-ma', title='SimCity Classic DOS', status='smoke-pass', genre='city builder', cmd='SIMCITY.EXE', root='work/start-dosroot-*', manuals=['raw/*Manual*.pdf'], source='https://www.myabandonware.com/game/simcity-ri', qa='simcity-classic-dos-ma-20260619T101919Z', summary='Started a new city, placed residential zoning, and funds changed to $19,900.'),
    dict(id='sim-farm-dos-ma', title='SimFarm', status='partial', genre='farm management', cmd='SIMFARM.EXE', root='work/start-dosroot-*', manuals=['raw/*Manual*.pdf'], source='https://www.myabandonware.com/game/sim-farm-204', qa='sim-farm-dos-ma-20260619T102116Z', summary='Reached title, region selection, and farm map; still needs a proven plant/build action.'),
    dict(id='railroad-tycoon-deluxe-dos-ma', title="Sid Meier's Railroad Tycoon Deluxe", status='partial', genre='railroad management', cmd='RRT.EXE', root='work/rrt-direct-*', manuals=['raw/*Manual*.pdf','work/rrt-direct-*/rtdeluxe.pdf'], source='https://www.myabandonware.com/game/sid-meier-s-railroad-tycoon-deluxe-22z', qa='railroad-tycoon-deluxe-dos-ma-20260619T102332Z', summary='Reached title and period/region selection; still needs a first track/station/train action.'),
    dict(id='firestorm-review', title='Firestorm: The Forest Fire Simulation Program', status='partial', genre='firefighting simulation', cmd='FSSW2K.EXE', root='zip:raw/Firestorm-The-Forest-Fire-Simulation-Program_DOS_EN.zip:firestor', manuals=[], package_text=['MANUAL.TXT','README.TXT'], source='https://www.myabandonware.com/game/firestorm-the-forest-fire-simulation-program-30g', qa='firestorm-review-20260619T100125Z', summary='Reached title/shareware screens; still needs a proven firefighting action.'),
    dict(id='a-train-dos-ma', title='A-Train', status='blocked', genre='railroad/business simulation', source='https://www.myabandonware.com/game/a-train-1bn', qa='a-train-dos-ma-20260619T101622Z', summary='Flattened launch invoked AT.EXE but did not reach a visible game screen.'),
    dict(id='black-gold-dos-ma', title='Black Gold / Oil Imperium', status='blocked', genre='oil/business management', source='https://www.myabandonware.com/game/black-gold-lu', qa='black-gold-dos-ma-20260619T101711Z', summary='Launch reaches ownership/code-card verification and stops; codes are not exposed.'),
]

SWEEP_FILES = [
    ROOT / 'game-intake/classic-downloadability-sweep-2026-06-19.csv',
    ROOT / 'game-intake/tycoon-downloadability-sweep-2026-06-19.csv',
]
DOS_RUNTIME_MARKERS = ('dosbox', 'emulatorjs', 'win3x')
STATUS_KEYS = ['smoke-pass', 'source-ready', 'partial', 'blocked', 'candidate']
STATUS_LABELS = {
    'smoke-pass': 'Play-tested',
    'source-ready': 'Ready to try',
    'partial': 'Partly tested',
    'blocked': 'Not ready',
    'candidate': 'Planned game',
}

PACKAGE_CONFIGS = {
    'a-train-dos-ma': dict(cmd='AT.EXE', root='work/start-dosroot-*', status='source-ready'),
    'black-gold-dos-ma': dict(cmd='BLKGOLD.EXE', root='work/start-dosroot-*', status='source-ready'),
    'incredible-machine-1-ma': dict(cmd='TIM.EXE', root='work/start-dosroot-*', status='source-ready'),
    'oregon-trail-deluxe-ma': dict(cmd='OREGON.EXE', root='work/start-dosroot-*', status='source-ready'),
    'prince-of-persia-ma': dict(cmd='PRINCE.EXE', root='work/start-dosroot-*', status='source-ready'),
    'lemmings-ma': dict(cmd='LEMMINGS.BAT', root='work/start-dosroot-*', status='source-ready'),
    'dune-ii-ma': dict(cmd='DUNE2.EXE', root='work/start-dosroot-*', status='source-ready'),
    'simant-ma': dict(cmd='SIMANT.EXE', root='work/start-dosroot-*', status='source-ready'),
    'rogue-ma': dict(cmd='ROGUE.EXE', root='work/start-dosroot-*', status='source-ready'),
    'gta-london-1961-ma': dict(cmd='LONDON61.BAT', root='work/start-dosroot-*', status='source-ready'),
    'railroad-tycoon-dos-ma': dict(cmd='RAILS.BAT', root='work/start-dosroot-*', status='source-ready'),
    'railroad-empire-dos-ma': dict(status='blocked'),
}

def sha(path):
    h = hashlib.sha256()
    with open(path,'rb') as f:
        for chunk in iter(lambda:f.read(1024*1024), b''):
            h.update(chunk)
    return h.hexdigest()

def safe(dest):
    dest = dest.resolve(); allowed = DEST.resolve()
    if dest != allowed and allowed not in dest.parents:
        raise SystemExit(f'refusing destination outside DOS vault: {dest}')

def rows():
    p = ROOT / 'game-intake/candidates.csv'
    if not p.exists(): return {}
    with p.open(newline='', encoding='utf-8') as f:
        return {r.get('id',''): r for r in csv.DictReader(f)}

def genre_from_lane(lane):
    lane = (lane or '').replace('private-classic-', '').replace('private-', '')
    return lane.replace('-', ' ') or 'DOS classic'

def short_summary(row):
    bits = [row.get('next_action', ''), row.get('notes', ''), row.get('download_evidence', '')]
    text = ' '.join(b.strip() for b in bits if b and b.strip())
    if not text:
        return 'Planned game found in the approved intake sweep; game package is not cached on the VM yet.'
    return 'Planned game only: ' + text[:260].rstrip()

def load_sweep_candidates():
    existing = {g['id'] for g in GAMES}
    seen = set(existing)
    out = []
    for path in SWEEP_FILES:
        if not path.exists():
            continue
        with path.open(newline='', encoding='utf-8') as f:
            for row in csv.DictReader(f):
                game_id = row.get('game_id') or row.get('id') or row.get('candidate_id')
                runtime = row.get('runtime_hypothesis', '')
                if not game_id or game_id in seen:
                    continue
                if not any(marker in runtime.lower() for marker in DOS_RUNTIME_MARKERS):
                    continue
                seen.add(game_id)
                out.append(dict(
                    id=game_id,
                    title=row.get('title') or game_id,
                    status='candidate',
                    genre=genre_from_lane(row.get('lane', '')),
                    source=row.get('source_url', ''),
                    runtime=runtime or 'DOSBox/EmulatorJS candidate',
                    availability=row.get('availability_status', ''),
                    evidence=row.get('download_evidence', ''),
                    summary=short_summary(row),
                    controls=['Game package is not cached yet', 'No gameplay smoke has been run for this candidate'],
                ))
    return out

def all_games():
    out = []
    for game in GAMES + load_sweep_candidates():
        merged = dict(game)
        if merged['id'] in PACKAGE_CONFIGS:
            merged.update(PACKAGE_CONFIGS[merged['id']])
        out.append(merged)
    return out

def cp_contents(src, dst):
    for item in src.iterdir():
        target = dst / item.name
        if item.is_dir(): shutil.copytree(item, target, dirs_exist_ok=True)
        else: shutil.copy2(item, target)

def latest(base, pattern):
    hits = sorted(base.glob(pattern), key=lambda p:(p.stat().st_mtime, str(p)))
    return hits[-1] if hits else None

def source_problem(game):
    if 'cmd' not in game:
        return None
    base = SRC / game['id']
    if not base.exists():
        return f'{game["id"]}: missing source directory {base}'
    srcspec = game['root']
    if srcspec.startswith('zip:'):
        _, raw, _sub = srcspec.split(':', 2)
        archive = base / raw
        if not archive.exists():
            return f'{game["id"]}: missing archive {archive}'
        return None
    if not latest(base, srcspec):
        return f'{game["id"]}: no source matching {base / srcspec}'
    return None

def preflight_sources(games=None):
    return [problem for problem in (source_problem(g) for g in (games or GAMES)) if problem]

def stage_game(game, stage):
    if 'cmd' not in game: return None
    base = SRC / game['id']
    if not base.exists(): return None
    root = stage / game['id'] / 'dosroot'; root.mkdir(parents=True)
    srcspec = game['root']
    if srcspec.startswith('zip:'):
        _, raw, sub = srcspec.split(':', 2)
        archive = base / raw
        if not archive.exists(): return None
        ex = stage / game['id'] / 'extract'
        with zipfile.ZipFile(archive) as z: z.extractall(ex)
        src = ex / sub
        if not src.exists(): src = ex
    else:
        src = latest(base, srcspec)
        if not src: return None
    cp_contents(src, root)
    (root/'PLAY.BAT').write_text('@echo off\r\n' + game['cmd'] + '\r\n', encoding='ascii')
    conf_lines = ['[sdl]', 'autolock=false', '[dosbox]', 'machine=svga_s3', 'memsize=32', '[render]', 'aspect=true', '[cpu]', 'core=auto', 'cycles=auto', '[autoexec]', '@echo off', 'mount c .', 'c:', 'PLAY.BAT']
    (root/'dosbox.conf').write_text('\r\n'.join(conf_lines) + '\r\n', encoding='ascii')
    return root

def zip_root(root, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as z:
        for p in sorted(root.rglob('*')):
            if p.is_file(): z.write(p, p.relative_to(root).as_posix())

def copy_docs(game, root, dest):
    out=[]; d=dest/'manuals'/game['id']; d.mkdir(parents=True, exist_ok=True)
    base=SRC/game['id']; seen=set()
    for pat in game.get('manuals', []):
        for src in sorted(base.glob(pat)):
            if not src.is_file() or src.resolve() in seen: continue
            seen.add(src.resolve()); target=d/src.name; shutil.copy2(src,target)
            out.append(dict(name=src.name, url=f'manuals/{game["id"]}/{src.name}', sha256=sha(target)))
    if root:
        for name in game.get('package_text', []):
            src=root/name
            if src.exists():
                target=d/name; shutil.copy2(src,target)
                out.append(dict(name=name, url=f'manuals/{game["id"]}/{name}', sha256=sha(target)))
    return out

def copy_shots(game, dest):
    src = REPORTS / game.get('qa','')
    if not src.exists(): return []
    d = dest/'screenshots'/game['id']; d.mkdir(parents=True, exist_ok=True)
    out=[]
    for p in sorted(src.glob('*.png'))[:5]:
        target=d/p.name; shutil.copy2(p,target)
        out.append(dict(name=p.name, url=f'screenshots/{game["id"]}/{p.name}'))
    return out

def build(dest):
    cand=rows(); out=[]
    with tempfile.TemporaryDirectory(prefix='dos-vault-') as tmp:
        stage=Path(tmp)
        for g in all_games():
            row=cand.get(g['id'], {})
            report = f'qa/reports/private-tycoon/{g.get("qa","")}/REPORT.md' if g.get('qa') else ''
            status = row.get('intake_status') or g.get('status', 'candidate')
            if status == 'restore-needed' and g.get('status'):
                status = g['status']
            root=stage_game(g, stage)
            if root and status == 'candidate':
                status = 'source-ready'
            entry=dict(id=g['id'], title=g['title'], platform='DOS', genre=row.get('genre') or g.get('genre', 'DOS classic'), status=status, sourceUrl=row.get('source_url') or g.get('source',''), summary=g.get('summary', 'Planned game found in intake; game package is not cached yet.'), qaReport=report, controls=g.get('controls') or ['Click inside the emulator first', 'If a DOSBox menu appears, choose PLAY.BAT'], manuals=[], screenshots=[], packageUrl='', packageSha256='', packageBytes=0, browserCore='dosbox_pure' if 'cmd' in g else '', runtime=g.get('runtime','DOSBox'), availability=g.get('availability',''), downloadEvidence=g.get('evidence',''), sourceState='source-missing')
            if root:
                target=dest/'packages'/f'{g["id"]}.zip'; zip_root(root,target)
                entry.update(packageUrl=f'packages/{target.name}', packageSha256=sha(target), packageBytes=target.stat().st_size, sourceState='packaged')
            entry['manuals']=copy_docs(g, root, dest)
            entry['screenshots']=copy_shots(g, dest)
            out.append(entry)
    return out

def label(status):
    return STATUS_LABELS.get(status, status)

def write_index(dest, games):
    cards=[]
    for g in games:
        shot = g['screenshots'][0]['url'] if g['screenshots'] else ''
        media = f'<img src="{html.escape(shot)}" alt="{html.escape(g["title"])} screenshot">' if shot else '<div class="placeholder">DOS</div>'
        play = f'<a class="primary" href="play.html?id={html.escape(g["id"])}">Play</a>' if g['packageUrl'] else '<span class="disabled">Game files needed</span>'
        source = f'<a href="{html.escape(g["sourceUrl"])}">Game page</a>' if g.get('sourceUrl') else ''
        manuals = ''.join(f'<a href="{html.escape(m["url"])}">{html.escape(m["name"])} </a>' for m in g['manuals']) or '<span>No manual cached yet</span>'
        text = html.escape((g['title']+' '+g['genre']+' '+g['summary']+' '+g.get('runtime','')).lower())
        cards.append(f'''<article class="card" data-status="{html.escape(g["status"])}" data-text="{text}">
<div class="media">{media}<b class="{html.escape(g["status"])}">{label(g["status"])}</b></div>
<h2>{html.escape(g["title"])}</h2>
<p class="meta">DOS - {html.escape(g["genre"])} - {html.escape(g.get("runtime") or "candidate")}</p>
<p>{html.escape(g["summary"])}</p>
<div class="actions">{play}{source}</div>
<div class="manuals">{manuals}</div>
</article>''')
    stats = {k:sum(1 for g in games if g['status']==k) for k in STATUS_KEYS}
    packaged = sum(1 for g in games if g.get('packageUrl'))
    page = f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta http-equiv="Cache-Control" content="no-store, max-age=0"><meta http-equiv="Pragma" content="no-cache"><meta http-equiv="Expires" content="0"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Classic PC Games</title><style>
:root{{color-scheme:dark;--bg:#080d12;--panel:#121922;--line:#314357;--text:#eef6ff;--muted:#a8b8cc;--green:#35d07f;--amber:#ffca55;--red:#ff7468}}*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--text);font-family:system-ui,-apple-system,Segoe UI,sans-serif}}main{{width:min(1220px,94vw);margin:auto;padding:24px 0 44px}}.top{{display:flex;justify-content:space-between;gap:12px;align-items:start}}h1{{font-size:clamp(30px,5vw,56px);margin:0}}p{{color:var(--muted);line-height:1.45}}a,.disabled,button{{border:1px solid var(--line);border-radius:7px;background:#182230;color:var(--text);text-decoration:none;font-weight:800;padding:8px 10px;display:inline-flex;align-items:center;min-height:38px}}.primary,button.active{{background:#1d7d4e;border-color:#35d07f}}.disabled{{opacity:.62}}.notice{{border-left:4px solid var(--amber);background:#18150b;border-radius:7px;padding:11px 12px;color:#f2ddb7;margin:14px 0}}.stats{{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin:12px 0}}.stat,.card{{border:1px solid var(--line);background:var(--panel);border-radius:8px}}.stat{{padding:12px}}.stat strong{{display:block;font-size:26px}}.toolbar{{display:grid;grid-template-columns:1fr auto;gap:10px;margin:14px 0}}input{{background:#0e151f;color:var(--text);border:1px solid var(--line);border-radius:7px;padding:11px;font:inherit}}.filters{{display:flex;gap:8px;flex-wrap:wrap}}.grid{{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}}.card{{overflow:hidden;padding:0 14px 14px}}.media{{position:relative;aspect-ratio:16/9;background:#05080c;margin:0 -14px 12px;display:grid;place-items:center}}.media img{{width:100%;height:100%;object-fit:cover}}.placeholder{{font-size:42px;color:#304457;font-weight:900}}.media b{{position:absolute;top:10px;left:10px;border-radius:999px;padding:6px 10px;background:#233145}}.media b.smoke-pass{{background:#11351f;color:#b9ffd2}}.media b.source-ready{{background:#123652;color:#c8ecff}}.media b.partial{{background:#37290c;color:#ffe0a1}}.media b.blocked{{background:#3b1414;color:#ffd0cc}}.media b.candidate{{background:#1b2d43;color:#c7ddff}}h2{{font-size:20px;margin:0}}.meta{{text-transform:uppercase;font-size:12px;letter-spacing:.08em}}.actions,.manuals{{display:flex;gap:8px;flex-wrap:wrap;margin-top:10px}}.manuals{{border-top:1px solid var(--line);padding-top:10px}}.manuals a,.manuals span{{font-size:13px}}@media(max-width:900px){{.grid{{grid-template-columns:repeat(2,1fr)}}.stats{{grid-template-columns:repeat(2,1fr)}}}}@media(max-width:650px){{main{{width:96vw}}.top,.toolbar{{display:block}}.top a{{width:100%;justify-content:center;margin-top:10px}}.grid{{grid-template-columns:1fr}}.filters{{margin-top:8px}}}}
</style></head><body><main><div class="top"><div><h1>Classic PC Games</h1><p>Old computer games from the DOS era run here through DOSBox in the browser. If a game says Game files needed, the arcade has notes or screenshots but not the local ZIP/package yet.</p></div><a href="../games/">Back to Arcade</a></div><div class="notice">Games with Play now are ready in the browser. Games marked Game files needed are waiting for a local copy of the game files before they can be launched offline.</div><section class="stats"><div class="stat"><strong>{len(games)}</strong><span>games listed</span></div><div class="stat"><strong>{packaged}</strong><span>playable here</span></div><div class="stat"><strong>{stats['source-ready']}</strong><span>ready to try</span></div><div class="stat"><strong>{stats['candidate']}</strong><span>planned games</span></div></section><section class="toolbar"><input id="q" type="search" placeholder="Search old PC games"><div class="filters"><button class="active" data-f="all">All</button><button data-f="smoke-pass">Play-tested</button><button data-f="source-ready">Ready to try</button><button data-f="partial">Partly tested</button><button data-f="blocked">Not ready</button><button data-f="candidate">Planned game</button></div></section><section class="grid">{''.join(cards)}</section></main><script>
const q=document.querySelector('#q'),cards=[...document.querySelectorAll('.card')],buttons=[...document.querySelectorAll('button')];let f='all';function draw(){{const s=q.value.toLowerCase().trim();for(const c of cards)c.hidden=!((f==='all'||c.dataset.status===f)&&(!s||c.dataset.text.includes(s)))}}q.oninput=draw;buttons.forEach(b=>b.onclick=()=>{{f=b.dataset.f;buttons.forEach(x=>x.classList.toggle('active',x===b));draw()}});
</script></body></html>'''
    (dest/'index.html').write_text(page, encoding='utf-8')

def write_play(dest):
    page='''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta http-equiv="Cache-Control" content="no-store, max-age=0"><meta http-equiv="Pragma" content="no-cache"><meta http-equiv="Expires" content="0"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Classic PC Game Player</title><style>
:root{color-scheme:dark;--bg:#070b10;--panel:#121922;--line:#314357;--text:#eef6ff;--muted:#a8b8cc;--amber:#ffca55}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font-family:system-ui,-apple-system,Segoe UI,sans-serif}main{width:min(1280px,96vw);margin:auto;padding:16px 0 28px}.top{display:flex;justify-content:space-between;gap:12px}.layout{display:grid;grid-template-columns:1fr 310px;gap:14px}.player{background:#020609;border:1px solid var(--line);border-radius:8px;overflow:hidden}#game{height:min(74vh,720px);min-height:430px}.panel{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:14px}a{color:var(--text);background:#182230;border:1px solid var(--line);border-radius:7px;padding:9px 11px;text-decoration:none;font-weight:850;display:inline-flex;margin:4px}.warn{border-left:4px solid var(--amber);background:#18150b;border-radius:7px;padding:10px;color:#f2ddb7}.key{border:1px solid var(--line);border-radius:7px;padding:8px;margin:6px 0;background:#0e151f}p{color:var(--muted);line-height:1.45}@media(max-width:900px){main{width:96vw}.layout{grid-template-columns:1fr}#game{height:62vh;min-height:340px}.top{display:block}.top a{width:100%;justify-content:center}}
</style></head><body><main><div class="top"><div><h1 id="title">Classic PC Game Player</h1><p id="meta"></p></div><a href="./">Back to Classic PC Games</a></div><div class="layout"><section class="player"><div id="game"></div></section><aside class="panel"><p id="summary"></p><div class="warn">Click inside the emulator first. If a DOSBox menu appears, choose PLAY.BAT.</div><h2>Controls</h2><div id="controls"></div><h2>Offline Files</h2><div id="files"></div><h2>Browser Check</h2><p id="browser"></p></aside></div></main><script>
function esc(v){const s=document.createElement('span');s.textContent=v||'';return s.innerHTML}async function boot(){const id=new URLSearchParams(location.search).get('id');const m=await fetch('manifest.json',{cache:'no-store'}).then(r=>r.json());const g=m.games.find(x=>x.id===id)||m.games[0];document.title=g.title+' - Classic PC Game Player';title.textContent=g.title;meta.textContent=g.platform+' - '+g.genre+' - '+g.status;summary.textContent=g.summary;controls.innerHTML=(g.controls||[]).map(c=>'<div class="key">'+esc(c)+'</div>').join('');let links=[];if(g.packageUrl)links.push('<a href="'+esc(g.packageUrl)+'">Download package</a>');for(const man of g.manuals||[])links.push('<a href="'+esc(man.url)+'">'+esc(man.name)+'</a>');if(g.sourceUrl)links.push('<a href="'+esc(g.sourceUrl)+'">Game page</a>');files.innerHTML=links.join('');browser.textContent=window.crossOriginIsolated?'Cross-origin isolation is active.':'Cross-origin isolation is not active. If the threaded core fails, use the package download with local DOSBox.';if(!g.packageUrl){game.innerHTML='<p style="padding:20px">This game needs local files before it can be played here.</p>';return}window.EJS_player='#game';window.EJS_core='dosbox_pure';window.EJS_gameUrl=g.packageUrl;window.EJS_gameName=g.title;window.EJS_pathtodata='../emulatorjs-runtime/4.2.3/data/';window.EJS_startOnLoaded=true;window.EJS_threads=true;const s=document.createElement('script');s.src='../emulatorjs-runtime/4.2.3/data/loader.js';document.body.appendChild(s)}boot().catch(e=>{game.innerHTML='<pre style="white-space:pre-wrap;padding:20px;color:#ffb4ae">'+esc(e.stack||e.message||String(e))+'</pre>'})
</script></body></html>'''
    (dest/'play.html').write_text(page, encoding='utf-8')

def publish(staged, dest):
    backup = dest.parent / f'.{dest.name}.previous-{int(time.time())}'
    if dest.exists():
        dest.rename(backup)
    try:
        staged.rename(dest)
    except Exception:
        if backup.exists():
            backup.rename(dest)
        raise
    if backup.exists():
        shutil.rmtree(backup)

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--dest',type=Path,default=DEST); args=ap.parse_args(); safe(args.dest)
    missing = preflight_sources()
    if missing:
        print('Warning: missing private old-PC game files; building metadata-only entries where packages are unavailable.')
        for m in missing:
            print(f'- {m}')
    args.dest.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=f'.{args.dest.name}-build-', dir=args.dest.parent) as tmp:
        staged = Path(tmp) / 'new'
        staged.mkdir()
        games=build(staged)
        write_index(staged,games); write_play(staged)
        manifest=dict(name='Classic PC Games', generatedAt=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), privateOnly=True, containsGameArchives=any(g.get('packageUrl') for g in games), runtime='EmulatorJS dosbox_pure', notes='Generated on GannanNet from private intake; do not commit generated packages. Planned game entries need game files before gameplay smoke.', counts={k:sum(1 for g in games if g.get('status')==k) for k in STATUS_KEYS}, packagedCount=sum(1 for g in games if g.get('packageUrl')), games=games)
        (staged/'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
        (staged/'.lan-arcade-ready').touch()
        publish(staged, args.dest)
    print(f'Built {len(games)} entries at {args.dest}')
    for g in games: print(f'- {g["id"]}: {g["status"]} {g["packageUrl"] or "no package"}')

if __name__ == '__main__': main()
