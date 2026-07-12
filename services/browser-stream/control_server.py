#!/usr/bin/env python3
"""Loopback-only player launcher for the allowlisted browser-stream service."""

import hashlib
import hmac
import json
import os
import re
import secrets
import sys
import threading
import time
import urllib.error
import urllib.request
from http import HTTPStatus
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import browser_stream_admin as admin  # noqa: E402

CONFIG = admin.load_config()
SERVICE = CONFIG["service"]
LOCK = threading.Lock()
LAST_ACTIVITY = time.monotonic()
STOP_EVENT = threading.Event()
MAX_BODY = 1024
GUEST_UUID = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
)
IDLE_TIMEOUT = int(os.environ.get(
    "BROWSER_STREAM_IDLE_TIMEOUT_SECONDS", SERVICE["idleTimeoutSeconds"]
))
IDLE_CHECK_SECONDS = int(os.environ.get("BROWSER_STREAM_IDLE_CHECK_SECONDS", "15"))
AUTH_ME_URL = os.environ.get(
    "BROWSER_STREAM_AUTH_ME_URL", SERVICE["accountValidationUrl"]
)
COOKIE_SECRET = secrets.token_bytes(32)
COOKIE_NAME = "lan_arcade_stream"


class IdentityError(ValueError):
    pass


def touch():
    global LAST_ACTIVITY
    LAST_ACTIVITY = time.monotonic()


