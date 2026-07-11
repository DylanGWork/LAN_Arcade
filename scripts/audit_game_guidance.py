#!/usr/bin/env python3
"""Audit player guidance across LAN Arcade launcher and nested game shelves."""

from __future__ import annotations

import argparse
import csv
import json
import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlparse

GUIDE_TERMS = (
    "how to play",
    "quick manual",
    "manual",
    "getting started",
    "beginner guide",
    "tutorial",
    "controls",
    "gameplay",
    "rules",
)
LINK_TERMS = ("manual", "guide", "wiki", "docs", "help", "tutorial")
OPERATOR_TERMS = ("mirror", "operator", "qa report", "source notes")


class PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.skip_depth = 0
        self.footer_depth = 0
        self.text_parts: list[str] = []
        self.links: list[dict[str, object]] = []
        self._link: dict[str, object] | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attrs_map = dict(attrs)
        if tag in {"script", "style", "template"}:
            self.skip_depth += 1
        if tag == "footer":
            self.footer_depth += 1
        if tag == "a":
            self._link = {
                "href": attrs_map.get("href") or "",
                "text": [],
                "inFooter": self.footer_depth > 0,
            }

    def handle_endtag(self, tag: str) -> None:
        if tag in {"script", "style", "template"} and self.skip_depth:
            self.skip_depth -= 1
        if tag == "a" and self._link is not None:
            self._link["text"] = " ".join(self._link["text"]).strip()
            self.links.append(self._link)
            self._link = None
        if tag == "footer" and self.footer_depth:
            self.footer_depth -= 1

    def handle_data(self, data: str) -> None:
        if self.skip_depth:
            return
        value = " ".join(data.split())
        if not value:
            return
        self.text_parts.append(value)
        if self._link is not None:
            self._link["text"].append(value)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="/var/www/html/mirrors")
    parser.add_argument("--catalog", default="/var/www/html/mirrors/games/catalog.json")
    parser.add_argument("--classic-pc", default="/var/www/html/mirrors/private-dos-vault/manifest.json")
    parser.add_argument("--game-boy", default="/var/www/html/mirrors/private-rom-vault/manifest.json")
    parser.add_argument("--recipes", default="config/site-mirror-recipes.json")
    parser.add_argument("--guide-sources", default="config/game-guide-sources.json")
    parser.add_argument("--output-dir", default="qa/reports/guidance-audit")
    return parser.parse_args()


def load_json(path: Path, fallback: object) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return fallback


def slug_base(game_id: str) -> str:
    value = game_id.lower()
    for suffix in ("-lan", "-gba", "-gbc", "-gb", "-scummvm", "-site", "-docs", "-wiki"):
        if value.endswith(suffix):
            value = value[: -len(suffix)]
    return re.sub(r"[^a-z0-9]+", "-", value).strip("-")


def catalog_target(root: Path, game: dict[str, object]) -> Path:
    raw = str(game.get("path") or "")
    parsed = urlparse(raw)
    path = unquote(parsed.path)
    if "/mirrors/" in path:
        relative = path.split("/mirrors/", 1)[1]
    elif path.startswith("../"):
        relative = path[3:]
    elif path.startswith("./"):
        relative = "games/" + path[2:]
    elif path.startswith("/"):
        relative = path.lstrip("/")
    else:
        relative = path or str(game.get("id") or "")
    target = root / relative
    if target.is_dir() or not target.suffix:
        target = target / "index.html"
    return target


def resolve_local_href(page: Path, href: str) -> Path | None:
    parsed = urlparse(href)
    if parsed.scheme in {"http", "https"} or parsed.netloc or not parsed.path:
        return None
    target = (page.parent / unquote(parsed.path)).resolve()
    if target.is_dir() or not target.suffix:
        target = target / "index.html"
    return target


