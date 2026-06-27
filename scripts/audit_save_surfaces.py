#!/usr/bin/env python3
"""Audit LAN Arcade save/profile storage surfaces.

This script is intentionally read-only. It scans known launcher/game/API paths for
browser storage, emulator runtime, and save API markers so account-save work can
be planned from evidence instead of one-off greps.
"""
from __future__ import annotations

import argparse
import datetime as dt
import html
import os
import re
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path

TEXT_EXTS = {
    ".cjs", ".css", ".html", ".js", ".json", ".jsx", ".md", ".mjs",
    ".py", ".sh", ".sql", ".ts", ".tsx", ".txt", ".yml", ".yaml",
}
EXCLUDE_DIRS = {".git", "node_modules", "dist", "build", ".cache", "qa"}
MAX_BYTES = 2_000_000
MAX_MATCHES_PER_FILE = 8

SURFACES = {
    "browser_storage": [r"localStorage", r"sessionStorage"],
    "indexeddb_filesystem": [r"indexedDB", r"IDBFS", r"indexedDB\.open", r"FS\.syncfs"],
    "emulatorjs": [r"EmulatorJS", r"EJS_", r"emulatorjs", r"EJS_player"],
    "js_dos": [r"js-dos", r"Dos\(", r"DosBundle", r"dosbox", r"\.jsdos"],
    "account_save_api": [r"account/saves", r"AccountSave", r"account_save_slots", r"save vault"],
    "game_save_terms": [r"saveState", r"saveData", r"autosave", r"SaveSystem", r"saveGame", r"loadGame", r"\.sav", r"battery"],
}
COMPILED = {name: re.compile("|".join(parts), re.I) for name, parts in SURFACES.items()}


@dataclass
class Hit:
    path: str
    surface: str
    line: int
    snippet: str


def iter_files(root: Path):
    if root.is_file():
        yield root
        return
    if not root.exists():
        return
    for current, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        base = Path(current)
        for name in files:
            path = base / name
            if path.suffix.lower() not in TEXT_EXTS:
                continue
            try:
                if path.stat().st_size > MAX_BYTES:
                    continue
            except OSError:
                continue
            yield path


def default_repo_targets(repo: Path) -> list[Path]:
    targets = [
        repo / "local-games",
        repo / "packages",
        repo / "services",
        repo / "scripts",
        repo / "setup_lan_arcade.sh",
    ]
    return [p for p in targets if p.exists()]


def default_mirror_targets(mirrors: Path | None) -> list[Path]:
    if not mirrors:
        return []
    candidates = [
        mirrors / "games" / "index.html",
        mirrors / "games" / "account" / "index.html",
        mirrors / "private-dos-vault" / "index.html",
        mirrors / "private-dos-vault" / "play.html",
        mirrors / "private-dos-vault" / "manifest.json",
        mirrors / "private-rom-vault" / "play.html",
        mirrors / "private-rom-vault" / "manifest.json",
        mirrors / "private-rom-wave-1" / "play.html",
        mirrors / "private-rom-wave-1" / "manifest.json",
    ]
    return [p for p in candidates if p.exists()]


def rel(path: Path, roots: list[Path]) -> str:
    for root in roots:
        try:
            return str(path.relative_to(root))
        except ValueError:
            pass
    return str(path)


def scan(paths: list[Path], display_roots: list[Path]) -> list[Hit]:
    hits: list[Hit] = []
    seen = set()
    for target in paths:
        for path in iter_files(target):
            resolved = path.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            try:
                text = path.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            lines = text.splitlines()
            per_file = 0
            for index, line in enumerate(lines, 1):
                matched = [name for name, pattern in COMPILED.items() if pattern.search(line)]
                if not matched:
                    continue
                snippet = html.escape(line.strip()[:180])
                for surface in matched:
                    hits.append(Hit(rel(path, display_roots), surface, index, snippet))
                    per_file += 1
                    if per_file >= MAX_MATCHES_PER_FILE:
                        break
                if per_file >= MAX_MATCHES_PER_FILE:
                    break
    return hits


