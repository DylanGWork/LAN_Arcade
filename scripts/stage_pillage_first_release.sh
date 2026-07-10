#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${PILLAGE_FIRST_RELEASE_CONFIG:-$ROOT/config/pillage-first-release.json}"
RELEASE_DIR="${1:-}"
OUTPUT_DIR="${2:-}"

if [[ -z "$RELEASE_DIR" ]]; then
  RELEASE_DIR="$(python3 - "$CONFIG" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1]))["releasePath"])
PY
)"
fi

if [[ -z "$OUTPUT_DIR" ]]; then
  short="$(python3 - "$CONFIG" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1]))["expectedCommit"][:12])
PY
)"
  OUTPUT_DIR="/home/dylan/backups/lan-arcade/pillage-first-extraction/staged-$short"
fi

RELEASE_DIR="$(realpath -m "$RELEASE_DIR")"
OUTPUT_DIR="$(realpath -m "$OUTPUT_DIR")"
case "$OUTPUT_DIR" in
  /var/www|/var/www/*|"$ROOT"|"$ROOT"/*|/home/dylan/Pillage-First-LAN|/home/dylan/Pillage-First-LAN/*)
    printf 'Refusing unsafe staging output: %s\n' "$OUTPUT_DIR" >&2
    exit 2
    ;;
esac
[[ ! -e "$OUTPUT_DIR" ]] || {
  printf 'Staging output already exists: %s\n' "$OUTPUT_DIR" >&2
  exit 2
}

python3 - "$CONFIG" "$RELEASE_DIR" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

config = json.loads(Path(sys.argv[1]).read_text())
release_dir = Path(sys.argv[2])
release = json.loads((release_dir / "release.json").read_text())
static = release_dir / "static"
manifest = json.loads((static / "static-manifest.json").read_text())

checks = {
    "commit": (release["commit"], config["expectedCommit"]),
    "base path": (release["basePath"], config["basePath"]),
    "static commit": (manifest["commit"], config["expectedCommit"]),
    "static base path": (manifest["basePath"], config["basePath"]),
}
for label, (actual, expected) in checks.items():
    if actual != expected:
        raise SystemExit(f"{label} mismatch: {actual!r} != {expected!r}")

for name, expected in release["files"].items():
    path = release_dir / name
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != expected["sha256"]:
        raise SystemExit(f"archive checksum mismatch: {name}")

for relative, expected in manifest["files"].items():
    path = static / relative
    if not path.is_file():
        raise SystemExit(f"missing static file: {relative}")
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != expected["sha256"]:
        raise SystemExit(f"static checksum mismatch: {relative}")

if not (static / ".lan-arcade-ready").is_file():
    raise SystemExit("release readiness marker missing")
print(f"Verified pinned Pillage First release {release['commit']}")
PY

parent="$(dirname "$OUTPUT_DIR")"
mkdir -p "$parent"
stage="$(mktemp -d "$parent/.pillage-first-stage.XXXXXX")"
cleanup() {
  if [[ -n "${stage:-}" && -d "$stage" ]]; then
    rm -rf "$stage"
  fi
}
trap cleanup EXIT
rsync -a "$RELEASE_DIR/static/" "$stage/"
cp "$CONFIG" "$stage/PINNED_RELEASE.json"
mv "$stage" "$OUTPUT_DIR"
stage=""
printf 'Pillage First staged at %s\n' "$OUTPUT_DIR"
printf 'Live deployment remains blocked by the OPFS export/import gate.\n'