def scan_catalog(
    root: Path,
    catalog: dict[str, object],
    recipes: dict[str, object],
    guide_sources: list[dict[str, object]],
) -> list[dict[str, object]]:
    recipe_rows = []
    for slug, recipe in recipes.items():
        if not isinstance(recipe, dict):
            continue
        dest = str(recipe.get("dest") or slug)
        recipe_rows.append({
            "slug": slug,
            "base": slug_base(dest),
            "dest": dest,
            "deployed": (
                (root / dest / "index.html").is_file()
                and not (root / dest / "LAN_ARCADE_DOCS_BLOCKED.txt").exists()
            ),
            "source": recipe.get("url") or (recipe.get("pages") or [""])[0],
            "gameIds": [str(item) for item in recipe.get("gameIds", [])],
        })

    source_by_game = {str(item.get("gameId")): item for item in guide_sources}
    rows = []
    for game in catalog.get("games", []):
        game_id = str(game.get("id") or "")
        page = catalog_target(root, game)
        parser = PageParser()
        page_text = ""
        if page.is_file():
            try:
                parser.feed(page.read_text(encoding="utf-8", errors="ignore"))
                page_text = " ".join(parser.text_parts).lower()
            except OSError:
                pass

        embedded = sorted({term for term in GUIDE_TERMS if term in page_text})
        local_links = []
        external_links = []
        for link in parser.links:
            href = str(link["href"])
            label = str(link["text"])
            signal = (href + " " + label).lower()
            if not any(term in signal for term in LINK_TERMS):
                continue
            target = resolve_local_href(page, href)
            if target is None:
                if urlparse(href).scheme in {"http", "https"}:
                    external_links.append({"href": href, "label": label})
                continue
            local_links.append({
                "href": href,
                "label": label,
                "exists": target.is_file(),
                "inFooter": bool(link["inFooter"]),
                "operatorWording": any(term in label.lower() for term in OPERATOR_TERMS),
            })

        base = slug_base(game_id)
        matching_recipes = [
            recipe for recipe in recipe_rows
            if game_id in recipe["gameIds"] or (not recipe["gameIds"] and recipe["base"] == base)
        ]
        known_source = source_by_game.get(game_id)
        usable_links = [link for link in local_links if link["exists"]]
        visible_links = [link for link in usable_links if not link["inFooter"] and not link["operatorWording"]]
        buried_links = [link for link in usable_links if link not in visible_links]
        has_basic = bool(embedded or usable_links)
        has_specific = bool(usable_links or any(item["deployed"] for item in matching_recipes))
        status = (
            "visible-local-guide" if visible_links
            else "buried-local-guide" if buried_links
            else "known-local-mirror-unlinked" if any(item["deployed"] for item in matching_recipes)
            else "embedded-quick-guide" if embedded
            else "known-upstream-not-local" if matching_recipes
            else "official-guide-found-not-cached" if known_source
            else "external-guide-only" if external_links
            else "missing"
        )
        rows.append({
            "scope": "catalog",
            "id": game_id,
            "title": str(game.get("title") or game_id),
            "page": str(page),
            "pageExists": page.is_file(),
            "status": status,
            "hasBasicHelp": has_basic,
            "hasGameSpecificGuide": has_specific,
            "embeddedSignals": embedded,
            "localGuideLinks": local_links,
            "externalGuideLinks": external_links,
            "knownRecipes": matching_recipes,
            "knownGuideSource": known_source,
            "guidePriority": str((known_source or {}).get("priority") or "untriaged"),
        })
    return rows


def scan_classic_pc(manifest: dict[str, object]) -> list[dict[str, object]]:
    rows = []
    for game in manifest.get("games", []):
        controls = [str(item) for item in game.get("controls", []) if str(item).strip()]
        manuals = [item for item in game.get("manuals", []) if item]
        rows.append({
            "scope": "classic-pc",
            "id": str(game.get("id") or ""),
            "title": str(game.get("title") or game.get("id") or ""),
            "status": "manual" if manuals else "controls-only" if controls else "missing",
            "hasBasicHelp": bool(controls or manuals),
            "hasGameSpecificGuide": bool(manuals),
            "controls": controls,
            "manuals": manuals,
        })
    return rows


