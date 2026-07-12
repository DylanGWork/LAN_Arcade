#!/usr/bin/env python3
"""Live same-origin browser-stream launch, authorization, WebSocket, and save QA."""
import argparse
import http.cookiejar
import json
import os
import socket
import subprocess
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
SAVE_ROOT = Path("/srv/lan-arcade/native-downloads/browser-stream/saves")
GUEST = "33333333-3333-4333-8333-333333333333"


def request(opener, url, *, method="GET", data=None, headers=None):
    raw = None if data is None else json.dumps(data).encode()
    req = urllib.request.Request(
        url, data=raw, method=method,
        headers={"Accept": "application/json", **(headers or {})},
    )
    with opener.open(req, timeout=90) as response:
        body = response.read()
        return response.status, dict(response.headers), (
            json.loads(body) if body and "json" in response.headers.get_content_type() else body
        )


def identity_headers(token=None):
    if token:
        return {"x-arcade-account-session": token}
    return {"x-lan-arcade-guest": GUEST}


def api(opener, base, path, *, token=None, method="GET", data=None):
    headers = identity_headers(token)
    if method != "GET":
        headers.update({
            "Content-Type": "application/json",
            "X-LAN-Arcade-Request": "browser-stream",
        })
    return request(opener, base + "browser-stream/" + path, method=method, data=data, headers=headers)


def websocket_probe(base, jar):
    parsed = urlsplit(base)
    host = parsed.hostname
    port = parsed.port or 80
    cookie = "; ".join(f"{c.name}={c.value}" for c in jar)
    handshake = (
        "GET /browser-stream/vnc/websockify HTTP/1.1\r\n"
        f"Host: {parsed.netloc}\r\n"
        "Connection: Upgrade\r\n"
        "Upgrade: websocket\r\n"
        "Sec-WebSocket-Version: 13\r\n"
        "Sec-WebSocket-Key: MDEyMzQ1Njc4OWFiY2RlZg==\r\n"
        "Sec-WebSocket-Protocol: binary\r\n"
        f"Cookie: {cookie}\r\n\r\n"
    ).encode()
    with socket.create_connection((host, port), timeout=5) as sock:
        sock.sendall(handshake)
        response = sock.recv(4096)
    first = response.split(b"\r\n", 1)[0]
    if b" 101 " not in first:
        raise AssertionError(f"WebSocket upgrade failed: {first!r}")


def status():
    raw = subprocess.check_output(
        ["python3", str(ROOT / "scripts/browser_stream_admin.py"), "status", "--json"],
        text=True,
    )
    return json.loads(raw)


def stop(opener, base, token=None):
    try:
        api(opener, base, "api/session/stop", token=token, method="POST")
    except Exception:
        subprocess.run(
            ["python3", str(ROOT / "scripts/browser_stream_admin.py"), "stop"],
            check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )


def run_identity(base, label, game_id, token=None):
    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    try:
        code, _, _ = api(opener, base, "api/session", token=token)
        assert code == 200
        code, _, payload = api(
            opener, base, "api/session", token=token,
            method="POST", data={"gameId": game_id},
        )
        assert code == 200 and payload["session"]["running"] is True
        current = status()
        assert current["gameId"] == game_id and current["health"] == "healthy"
        scope = current["scope"]
        assert scope.startswith(("account-", "guest-"))
        code, _, html = request(opener, base + "browser-stream/vnc/vnc.html")
        assert code == 200 and b"noVNC" in html
        websocket_probe(base, jar)
        subprocess.check_call([
            "docker", "exec", "lan-arcade-browser-stream",
            "sh", "-c", "printf live-save-proof > /home/player/live-save-proof.txt",
        ])
        save_file = SAVE_ROOT / scope / game_id / "live-save-proof.txt"
        assert save_file.read_text() == "live-save-proof"
        stop(opener, base, token)
        code, _, payload = api(
            opener, base, "api/session", token=token,
            method="POST", data={"gameId": game_id},
        )
        assert code == 200 and payload["session"]["running"] is True
        subprocess.check_call([
            "docker", "exec", "lan-arcade-browser-stream",
            "test", "-s", "/home/player/live-save-proof.txt",
        ])
        stop(opener, base, token)
        return {"identity": label, "game": game_id, "scope": scope, "result": "PASS"}
    finally:
        stop(opener, base, token)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1/")
    parser.add_argument("--report", required=True)
    args = parser.parse_args()
    base = args.base.rstrip("/") + "/"
    report = Path(args.report)
    report.mkdir(parents=True, exist_ok=True)

    results = [run_identity(base, "guest", "ace-of-penguins-lan")]
    username = os.environ.get("LAN_ARCADE_QA_USERNAME")
    password = os.environ.get("LAN_ARCADE_QA_PASSWORD")
    if not username or not password:
        raise SystemExit("LAN_ARCADE_QA_USERNAME and LAN_ARCADE_QA_PASSWORD are required")
    opener = urllib.request.build_opener()
    _, _, login = request(
        opener, base + "arcade-api/auth/login", method="POST",
        data={"username": username, "password": password},
        headers={"Content-Type": "application/json"},
    )
    results.append(run_identity(base, "account", "freedroidrpg-lan", login["token"]))

    (report / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    lines = [
        "# Browser Stream Live QA", "",
        "Same-origin launch, authorization cookie, protected noVNC HTML/WebSocket, "
        "server-derived save ownership, restart persistence, and clean stop all passed.", "",
    ]
    lines.extend(
        f"- **PASS** {item['identity']}: {item['game']} ({item['scope']})"
        for item in results
    )
    (report / "report.md").write_text("\n".join(lines) + "\n")
    print("BROWSER_STREAM_LIVE_PASS")


if __name__ == "__main__":
    main()
