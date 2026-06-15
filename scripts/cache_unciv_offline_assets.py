#!/usr/bin/env python3
"""Cache Unciv client/server release files and official docs for LAN Arcade.

Large binaries are intentionally written to the deployed mirror tree instead of
Git. The generated hub page links to the stable latest/ symlink.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import urllib.request

API_LATEST = "https://api.github.com/repos/yairm210/Unciv/releases/latest"
API_RELEASE_BY_TAG = "https://api.github.com/repos/yairm210/Unciv/releases/tags/{tag}"
DOCS_URL = "https://yairm210.github.io/Unciv/"
USER_AGENT = "LAN-Arcade-Unciv-Cache/1.0"

ASSET_NOTES = {
    "Unciv-signed.apk": {
        "label": "Android APK",
        "audience": "Android phones/tablets",
        "note": "Install directly on Android devices. Enable installing local APKs if Android asks.",
    },
    "Unciv.msi": {
        "label": "Windows installer",
        "audience": "Windows PCs",
        "note": "Best default for Windows laptops/desktops.",
    },
    "Unciv-Windows64.zip": {
        "label": "Windows portable ZIP",
        "audience": "Windows PCs without installer use",
        "note": "Extract and run from a folder when MSI install is not wanted.",
    },
    "Unciv-Linux64.zip": {
        "label": "Linux 64-bit ZIP",
        "audience": "Linux desktops",
        "note": "Extract and run the bundled Linux desktop build.",
    },
    "Unciv.jar": {
        "label": "Desktop JAR",
        "audience": "Java-capable desktops",
        "note": "Cross-platform fallback. Requires a suitable Java runtime on the client device.",
    },
    "UncivServer.jar": {
        "label": "Server JAR",
        "audience": "LAN Arcade/server admins",
        "note": "Cached for rebuilding or repairing the local multiplayer turn server offline.",
    },
    "linuxFilesForJar.zip": {
        "label": "Linux JAR helper files",
        "audience": "Linux desktop JAR users",
        "note": "Small upstream helper package shipped with the release.",
    },
}

ASSET_ORDER = list(ASSET_NOTES)


def request_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.load(response)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, target: Path, expected_size: int | None) -> str:
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and (expected_size is None or target.stat().st_size == expected_size):
        return sha256_file(target)

    tmp = target.with_suffix(target.suffix + ".tmp")
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=120) as response, tmp.open("wb") as out:
        shutil.copyfileobj(response, out)
    if expected_size is not None and tmp.stat().st_size != expected_size:
        tmp.unlink(missing_ok=True)
        raise RuntimeError(f"size mismatch for {target.name}: expected {expected_size}, got {tmp.stat().st_size}")
    tmp.replace(target)
    return sha256_file(target)


def human_size(size: int) -> str:
    value = float(size)
    for unit in ["B", "KB", "MB", "GB"]:
        if value < 1024 or unit == "GB":
            return f"{value:.1f} {unit}" if unit != "B" else f"{int(value)} B"
        value /= 1024
    return f"{size} B"


def write_download_index(root: Path, version: str, release: dict, assets: list[dict]) -> None:
    root.mkdir(parents=True, exist_ok=True)
    version_dir = root / version
    rows = []
    for asset in assets:
        name = asset["name"]
        note = ASSET_NOTES[name]
        rows.append(
            "<article class='card'>"
            f"<h2>{html.escape(note['label'])}</h2>"
            f"<p class='audience'>{html.escape(note['audience'])}</p>"
            f"<p>{html.escape(note['note'])}</p>"
            f"<a class='button' href='{html.escape(version)}/{html.escape(name)}'>Download {html.escape(name)}</a>"
            f"<p class='meta'>{human_size(asset['size'])} - SHA256 <code>{asset['sha256'][:16]}...</code></p>"
            "</article>"
        )
    html_text = f"""<!doctype html>
