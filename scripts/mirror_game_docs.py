#!/usr/bin/env python3
"""Mirror official game sites/wikis/manual pages for LAN Arcade.

This centralizes the wget pattern that older intake scripts duplicated. It writes
only under /var/www/html/mirrors by default, stages downloads first, keeps a
single previous backup, strips common tracker/font references, and leaves a small
source/patch note in the mirrored folder.
"""
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
from urllib.parse import urlparse

DEFAULT_MIRRORS_ROOT = Path("/var/www/html/mirrors")
DEFAULT_USER_AGENT = "LAN-Arcade-Docs-Mirror/1.0"
COMMON_REJECT_RE = r"(logout|login|signup|register|action=edit|Special:|printable=yes|oldid=|diff=|User:)"
EXTERNAL_NOISE = (
    "googletagmanager.com",
    "google-analytics.com",
    "fonts.googleapis.com",
    "fonts.gstatic.com",
    "doubleclick.net",
    "facebook.net",
    "twitter.com/widgets",
)


def utc_stamp() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def safe_dest(root: Path, dest_name: str) -> Path:
    root = root.resolve()
    dest = (root / dest_name).resolve()
    if dest != root and root not in dest.parents:
        raise SystemExit(f"refusing destination outside mirror root: {dest}")
    if dest == root:
        raise SystemExit("destination must be a child directory, not the mirror root")
    return dest


def load_recipe(path: Path | None, slug: str | None) -> dict:
    if not path:
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    if slug:
        if slug not in data:
            raise SystemExit(f"recipe slug not found: {slug}")
        return dict(data[slug])
    if len(data) == 1:
        return dict(next(iter(data.values())))
    raise SystemExit("recipe file has multiple entries; pass --slug")


def page_args_from(recipe: dict, cli_pages: list[str]) -> list[str]:
    pages = cli_pages or recipe.get("pages") or []
    if not pages and recipe.get("url"):
        pages = [recipe["url"]]
    if not pages:
        raise SystemExit("at least one --page or recipe pages/url is required")
    return [str(page) for page in pages]


def copy_source_from_stage(stage: Path, source_subdir: str | None) -> Path:
    if source_subdir:
        source = stage / source_subdir
        if source.exists():
            return source
        # Some wget versions include scheme/path fragments differently. Fall
        # back to a suffix match before failing.
        hits = [p for p in stage.rglob("*") if p.is_dir() and p.as_posix().endswith(source_subdir.strip("/"))]
        if hits:
            return hits[0]
        raise RuntimeError(f"expected mirrored source folder not found: {source}")
    html_dirs = []
    for child in stage.iterdir():
        if child.is_dir() and list(child.rglob("*.html")):
            html_dirs.append(child)
    if len(html_dirs) == 1:
        return html_dirs[0]
    if list(stage.rglob("*.html")):
        return stage
    raise RuntimeError("wget did not produce any HTML pages")


def patch_html_for_offline(root: Path) -> dict:
    changed = 0
    scanned = 0
    for path in root.rglob("*.html"):
        scanned += 1
        text = path.read_text(encoding="utf-8", errors="ignore")
        lines = [line for line in text.splitlines() if not any(noise in line for noise in EXTERNAL_NOISE)]
        patched = "\n".join(lines) + ("\n" if text.endswith("\n") else "")
        patched = patched.replace('data-md-component="search"', 'data-md-component="search-offline"')
        patched = patched.replace('data-md-component="source"', 'data-md-component="source-offline"')
        if patched != text:
            path.write_text(patched, encoding="utf-8")
            changed += 1
    (root / "LAN_ARCADE_OFFLINE_PATCH.txt").write_text(
        "Mirrored for LAN Arcade. Common external tracker/font/search widgets were stripped where practical.\n",
        encoding="utf-8",
    )
    return {"html_scanned": scanned, "html_changed": changed}