def account_scope(token):
    if not token or len(token) > 512:
        raise IdentityError("invalid account session")
    request = urllib.request.Request(
        AUTH_ME_URL,
        headers={"x-arcade-account-session": token, "accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=3) as response:
            payload = json.load(response)
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, ValueError):
        raise IdentityError("account session is missing or expired")
    account_id = str((payload.get("account") or {}).get("id") or "")
    if not re.fullmatch(r"[A-Za-z0-9._:-]{1,120}", account_id):
        raise IdentityError("account service returned an invalid account ID")
    digest = hashlib.sha256(account_id.encode()).hexdigest()[:32]
    return f"account-{digest}"


def guest_scope(guest_uuid):
    value = (guest_uuid or "").lower()
    if not GUEST_UUID.fullmatch(value):
        raise IdentityError("a valid guest profile is required")
    return "guest-" + value.replace("-", "")


def request_scope(headers):
    token = headers.get("x-arcade-account-session", "").strip()
    if token:
        return account_scope(token)
    return guest_scope(headers.get("x-lan-arcade-guest", "").strip())


def signed_cookie(scope):
    signature = hmac.new(COOKIE_SECRET, scope.encode(), hashlib.sha256).hexdigest()
    return f"{scope}.{signature}"


def session_cookie(scope):
    return (
        f"{COOKIE_NAME}={signed_cookie(scope)}; Path={SERVICE['publicBasePath']}; "
        "HttpOnly; SameSite=Strict"
    )


def authorized_cookie(headers):
    cookie = SimpleCookie()
    try:
        cookie.load(headers.get("Cookie", ""))
    except Exception:
        return False
    morsel = cookie.get(COOKIE_NAME)
    if not morsel or "." not in morsel.value:
        return False
    scope, supplied = morsel.value.rsplit(".", 1)
    expected = hmac.new(COOKIE_SECRET, scope.encode(), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(supplied, expected):
        return False
    current = admin.status_payload(CONFIG)
    return bool(current.get("running") and current.get("scope") == scope)


def scoped_payload(scope):
    raw = admin.status_payload(CONFIG)
    if raw.get("running") and raw.get("scope") != scope:
        session = {"running": False, "occupied": True}
    else:
        session = {key: value for key, value in raw.items() if key != "scope"}
        session["occupied"] = False
    return {
        "session": session,
        "games": [
            {"id": game_id, "title": game["title"]}
            for game_id, game in sorted(CONFIG["games"].items())
        ],
        "idleTimeoutSeconds": IDLE_TIMEOUT,
        "vncUrl": (
            f"{SERVICE['publicBasePath']}vnc/vnc.html"
            f"?autoconnect=1&resize=scale&path="
            f"{SERVICE['publicBasePath'].lstrip('/')}vnc/websockify"
        ),
    }


def render_page():
    games = json.dumps([
        {"id": game_id, "title": game["title"]}
        for game_id, game in sorted(CONFIG["games"].items())
    ])
    return f"""<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>GannanNet Game Player</title>
<style>
:root{{color-scheme:dark;font-family:system-ui,sans-serif}}body{{margin:0;background:#0d1418;color:#edf6f1}}
main{{max-width:1100px;margin:auto;padding:24px}}h1{{margin:0 0 8px}}p{{color:#b9c9c2}}
.games{{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px}}
button{{min-height:48px;border:1px solid #456158;background:#19352c;color:#fff;border-radius:6px;padding:10px 14px;font-weight:700;cursor:pointer}}
button:hover{{background:#245442}}button.stop{{background:#4d2424}}
#status{{margin:18px 0;padding:12px;border:1px solid #344942;border-radius:6px}}
#player{{width:100%;height:min(75vh,850px);border:1px solid #344942;background:#000;display:none}}
.actions{{display:flex;gap:10px;flex-wrap:wrap;margin:12px 0}}.error{{color:#ffb5b5}}
</style></head><body><main>
<h1>GannanNet Game Player</h1>
<p>Choose a game. Only one streamed game can run at a time.</p>
<div class="games" id="games"></div>
<div id="status" aria-live="polite">Checking session...</div>
<div class="actions"><button class="stop" id="stop">Stop current game</button></div>
<iframe id="player" title="Game stream" allow="fullscreen"></iframe>
</main><script>
const games={games},list=document.getElementById('games'),statusBox=document.getElementById('status'),player=document.getElementById('player');
function uuid(){{
  let value=localStorage.getItem('lanArcadeBrowserStreamGuest.v1')||'';
  if(/^[0-9a-f]{{8}}-[0-9a-f]{{4}}-4[0-9a-f]{{3}}-[89ab][0-9a-f]{{3}}-[0-9a-f]{{12}}$/.test(value))return value;
  const b=new Uint8Array(16);crypto.getRandomValues(b);b[6]=(b[6]&15)|64;b[8]=(b[8]&63)|128;
  const h=[...b].map(x=>x.toString(16).padStart(2,'0')).join('');
  value=h.slice(0,8)+'-'+h.slice(8,12)+'-'+h.slice(12,16)+'-'+h.slice(16,20)+'-'+h.slice(20);
  localStorage.setItem('lanArcadeBrowserStreamGuest.v1',value);return value;
}}
function identityHeaders(){{
  try{{const a=JSON.parse(localStorage.getItem('lanArcadeAccount.v1')||'null');
    if(a&&a.token)return{{'x-arcade-account-session':a.token}};}}catch(_){{}}
  return{{'x-lan-arcade-guest':uuid()}};
}}
function headers(){{return Object.assign({{'Content-Type':'application/json','X-LAN-Arcade-Request':'browser-stream'}},identityHeaders());}}
for(const game of games){{const b=document.createElement('button');b.textContent='Play '+game.title;b.onclick=()=>launch(game.id);list.appendChild(b);}}
async function api(path,options={{}}){{options.headers=Object.assign({{}},identityHeaders(),options.headers||{{}});
  const r=await fetch(path,options),d=await r.json();if(!r.ok)throw new Error(d.error||'Request failed');return d;}}
function show(d){{const s=d.session;if(s.running){{statusBox.className='';statusBox.textContent='Playing '+(s.title||s.gameId)+' - progress is saved to this player profile.';player.src=d.vncUrl;player.style.display='block';}}
  else{{statusBox.className=s.occupied?'error':'';statusBox.textContent=s.occupied?'Another player is using the game stream.':'No game is running.';player.removeAttribute('src');player.style.display='none';}}}}
async function refresh(){{try{{show(await api('api/session'));}}catch(e){{statusBox.className='error';statusBox.textContent=e.message;}}}}
async function launch(gameId){{statusBox.textContent='Starting game...';try{{show(await api('api/session',{{method:'POST',headers:headers(),body:JSON.stringify({{gameId}})}}));}}catch(e){{statusBox.className='error';statusBox.textContent=e.message;}}}}
document.getElementById('stop').onclick=async()=>{{try{{show(await api('api/session/stop',{{method:'POST',headers:headers()}}));}}catch(e){{statusBox.className='error';statusBox.textContent=e.message;}}}};
setInterval(async()=>{{try{{show(await api('api/session/heartbeat',{{method:'POST',headers:headers()}}));}}catch(_){{}}}},20000);
refresh().then(()=>{{const wanted=new URLSearchParams(location.search).get('game');if(games.some(g=>g.id===wanted))launch(wanted);}});
</script></body></html>"""


class Handler(BaseHTTPRequestHandler):
    server_version = "LANArcadeBrowserStream/1"

    def send_headers(self, status, content_type, length, extra_headers=None):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(length))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "SAMEORIGIN")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'self'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; "
            "frame-src 'self'; connect-src 'self'",
        )
        for name, value in (extra_headers or {}).items():
            self.send_header(name, value)
        self.end_headers()

    def send_json(self, payload, status=HTTPStatus.OK, extra_headers=None):
        body = json.dumps(payload).encode()
        self.send_headers(
            status, "application/json; charset=utf-8", len(body), extra_headers
        )
        self.wfile.write(body)

    def do_GET(self):
        path = urlsplit(self.path).path
        if path == "/healthz":
            self.send_json({"ok": True})
        elif path == "/authz":
            status = HTTPStatus.NO_CONTENT if authorized_cookie(self.headers) else HTTPStatus.UNAUTHORIZED
            self.send_headers(status, "text/plain; charset=utf-8", 0)
        elif path == "/api/games":
            self.send_json({"games": scoped_payload("guest-00000000000000000000000000000000")["games"]})
        elif path == "/api/session":
            try:
                scope = request_scope(self.headers)
                self.send_json(
                    scoped_payload(scope),
                    extra_headers={"Set-Cookie": session_cookie(scope)},
                )
            except IdentityError as exc:
                self.send_json({"error": str(exc)}, HTTPStatus.UNAUTHORIZED)
        elif path == "/":
            body = render_page().encode()
            self.send_headers(HTTPStatus.OK, "text/html; charset=utf-8", len(body))
            self.wfile.write(body)
        else:
            self.send_json({"error": "not found"}, HTTPStatus.NOT_FOUND)

    def read_json(self):
        if self.headers.get("X-LAN-Arcade-Request") != "browser-stream":
            raise ValueError("missing launcher request header")
        length = int(self.headers.get("Content-Length", "0"))
        if length < 0 or length > MAX_BODY:
            raise ValueError("request body is too large")
        return json.loads(self.rfile.read(length)) if length else {}

    def do_POST(self):
        path = urlsplit(self.path).path
        try:
            body = self.read_json()
            scope = request_scope(self.headers)
            with LOCK:
                current = admin.status_payload(CONFIG)
                owns = current.get("running") and current.get("scope") == scope
                if path == "/api/session":
                    game_id = body.get("gameId")
                    if game_id not in CONFIG["games"]:
                        self.send_json({"error": "game is not available"}, HTTPStatus.BAD_REQUEST)
                        return
                    if current.get("running") and not owns:
                        self.send_json({"error": "another player is using the stream"}, HTTPStatus.CONFLICT)
                        return
                    if owns and current.get("gameId") != game_id:
                        self.send_json({"error": "stop the current game before starting another"}, HTTPStatus.CONFLICT)
                        return
                    if not current.get("running"):
                        admin.start_session(CONFIG, game_id, scope=scope, replace=False)
                    touch()
                elif path == "/api/session/heartbeat":
                    if owns:
                        touch()
                elif path == "/api/session/stop":
                    if current.get("running") and not owns:
                        self.send_json({"error": "this session belongs to another player"}, HTTPStatus.FORBIDDEN)
                        return
                    if owns:
                        admin.stop_session(CONFIG, quiet=True)
                    touch()
                else:
                    self.send_json({"error": "not found"}, HTTPStatus.NOT_FOUND)
                    return
                self.send_json(
                    scoped_payload(scope),
                    extra_headers={"Set-Cookie": session_cookie(scope)},
                )
        except (IdentityError, ValueError, json.JSONDecodeError) as exc:
            self.send_json({"error": str(exc)}, HTTPStatus.UNAUTHORIZED if isinstance(exc, IdentityError) else HTTPStatus.BAD_REQUEST)
        except admin.BrowserStreamError as exc:
            self.send_json({"error": str(exc)}, HTTPStatus.SERVICE_UNAVAILABLE)

    def log_message(self, fmt, *args):
        print(f"[browser-stream-control] {self.address_string()} {fmt % args}", flush=True)


def idle_monitor():
    while not STOP_EVENT.wait(IDLE_CHECK_SECONDS):
        with LOCK:
            status = admin.status_payload(CONFIG)
            if status["running"] and time.monotonic() - LAST_ACTIVITY > IDLE_TIMEOUT:
                print("[browser-stream-control] idle timeout reached; stopping session", flush=True)
                admin.stop_session(CONFIG, quiet=True)


def main():
    host = SERVICE["controlHost"]
    port = int(SERVICE["controlPort"])
    threading.Thread(target=idle_monitor, name="idle-cleaner", daemon=True).start()
    server = ThreadingHTTPServer((host, port), Handler)
    print(f"[browser-stream-control] listening on http://{host}:{port}/", flush=True)
    try:
        server.serve_forever()
    finally:
        STOP_EVENT.set()
        server.server_close()


if __name__ == "__main__":
    main()
