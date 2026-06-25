#!/usr/bin/env python3
"""Allowlisted native/LAN service status and smoke helper.

This is intentionally narrow: it reads config/native-services.json and only runs
known local commands from this repository. It never accepts arbitrary shell from
browser/admin input.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "config" / "native-services.json"
SMOKE_SCRIPT = ROOT / "scripts" / "native_service_smoke.sh"
DEFAULT_REPORT_DIR = ROOT / "qa" / "reports" / "service-admin"
LOCK_DIR = Path("/tmp/lan-arcade-native-service-smoke.lock")

SCRIPT_SMOKE_IDS = {
    "openttd-lan",
    "freeciv-lan",
    "wesnoth-lan",
    "teeworlds-ddnet-lan",
    "luanti-lan",
    "openarena-lan",
    "bzflag-lan",
    "hedgewars-lan",
    "widelands-lan",
    "warzone2100-lan",
    "veloren-lan",
    "stendhal-lan",
}


def load_config() -> dict[str, Any]:
    if not CONFIG.exists():
        raise SystemExit(f"missing service config: {CONFIG}")
    return json.loads(CONFIG.read_text())


def services_by_id() -> dict[str, dict[str, Any]]:
    data = load_config()
    return {str(item["id"]): item for item in data.get("services", [])}


def parse_ports(service: dict[str, Any]) -> list[tuple[int, str]]:
    ports: list[tuple[int, str]] = []
    for raw in service.get("ports", []) or []:
        m = re.match(r"^(\d+)/(tcp|udp)", str(raw).strip())
        if m:
            ports.append((int(m.group(1)), m.group(2)))
    return ports


def tcp_listens(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.settimeout(0.4)
        return sock.connect_ex(("127.0.0.1", port)) == 0


def udp_listen_known(port: int) -> bool:
    ss = shutil.which("ss")
    if not ss:
        return False
    proc = subprocess.run([ss, "-lun"], text=True, capture_output=True, check=False)
    return f":{port}" in proc.stdout


def compose_status(service: dict[str, Any]) -> dict[str, Any]:
    compose = service.get("composeFile")
    if not compose:
        return {"available": False, "reason": "no composeFile"}
    compose_path = ROOT / str(compose)
    if not compose_path.exists():
        return {"available": False, "reason": f"missing {compose}"}
    docker = shutil.which("docker")
    if not docker:
        return {"available": False, "reason": "docker command not found"}
    proc = subprocess.run([docker, "compose", "-f", str(compose_path), "ps"], text=True, capture_output=True, check=False)
    return {"available": True, "returncode": proc.returncode, "stdout": proc.stdout.strip(), "stderr": proc.stderr.strip()}


def service_status(service: dict[str, Any]) -> dict[str, Any]:
    ports = []
    for port, proto in parse_ports(service):
        if proto == "tcp":
            listening = tcp_listens(port)
        else:
            listening = udp_listen_known(port)
        ports.append({"port": port, "proto": proto, "listening": listening})
    return {
        "id": service["id"],
        "label": service.get("label", service["id"]),
        "adminState": service.get("adminState", "unknown"),
        "smokeStatus": service.get("smokeStatus", "unknown"),
        "ports": ports,
        "compose": compose_status(service),
        "lastReport": service.get("lastReport", ""),
    }


def print_table(rows: list[dict[str, Any]]) -> None:
    print(f"{'SERVICE':24} {'ADMIN':22} {'SMOKE':32} PORTS")
    for row in rows:
        port_text = ", ".join(f"{p['port']}/{p['proto']}={'up' if p['listening'] else 'down'}" for p in row["ports"]) or "n/a"
        print(f"{row['id'][:24]:24} {row['adminState'][:22]:22} {row['smokeStatus'][:32]:32} {port_text}")


def write_report(report_dir: Path, name: str, data: dict[str, Any]) -> Path:
    report_dir.mkdir(parents=True, exist_ok=True)
    path = report_dir / f"{name}-{time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())}.json"
    path.write_text(json.dumps(data, indent=2) + "\n")
    return path


def ensure_service(service_id: str) -> dict[str, Any]:
    services = services_by_id()
    if service_id not in services:
        valid = ", ".join(sorted(services))
        raise SystemExit(f"unknown service id {service_id!r}; valid ids: {valid}")
    return services[service_id]


def run_script_smoke(service_id: str, report_dir: Path) -> dict[str, Any]:
    env = os.environ.copy()
    env["LAN_ARCADE_SERVICE_REPORT_DIR"] = str(report_dir)
    proc = subprocess.run([str(SMOKE_SCRIPT), service_id], cwd=ROOT, text=True, capture_output=True, env=env, check=False)
    return {
        "mode": "native_service_smoke.sh",
        "service": service_id,
        "returncode": proc.returncode,
        "stdout": proc.stdout.strip(),
        "stderr": proc.stderr.strip(),
    }


def run_compose_smoke(service: dict[str, Any], report_dir: Path, keep_running: bool) -> dict[str, Any]:
    compose = service.get("composeFile")
    if not compose:
        return {"mode": "compose", "service": service["id"], "returncode": 2, "error": "service has no composeFile"}
    compose_path = ROOT / str(compose)
    docker = shutil.which("docker")
    if not docker:
        return {"mode": "compose", "service": service["id"], "returncode": 2, "error": "docker command not found"}
    if not compose_path.exists():
        return {"mode": "compose", "service": service["id"], "returncode": 2, "error": f"missing {compose}"}
    env = os.environ.copy()
    env.update({str(k): str(v) for k, v in (service.get("startEnv") or {}).items()})
    report_dir.mkdir(parents=True, exist_ok=True)
    commands: list[dict[str, Any]] = []
    def run(args: list[str]) -> subprocess.CompletedProcess[str]:
        proc = subprocess.run(args, cwd=ROOT, text=True, capture_output=True, env=env, check=False)
        commands.append({"args": args, "returncode": proc.returncode, "stdout": proc.stdout[-4000:], "stderr": proc.stderr[-4000:]})
        return proc
    up = run([docker, "compose", "-f", str(compose_path), "up", "-d"])
    time.sleep(8)
    status = service_status(service)
    ok = up.returncode == 0 and any(p["listening"] for p in status["ports"])
    if not keep_running:
        run([docker, "compose", "-f", str(compose_path), "down"])
    return {"mode": "compose", "service": service["id"], "returncode": 0 if ok else 1, "status": status, "commands": commands, "keptRunning": keep_running}


def main() -> int:
    parser = argparse.ArgumentParser(description="Allowlisted LAN Arcade native-service helper")
    parser.add_argument("command", choices=["list", "status", "smoke", "start", "stop"])
    parser.add_argument("service", nargs="?", help="service id for status/smoke/start/stop")
    parser.add_argument("--json", action="store_true", help="print JSON instead of table")
    parser.add_argument("--report-dir", default=str(DEFAULT_REPORT_DIR))
    parser.add_argument("--keep-running", action="store_true", help="for compose smoke/start, leave service running")
    args = parser.parse_args()

    services = services_by_id()
    report_dir = Path(args.report_dir)

    if args.command == "list":
        rows = [service_status(s) for s in services.values()]
        if args.json:
            print(json.dumps(rows, indent=2))
        else:
            print_table(rows)
        return 0

    if not args.service:
        raise SystemExit(f"{args.command} requires a service id")
    service = ensure_service(args.service)

    if args.command == "status":
        row = service_status(service)
        write_report(report_dir, f"status-{service['id']}", row)
        print(json.dumps(row, indent=2) if args.json else "")
        if not args.json:
            print_table([row])
        return 0

    if args.command in {"smoke", "start", "stop"}:
        if args.command == "stop":
            compose = service.get("composeFile")
            if not compose:
                raise SystemExit("stop currently supports compose services only")
            docker = shutil.which("docker")
            if not docker:
                raise SystemExit("docker command not found")
            proc = subprocess.run([docker, "compose", "-f", str(ROOT / str(compose)), "down"], cwd=ROOT, text=True, capture_output=True, check=False)
            result = {"mode": "compose-stop", "service": service["id"], "returncode": proc.returncode, "stdout": proc.stdout.strip(), "stderr": proc.stderr.strip()}
            path = write_report(report_dir, f"stop-{service['id']}", result)
            print(json.dumps({"report": str(path), **result}, indent=2))
            return proc.returncode

        if LOCK_DIR.exists():
            raise SystemExit(f"another native-service action appears active: {LOCK_DIR}")
        LOCK_DIR.mkdir()
        try:
            if args.command == "start":
                result = run_compose_smoke(service, report_dir, keep_running=True)
            elif service["id"] in SCRIPT_SMOKE_IDS:
                result = run_script_smoke(service["id"], report_dir)
            else:
                result = run_compose_smoke(service, report_dir, keep_running=args.keep_running)
        finally:
            try:
                LOCK_DIR.rmdir()
            except OSError:
                pass
        path = write_report(report_dir, f"{args.command}-{service['id']}", result)
        print(json.dumps({"report": str(path), **result}, indent=2))
        return int(result.get("returncode", 1))

    return 2


if __name__ == "__main__":
    raise SystemExit(main())