#!/usr/bin/env python3
import os
import socket
import subprocess
import sys


def port_open(port):
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=1):
            return True
    except OSError:
        return False


checks = [
    port_open(5900),
    port_open(6080),
    subprocess.run(
        ["/usr/bin/pgrep", "-f", "^/usr/games/"],
        stdout=subprocess.DEVNULL,
        check=False,
    ).returncode == 0,
    subprocess.run(
        ["/usr/bin/xdotool", "search", "--onlyvisible", "--name", "."],
        env={**os.environ, "DISPLAY": ":0"},
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    ).returncode == 0,
]
sys.exit(0 if all(checks) else 1)