def scan_game_boy(manifest: dict[str, object]) -> list[dict[str, object]]:
    return [{
        "scope": "game-boy",
        "id": str(game.get("id") or ""),
        "title": str(game.get("title") or game.get("id") or ""),
        "status": "platform-controls-only",
        "hasBasicHelp": True,
        "hasGameSpecificGuide": False,
    } for game in manifest.get("games", [])]


def summarize(rows: list[dict[str, object]]) -> dict[str, object]:
    scopes = {}
    for scope in sorted({str(row["scope"]) for row in rows}):
        scoped = [row for row in rows if row["scope"] == scope]
        scopes[scope] = {
            "records": len(scoped),
            "withBasicHelp": sum(bool(row["hasBasicHelp"]) for row in scoped),
            "missingBasicHelp": sum(not bool(row["hasBasicHelp"]) for row in scoped),
            "withGameSpecificGuide": sum(bool(row["hasGameSpecificGuide"]) for row in scoped),
            "missingGameSpecificGuide": sum(not bool(row["hasGameSpecificGuide"]) for row in scoped),
            "officialGuideSourceFound": sum(bool(row.get("knownGuideSource")) for row in scoped),
            "needsSourceResearch": sum(not bool(row.get("knownGuideSource")) and not bool(row["hasGameSpecificGuide"]) for row in scoped),
            "statuses": {
                status: sum(row["status"] == status for row in scoped)
                for status in sorted({str(row["status"]) for row in scoped})
            },
        }
    return {"scopes": scopes, "totalSourceRecords": len(rows)}


def write_reports(output_dir: Path, rows: list[dict[str, object]], summary: dict[str, object]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "guidance-audit.json").write_text(
        json.dumps({"summary": summary, "rows": rows}, indent=2) + "\n",
        encoding="utf-8",
    )
    with (output_dir / "guidance-audit.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=[
            "scope", "id", "title", "status", "hasBasicHelp", "hasGameSpecificGuide", "page",
        ])
        writer.writeheader()
        for row in rows:
            writer.writerow({key: row.get(key, "") for key in writer.fieldnames})

    lines = ["# Game Guidance Audit", "", "## Summary", ""]
    lines.append("| Scope | Records | Basic help | Missing basic help | Local game-specific guide | Missing local guide | Official source found | Needs source research |")
    lines.append("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
    for scope, metrics in summary["scopes"].items():
        lines.append(
            f"| {scope} | {metrics['records']} | {metrics['withBasicHelp']} | "
            f"{metrics['missingBasicHelp']} | {metrics['withGameSpecificGuide']} | "
            f"{metrics['missingGameSpecificGuide']} | {metrics['officialGuideSourceFound']} | "
            f"{metrics['needsSourceResearch']} |"
        )
    lines.extend(["", "## Catalog Gaps", ""])
    for row in rows:
        if row["scope"] == "catalog" and row["status"] not in {"visible-local-guide", "embedded-quick-guide"}:
            lines.append(f"- **{row['title']}** (`{row['id']}`): {row['status']}")
    lines.extend([
        "",
        "## Interpretation",
        "",
        "- Basic help means a local quick-start, controls, tutorial, rules, or reachable local guide exists.",
        "- Game-specific guide excludes generic emulator controls.",
        "- Game Boy titles currently share platform controls but do not have per-title manual metadata.",
        "- Board-game research rows are not counted until they have a playable adapter.",
        "",
    ])
    (output_dir / "guidance-audit.md").write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    args = parse_args()
    root = Path(args.root)
    catalog = load_json(Path(args.catalog), {"games": []})
    classic_pc = load_json(Path(args.classic_pc), {"games": []})
    game_boy = load_json(Path(args.game_boy), {"games": []})
    recipes = load_json(Path(args.recipes), {})
    guide_sources = load_json(Path(args.guide_sources), [])
    rows = (
        scan_catalog(root, catalog, recipes, guide_sources)
        + scan_classic_pc(classic_pc)
        + scan_game_boy(game_boy)
    )
    summary = summarize(rows)
    write_reports(Path(args.output_dir), rows, summary)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
