#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ROOT="$ROOT/local-games"
DEST_ROOT="/var/www/html/mirrors"
DEPLOY_GUARD="$ROOT/scripts/assert_safe_deploy_target.sh"

fail() {
  echo "DEPLOY_REFUSED: $*" >&2
  exit 1
}

[ "$#" -gt 0 ] || fail "provide at least one game id"
command -v rsync >/dev/null 2>&1 || fail "rsync is required"
[ -x "$DEPLOY_GUARD" ] || fail "deployment target guard is missing"

source_root_real="$(realpath "$SOURCE_ROOT")"
dest_root_real="$(realpath "$DEST_ROOT")"
[ "$source_root_real" = "$ROOT/local-games" ] || fail "unexpected source root"
[ "$dest_root_real" = "/var/www/html/mirrors" ] || fail "unexpected destination root"

for game_id in "$@"; do
  [[ "$game_id" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "invalid game id: $game_id"
  source_dir="$SOURCE_ROOT/$game_id"
  dest_dir="$DEST_ROOT/$game_id"
  [ -d "$source_dir" ] || fail "missing source directory: $source_dir"

  source_real="$(realpath "$source_dir")"
  dest_real="$(realpath -m "$dest_dir")"
  case "$source_real" in "$source_root_real"/*) ;; *) fail "source escaped local-games" ;; esac
  case "$dest_real" in "$dest_root_real"/*) ;; *) fail "destination escaped mirrors" ;; esac
  [ "$source_real" != "$source_root_real" ] || fail "source may not be local-games root"
  [ "$dest_real" != "$dest_root_real" ] || fail "destination may not be mirrors root"
  [ "$dest_real" != "$DEST_ROOT/games" ] || fail "generated library is not a hub target"

  "$DEPLOY_GUARD" "$dest_real" "$dest_root_real"
  echo "Deploying $game_id"
  mkdir -p "$dest_real"
  rsync -a -- "$source_real/" "$dest_real/"
done

echo "LOCAL_GAME_HUB_DEPLOY_PASS count=$#"