def make_root_index(dest: Path, title: str, pages: list[str]) -> None:
    if (dest / "index.html").exists():
        return
    html_pages = sorted(p.relative_to(dest).as_posix() for p in dest.rglob("*.html"))
    links = "".join(f"<li><a href='{html.escape(p)}'>{html.escape(p)}</a></li>" for p in html_pages[:120])
    if not links:
        links = "<li>No mirrored HTML pages were found.</li>"
    source = html.escape(", ".join(pages))
    body = f"""<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'><title>{html.escape(title)} Offline Guide</title><style>body{{margin:0;font-family:system-ui,Segoe UI,sans-serif;background:#101316;color:#f4f8f8}}main{{max-width:980px;margin:0 auto;padding:42px 20px}}a{{color:#9ec9ff}}p,li{{color:#c4d0d4;line-height:1.55}}.panel{{border:1px solid #33424b;border-radius:8px;background:#171f25;padding:18px}}</style></head><body><main><p><a href='../games/'>Back to Game Library</a></p><h1>{html.escape(title)} Offline Guide</h1><div class='panel'><p>Saved from: {source}</p></div><h2>Available Pages</h2><ul>{links}</ul></main></body></html>"""
    (dest / "index.html").write_text(body, encoding="utf-8")


def write_blocker(dest: Path, title: str, pages: list[str], detail: str) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    (dest / "LAN_ARCADE_DOCS_BLOCKED.txt").write_text(detail, encoding="utf-8")
    body = f"""<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'><title>{html.escape(title)} Offline Guide</title><style>body{{margin:0;font-family:system-ui,Segoe UI,sans-serif;background:#101316;color:#f4f8f8}}main{{max-width:900px;margin:0 auto;padding:42px 20px}}a{{color:#9ec9ff}}p,li{{color:#c4d0d4;line-height:1.55}}.panel{{border:1px solid #33424b;border-radius:8px;background:#171f25;padding:18px}}code{{white-space:pre-wrap;color:#ffe08a}}</style></head><body><main><p><a href='../games/'>Back to Game Library</a></p><h1>{html.escape(title)} Offline Guide</h1><div class='panel'><p>The guide could not be saved automatically. This page records the blocker so it can be fixed later.</p><p>Source pages: {html.escape(', '.join(pages))}</p><code>{html.escape(detail)}</code></div></main></body></html>"""
    (dest / "index.html").write_text(body, encoding="utf-8")


def publish(staged_source: Path, dest: Path, title: str, pages: list[str], source_note: str) -> dict:
    backup = dest.with_name(dest.name + ".backup-before-refresh")
    tmp_dest = dest.with_name(dest.name + f".new-{int(time.time())}")
    if tmp_dest.exists():
        shutil.rmtree(tmp_dest)
    shutil.copytree(staged_source, tmp_dest)
    patch_result = patch_html_for_offline(tmp_dest)
    make_root_index(tmp_dest, title, pages)
    (tmp_dest / "LAN_ARCADE_SOURCE.txt").write_text(
        f"Mirrored from {source_note}\nRefreshed {utc_stamp()}\n",
        encoding="utf-8",
    )
    if backup.exists():
        shutil.rmtree(backup)
    if dest.exists() and any(dest.iterdir()):
        dest.rename(backup)
    elif dest.exists():
        shutil.rmtree(dest)
    tmp_dest.rename(dest)
    return patch_result


def validate(dest: Path) -> dict:
    html_pages = list(dest.rglob("*.html")) if dest.exists() else []
    noisy = []
    for path in html_pages[:500]:
        text = path.read_text(encoding="utf-8", errors="ignore")
        hits = [noise for noise in EXTERNAL_NOISE if noise in text]
        if hits:
            noisy.append({"path": path.relative_to(dest).as_posix(), "hits": hits})
    blocked = (dest / "LAN_ARCADE_DOCS_BLOCKED.txt").exists()
    has_index = (dest / "index.html").exists()
    return {
        "dest": str(dest),
        "exists": dest.exists(),
        "html_pages": len(html_pages),
        "has_index": has_index,
        "blocked": blocked,
        "usable": bool(dest.exists() and has_index and html_pages and not blocked),
        "external_noise_pages": noisy[:20],
    }