<html lang='en'>
<head>
  <meta charset='utf-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1'>
  <title>Unciv Offline Downloads</title>
  <style>
    :root {{ color-scheme: dark; --bg:#10130f; --card:#20251f; --line:#3b4635; --text:#f3f5ea; --muted:#c3cbb8; --accent:#9fd356; --ink:#07100c; }}
    * {{ box-sizing: border-box; }}
    body {{ margin:0; font-family: system-ui, -apple-system, Segoe UI, sans-serif; background:var(--bg); color:var(--text); }}
    main {{ width:min(1120px,94vw); margin:0 auto; padding:34px 0 48px; }}
    h1 {{ margin:0 0 8px; font-size:clamp(32px,6vw,64px); line-height:1; }}
    .lede {{ color:var(--muted); max-width:780px; line-height:1.5; }}
    .grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(260px,1fr)); gap:14px; margin-top:22px; }}
    .card {{ border:1px solid var(--line); border-radius:8px; padding:16px; background:var(--card); }}
    .card h2 {{ margin:0 0 5px; font-size:20px; }}
    .audience, .meta {{ color:var(--muted); }}
    .button {{ display:inline-block; margin:8px 0; padding:10px 12px; border-radius:8px; background:var(--accent); color:var(--ink); font-weight:850; text-decoration:none; }}
    code {{ background:#090d09; border:1px solid rgba(255,255,255,.12); border-radius:5px; padding:2px 5px; }}
    .links {{ display:flex; flex-wrap:wrap; gap:10px; margin-top:18px; }}
    .links a {{ color:var(--text); border:1px solid var(--line); border-radius:8px; padding:9px 10px; text-decoration:none; }}
  </style>
</head>
<body>
  <main>
    <h1>Unciv Offline Downloads</h1>
    <p class='lede'>Official Unciv release files cached for LAN Arcade. Version <strong>{html.escape(version)}</strong>, published {html.escape(str(release.get('published_at', 'unknown')))}. Use these when the internet is already unavailable.</p>
    <div class='links'><a href='../../../../unciv-lan/'>Back to Unciv LAN Hub</a><a href='{html.escape(version)}/SHA256SUMS.txt'>SHA256SUMS</a><a href='manifest.json'>Manifest JSON</a></div>
    <section class='grid'>
      {''.join(rows)}
    </section>
  </main>
</body>
</html>
"""
    (root / "index.html").write_text(html_text, encoding="utf-8")
    (version_dir / "index.html").write_text(html_text.replace(f"href='{html.escape(version)}/", "href='"), encoding="utf-8")
    manifest = json.dumps({"version": version, "published_at": release.get("published_at"), "assets": assets}, indent=2) + "\n"
    (root / "manifest.json").write_text(manifest, encoding="utf-8")
    (version_dir / "manifest.json").write_text(manifest, encoding="utf-8")
    sums = "".join(f"{asset['sha256']}  {asset['name']}\n" for asset in assets)
    (version_dir / "SHA256SUMS.txt").write_text(sums, encoding="utf-8")
    latest = root / "latest"
    if latest.is_symlink() or latest.exists():
        if latest.is_dir() and not latest.is_symlink():
            shutil.rmtree(latest)
        else:
            latest.unlink()
    latest.symlink_to(version_dir.name, target_is_directory=True)


def mirror_docs(dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="unciv-docs-") as tmp_name:
        tmp = Path(tmp_name)
        cmd = [
            "wget",
            "--quiet",
            "--mirror",
            "--convert-links",
            "--adjust-extension",
            "--page-requisites",
            "--no-parent",
            "--directory-prefix", str(tmp),
            DOCS_URL,
        ]
        subprocess.run(cmd, check=False)
        source = tmp / "yairm210.github.io" / "Unciv"
        if not source.exists():
            raise RuntimeError(f"wget did not create expected docs mirror at {source}")
        backup = dest.with_name(dest.name + ".backup-before-refresh")
        if backup.exists():
            shutil.rmtree(backup)
        if dest.exists() and any(dest.iterdir()):
            dest.rename(backup)
            dest.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source, dest, dirs_exist_ok=True)
        patch_docs_for_offline(dest)
        (dest / "LAN_ARCADE_SOURCE.txt").write_text(f"Mirrored from {DOCS_URL}\nRefreshed {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}\n", encoding="utf-8")



def patch_docs_for_offline(root: Path) -> None:
    q = chr(34)
    font_prefix = '<link rel=' + q + 'stylesheet' + q + ' href=' + q + 'https://fonts.googleapis.com'
    for path in root.rglob('*.html'):
        text = path.read_text(encoding='utf-8', errors='ignore')
        lines = [line for line in text.splitlines() if font_prefix not in line]
        text = '\n'.join(lines) + ('\n' if text.endswith('\n') else '')
        text = text.replace('name=' + q + 'search' + q, 'name=' + q + 'offline-search-disabled' + q)
        text = text.replace('data-md-component=' + q + 'search' + q, 'data-md-component=' + q + 'search-offline' + q)
        text = text.replace('data-md-component=' + q + 'source' + q, 'data-md-component=' + q + 'source-offline' + q)
        path.write_text(text, encoding='utf-8')
    (root / 'search').mkdir(parents=True, exist_ok=True)
    search_json = '{"config":{"lang":["en"],"separator":"[\\s\\-]+"},"docs":[]}\n'
    (root / 'search' / 'search_index.json').write_text(search_json, encoding='utf-8')
    worker_dir = root / 'assets' / 'javascripts' / 'workers'
    worker_dir.mkdir(parents=True, exist_ok=True)
    worker = "self.onmessage=function(e){self.postMessage({type:1,data:{config:{lang:['en'],separator:'[\\s\\-]+'},docs:[]}})};\n"
    (worker_dir / 'search.2c215733.min.js').write_text(worker, encoding='utf-8')
    (root / 'LAN_ARCADE_OFFLINE_PATCH.txt').write_text('Disabled external fonts, source metadata fetches, and MkDocs search network dependencies for offline LAN Arcade use.\n', encoding='utf-8')

def main() -> int:
    parser = argparse.ArgumentParser(description="Cache Unciv offline downloads and docs for LAN Arcade")
    parser.add_argument("--version", default="latest", help="Release tag to cache, or latest")
    parser.add_argument("--dest", default="/var/www/html/mirrors/games/downloads/native/unciv", help="Download mirror root")
    parser.add_argument("--docs-dest", default="/var/www/html/mirrors/unciv-docs", help="Official docs mirror root")
    parser.add_argument("--skip-downloads", action="store_true")
    parser.add_argument("--skip-docs", action="store_true")
    args = parser.parse_args()

    if not args.skip_downloads:
        release = request_json(API_LATEST if args.version == "latest" else API_RELEASE_BY_TAG.format(tag=args.version))
        version = str(release.get("tag_name") or args.version).lstrip("v")
        assets_by_name = {asset.get("name"): asset for asset in release.get("assets", [])}
        missing = [name for name in ASSET_ORDER if name not in assets_by_name]
        if missing:
            raise RuntimeError("missing expected release assets: " + ", ".join(missing))
        version_dir = Path(args.dest) / version
        version_dir.mkdir(parents=True, exist_ok=True)
        selected_assets = []
        for name in ASSET_ORDER:
            asset = assets_by_name[name]
            print(f"Caching {name} ({human_size(asset.get('size', 0))})", flush=True)
            sha = download(asset["browser_download_url"], version_dir / name, asset.get("size"))
            selected_assets.append({
                "name": name,
                "label": ASSET_NOTES[name]["label"],
                "size": asset.get("size", 0),
                "sha256": sha,
                "browser_download_url": asset.get("browser_download_url"),
            })
        write_download_index(Path(args.dest), version, release, selected_assets)
        print(f"DOWNLOADS_READY={Path(args.dest)}")

    if not args.skip_docs:
        print(f"Mirroring official docs from {DOCS_URL}", flush=True)
        mirror_docs(Path(args.docs_dest))
        print(f"DOCS_READY={Path(args.docs_dest)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
