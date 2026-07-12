#!/usr/bin/env python3
import json
import os
import signal
import subprocess
import time
from pathlib import Path

CONFIG = Path("/etc/lan-arcade/browser-stream-games.json")
DISPLAY = ":0"
children = []
stopping = False


def log(message):
    print(f"[browser-stream] {message}", flush=True)


def spawn(name, argv, env):
    log(f"starting {name}: {' '.join(argv)}")
    proc = subprocess.Popen(argv, env=env)
    children.append((name, proc))
    return proc


def terminate_all():
    global stopping
    if stopping:
        return
    stopping = True
    for name, proc in reversed(children):
        if proc.poll() is None:
            log(f"stopping {name}")
            proc.terminate()
    deadline = time.monotonic() + 6
    for _, proc in reversed(children):
        if proc.poll() is None:
            try:
                proc.wait(timeout=max(0.1, deadline - time.monotonic()))
            except subprocess.TimeoutExpired:
                proc.kill()


def handle_signal(signum, _frame):
    log(f"received signal {signum}")
    terminate_all()


def wait_for_x():
    for _ in range(100):
        result = subprocess.run(
            ["/usr/bin/xdpyinfo", "-display", DISPLAY],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if result.returncode == 0:
            return
        time.sleep(0.1)
    raise RuntimeError("Xvfb did not become ready")


def main():
    game_id = os.environ.get("GAME_ID", "")
    with CONFIG.open(encoding="utf-8") as handle:
        config = json.load(handle)
    game = config.get("games", {}).get(game_id)
    if not game:
        raise SystemExit(f"GAME_ID is not allowlisted: {game_id!r}")
    command = game.get("command")
    display = game.get("display", [1024, 768])
    if (
        not isinstance(command, list)
        or not command
        or not all(isinstance(item, str) and item for item in command)
        or not command[0].startswith("/usr/games/")
    ):
        raise SystemExit("allowlisted command is invalid")
    if (
        not isinstance(display, list)
        or len(display) != 2
        or not isinstance(display[0], int)
        or not isinstance(display[1], int)
        or not 640 <= display[0] <= 1920
        or not 480 <= display[1] <= 1200
    ):
        raise SystemExit("allowlisted display size is invalid")

    env = os.environ.copy()
    env.update({
        "DISPLAY": DISPLAY,
        "HOME": "/home/player",
        "XDG_RUNTIME_DIR": "/tmp/runtime-player",
        "SDL_AUDIODRIVER": "dummy",
        "PULSE_SERVER": "disabled",
        "LANG": "C.UTF-8",
    })
    Path(env["XDG_RUNTIME_DIR"]).mkdir(mode=0o700, parents=True, exist_ok=True)

    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, handle_signal)

    spawn("xvfb", [
        "/usr/bin/Xvfb", DISPLAY, "-screen", "0", f"{display[0]}x{display[1]}x24",
        "-nolisten", "tcp",
    ], env)
    wait_for_x()
    spawn("openbox", ["/usr/bin/openbox", "--sm-disable"], env)
    spawn("x11vnc", [
        "/usr/bin/x11vnc", "-display", DISPLAY, "-forever", "-shared",
        "-nopw", "-localhost", "-rfbport", "5900",
    ], env)
    spawn("websockify", [
        "/usr/bin/websockify", "--web", "/usr/share/novnc",
        "6080", "127.0.0.1:5900",
    ], env)
    game_proc = spawn("game", command, env)
    log(f"session ready for {game_id}")

    while not stopping:
        code = game_proc.poll()
        if code is not None:
            log(f"game exited with code {code}")
            terminate_all()
            return code
        time.sleep(0.5)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        log(f"fatal: {exc}")
        terminate_all()
        raise
