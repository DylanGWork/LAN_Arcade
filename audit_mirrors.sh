#!/usr/bin/env bash

set -euo pipefail

MIRRORS_DIR="${1:-/var/www/html/mirrors}"
WEB_ROOT="${WEB_ROOT:-/var/www/html}"
CATALOG_FILE="${CATALOG_FILE:-$MIRRORS_DIR/games/catalog.json}"
AUDIT_SOURCE="${LAN_ARCADE_AUDIT_SOURCE:-catalog}"

if [ ! -d "$MIRRORS_DIR" ]; then
  echo "Mirrors directory not found: $MIRRORS_DIR" >&2
  exit 1
fi

tmp_missing="$(mktemp)"
tmp_external="$(mktemp)"
tmp_status="$(mktemp)"
trap 'rm -f "$tmp_missing" "$tmp_external" "$tmp_status"' EXIT

normalize_ref() {
  local ref="$1"
  ref="${ref%%\#*}"
  ref="${ref%%\?*}"
  printf '%s' "$ref"
}

extract_refs() {
  local html_file="$1"
  grep -Eoi '(src|href)=["'"'"'][^"'"'"']+["'"'"']' "$html_file" \
    | sed -E 's/^(src|href)=["'"'"']([^"'"'"']+)["'"'"']$/\2/' \
    | sort -u || true
}

resolve_local_path() {
  local html_dir="$1"
  local ref="$2"
  local target

  if [[ "$ref" == /* ]]; then
    target="$WEB_ROOT$ref"
  else
    target="$html_dir/$ref"
  fi

  realpath -m "$target"
}

list_game_dirs() {
  if [ "$AUDIT_SOURCE" = "catalog" ] && [ -f "$CATALOG_FILE" ] && command -v node >/dev/null 2>&1; then
    node - "$CATALOG_FILE" "$MIRRORS_DIR" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');

const catalogFile = process.argv[2];
const mirrorsDir = process.argv[3];
const baseUrl = 'http://lan-arcade.invalid/mirrors/games/';

let catalog = { games: [] };
try {
  catalog = JSON.parse(fs.readFileSync(catalogFile, 'utf8'));
} catch {
  catalog = { games: [] };
}

for (const game of Array.isArray(catalog.games) ? catalog.games : []) {
  const id = String(game.id || '').trim();
  if (!id) continue;
  const gamePath = String(game.path || `../${id}/`);
  let url;
  try {
    url = new URL(gamePath, baseUrl);
  } catch {
    continue;
  }
  const relPath = decodeURIComponent(url.pathname).replace(/^\/mirrors\/?/, '').replace(/\/$/, '');
  const dir = path.join(mirrorsDir, relPath);
  console.log(`${id}|${dir}`);
}
NODE
    return
  fi

  while IFS= read -r dir; do
    [ "$(basename "$dir")" = "games" ] && continue
    printf '%s|%s\n' "$(basename "$dir")" "$dir"
  done < <(find "$MIRRORS_DIR" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort)
}

check_game_dir() {
  local game_dir="$1"
  local game_name="${2:-}"
  local html_file html_dir
  local missing_count external_count
  local raw_ref ref resolved

  if [ -z "$game_name" ]; then
    game_name="$(basename "$game_dir")"
  fi
  missing_count=0
  external_count=0

  html_file=""
  for candidate in "$game_dir/index.html" "$game_dir/index.htm"; do
    if [ -f "$candidate" ]; then
      html_file="$candidate"
      break
    fi
  done

  if [ -z "$html_file" ]; then
    html_file="$(find "$game_dir" -maxdepth 2 -type f \( -iname '*.html' -o -iname '*.htm' \) | head -n1 || true)"
  fi

  if [ -z "$html_file" ]; then
    echo "$game_name|entrypoint_missing" >> "$tmp_status"
    return
  fi

  html_dir="$(dirname "$html_file")"

  while IFS= read -r raw_ref; do
    ref="$(normalize_ref "$raw_ref")"
    [ -z "$ref" ] && continue

    case "$ref" in
      \#*|data:*|javascript:*|mailto:*|tel:*)
        continue
        ;;
      http://*|https://*|//*)
        external_count=$((external_count + 1))
        echo "$game_name|$ref" >> "$tmp_external"
        continue
        ;;
    esac

    resolved="$(resolve_local_path "$html_dir" "$ref")"
    if [ ! -e "$resolved" ]; then
      missing_count=$((missing_count + 1))
      echo "$game_name|$ref|$resolved" >> "$tmp_missing"
    fi
  done < <(extract_refs "$html_file")

  if [ "$missing_count" -gt 0 ]; then
    echo "$game_name|missing_refs|$missing_count|$external_count" >> "$tmp_status"
  else
    echo "$game_name|ok|0|$external_count" >> "$tmp_status"
  fi
}

while IFS='|' read -r game_name dir; do
  [ -z "$game_name" ] && continue
  [ -z "$dir" ] && continue
  check_game_dir "$dir" "$game_name"
done < <(list_game_dirs)

echo "=== LAN Arcade Mirror Audit ==="
echo "Mirrors dir: $MIRRORS_DIR"
echo "Audit source: $AUDIT_SOURCE"
[ "$AUDIT_SOURCE" = "catalog" ] && echo "Catalog: $CATALOG_FILE"
echo

total_games="$(wc -l < "$tmp_status" | tr -d ' ')"
broken_games="$(awk -F'|' '$2=="missing_refs" || $2=="entrypoint_missing" {c++} END {print c+0}' "$tmp_status")"
ok_games=$((total_games - broken_games))

echo "Games scanned: $total_games"
echo "OK: $ok_games"
echo "Needs attention: $broken_games"
echo

if [ "$broken_games" -gt 0 ]; then
  echo "Broken games:"
  awk -F'|' '
    $2=="entrypoint_missing" { printf "  - %s: missing HTML entrypoint\n", $1 }
    $2=="missing_refs" { printf "  - %s: missing_refs=%s external_refs=%s\n", $1, $3, $4 }
  ' "$tmp_status" | LC_ALL=C sort
  echo
fi

external_games="$(awk -F'|' '$2=="ok" || $2=="missing_refs" { if (($4+0) > 0) c++ } END {print c+0}' "$tmp_status")"
echo "Games with external dependency refs in entry HTML: $external_games"
echo

if [ -s "$tmp_missing" ]; then
  echo "First 30 missing refs:"
  head -n 30 "$tmp_missing" | awk -F'|' '{ printf "  - %s: %s\n", $1, $2 }'
  echo
fi

if [ -s "$tmp_external" ]; then
  echo "First 30 external refs:"
  head -n 30 "$tmp_external" | awk -F'|' '{ printf "  - %s: %s\n", $1, $2 }'
  echo
fi

if [ "$broken_games" -gt 0 ]; then
  exit 2
fi
