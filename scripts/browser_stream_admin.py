#!/usr/bin/env python3
"""Operate the single allowlisted LAN Arcade browser-stream session."""

import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = REPO_ROOT / "config" / "browser-stream-games.json"
MANAGED_LABEL = "io.gannannet.browser-stream"
SAFE_SCOPE = re.compile(r"^(?:account|guest|operator)-[a-z0-9-]{8,80}$")


class BrowserStreamError(RuntimeError):
    pass


def run(argv, *, check=True):
    result = subprocess.run(
        argv, check=False, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    if check and result.returncode:
        detail = (result.stderr or result.stdout or "").strip()
        raise BrowserStreamError(f"{' '.join(argv)} failed: {detail}")
    return result


def load_config():
    with CONFIG_PATH.open(encoding="utf-8") as handle:
        config = json.load(handle)
    if config.get("schemaVersion") != 1:
        raise BrowserStreamError("unsupported browser-stream config schema")
    service = config.get("service")
    games = config.get("games")
    if not isinstance(service, dict) or not isinstance(games, dict) or not games:
        raise BrowserStreamError("invalid browser-stream config")
    for game_id, game in games.items():
        command = game.get("command")
        if (
            not game_id.endswith("-lan")
            or not isinstance(command, list)
            or not command
            or not all(isinstance(item, str) and item for item in command)
            or not command[0].startswith("/usr/games/")
        ):
            raise BrowserStreamError(f"invalid allowlist entry: {game_id}")
    if service.get("controlHost") != "172.18.0.1":
        raise BrowserStreamError("control service must be bound only to the webserver bridge gateway")
    return config


def validate_scope(scope):
    if not isinstance(scope, str) or not SAFE_SCOPE.fullmatch(scope):
        raise BrowserStreamError("invalid server-derived save scope")
    return scope


def ensure_save_dir(config, scope, game_id):
    validate_scope(scope)
    if game_id not in config["games"]:
        raise BrowserStreamError("cannot create a save directory for an unknown game")
    root = Path(config["service"]["saveRoot"]).resolve()
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    scope_dir = root / scope
    game_dir = scope_dir / game_id
    if scope_dir.is_symlink() or game_dir.is_symlink():
        raise BrowserStreamError("save scope contains an unsafe symlink")
    game_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    game_dir.chmod(0o700)
    resolved = game_dir.resolve()
    if not resolved.is_relative_to(root):
        raise BrowserStreamError("save directory escaped the configured save root")
    return resolved


def container_exists(name):
    return run(["docker", "container", "inspect", name], check=False).returncode == 0


def inspect_container(name):
    return json.loads(run(["docker", "container", "inspect", name]).stdout)[0]


def assert_managed(container):
    labels = container.get("Config", {}).get("Labels") or {}
    if labels.get(MANAGED_LABEL) != "true":
        raise BrowserStreamError(
            f"refusing to modify {container.get('Name', '').lstrip('/')}: "
            "container is not managed by browser-stream"
        )


def ensure_network(name):
    result = run(["docker", "network", "inspect", name], check=False)
    if result.returncode == 0:
        network = json.loads(result.stdout)[0]
        if not network.get("Internal"):
            raise BrowserStreamError(f"Docker network {name} is not internal")
    else:
        run([
            "docker", "network", "create", "--driver", "bridge", "--internal",
            "--label", f"{MANAGED_LABEL}=true", name,
        ])
        network = json.loads(run(["docker", "network", "inspect", name]).stdout)[0]
    if "webserver" not in {
        endpoint.get("Name") for endpoint in (network.get("Containers") or {}).values()
    }:
        run(["docker", "network", "connect", name, "webserver"])


def health_state(container):
    state = container.get("State", {})
    return state.get("Status", "unknown"), (
        (state.get("Health") or {}).get("Status", "not-configured")
    )


def stop_session(config, quiet=False):
    name = config["service"]["containerName"]
    if not container_exists(name):
        if not quiet:
            print("No browser-stream session is running.")
        return
    container = inspect_container(name)
    assert_managed(container)
    run(["docker", "stop", "--time", "10", name], check=False)
    run(["docker", "rm", "--force", name])
    if not quiet:
        print(f"Stopped and removed {name}.")


def start_session(config, game_id, *, scope, replace=False):
    service = config["service"]
    game = config["games"].get(game_id)
    if game is None:
        choices = ", ".join(sorted(config["games"]))
        raise BrowserStreamError(f"unknown game ID {game_id!r}; allowed: {choices}")
    save_dir = ensure_save_dir(config, scope, game_id)

    name = service["containerName"]
    if container_exists(name):
        current = inspect_container(name)
        assert_managed(current)
        labels = current.get("Config", {}).get("Labels") or {}
        current_game = labels.get(f"{MANAGED_LABEL}.game-id", "unknown")
        if not replace:
            raise BrowserStreamError(
                f"{current_game} already owns the single session; use --replace explicitly"
            )
        stop_session(config, quiet=True)

    image = service["image"]
    if run(["docker", "image", "inspect", image], check=False).returncode:
        raise BrowserStreamError(
            f"image {image} is missing; run deploy/browser-stream/build_image.sh"
        )
    ensure_network(service["networkName"])

    command = [
        "docker", "run", "--detach", "--name", name,
        "--hostname", "browser-stream", "--init",
        "--network", service["networkName"],
        "--read-only",
        "--tmpfs", "/tmp:rw,nosuid,noexec,size=256m,mode=1777",
        "--tmpfs", "/run:rw,nosuid,noexec,size=32m,mode=755",
        "--cap-drop", "ALL",
        "--security-opt", "no-new-privileges:true",
        "--pids-limit", str(service["pidsLimit"]),
        "--memory", str(service["memory"]),
        "--cpus", str(service["cpus"]),
        "--shm-size", str(service["shmSize"]),
        "--label", f"{MANAGED_LABEL}=true",
        "--label", f"{MANAGED_LABEL}.game-id={game_id}",
        "--label", f"{MANAGED_LABEL}.scope={scope}",
        "--env", f"GAME_ID={game_id}",
        "--mount",
        f"type=bind,src={CONFIG_PATH},dst=/etc/lan-arcade/browser-stream-games.json,readonly",
        "--mount",
        f"type=bind,src={save_dir},dst=/home/player",
        image,
    ]
    run(command)

    deadline = time.monotonic() + int(service["startupTimeoutSeconds"])
    last_status, last_health = "created", "starting"
    while time.monotonic() < deadline:
        current = inspect_container(name)
        last_status, last_health = health_state(current)
        if last_status == "running" and last_health == "healthy":
            print(f"Started {game['title']} ({game_id}).")
            print(f"Local operator URL: {local_vnc_url(config)}")
            return
        if last_status in {"exited", "dead"}:
            log_result = run(["docker", "logs", name], check=False)
            logs = (log_result.stdout + log_result.stderr)[-8000:]
            stop_session(config, quiet=True)
            raise BrowserStreamError(f"session exited during startup:\n{logs}")
        time.sleep(1)

    log_result = run(["docker", "logs", name], check=False)
    logs = (log_result.stdout + log_result.stderr)[-8000:]
    stop_session(config, quiet=True)
    raise BrowserStreamError(
        f"session did not become healthy ({last_status}/{last_health}):\n{logs}"
    )


def local_vnc_url(config):
    service = config["service"]
    return (
        f"{service['publicBasePath']}vnc/vnc.html"
        f"?autoconnect=1&resize=scale&path={service['publicBasePath'].lstrip('/')}vnc/websockify"
    )


def status_payload(config):
    name = config["service"]["containerName"]
    if not container_exists(name):
        return {"running": False, "container": name}
    container = inspect_container(name)
    assert_managed(container)
    labels = container.get("Config", {}).get("Labels") or {}
    status, health = health_state(container)
    game_id = labels.get(f"{MANAGED_LABEL}.game-id")
    process = run(
        ["docker", "exec", name, "pgrep", "-af", "^/usr/games/"],
        check=False,
    ).stdout.strip()
    windows = run([
        "docker", "exec", "--env", "DISPLAY=:0", name, "xdotool",
        "search", "--onlyvisible", "--name", ".", "getwindowname", "%@",
    ], check=False).stdout.splitlines()
    game = config["games"].get(game_id, {})
    return {
        "running": status == "running",
        "container": name,
        "status": status,
        "health": health,
        "gameId": game_id,
        "title": game.get("title", game_id),
        "scope": labels.get(f"{MANAGED_LABEL}.scope"),
        "gameProcess": process,
        "visibleWindows": [line for line in windows if line.strip()],
        "url": local_vnc_url(config),
    }


def status_session(config, as_json=False):
    payload = status_payload(config)
    if as_json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    elif not payload["running"]:
        print("No browser-stream session is running.")
    else:
        print(
            f"{payload['gameId']}: {payload['status']}/{payload['health']}\n"
            f"Scope: {payload['scope']}\n"
            f"Process: {payload['gameProcess']}\n"
            f"Windows: {', '.join(payload['visibleWindows']) or 'none'}\n"
            f"URL: {payload['url']}"
        )


def cleanup(config):
    stop_session(config, quiet=True)
    network = config["service"]["networkName"]
    result = run(["docker", "network", "inspect", network], check=False)
    if result.returncode == 0:
        details = json.loads(result.stdout)[0]
        labels = details.get("Labels") or {}
        if labels.get(MANAGED_LABEL) != "true":
            raise BrowserStreamError(f"refusing to use unmanaged network {network}")
    print("Browser-stream session is clean; the private webserver network remains ready.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="action", required=True)
    subparsers.add_parser("list", help="list allowlisted games")
    start = subparsers.add_parser("start", help="start one allowlisted game")
    start.add_argument("game_id")
    start.add_argument("--replace", action="store_true")
    start.add_argument("--scope", default="operator-local0001")
    status = subparsers.add_parser("status", help="show current session")
    status.add_argument("--json", action="store_true")
    subparsers.add_parser("stop", help="stop and remove the session")
    subparsers.add_parser("cleanup", help="remove session and internal network")
    args = parser.parse_args()
    config = load_config()

    if args.action == "list":
        for game_id, game in sorted(config["games"].items()):
            print(f"{game_id}\t{game['title']}\t{' '.join(game['command'])}")
    elif args.action == "start":
        start_session(config, args.game_id, scope=args.scope, replace=args.replace)
    elif args.action == "status":
        status_session(config, args.json)
    elif args.action == "stop":
        stop_session(config)
    elif args.action == "cleanup":
        cleanup(config)


if __name__ == "__main__":
    try:
        main()
    except BrowserStreamError as exc:
        print(f"browser-stream: {exc}", file=sys.stderr)
        raise SystemExit(1)