def classify(path: str) -> str:
    if path.startswith("services/arcade-api"):
        return "server API"
    if path.startswith("setup_lan_arcade.sh") or path.startswith("games/index.html") or path.startswith("games/account"):
        return "generated library UI"
    if "private-dos-vault" in path or "build_private_dos_vault" in path:
        return "classic PC / js-dos"
    if "private-rom" in path or "emulator" in path or "-gb" in path or "-gba" in path or "-gbc" in path or "rom_vault" in path:
        return "retro emulator"
    if path.startswith("local-games/"):
        return "browser game"
    return "support tooling"


def write_markdown(hits: list[Hit]) -> str:
    now = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    by_surface = Counter(hit.surface for hit in hits)
    by_class = Counter(classify(hit.path) for hit in hits)
    files_by_class: dict[str, set[str]] = defaultdict(set)
    surfaces_by_file: dict[str, set[str]] = defaultdict(set)
    examples_by_file: dict[str, list[Hit]] = defaultdict(list)
    for hit in hits:
        cls = classify(hit.path)
        files_by_class[cls].add(hit.path)
        surfaces_by_file[hit.path].add(hit.surface)
        if len(examples_by_file[hit.path]) < 3:
            examples_by_file[hit.path].append(hit)

    lines = [
        "# Save Surface Inventory",
        "",
        f"Generated: {now}",
        "",
        "This is a read-only heuristic scan of known LAN Arcade launcher, game, and API paths.",
        "It identifies places that may hold user progress, save state, settings, or launcher activity.",
        "",
        "## Summary",
        "",
        f"- Matching files: {len(surfaces_by_file)}",
        f"- Matching lines sampled: {len(hits)}",
        "",
        "### By Surface",
        "",
    ]
    for name, count in sorted(by_surface.items()):
        lines.append(f"- {name}: {count}")
    lines.extend(["", "### By Area", ""])
    for name, count in sorted(by_class.items()):
        lines.append(f"- {name}: {count} sampled matches across {len(files_by_class[name])} files")

    lines.extend(["", "## Files", ""])
    for path in sorted(surfaces_by_file):
        surfaces = ", ".join(sorted(surfaces_by_file[path]))
        lines.append(f"### `{path}`")
        lines.append(f"Area: {classify(path)}  ")
        lines.append(f"Surfaces: {surfaces}")
        lines.append("")
        for hit in examples_by_file[path]:
            lines.append(f"- L{hit.line} `{hit.surface}`: {hit.snippet}")
        lines.append("")

    lines.extend([
        "## Adapter Implications",
        "",
        "- Server API account-save routes now exist, but launchers still need adapters before saves are truly account-scoped.",
        "- Generated library/account pages use browser storage for session convenience and recent play cache; server recent activity is the stronger account source.",
        "- Browser games with direct localStorage save systems are the safest first account-save adapter candidates, after confirming exact key names per game.",
        "- EmulatorJS and js-dos save behavior should be treated as runtime-specific until export/import can be smoke-tested without corrupting existing saves.",
        "- Native/LAN-service games should keep server-side or game-native save/account storage and only mirror summary activity into the arcade account system.",
    ])
    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit LAN Arcade save/profile storage surfaces")
    parser.add_argument("--repo", default=".", help="LAN Arcade repo root")
    parser.add_argument("--mirrors", default="", help="optional /var/www/html/mirrors path")
    parser.add_argument("--output", default="", help="optional Markdown output path")
    args = parser.parse_args()

    repo = Path(args.repo).resolve()
    mirrors = Path(args.mirrors).resolve() if args.mirrors else None
    targets = default_repo_targets(repo) + default_mirror_targets(mirrors)
    display_roots = [repo]
    if mirrors:
        display_roots.append(mirrors)
    hits = scan(targets, display_roots)
    markdown = write_markdown(hits)
    if args.output:
        Path(args.output).write_text(markdown, encoding="utf-8")
    else:
        print(markdown, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