def run_wget(
    stage: Path, pages: list[str], level: int, timeout: int, tries: int,
    reject_regex: str, user_agent: str, no_parent: bool, recursive: bool,
) -> int:
    cmd = [
        "wget",
        "--quiet",
        "--convert-links",
        "--adjust-extension",
        "--page-requisites",
        "--timeout", str(timeout),
        "--tries", str(tries),
        "--user-agent", user_agent,
        "--reject-regex", reject_regex,
        "--directory-prefix", str(stage),
    ]
    if recursive:
        cmd.extend(["--recursive", "--level", str(level)])
        if no_parent:
            cmd.append("--no-parent")
    else:
        cmd.append("--force-directories")
    cmd.extend(pages)
    return subprocess.run(cmd, check=False).returncode


def main() -> int:
    parser = argparse.ArgumentParser(description="Mirror official game sites/wikis/manuals into /mirrors")
    parser.add_argument("--recipe", type=Path, help="JSON recipe file")
    parser.add_argument("--slug", help="recipe key to use")
    parser.add_argument("--title", help="display title")
    parser.add_argument("--dest", help="destination folder name under mirror root")
    parser.add_argument("--source-subdir", help="expected wget output subfolder, e.g. wiki.openttd.org")
    parser.add_argument("--page", action="append", default=[], help="source page URL; may repeat")
    parser.add_argument("--level", type=int, help="wget recursion depth")
    parser.add_argument("--timeout", type=int, default=20)
    parser.add_argument("--tries", type=int, default=2)
    parser.add_argument("--reject-regex", default=COMMON_REJECT_RE)
    parser.add_argument("--user-agent", default=DEFAULT_USER_AGENT)
    parser.add_argument("--mirror-root", type=Path, default=DEFAULT_MIRRORS_ROOT)
    parser.add_argument("--allow-parent", action="store_true", help="omit wget --no-parent")
    parser.add_argument("--validate-only", action="store_true", help="validate an existing destination without network")
    parser.add_argument("--repair-existing", action="store_true", help="patch existing files and add a root index without network")
    parser.add_argument("--report", type=Path, help="write JSON report")
    args = parser.parse_args()

    recipe = load_recipe(args.recipe, args.slug)
    pages = page_args_from(recipe, args.page) if (not args.validate_only or args.repair_existing) else []
    title = args.title or recipe.get("title") or args.slug or "Game Docs"
    dest_name = args.dest or recipe.get("dest") or args.slug
    if not dest_name:
        raise SystemExit("--dest or recipe dest/slug is required")
    dest = safe_dest(args.mirror_root, str(dest_name))

    if args.repair_existing:
        if not dest.exists():
            raise SystemExit(f"cannot repair missing destination: {dest}")
        patch_result = patch_html_for_offline(dest)
        make_root_index(dest, title, pages)
        (dest / "LAN_ARCADE_REPAIR.txt").write_text(f"Existing mirror repaired without network on {utc_stamp()}\n", encoding="utf-8")
        result = {"mode": "repair-existing", **patch_result, **validate(dest)}
    elif args.validate_only:
        result = {"mode": "validate-only", **validate(dest)}
    else:
        source_subdir = args.source_subdir or recipe.get("source_subdir")
        level = args.level if args.level is not None else int(recipe.get("level", 2))
        recursive = bool(recipe.get("recursive", True))
        source_note = recipe.get("url") or ", ".join(pages)
        with tempfile.TemporaryDirectory(prefix=f"lan-arcade-docs-{dest.name}-") as tmp_name:
            stage = Path(tmp_name)
            status = run_wget(
                stage, pages, level, args.timeout, args.tries, args.reject_regex,
                args.user_agent, not args.allow_parent, recursive,
            )
            try:
                source = copy_source_from_stage(stage, source_subdir)
                patch_result = publish(source, dest, title, pages, source_note)
                result = {"mode": "mirror", "status": "ready", "wget_status": status, **patch_result, **validate(dest)}
            except Exception as exc:
                detail = f"wget_status={status}\nerror={exc}\nchecked={utc_stamp()}\n"
                write_blocker(dest, title, pages, detail)
                result = {"mode": "mirror", "status": "blocked", "wget_status": status, "error": str(exc), **validate(dest)}

    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if result.get("usable") else 1


if __name__ == "__main__":
    raise SystemExit(main())
