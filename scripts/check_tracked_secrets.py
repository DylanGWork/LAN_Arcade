#!/usr/bin/env python3
"""Fail when tracked files contain common credential material."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SENSITIVE_KEYS = (
    "MARIADB_ROOT_PASSWORD",
    "MARIADB_PASSWORD",
    "MYSQL_ROOT_PASSWORD",
    "MYSQL_PASSWORD",
    "SMTP_PASSWORD",
    "GITHUB_TOKEN",
    "GH_TOKEN",
    "API_KEY",
    "PRIVATE_KEY",
)
ASSIGNMENT = re.compile(
    rf"(?i)\\b(?:{'|'.join(SENSITIVE_KEYS)})\\s*[:=]\\s*[\\\"']?([^\\\"'\\s#,]+)"
)
COMPOSE_DEFAULT = re.compile(
    rf"\\$\\{{(?:{'|'.join(SENSITIVE_KEYS)}):-([^}}]+)\\}}",
    re.IGNORECASE,
)
TOKEN_PATTERNS = (
    ("GitHub personal access token", re.compile(r"\\bgithub_pat_[A-Za-z0-9_]+\\b")),
    ("GitHub token", re.compile(r"\\bgh[pousr]_[A-Za-z0-9]{20,}\\b")),
    ("private key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
)
PLACEHOLDERS = {
    "changeme",
    "change-me",
    "example",
    "placeholder",
    "redacted",
    "required",
    "unset",
}


def tracked_files() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    return [ROOT / item for item in result.stdout.decode().split("\0") if item]


def is_placeholder(value: str) -> bool:
    normalized = value.strip().strip("'\"").lower()
    return (
        not normalized
        or "$" in normalized
        or "<" in normalized
        or ">" in normalized
        or normalized in PLACEHOLDERS
        or normalized.endswith("_file")
    )


def main() -> int:
    findings: list[str] = []
    for path in tracked_files():
        relative = path.relative_to(ROOT)
        lowered_parts = [part.lower() for part in relative.parts]
        if (
            (relative.name == ".env" or relative.name.startswith(".env."))
            and not relative.name.endswith(".example")
        ) or "secrets" in lowered_parts:
            findings.append(f"{relative}: tracked sensitive path")

        try:
            if path.stat().st_size > 2_000_000:
                continue
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue

        for line_number, line in enumerate(text.splitlines(), 1):
            assignment = ASSIGNMENT.search(line)
            if assignment and not is_placeholder(assignment.group(1)):
                findings.append(f"{relative}:{line_number}: literal secret assignment")
            default = COMPOSE_DEFAULT.search(line)
            if default and not is_placeholder(default.group(1)):
                findings.append(f"{relative}:{line_number}: insecure secret default")
            for label, pattern in TOKEN_PATTERNS:
                if pattern.search(line):
                    findings.append(f"{relative}:{line_number}: {label}")

    if findings:
        print("Tracked secret scan failed:")
        for finding in sorted(set(findings)):
            print(f"  {finding}")
        return 1

    print("Tracked secret scan passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
