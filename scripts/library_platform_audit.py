#!/usr/bin/env python3
"""Audit the deployed LAN Arcade library as a platform catalogue.

This is intentionally lightweight: it does not play every game. It checks the
storefront-level promises that users depend on before deeper game smoke tests run.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
from typing import Any, Iterable


def as_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item).strip() for item in value if str(item).strip()]


def blob(game: dict[str, Any]) -> str:
    parts = [
        str(game.get("id", "")),
        str(game.get("title", "")),
        str(game.get("meta", "")),
        str(game.get("description", "")),
        " ".join(as_list(game.get("categories"))),
        " ".join(as_list(game.get("tags"))),
    ]
    return " ".join(parts).lower()


def has_category(game: dict[str, Any], category: str) -> bool:
    return category in as_list(game.get("categories"))


def has_any_category(game: dict[str, Any], categories: Iterable[str]) -> bool:
    return any(has_category(game, category) for category in categories)


def has_text(game: dict[str, Any], needles: Iterable[str]) -> bool:
    text = blob(game)
    return any(needle in text for needle in needles)


def is_emulator(game: dict[str, Any]) -> bool:
    return has_category(game, "emulator") or has_text(game, ["emulator", "game boy", "gbc", "gba", "dos shelf", "rom"])


def is_collection(game: dict[str, Any]) -> bool:
    game_id = str(game.get("id", "")).lower()
    if game_id in {
        "emulator-library",
        "private-gbc-vault",
        "private-dos-classics",
        "private-rom-wave-1",
        "board-games-wave-1",
        "retro-emulator-lab",
    }:
        return True
    return has_text(game, ["vault", "shelf", "collection", "wave 1", "intake"]) and (
        is_emulator(game) or has_category(game, "board-game") or has_category(game, "private")
    )


def is_server_service(game: dict[str, Any]) -> bool:
    return has_text(game, ["lan service", "lan server", "server", "hosted service"])


def is_native_or_server(game: dict[str, Any]) -> bool:
    game_id = str(game.get("id", "")).lower()
    return game_id.endswith("-lan") or is_server_service(game) or has_text(game, ["native", "client required", "installer"])


def is_research(game: dict[str, Any]) -> bool:
    if is_collection(game):
        return has_text(game, ["restore needed", "blocked", "waiting", "research", "candidate"])
    return has_text(game, ["research", "candidate", "blocked", "waiting", "needs qa", "partial smoke", "not yet", "restore needed"])


def is_ready_now(game: dict[str, Any]) -> bool:
    if is_research(game) or has_text(game, ["restore needed", "blocked", "waiting"]):
        return False
    if is_collection(game):
        return True
    return not is_native_or_server(game)


def content_type(game: dict[str, Any]) -> str:
    if is_collection(game):
        return "collection"
    if is_server_service(game):
        return "lan-service"
    if is_native_or_server(game):
        return "native-hub"
    if is_emulator(game):
        return "emulator"
    if has_category(game, "board-game"):
        return "board-game"
    return "browser-game"


def readiness(game: dict[str, Any]) -> str:
    if has_text(game, ["restore needed"]):
        return "restore-needed"
    if has_text(game, ["blocked", "waiting"]):
        return "blocked"
    if is_research(game):
        return "needs-qa"
    if is_server_service(game):
        return "start-on-demand"
    if is_native_or_server(game):
        return "client-install"
    if is_collection(game):
        return "shelf-ready"
    if has_category(game, "private"):
        return "private"
    return "ready-offline"


def action(game: dict[str, Any]) -> str:
    if is_research(game):
        return "review"
    if is_collection(game):
        return "open-shelf"
    if is_server_service(game):
        return "start-join"
    if is_native_or_server(game):
        return "install-play"
    return "play"


def resolve_target(catalog_path: Path, game: dict[str, Any]) -> tuple[str, bool, str]:
    href = str(game.get("path") or f"../{game.get('id', '')}/")
    if href.startswith(("http://", "https://")):
        return href, False, "external"
    target = (catalog_path.parent / href).resolve()
    exists = target.exists() or (target / "index.html").exists()
    return str(target), exists, "local"


def increment(counts: dict[str, int], key: str) -> None:
    counts[key] = counts.get(key, 0) + 1


def audit(catalog_path: Path) -> dict[str, Any]:
    raw = json.loads(catalog_path.read_text())
    games = raw.get("games") if isinstance(raw.get("games"), list) else []
    counts: dict[str, dict[str, int]] = {"content_type": {}, "readiness": {}, "action": {}}
    problems: dict[str, list[dict[str, str]]] = {
        "missing_target": [],
        "external_target": [],
        "thin_metadata": [],
        "missing_age": [],
    }
    for game in games:
        ctype = content_type(game)
        state = readiness(game)
        launch_action = action(game)
        increment(counts["content_type"], ctype)
        increment(counts["readiness"], state)
        increment(counts["action"], launch_action)
        target, exists, target_kind = resolve_target(catalog_path, game)
        item = {"id": str(game.get("id", "")), "title": str(game.get("title", "")), "target": target}
        if target_kind == "external":
            problems["external_target"].append(item)
        elif not exists:
            problems["missing_target"].append(item)
        if len(str(game.get("description", "")).strip()) < 35 or not as_list(game.get("tags")):
            problems["thin_metadata"].append(item)
        if not has_any_category(game, ["age-5-plus", "age-10-plus", "age-13-plus"]):
            problems["missing_age"].append(item)
    return {
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "catalog": str(catalog_path),
        "total_cards": len(games),
        "counts": counts,
        "problems": problems,
    }


def markdown_report(result: dict[str, Any]) -> str:
    lines = [
        "# LAN Arcade Library Platform Audit",
        "",
        f"Generated: `{result['generated_at']}`",
        f"Catalog: `{result['catalog']}`",
        f"Top-level cards: **{result['total_cards']}**",
        "",
        "## Counts",
        "",
    ]
    for group in ["content_type", "readiness", "action"]:
        lines.append(f"### {group.replace('_', ' ').title()}")
        for key, value in sorted(result["counts"][group].items()):
            lines.append(f"- `{key}`: {value}")
        lines.append("")
    lines.append("## Findings")
    for name, items in result["problems"].items():
        lines.append(f"- `{name}`: {len(items)}")
    lines.append("")
    for name in ["missing_target", "external_target", "thin_metadata", "missing_age"]:
        items = result["problems"][name]
        if not items:
            continue
        lines.append(f"### {name.replace('_', ' ').title()}")
        for item in items[:40]:
            lines.append(f"- `{item['id']}` - {item['title']} ({item['target']})")
        if len(items) > 40:
            lines.append(f"- ... {len(items) - 40} more")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit LAN Arcade catalogue platform metadata and launch targets.")
    parser.add_argument("--catalog", default="/var/www/html/mirrors/games/catalog.json")
    parser.add_argument("--output-dir", default="qa/reports/platform-phases/latest-library-platform-audit")
    parser.add_argument("--strict", action="store_true", help="Fail on missing local targets or external launch targets.")
    args = parser.parse_args()

    catalog_path = Path(args.catalog)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    result = audit(catalog_path)
    (output_dir / "report.json").write_text(json.dumps(result, indent=2))
    (output_dir / "REPORT.md").write_text(markdown_report(result))
    print(markdown_report(result))
    if args.strict and (result["problems"]["missing_target"] or result["problems"]["external_target"]):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
