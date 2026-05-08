#!/usr/bin/env bash
# ===============================================================
# 🕹️ LAN Arcade – Auto-mirroring + pretty index.html
#   - Mirrors HTML/JS games into /var/www/html/mirrors
#   - Keeps index at /var/www/html/mirrors/games/index.html
#   - Uses games.meta.sh for URLs + metadata
# ===============================================================

set -euo pipefail

LAN_ARCADE_SKIP_PACKAGE_INSTALL="${LAN_ARCADE_SKIP_PACKAGE_INSTALL:-0}"
LAN_ARCADE_SKIP_MIRROR="${LAN_ARCADE_SKIP_MIRROR:-0}"
LAN_ARCADE_SKIP_ADMIN_AUTH="${LAN_ARCADE_SKIP_ADMIN_AUTH:-0}"
LAN_ARCADE_CATALOG_SOURCE="${LAN_ARCADE_CATALOG_SOURCE:-all-dirs}"
LAN_ARCADE_SKIP_DEVICE_CHECKS="${LAN_ARCADE_SKIP_DEVICE_CHECKS:-0}"
LAN_ARCADE_SKIP_OFFLINE_PATCH="${LAN_ARCADE_SKIP_OFFLINE_PATCH:-0}"
LAN_ARCADE_SKIP_TANK_SERVICE="${LAN_ARCADE_SKIP_TANK_SERVICE:-0}"
LAN_TANK_HOST="${LAN_TANK_HOST:-0.0.0.0}"
LAN_TANK_PORT="${LAN_TANK_PORT:-8787}"

RUNNING_AS_ROOT=0
if [ "$(id -u)" -eq 0 ]; then
  RUNNING_AS_ROOT=1
fi

if [ "$RUNNING_AS_ROOT" -ne 1 ]; then
  if [ "$LAN_ARCADE_SKIP_PACKAGE_INSTALL" != "1" ] || [ "$LAN_ARCADE_SKIP_ADMIN_AUTH" != "1" ]; then
    echo "Please run this script as root, e.g.: sudo bash $0"
    echo "Non-root mode requires LAN_ARCADE_SKIP_PACKAGE_INSTALL=1 and LAN_ARCADE_SKIP_ADMIN_AUTH=1."
    exit 1
  fi
  echo "Running in unprivileged generation mode."
fi

LOCAL_USER="${SUDO_USER:-$(id -un)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
META_FILE="$SCRIPT_DIR/games.meta.sh"

# Parse metadata as data instead of sourcing it, so repository content is never
# executed as shell code.
declare -A GAMES=()
declare -A GAME_INFO=()
declare -A GAME_CATEGORIES=()

declare -a CATEGORY_ORDER=(
  educational
  maths
  english
  typing
  age-5-plus
  age-10-plus
  age-13-plus
  puzzle
  arcade
  multiplayer
  action
  idle
  clicker
  strategy
  tactical
  roguelite
  tower-defense
  factory
  automation
  simulation
  management
  adventure
  rpg
  science
  city-builder
  racing
  space
  fantasy
  seasonal
  retro
  mobile-friendly
  family
  casual
)

declare -A CATEGORY_LABELS=(
  ["educational"]="Educational"
  ["maths"]="Maths"
  ["english"]="English"
  ["typing"]="Typing"
  ["age-5-plus"]="Ages 5+"
  ["age-10-plus"]="Ages 10+"
  ["age-13-plus"]="Ages 13+"
  ["puzzle"]="Puzzle"
  ["arcade"]="Arcade"
  ["multiplayer"]="Multiplayer"
  ["action"]="Action"
  ["idle"]="Idle"
  ["clicker"]="Clicker"
  ["strategy"]="Strategy"
  ["tactical"]="Tactical"
  ["roguelite"]="Roguelite"
  ["tower-defense"]="Tower Defense"
  ["factory"]="Factory"
  ["automation"]="Automation"
  ["simulation"]="Simulation"
  ["management"]="Management"
  ["adventure"]="Adventure"
  ["rpg"]="RPG"
  ["science"]="Science"
  ["city-builder"]="City Builder"
  ["racing"]="Racing"
  ["space"]="Space"
  ["fantasy"]="Fantasy"
  ["seasonal"]="Seasonal"
  ["retro"]="Retro"
  ["mobile-friendly"]="Mobile Friendly"
  ["family"]="Family"
  ["casual"]="Casual"
)

load_assoc_array() {
  local array_name="$1"
  local in_block=0
  local line key value

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"

    if [ "$in_block" -eq 0 ]; then
      if [[ "$line" =~ ^[[:space:]]*declare[[:space:]]+-A[[:space:]]+$array_name=\([[:space:]]*$ ]]; then
        in_block=1
      fi
      continue
    fi

    if [[ "$line" =~ ^[[:space:]]*\)[[:space:]]*$ ]]; then
      return 0
    fi

    if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    if [[ "$line" =~ ^[[:space:]]*\[\"([^\"]+)\"\]=\"(.*)\"[[:space:]]*$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      case "$array_name" in
        GAMES) GAMES["$key"]="$value" ;;
        GAME_INFO) GAME_INFO["$key"]="$value" ;;
        GAME_CATEGORIES) GAME_CATEGORIES["$key"]="$value" ;;
        *)
          echo "Unsupported metadata array: $array_name"
          exit 1
          ;;
      esac
    else
      echo "Invalid $array_name entry in $META_FILE:"
      echo "$line"
      exit 1
    fi
  done < "$META_FILE"

  echo "Could not find complete $array_name block in $META_FILE"
  exit 1
}

load_metadata() {
  if [ ! -f "$META_FILE" ]; then
    echo "Metadata file not found: $META_FILE"
    exit 1
  fi

  GAMES=()
  GAME_INFO=()
  GAME_CATEGORIES=()
  load_assoc_array "GAMES"
  load_assoc_array "GAME_INFO"
  load_assoc_array "GAME_CATEGORIES"

  if [ "${#GAMES[@]}" -eq 0 ]; then
    echo "No game sources found in $META_FILE"
    exit 1
  fi
}

load_metadata

MIRRORS_DIR="/var/www/html/mirrors"
INDEX_DIR="$MIRRORS_DIR/games"
INDEX_FILE="$INDEX_DIR/index.html"
CATALOG_FILE="$INDEX_DIR/catalog.json"
FILTERS_FILE="$INDEX_DIR/admin.filters.json"
WIKI_DIR="$INDEX_DIR/wiki"
WIKI_INDEX_FILE="$WIKI_DIR/index.html"
DOWNLOADS_DIR="$INDEX_DIR/downloads"
DOWNLOADS_INDEX_FILE="$DOWNLOADS_DIR/index.html"
DOWNLOAD_SCREENSHOTS_DIR="$DOWNLOADS_DIR/screenshots"
COMPANION_APK_REPO_FILE="$SCRIPT_DIR/releases/android/lan-arcade-companion-debug.apk"
DOC_ASSETS_DIR="$SCRIPT_DIR/docs/assets"
ADMIN_DIR="$INDEX_DIR/admin"
ADMIN_INDEX_FILE="$ADMIN_DIR/index.html"
ADMIN_CGI_FILE="$ADMIN_DIR/save_filters.cgi"
ADMIN_HTPASSWD="/etc/apache2/.lan_arcade_admin_htpasswd"
ADMIN_APACHE_CONF="/etc/apache2/conf-available/lan-arcade-admin.conf"
DEFAULT_ADMIN_USER="arcadeadmin"
READY_MARKER=".mirror_ok"
MIRROR_MISSING_REF_FAIL_THRESHOLD="${MIRROR_MISSING_REF_FAIL_THRESHOLD:-3}"

# ---------- Arcade name prompt ----------
DEFAULT_ARCADE_NAME="GannanNet"

if [ -n "${ARCADE_NAME:-}" ]; then
  ARCADE_NAME_USE="$ARCADE_NAME"
else
  echo
  read -rp "Enter a name for your LAN arcade (e.g. 'GannanNet', 'SmithNet', 'Magical LAN') [${DEFAULT_ARCADE_NAME}]: " ARCADE_NAME_INPUT
  if [ -z "$ARCADE_NAME_INPUT" ]; then
    ARCADE_NAME_USE="$DEFAULT_ARCADE_NAME"
  else
    ARCADE_NAME_USE="$ARCADE_NAME_INPUT"
  fi
fi

echo "Using arcade name: $ARCADE_NAME_USE"
echo

device_memory_mb() {
  if [ -r /proc/meminfo ]; then
    awk '/^MemTotal:/ { printf "%.0f\n", $2 / 1024 }' /proc/meminfo
  else
    printf '0\n'
  fi
}

print_device_suitability() {
  local mem_mb arch
  [ "$LAN_ARCADE_SKIP_DEVICE_CHECKS" = "1" ] && return 0

  mem_mb="$(device_memory_mb)"
  arch="$(uname -m 2>/dev/null || printf 'unknown')"

  echo "===== Device suitability check ====="
  if [ "$mem_mb" -gt 0 ]; then
    echo "Detected memory: ${mem_mb} MB (${arch})"
  else
    echo "Detected memory: unknown (${arch})"
  fi

  if [ "$mem_mb" -gt 0 ] && [ "$mem_mb" -lt 2048 ]; then
    echo "WARN: This device is tight for bigger LAN games."
    echo "      Browser arcade pages should be fine, but skip Mindustry/Unciv server containers for camping."
  elif [ "$mem_mb" -gt 0 ] && [ "$mem_mb" -lt 4096 ]; then
    echo "WARN: Bigger LAN games may work only with conservative settings."
    echo "      Try Unciv with -Xmx256m and Mindustry with -Xmx512m on a small map."
  elif [ "$mem_mb" -gt 0 ] && [ "$mem_mb" -lt 7680 ]; then
    echo "OK: This should fit the browser arcade plus one bigger LAN service at a time."
    echo "    Freeciv-web remains experimental; test it before relying on it offline."
  else
    echo "OK: Memory looks healthy for the browser arcade and bigger LAN service trials."
    echo "    Still test Mindustry/Unciv with real phones before a trip."
  fi
  echo
}

print_device_suitability

# ---------- Base packages ----------
if [ "$LAN_ARCADE_SKIP_PACKAGE_INSTALL" = "1" ]; then
  echo "Skipping package installation because LAN_ARCADE_SKIP_PACKAGE_INSTALL=1"
else
  apt-get update -y
  apt-get install -y apache2 apache2-utils wget unzip git nodejs

  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now apache2 || true
  fi
fi

mkdir -p "$MIRRORS_DIR" "$INDEX_DIR" "$WIKI_DIR" "$ADMIN_DIR"
if [ "$RUNNING_AS_ROOT" -eq 1 ]; then
  chown -R "$LOCAL_USER:$LOCAL_USER" "$MIRRORS_DIR"
fi

# ---------- Helper to flatten wget mirror ----------
flatten_mirror() {
  local url="$1"
  local target="$2"

  local domain relpath root_dir src
  domain="$(echo "$url" | sed -E 's#https?://([^/]+)/?.*#\1#')"
  relpath="$(echo "$url" | sed -E "s#https?://$domain/##")"
  relpath="${relpath%%\?*}"
  relpath="${relpath%/}"
  root_dir="$target/$domain"

  if [ -d "$root_dir" ]; then
    if [ -n "$relpath" ] && [ -d "$root_dir/$relpath" ]; then
      src="$root_dir/$relpath"
    else
      src="$root_dir"
    fi
    shopt -s dotglob nullglob
    mv "$src"/* "$target"/ 2>/dev/null || true
    shopt -u dotglob nullglob
    rm -rf "$root_dir"
  fi
}

promote_entrypoint_if_missing() {
  local target_dir="$1"
  local fallback_html=""
  if [ -f "$target_dir/index.html" ]; then
    return 0
  fi

  fallback_html="$(find "$target_dir" -maxdepth 1 -type f -iname '*.html' | LC_ALL=C sort | head -n1 || true)"
  if [ -z "$fallback_html" ]; then
    fallback_html="$(find "$target_dir" -type f -iname '*.html' | LC_ALL=C sort | head -n1 || true)"
  fi
  if [ -n "$fallback_html" ] && [ -f "$fallback_html" ]; then
    cp "$fallback_html" "$target_dir/index.html"
  fi
}

html_escape() {
  local text="$1"
  text="${text//&/&amp;}"
  text="${text//</&lt;}"
  text="${text//>/&gt;}"
  text="${text//\"/&quot;}"
  text="${text//\'/&#39;}"
  printf '%s' "$text"
}

trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

slug_to_label() {
  local slug="$1"
  local normalized word label=""
  normalized="${slug//-/ }"
  for word in $normalized; do
    if [ -z "$label" ]; then
      label="${word^}"
    else
      label="$label ${word^}"
    fi
  done
  printf '%s' "$label"
}

json_escape() {
  local text="$1"
  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  text="${text//$'\n'/\\n}"
  text="${text//$'\r'/\\r}"
  text="${text//$'\t'/\\t}"
  printf '%s' "$text"
}

json_array_from_values() {
  local value escaped
  local first=1
  local output=""
  for value in "$@"; do
    escaped="$(json_escape "$value")"
    if [ "$first" -eq 1 ]; then
      output="\"$escaped\""
      first=0
    else
      output="$output,\"$escaped\""
    fi
  done
  printf '%s' "$output"
}

split_csv_unique() {
  local raw="$1"
  local mode="$2"
  local -n out_ref="$3"
  local -a parts=()
  local -A seen=()
  local part trimmed normalized

  out_ref=()
  IFS=',' read -ra parts <<< "$raw"
  for part in "${parts[@]}"; do
    trimmed="$(trim_whitespace "$part")"
    [ -z "$trimmed" ] && continue

    if [ "$mode" = "category" ]; then
      normalized="$(printf '%s' "$trimmed" | tr '[:upper:]' '[:lower:]')"
      [[ "$normalized" =~ ^[a-z0-9][a-z0-9-]*$ ]] || continue
    else
      normalized="$trimmed"
    fi

    if [ -z "${seen[$normalized]+x}" ]; then
      seen["$normalized"]=1
      out_ref+=("$normalized")
    fi
  done
}

extract_html_refs() {
  local html_file="$1"
  grep -Eoi "(src|href)=['\"][^'\"]+['\"]" "$html_file" \
    | sed -E "s/^(src|href)=['\"]([^'\"]+)['\"]$/\\2/" \
    | sort -u || true
}

find_mirror_entrypoint() {
  local target_dir="$1"
  local candidate

  for candidate in "$target_dir/index.html" "$target_dir/index.htm"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  candidate="$(find "$target_dir" -maxdepth 2 -type f \( -iname '*.html' -o -iname '*.htm' \) | LC_ALL=C sort | head -n1 || true)"
  if [ -n "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

mirror_content_is_complete() {
  local game_name="$1"
  local target_dir="$2"
  local entry_html entry_dir raw_ref ref resolved
  local missing_ref_count=0
  local has_any_content=""

  if [ ! -d "$target_dir" ]; then
    return 1
  fi

  has_any_content="$(find "$target_dir" -mindepth 1 ! -name "$READY_MARKER" -print -quit 2>/dev/null || true)"
  if [ -z "$has_any_content" ]; then
    return 1
  fi

  entry_html="$(find_mirror_entrypoint "$target_dir" || true)"
  if [ -z "$entry_html" ]; then
    echo "WARN $game_name has no HTML entrypoint in $target_dir."
    return 1
  fi

  entry_dir="$(dirname "$entry_html")"

  while IFS= read -r raw_ref; do
    ref="$(trim_whitespace "$raw_ref")"
    ref="${ref%%\#*}"
    ref="${ref%%\?*}"
    [ -z "$ref" ] && continue

    case "$ref" in
      \#*|data:*|javascript:*|mailto:*|tel:*|http://*|https://*|//*)
        continue
        ;;
    esac

    if [[ "$ref" == /* ]]; then
      resolved="/var/www/html$ref"
    else
      resolved="$entry_dir/$ref"
    fi

    if [ ! -e "$resolved" ]; then
      missing_ref_count=$((missing_ref_count + 1))
      if [ "$missing_ref_count" -le 3 ]; then
        echo "WARN $game_name missing local asset: $ref"
      fi
    fi
  done < <(extract_html_refs "$entry_html")

  if [ "$missing_ref_count" -ge "$MIRROR_MISSING_REF_FAIL_THRESHOLD" ]; then
    echo "WARN $game_name failed mirror validation ($missing_ref_count missing local assets from entry HTML)."
    return 1
  fi

  return 0
}

patch_mirror_for_offline_use() {
  local game_name="$1"
  local target_dir="$2"
  local patcher="$SCRIPT_DIR/scripts/offline_patch_mirrors.sh"

  [ "$LAN_ARCADE_SKIP_OFFLINE_PATCH" = "1" ] && return 0
  [ -d "$target_dir" ] || return 0

  if [ ! -x "$patcher" ]; then
    return 0
  fi

  "$patcher" "$MIRRORS_DIR" "$game_name" || true
}

discover_mirror_dirs() {
  local -n out_ref="$1"
  local dir_name
  out_ref=()

  case "$LAN_ARCADE_CATALOG_SOURCE" in
    all-dirs)
      while IFS= read -r dir_name; do
        [ "$dir_name" = "games" ] && continue
        out_ref+=("$dir_name")
      done < <(find "$MIRRORS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort)
      ;;
    metadata-existing)
      while IFS= read -r dir_name; do
        [ -d "$MIRRORS_DIR/$dir_name" ] && out_ref+=("$dir_name")
      done < <(printf '%s\n' "${!GAMES[@]}" | LC_ALL=C sort)
      ;;
    *)
      echo "Invalid LAN_ARCADE_CATALOG_SOURCE '$LAN_ARCADE_CATALOG_SOURCE'. Use all-dirs or metadata-existing."
      exit 1
      ;;
  esac
}

ensure_filters_file() {
  if [ -f "$FILTERS_FILE" ]; then
    chmod 644 "$FILTERS_FILE"
    return 0
  fi

  cat > "$FILTERS_FILE" <<'JSON'
{
  "disabled_categories": [],
  "disabled_games": []
}
JSON
  chmod 644 "$FILTERS_FILE"
}

configure_admin_credentials() {
  local admin_user admin_password pass1 pass2
  admin_user="${ADMIN_USER:-$DEFAULT_ADMIN_USER}"
  admin_password="${ADMIN_PASSWORD:-}"

  if ! [[ "$admin_user" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Invalid ADMIN_USER '$admin_user'. Use letters, numbers, dot, underscore, or dash."
    exit 1
  fi

  if [ -f "$ADMIN_HTPASSWD" ] && [ -z "$admin_password" ]; then
    echo "Admin credentials already exist at $ADMIN_HTPASSWD, keeping them unchanged."
    return 0
  fi

  if [ -z "$admin_password" ]; then
    if [ ! -t 0 ]; then
      echo "No admin password available in non-interactive mode."
      echo "Set ADMIN_PASSWORD to initialize admin access."
      exit 1
    fi

    while true; do
      read -rsp "Set LAN Arcade admin password for '$admin_user': " pass1
      echo
      read -rsp "Confirm password: " pass2
      echo
      if [ -z "$pass1" ]; then
        echo "Password cannot be empty."
        continue
      fi
      if [ "$pass1" != "$pass2" ]; then
        echo "Passwords did not match, try again."
        continue
      fi
      admin_password="$pass1"
      break
    done
  fi

  printf '%s\n' "$admin_password" | htpasswd -iB -c "$ADMIN_HTPASSWD" "$admin_user" >/dev/null
  chown root:www-data "$ADMIN_HTPASSWD"
  chmod 640 "$ADMIN_HTPASSWD"
}

configure_admin_auth() {
  cat > "$ADMIN_APACHE_CONF" <<CONF
<Directory "$ADMIN_DIR">
    Options +ExecCGI
    AddHandler cgi-script .cgi
    AuthType Basic
    AuthName "LAN Arcade Admin"
    AuthUserFile "$ADMIN_HTPASSWD"
    Require valid-user
</Directory>
CONF

  if command -v a2enmod >/dev/null 2>&1; then
    a2enmod cgi >/dev/null 2>&1 || true
  fi
  if command -v a2enconf >/dev/null 2>&1; then
    a2enconf lan-arcade-admin >/dev/null 2>&1 || true
  fi
}

configure_tank_arena_service() {
  local node_bin service_group unit_file

  if [ "$LAN_ARCADE_SKIP_TANK_SERVICE" = "1" ]; then
    echo "Skipping LAN Tank Arena service because LAN_ARCADE_SKIP_TANK_SERVICE=1"
    return 0
  fi

  if [ "$LAN_ARCADE_SKIP_PACKAGE_INSTALL" = "1" ]; then
    echo "Skipping LAN Tank Arena service because LAN_ARCADE_SKIP_PACKAGE_INSTALL=1"
    return 0
  fi

  if [ "$RUNNING_AS_ROOT" -ne 1 ]; then
    echo "Skipping LAN Tank Arena service because this run is not root."
    return 0
  fi

  if ! command -v systemctl >/dev/null 2>&1; then
    echo "WARN: systemctl not found; LAN Tank Arena service was not installed."
    return 0
  fi

  node_bin="$(command -v node 2>/dev/null || command -v nodejs 2>/dev/null || true)"
  if [ -z "$node_bin" ]; then
    echo "WARN: node not found; LAN Tank Arena service was not installed."
    return 0
  fi

  if [ ! -f "$SCRIPT_DIR/services/lan-tank-arena/server.mjs" ]; then
    echo "WARN: LAN Tank Arena server missing; service was not installed."
    return 0
  fi

  service_group="$(id -gn "$LOCAL_USER" 2>/dev/null || printf '%s' "$LOCAL_USER")"
  unit_file="/etc/systemd/system/lan-tank-arena.service"

  cat > "$unit_file" <<CONF
[Unit]
Description=LAN Arcade Tank Arena WebSocket Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$SCRIPT_DIR
Environment=LAN_TANK_HOST=$LAN_TANK_HOST
Environment=LAN_TANK_PORT=$LAN_TANK_PORT
ExecStart=$node_bin $SCRIPT_DIR/services/lan-tank-arena/server.mjs
Restart=on-failure
RestartSec=2
User=$LOCAL_USER
Group=$service_group

[Install]
WantedBy=multi-user.target
CONF

  chmod 644 "$unit_file"
  systemctl daemon-reload || true
  if systemctl enable --now lan-tank-arena.service; then
    echo "LAN Tank Arena service enabled on ${LAN_TANK_HOST}:${LAN_TANK_PORT}."
  else
    echo "WARN: LAN Tank Arena service could not be started. Check: systemctl status lan-tank-arena.service"
  fi
}

build_catalog_json() {
  local -a mirror_dirs=()
  local -a game_json_items=()
  local -a tags_values=()
  local -a category_values=()
  local -A used_categories=()
  local -A category_in_order=()
  local -a ordered_categories=()
  local -a extra_categories=()
  local dir_name info title icon meta desc tags categories
  local entry_html rel_entry_dir play_path
  local tags_json categories_json game_json
  local generated_at tmp_file idx category_id category_label

  discover_mirror_dirs mirror_dirs

  for dir_name in "${mirror_dirs[@]}"; do
    entry_html="$(find_mirror_entrypoint "$MIRRORS_DIR/$dir_name" || true)"
    if [ -z "$entry_html" ]; then
      echo "WARN skipping $dir_name in catalog: no HTML entrypoint found."
      continue
    fi
    rel_entry_dir="$(dirname "${entry_html#"$MIRRORS_DIR/"}")"
    play_path="../$rel_entry_dir/"

    info="${GAME_INFO[$dir_name]:-}"
    if [ -n "$info" ]; then
      IFS='|' read -r title icon meta desc tags <<< "$info"
    else
      title="$(echo "$dir_name" | tr '-' ' ')"
      icon="Play"
      meta="HTML5 / Offline"
      desc="Offline-friendly browser game mirrored in the '$dir_name' folder."
      tags="Offline"
    fi

    categories="${GAME_CATEGORIES[$dir_name]:-casual,age-10-plus}"
    split_csv_unique "$tags" "tag" tags_values
    split_csv_unique "$categories" "category" category_values
    if [ "${#category_values[@]}" -eq 0 ]; then
      category_values=("casual" "age-10-plus")
    fi

    for category_id in "${category_values[@]}"; do
      used_categories["$category_id"]=1
    done

    tags_json="$(json_array_from_values "${tags_values[@]}")"
    categories_json="$(json_array_from_values "${category_values[@]}")"
    game_json="{\"id\":\"$(json_escape "$dir_name")\",\"title\":\"$(json_escape "$title")\",\"icon\":\"$(json_escape "$icon")\",\"meta\":\"$(json_escape "$meta")\",\"description\":\"$(json_escape "$desc")\",\"tags\":[${tags_json}],\"categories\":[${categories_json}],\"path\":\"$(json_escape "$play_path")\"}"
    game_json_items+=("$game_json")
  done

  for category_id in "${CATEGORY_ORDER[@]}"; do
    if [ -n "${used_categories[$category_id]+x}" ]; then
      ordered_categories+=("$category_id")
      category_in_order["$category_id"]=1
    fi
  done

  mapfile -t extra_categories < <(
    for category_id in "${!used_categories[@]}"; do
      [ -z "${category_in_order[$category_id]+x}" ] && printf '%s\n' "$category_id"
    done | LC_ALL=C sort
  )

  for category_id in "${extra_categories[@]}"; do
    ordered_categories+=("$category_id")
  done

  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tmp_file="$(mktemp "$INDEX_DIR/catalog.json.tmp.XXXXXX")"

  {
    printf '{\n'
    printf '  "generated_at": "%s",\n' "$(json_escape "$generated_at")"
    printf '  "arcade_name": "%s",\n' "$(json_escape "$ARCADE_NAME_USE")"
    printf '  "categories": [\n'

    for idx in "${!ordered_categories[@]}"; do
      category_id="${ordered_categories[$idx]}"
      category_label="${CATEGORY_LABELS[$category_id]:-$(slug_to_label "$category_id")}"
      if [ "$idx" -lt $(( ${#ordered_categories[@]} - 1 )) ]; then
        printf '    {"id":"%s","label":"%s"},\n' "$(json_escape "$category_id")" "$(json_escape "$category_label")"
      else
        printf '    {"id":"%s","label":"%s"}\n' "$(json_escape "$category_id")" "$(json_escape "$category_label")"
      fi
    done

    printf '  ],\n'
    printf '  "games": [\n'

    for idx in "${!game_json_items[@]}"; do
      if [ "$idx" -lt $(( ${#game_json_items[@]} - 1 )) ]; then
        printf '    %s,\n' "${game_json_items[$idx]}"
      else
        printf '    %s\n' "${game_json_items[$idx]}"
      fi
    done

    printf '  ]\n'
    printf '}\n'
  } > "$tmp_file"

  mv "$tmp_file" "$CATALOG_FILE"
  chmod 644 "$CATALOG_FILE"
}

write_public_index() {
  local arcade_name_html
  arcade_name_html="$(html_escape "$ARCADE_NAME_USE")"

  cat > "$INDEX_FILE" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${arcade_name_html} LAN Arcade</title>
  <style>
    :root {
      --bg: #0b1720;
      --card-bg: #111c28;
      --accent: #4caf50;
      --accent-soft: rgba(76, 175, 80, 0.15);
      --text: #f5f7fa;
      --muted: #9ca3af;
      --border: #1f2933;
      --radius: 14px;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: radial-gradient(circle at top, #182a3a 0, #050910 55%, #020509 100%);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: stretch;
    }
    header {
      padding: 1.5rem 1.5rem 0.5rem;
      text-align: center;
    }
    h1 {
      margin: 0;
      font-size: 1.8rem;
      letter-spacing: 0.03em;
    }
    .subtitle {
      margin-top: 0.5rem;
      color: var(--muted);
      font-size: 0.95rem;
    }
    .toolbar {
      margin-top: 1rem;
      display: flex;
      justify-content: center;
      gap: 0.6rem;
      flex-wrap: wrap;
    }
    .filters {
      margin-top: 1rem;
      display: flex;
      gap: 0.45rem;
      flex-wrap: wrap;
      justify-content: center;
    }
    .filter-chip {
      background: rgba(15, 23, 42, 0.7);
      border: 1px solid var(--border);
      color: var(--text);
      border-radius: 999px;
      padding: 0.35rem 0.8rem;
      font-size: 0.82rem;
      cursor: pointer;
    }
    .filter-chip:hover {
      border-color: var(--accent);
    }
    .filter-chip.active {
      border-color: var(--accent);
      background: var(--accent-soft);
      color: #bbf7d0;
    }
    .toolbar-link {
      display: inline-block;
      border: 1px solid var(--border);
      border-radius: 999px;
      padding: 0.35rem 0.9rem;
      color: var(--text);
      text-decoration: none;
      font-size: 0.84rem;
      background: rgba(15, 23, 42, 0.75);
    }
    .toolbar-link:hover {
      border-color: var(--accent);
    }
    .download-panel {
      margin: 0 auto 1rem;
      border: 1px solid var(--border);
      border-radius: var(--radius);
      background: linear-gradient(135deg, rgba(17, 28, 40, 0.96), rgba(10, 20, 31, 0.96));
      padding: 0.85rem;
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 0.9rem;
      align-items: center;
    }
    .download-panel h2 {
      margin: 0 0 0.25rem;
      font-size: 1rem;
    }
    .download-panel p {
      margin: 0;
      color: var(--muted);
      font-size: 0.88rem;
      line-height: 1.4;
    }
    .download-actions {
      display: flex;
      gap: 0.5rem;
      flex-wrap: wrap;
      justify-content: flex-end;
    }
    .download-link {
      border: 1px solid rgba(148, 163, 184, 0.35);
      border-radius: 999px;
      color: var(--text);
      text-decoration: none;
      padding: 0.45rem 0.8rem;
      font-size: 0.84rem;
      font-weight: 700;
      background: rgba(15, 23, 42, 0.76);
      white-space: nowrap;
    }
    .download-link.primary {
      border-color: rgba(76, 175, 80, 0.55);
      background: var(--accent-soft);
      color: #bbf7d0;
    }
    .download-link:hover {
      border-color: var(--accent);
    }
    main {
      padding: 1rem 1.5rem 2rem;
      max-width: 1100px;
      width: 100%;
      margin: 0 auto;
    }
    .status {
      margin-top: 0.4rem;
      font-size: 0.88rem;
      color: var(--muted);
      text-align: center;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 1.25rem;
      margin-top: 1rem;
    }
    .game-card {
      display: flex;
      flex-direction: column;
      padding: 1rem 1rem 0.9rem;
      border-radius: var(--radius);
      background: linear-gradient(145deg, #0b1520, #101b28);
      border: 1px solid var(--border);
      text-decoration: none;
      color: inherit;
      box-shadow: 0 14px 30px rgba(0, 0, 0, 0.4);
      position: relative;
      overflow: hidden;
      transition: transform 0.18s ease-out, border-color 0.18s ease-out;
    }
    .game-card::before {
      content: "";
      position: absolute;
      inset: 0;
      background: radial-gradient(circle at top left, rgba(76, 175, 80, 0.2), transparent 55%);
      opacity: 0;
      transition: opacity 0.18s ease-out;
      pointer-events: none;
    }
    .game-card:hover {
      transform: translateY(-2px);
      border-color: var(--accent);
    }
    .game-card:hover::before {
      opacity: 1;
    }
    .game-title {
      font-weight: 600;
      font-size: 1.05rem;
      margin-bottom: 0.35rem;
    }
    .game-meta {
      font-size: 0.78rem;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: var(--muted);
      margin-bottom: 0.4rem;
    }
    .game-desc {
      font-size: 0.9rem;
      color: var(--muted);
      margin-bottom: 0.7rem;
      flex: 1;
    }
    .pill-row {
      display: flex;
      gap: 0.35rem;
      flex-wrap: wrap;
      margin-bottom: 0.7rem;
    }
    .pill {
      font-size: 0.72rem;
      padding: 0.15rem 0.5rem;
      border-radius: 999px;
      background: rgba(148, 163, 184, 0.15);
      color: var(--muted);
    }
    .pill--primary {
      background: var(--accent-soft);
      color: #bbf7d0;
    }
    .play-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-top: 0.2rem;
    }
    .play-btn {
      padding: 0.4rem 0.8rem;
      border-radius: 999px;
      border: 1px solid rgba(148, 163, 184, 0.35);
      font-size: 0.82rem;
      display: inline-flex;
      align-items: center;
      gap: 0.35rem;
      color: var(--text);
      background: rgba(15, 23, 42, 0.75);
    }
    .hint {
      font-size: 0.8rem;
      color: var(--muted);
      text-align: center;
      margin-top: 1rem;
      opacity: 0.85;
    }
    .empty-state {
      margin-top: 2rem;
      text-align: center;
      color: var(--muted);
      font-size: 0.95rem;
    }
    @media (max-width: 600px) {
      header { padding: 1.25rem 1rem 0.5rem; }
      main { padding: 0.5rem 1rem 1.5rem; }
      .download-panel { grid-template-columns: 1fr; }
      .download-actions { justify-content: stretch; }
      .download-link { flex: 1; text-align: center; }
    }
  </style>
</head>
<body>
  <header>
    <h1>${arcade_name_html} LAN Arcade</h1>
    <div class="subtitle">
      Offline-friendly games hosted on your home server.<br>
      Tap a game to launch it in your browser or add to home screen on mobile.
    </div>
    <div class="toolbar">
      <a class="toolbar-link" href="./wiki/">Offline Wiki</a>
      <a class="toolbar-link" href="./downloads/">Downloads</a>
      <a class="toolbar-link" href="./admin/">Admin Panel</a>
    </div>
  </header>
  <main>
    <section class="download-panel" aria-label="Downloads">
      <div>
        <h2>Android Companion App</h2>
        <p>Download the APK on Android devices, install it, then set the app server to <code>http://&lt;server-ip&gt;/arcade-api/</code>. Browser games work without installing anything.</p>
      </div>
      <div class="download-actions">
        <a class="download-link primary" href="./downloads/lan-arcade-companion-debug.apk">Download APK</a>
        <a class="download-link" href="./downloads/">Setup Instructions</a>
      </div>
    </section>
    <div id="status" class="status">Loading game catalog...</div>
    <div id="categoryFilters" class="filters" hidden></div>
    <section id="grid" class="grid" aria-live="polite"></section>
    <div id="emptyState" class="empty-state" hidden>
      No games are currently enabled. Check the admin panel filters.
    </div>
    <div class="hint">
      To add more games, update <code>games.meta.sh</code>, then rerun this setup script.
    </div>
  </main>
  <script>
    (function () {
      "use strict";

      var state = {
        catalog: { games: [], categories: [] },
        filters: { disabled_categories: [], disabled_games: [] },
        activeCategory: ""
      };

      function toStringArray(value) {
        if (!Array.isArray(value)) return [];
        return value.map(function (item) { return String(item).trim(); }).filter(function (item) { return item.length > 0; });
      }

      function uniqueArray(items) {
        var seen = Object.create(null);
        var output = [];
        items.forEach(function (item) {
          if (!seen[item]) {
            seen[item] = true;
            output.push(item);
          }
        });
        return output;
      }

      function normalizeFilters(raw) {
        var data = raw || {};
        return {
          disabled_categories: uniqueArray(toStringArray(data.disabled_categories)),
          disabled_games: uniqueArray(toStringArray(data.disabled_games))
        };
      }

      function fetchJson(url, fallbackValue) {
        return fetch(url, { cache: "no-store" })
          .then(function (response) {
            if (!response.ok) throw new Error("HTTP " + response.status);
            return response.json();
          })
          .catch(function () {
            return fallbackValue;
          });
      }

      function categoryLabelMap(catalog) {
        var map = Object.create(null);
        (Array.isArray(catalog.categories) ? catalog.categories : []).forEach(function (category) {
          if (!category || !category.id) return;
          map[String(category.id)] = category.label ? String(category.label) : String(category.id);
        });
        return map;
      }

      function gameEnabled(game, filters) {
        var disabledGames = new Set(filters.disabled_games);
        var disabledCategories = new Set(filters.disabled_categories);
        if (disabledGames.has(game.id)) return false;
        var categories = toStringArray(game.categories);
        return !categories.some(function (category) { return disabledCategories.has(category); });
      }

      function gameHasCategory(game, categoryId) {
        return toStringArray(game.categories).indexOf(categoryId) >= 0;
      }

      function buildCard(game) {
        var card = document.createElement("a");
        card.className = "game-card";
        card.href = game.path ? String(game.path) : "../" + encodeURIComponent(game.id) + "/";

        var title = document.createElement("div");
        title.className = "game-title";
        title.textContent = game.title || game.id;
        card.appendChild(title);

        var meta = document.createElement("div");
        meta.className = "game-meta";
        meta.textContent = game.meta || "HTML5 / Offline";
        card.appendChild(meta);

        var desc = document.createElement("div");
        desc.className = "game-desc";
        desc.textContent = game.description || "Offline-friendly browser game.";
        card.appendChild(desc);

        var pills = document.createElement("div");
        pills.className = "pill-row";
        toStringArray(game.tags).forEach(function (tag, index) {
          var pill = document.createElement("div");
          pill.className = index === 0 ? "pill pill--primary" : "pill";
          pill.textContent = tag;
          pills.appendChild(pill);
        });
        card.appendChild(pills);

        var playRow = document.createElement("div");
        playRow.className = "play-row";

        var playBadge = document.createElement("span");
        playBadge.className = "play-btn";
        playBadge.textContent = (game.icon ? game.icon + " " : "") + "Play";
        playRow.appendChild(playBadge);

        var pathHint = document.createElement("span");
        pathHint.style.fontSize = "0.75rem";
        pathHint.style.color = "var(--muted)";
        pathHint.textContent = card.getAttribute("href").replace(/^\.\.\//, "/mirrors/");
        playRow.appendChild(pathHint);

        card.appendChild(playRow);
        return card;
      }

      function buildCategoryFilters(catalog, adminVisibleGames) {
        var wrapper = document.getElementById("categoryFilters");
        var categories = Array.isArray(catalog.categories) ? catalog.categories : [];
        var counts = Object.create(null);
        var available = new Set();

        adminVisibleGames.forEach(function (game) {
          toStringArray(game.categories).forEach(function (categoryId) {
            counts[categoryId] = (counts[categoryId] || 0) + 1;
            available.add(categoryId);
          });
        });

        if (state.activeCategory && !available.has(state.activeCategory)) {
          state.activeCategory = "";
        }

        wrapper.textContent = "";

        function addChip(categoryId, label, count) {
          var chip = document.createElement("button");
          chip.type = "button";
          chip.className = "filter-chip" + (state.activeCategory === categoryId ? " active" : "");
          chip.textContent = label + " (" + count + ")";
          chip.addEventListener("click", function () {
            if (state.activeCategory === categoryId) return;
            state.activeCategory = categoryId;
            render(state.catalog, state.filters);
          });
          wrapper.appendChild(chip);
        }

        addChip("", "All", adminVisibleGames.length);

        categories.forEach(function (category) {
          var id = String(category && category.id ? category.id : "");
          if (!id || !available.has(id)) return;
          addChip(id, category.label ? String(category.label) : id, counts[id] || 0);
        });

        wrapper.hidden = wrapper.children.length <= 1;
      }

      function render(catalog, filters) {
        var status = document.getElementById("status");
        var grid = document.getElementById("grid");
        var emptyState = document.getElementById("emptyState");
        var labelsByCategory = categoryLabelMap(catalog);
        var games = Array.isArray(catalog.games) ? catalog.games : [];
        var adminVisibleGames = games.filter(function (game) { return gameEnabled(game, filters); });
        var visibleGames = adminVisibleGames;
        var activeCategoryLabel = "";

        buildCategoryFilters(catalog, adminVisibleGames);

        if (state.activeCategory) {
          visibleGames = adminVisibleGames.filter(function (game) {
            return gameHasCategory(game, state.activeCategory);
          });
          activeCategoryLabel = labelsByCategory[state.activeCategory] || state.activeCategory;
        }

        grid.textContent = "";
        visibleGames.forEach(function (game) { grid.appendChild(buildCard(game)); });
        emptyState.hidden = visibleGames.length !== 0;

        var summary = "Showing " + visibleGames.length + " of " + games.length + " games.";
        if (activeCategoryLabel) {
          summary += " Category filter: " + activeCategoryLabel + ".";
        }
        if (filters.disabled_categories.length > 0 || filters.disabled_games.length > 0) {
          summary += " Hidden by admin filters: " + filters.disabled_categories.length + " categories, " + filters.disabled_games.length + " games.";
        }
        status.textContent = summary;
      }

      Promise.all([
        fetchJson("./catalog.json", { games: [], categories: [] }),
        fetchJson("./admin.filters.json", { disabled_categories: [], disabled_games: [] })
      ]).then(function (results) {
        state.catalog = results[0] || { games: [], categories: [] };
        state.filters = normalizeFilters(results[1]);
        state.activeCategory = "";
        render(state.catalog, state.filters);
      });
    })();
  </script>
</body>
</html>
HTML
}

publish_companion_downloads() {
  mkdir -p "$DOWNLOADS_DIR" "$DOWNLOAD_SCREENSHOTS_DIR"

  if [ -f "$COMPANION_APK_REPO_FILE" ]; then
    cp "$COMPANION_APK_REPO_FILE" "$DOWNLOADS_DIR/lan-arcade-companion-debug.apk"
    chmod 644 "$DOWNLOADS_DIR/lan-arcade-companion-debug.apk"
  fi

  if [ -d "$DOC_ASSETS_DIR" ]; then
    for screenshot in \
      companion-catalog.png \
      companion-trailguard.png \
      companion-unciv-service.png \
      companion-mindustry-service.png; do
      if [ -f "$DOC_ASSETS_DIR/$screenshot" ]; then
        cp "$DOC_ASSETS_DIR/$screenshot" "$DOWNLOAD_SCREENSHOTS_DIR/$screenshot"
        chmod 644 "$DOWNLOAD_SCREENSHOTS_DIR/$screenshot"
      fi
    done
  fi

  cat > "$DOWNLOADS_INDEX_FILE" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>LAN Arcade Downloads</title>
  <style>
    :root { color-scheme: dark; --bg: #07101a; --panel: #101b2b; --text: #eef4fa; --muted: #a2b0bf; --line: #213245; --accent: #5de4c7; --accent-soft: rgba(93, 228, 199, 0.12); }
    body { margin: 0; font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: var(--bg); color: var(--text); }
    main { width: min(980px, calc(100vw - 24px)); margin: 0 auto; padding: 1.5rem 0 2rem; }
    a { color: var(--accent); font-weight: 800; }
    .card { border: 1px solid var(--line); border-radius: 8px; background: var(--panel); padding: 1rem; margin-top: 1rem; }
    .muted { color: var(--muted); }
    .top-actions { display: flex; gap: 0.55rem; flex-wrap: wrap; margin-top: 1rem; }
    .button-link { border: 1px solid var(--line); border-radius: 999px; color: var(--text); display: inline-flex; padding: 0.45rem 0.85rem; text-decoration: none; }
    .button-link.primary { background: var(--accent-soft); border-color: rgba(93, 228, 199, 0.55); color: #ccfff5; }
    .steps { display: grid; gap: 0.45rem; margin: 0.7rem 0 0; padding-left: 1.15rem; }
    .steps li { color: var(--muted); line-height: 1.45; }
    code { background: rgba(162, 176, 191, 0.14); border-radius: 6px; color: #d7e7f6; padding: 0.1rem 0.3rem; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 0.85rem; }
    .screens { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 0.75rem; margin-top: 0.75rem; }
    .screens img { width: 100%; border: 1px solid var(--line); border-radius: 8px; background: #050b12; }
  </style>
</head>
<body>
  <main>
    <h1>LAN Arcade Downloads</h1>
    <p class="muted">Local files and setup notes for phones and tablets on this offline network.</p>
    <div class="top-actions">
      <a class="button-link" href="../">Back to Arcade</a>
      <a class="button-link" href="../wiki/">Offline Wiki</a>
      <a class="button-link primary" href="./lan-arcade-companion-debug.apk">Download Android APK</a>
    </div>

    <div class="grid">
      <section class="card">
        <h2>Android Companion APK</h2>
        <p><a href="./lan-arcade-companion-debug.apk">Download lan-arcade-companion-debug.apk</a></p>
        <p class="muted">Install this on Android phones that will connect to the LAN Arcade server. Browser games still work directly from the arcade page without this app.</p>
      </section>
      <section class="card">
        <h2>Server Addresses</h2>
        <p class="muted">Use these after replacing <code>&lt;server-ip&gt;</code> with the LAN Arcade host address.</p>
        <ol class="steps">
          <li>Browser arcade: <code>http://&lt;server-ip&gt;/mirrors/games/</code></li>
          <li>Companion app server: <code>http://&lt;server-ip&gt;/arcade-api/</code></li>
          <li>Tank Arena: <code>http://&lt;server-ip&gt;/mirrors/lan-tank-arena/</code></li>
        </ol>
      </section>
    </div>

    <section class="card">
      <h2>Android Install Steps</h2>
      <ol class="steps">
        <li>Open this downloads page on the Android phone or tablet.</li>
        <li>Tap <strong>Download Android APK</strong> and keep the file if the browser asks.</li>
        <li>Open the downloaded APK. If Android blocks it, allow installs from this browser for this one install.</li>
        <li>Open LAN Arcade Companion and set the server URL to <code>http://&lt;server-ip&gt;/arcade-api/</code>.</li>
        <li>Keep using <code>/mirrors/games/</code> in the browser for normal web games; the APK adds profiles, scores, app-only games, and service cards.</li>
      </ol>
    </section>

    <section class="card">
      <h2>Screenshots</h2>
      <div class="screens">
        <a href="./screenshots/companion-catalog.png"><img src="./screenshots/companion-catalog.png" alt="Companion catalog screenshot"></a>
        <a href="./screenshots/companion-trailguard.png"><img src="./screenshots/companion-trailguard.png" alt="Trailguard TD screenshot"></a>
        <a href="./screenshots/companion-unciv-service.png"><img src="./screenshots/companion-unciv-service.png" alt="Unciv LAN Server screenshot"></a>
        <a href="./screenshots/companion-mindustry-service.png"><img src="./screenshots/companion-mindustry-service.png" alt="Mindustry LAN Server screenshot"></a>
      </div>
    </section>
  </main>
</body>
</html>
HTML
}

write_wiki_index() {
  local arcade_name_html
  arcade_name_html="$(html_escape "$ARCADE_NAME_USE")"

  cat > "$WIKI_INDEX_FILE" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${arcade_name_html} LAN Arcade Wiki</title>
  <style>
    :root {
      --bg: #0a1420;
      --panel: #122235;
      --panel-soft: #0f1d2e;
      --text: #eef4fa;
      --muted: #a2b0bf;
      --accent: #6bcf78;
      --accent-soft: rgba(107, 207, 120, 0.15);
      --border: #213245;
      --danger: #ff8a80;
      --radius: 12px;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: radial-gradient(circle at top left, #10253a 0, #07101a 52%, #040a10 100%);
      color: var(--text);
    }
    .wrap {
      max-width: 1150px;
      margin: 0 auto;
      padding: 1.4rem;
    }
    h1 {
      margin: 0 0 0.45rem;
      font-size: 1.9rem;
    }
    .subtitle {
      margin: 0;
      color: var(--muted);
      line-height: 1.4;
    }
    .toolbar {
      margin-top: 1rem;
      display: flex;
      gap: 0.55rem;
      flex-wrap: wrap;
    }
    .link-btn {
      text-decoration: none;
      color: var(--text);
      border: 1px solid var(--border);
      border-radius: 999px;
      padding: 0.4rem 0.9rem;
      background: rgba(14, 26, 40, 0.85);
      font-size: 0.84rem;
      display: inline-flex;
      align-items: center;
    }
    .link-btn:hover { border-color: var(--accent); }
    .grid {
      margin-top: 1rem;
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 0.85rem;
    }
    .screenshots {
      margin-top: 1rem;
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 0.75rem;
    }
    .screenshots a {
      display: block;
      color: var(--text);
      text-decoration: none;
      font-size: 0.82rem;
      font-weight: 700;
    }
    .screenshots img {
      width: 100%;
      display: block;
      border: 1px solid var(--border);
      border-radius: 8px;
      background: #050b12;
      margin-bottom: 0.35rem;
    }
    .panel {
      border: 1px solid var(--border);
      border-radius: var(--radius);
      background: linear-gradient(160deg, var(--panel-soft), #0c1826);
      padding: 0.9rem;
    }
    .panel h2 {
      margin: 0 0 0.55rem;
      font-size: 1.05rem;
    }
    .panel p, .panel li {
      margin: 0;
      color: var(--muted);
      line-height: 1.45;
      font-size: 0.92rem;
    }
    .panel ul, .panel ol {
      margin: 0.4rem 0 0;
      padding-left: 1rem;
      display: grid;
      gap: 0.35rem;
    }
    code {
      background: rgba(162, 176, 191, 0.15);
      color: #d7e7f6;
      border-radius: 6px;
      padding: 0.1rem 0.3rem;
      font-size: 0.85em;
    }
    .library {
      margin-top: 1rem;
      border: 1px solid var(--border);
      border-radius: var(--radius);
      background: linear-gradient(160deg, #0d1d2d, #0a1622);
      padding: 0.9rem;
    }
    .library-head {
      display: flex;
      justify-content: space-between;
      align-items: end;
      gap: 0.8rem;
      flex-wrap: wrap;
      margin-bottom: 0.75rem;
    }
    .library h2 {
      margin: 0;
      font-size: 1.1rem;
    }
    .summary {
      color: var(--muted);
      font-size: 0.88rem;
    }
    .controls {
      display: grid;
      grid-template-columns: 1fr 220px auto;
      gap: 0.5rem;
      margin-bottom: 0.7rem;
      align-items: center;
    }
    .controls input[type="search"], .controls select {
      width: 100%;
      border-radius: 10px;
      border: 1px solid var(--border);
      background: var(--panel);
      color: var(--text);
      padding: 0.48rem 0.6rem;
    }
    .controls label {
      color: var(--muted);
      font-size: 0.86rem;
      display: inline-flex;
      align-items: center;
      gap: 0.35rem;
      white-space: nowrap;
    }
    .table-wrap {
      overflow: auto;
      border: 1px solid var(--border);
      border-radius: 10px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      min-width: 800px;
    }
    thead th {
      text-align: left;
      font-size: 0.78rem;
      text-transform: uppercase;
      letter-spacing: 0.07em;
      color: var(--muted);
      background: rgba(13, 25, 38, 0.95);
      position: sticky;
      top: 0;
      z-index: 1;
    }
    th, td {
      border-bottom: 1px solid rgba(33, 50, 69, 0.7);
      padding: 0.55rem 0.6rem;
      vertical-align: top;
      font-size: 0.86rem;
    }
    tbody tr:hover {
      background: rgba(107, 207, 120, 0.06);
    }
    .game-link {
      color: #c8f7d0;
      text-decoration: none;
      font-weight: 600;
    }
    .game-link:hover { text-decoration: underline; }
    .hidden-yes { color: var(--danger); font-weight: 600; }
    .hidden-no { color: #b9f6ca; }
    .chip-row {
      display: flex;
      flex-wrap: wrap;
      gap: 0.3rem;
    }
    .chip {
      border-radius: 999px;
      padding: 0.1rem 0.45rem;
      background: rgba(162, 176, 191, 0.16);
      color: var(--muted);
      font-size: 0.75rem;
      line-height: 1.35;
    }
    .chip--category {
      background: var(--accent-soft);
      color: #d9f8df;
    }
    @media (max-width: 900px) {
      .controls {
        grid-template-columns: 1fr;
      }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <h1>${arcade_name_html} LAN Arcade Wiki</h1>
    <p class="subtitle">
      Offline documentation and searchable game catalog for this LAN Arcade install.
    </p>

    <div class="toolbar">
      <a class="link-btn" href="../">Back To Arcade</a>
      <a class="link-btn" href="../admin/">Admin Controls</a>
      <a class="link-btn" href="../downloads/">Downloads</a>
      <a class="link-btn" href="../downloads/lan-arcade-companion-debug.apk">Companion APK</a>
    </div>

    <section class="grid">
      <article class="panel">
        <h2>Admin Controls</h2>
        <ol>
          <li>Open <code>/mirrors/games/admin/</code> and sign in.</li>
          <li>Tick categories and games you want disabled.</li>
          <li>Click <strong>Save Changes</strong> to write <code>admin.filters.json</code>.</li>
          <li>Public arcade updates immediately using those filters.</li>
        </ol>
      </article>

      <article class="panel">
        <h2>Core Files</h2>
        <ul>
          <li><code>/mirrors/games/catalog.json</code> - generated game data + categories.</li>
          <li><code>/mirrors/games/admin.filters.json</code> - disabled categories and games.</li>
          <li><code>/mirrors/games/index.html</code> - public arcade page.</li>
          <li><code>/mirrors/games/wiki/index.html</code> - this offline wiki page.</li>
          <li><code>/mirrors/games/downloads/</code> - Android APK and companion screenshots.</li>
        </ul>
      </article>

      <article class="panel">
        <h2>Original Browser Games</h2>
        <ul>
          <li><code>outpost-siege</code> - tower defense with waves, upgrades, and local save progress.</li>
          <li><code>breachline-tactics</code> - turn-based tactical grid combat with squad abilities.</li>
          <li><code>circuit-foundry</code> - mini factory automation with generators, belts, and assemblers.</li>
          <li><code>lan-tank-arena</code> - LAN multiplayer tank combat backed by a local WebSocket server.</li>
        </ul>
      </article>

      <article class="panel">
        <h2>LAN Tank Arena</h2>
        <ul>
          <li>Play URL: <code>/mirrors/lan-tank-arena/</code>.</li>
          <li>Service: <code>lan-tank-arena.service</code>.</li>
          <li>Default health check: <code>http://127.0.0.1:8787/tank-arena/healthz</code>.</li>
          <li>Players join with a callsign and shared room code from any LAN browser.</li>
        </ul>
      </article>

      <article class="panel">
        <h2>Companion App</h2>
        <ul>
          <li>Android APK: <code>/mirrors/games/downloads/lan-arcade-companion-debug.apk</code>.</li>
          <li>Downloads and install notes: <code>/mirrors/games/downloads/</code>.</li>
          <li>Server URL on phones: <code>http://&lt;pi-ip&gt;/arcade-api/</code>.</li>
          <li>Includes app-only games, local profiles, scores, and Pi service cards.</li>
          <li>Mirrors the PestSense WiFi provisioning app handoff style: a direct APK download plus simple local instructions.</li>
        </ul>
      </article>

      <article class="panel">
        <h2>Update Flow</h2>
        <ul>
          <li>Edit <code>games.meta.sh</code> for new games or metadata.</li>
          <li>Run <code>sudo ./setup_lan_arcade.sh</code> again.</li>
          <li>Catalog, pages, and admin controls are regenerated.</li>
          <li>Game folders with completion markers are skipped safely.</li>
        </ul>
      </article>

      <article class="panel">
        <h2>QA Flow</h2>
        <ul>
          <li>Static mirror audit: <code>npm run qa:static</code>.</li>
          <li>Catalog browser smoke: <code>npm run qa:smoke -- --catalog</code>.</li>
          <li>Focused game gate: <code>npm run qa:game -- &lt;game-id&gt;</code>.</li>
          <li>Tank multiplayer gate: <code>npm run qa:tank</code>.</li>
          <li>Chunk long runs with <code>--offset</code> and <code>--limit</code>.</li>
        </ul>
      </article>
    </section>

    <section class="panel">
      <h2>Companion Screenshots</h2>
      <p>These screenshots are copied into the offline downloads folder when setup runs.</p>
      <div class="screenshots">
        <a href="../downloads/screenshots/companion-catalog.png"><img src="../downloads/screenshots/companion-catalog.png" alt="Companion catalog screenshot">Catalog and profiles</a>
        <a href="../downloads/screenshots/companion-trailguard.png"><img src="../downloads/screenshots/companion-trailguard.png" alt="Trailguard TD screenshot">Trailguard TD</a>
        <a href="../downloads/screenshots/companion-unciv-service.png"><img src="../downloads/screenshots/companion-unciv-service.png" alt="Unciv service screenshot">Unciv service card</a>
        <a href="../downloads/screenshots/companion-mindustry-service.png"><img src="../downloads/screenshots/companion-mindustry-service.png" alt="Mindustry service screenshot">Mindustry service card</a>
      </div>
    </section>

    <section class="library">
      <div class="library-head">
        <h2>Game Library</h2>
        <div id="gamesSummary" class="summary">Loading game catalog...</div>
      </div>

      <div class="controls">
        <input id="searchInput" type="search" placeholder="Search title, id, tags, categories, description...">
        <select id="categoryFilter">
          <option value="">All categories</option>
        </select>
        <label><input id="showHiddenToggle" type="checkbox" checked> Show admin-hidden games</label>
      </div>

      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Game</th>
              <th>Categories</th>
              <th>Tags</th>
              <th>Admin Hidden</th>
              <th>Description</th>
            </tr>
          </thead>
          <tbody id="gamesBody"></tbody>
        </table>
      </div>
    </section>
  </div>

  <script>
    (function () {
      "use strict";

      var state = {
        catalog: { categories: [], games: [] },
        filters: { disabled_categories: [], disabled_games: [] },
        query: "",
        category: "",
        showHidden: true
      };

      function toStringArray(value) {
        if (!Array.isArray(value)) return [];
        return value.map(function (item) { return String(item).trim(); }).filter(function (item) { return item.length > 0; });
      }

      function uniqueArray(items) {
        var seen = Object.create(null);
        var output = [];
        items.forEach(function (item) {
          if (!seen[item]) {
            seen[item] = true;
            output.push(item);
          }
        });
        return output;
      }

      function normalizeFilters(raw) {
        var source = raw || {};
        return {
          disabled_categories: uniqueArray(toStringArray(source.disabled_categories)),
          disabled_games: uniqueArray(toStringArray(source.disabled_games))
        };
      }

      function fetchJson(url, fallbackValue) {
        return fetch(url, { cache: "no-store" })
          .then(function (response) {
            if (!response.ok) throw new Error("HTTP " + response.status);
            return response.json();
          })
          .catch(function () {
            return fallbackValue;
          });
      }

      function categoryLabelMap() {
        var map = Object.create(null);
        (Array.isArray(state.catalog.categories) ? state.catalog.categories : []).forEach(function (category) {
          if (!category || !category.id) return;
          map[String(category.id)] = category.label ? String(category.label) : String(category.id);
        });
        return map;
      }

      function hiddenByAdmin(game) {
        var disabledGames = new Set(state.filters.disabled_games);
        var disabledCategories = new Set(state.filters.disabled_categories);
        if (disabledGames.has(String(game.id || ""))) return true;
        return toStringArray(game.categories).some(function (categoryId) {
          return disabledCategories.has(categoryId);
        });
      }

      function clearChildren(el) {
        el.textContent = "";
      }

      function populateCategoryFilter() {
        var select = document.getElementById("categoryFilter");
        var used = new Set();
        var labelMap = categoryLabelMap();
        state.catalog.games.forEach(function (game) {
          toStringArray(game.categories).forEach(function (categoryId) {
            used.add(categoryId);
          });
        });

        clearChildren(select);
        var allOption = document.createElement("option");
        allOption.value = "";
        allOption.textContent = "All categories";
        select.appendChild(allOption);

        (Array.isArray(state.catalog.categories) ? state.catalog.categories : []).forEach(function (category) {
          var id = String(category && category.id ? category.id : "");
          if (!id || !used.has(id)) return;
          var option = document.createElement("option");
          option.value = id;
          option.textContent = labelMap[id] || id;
          select.appendChild(option);
        });

        select.value = state.category || "";
      }

      function createChipRow(values, map, extraClass) {
        var wrap = document.createElement("div");
        wrap.className = "chip-row";
        values.forEach(function (value) {
          var chip = document.createElement("span");
          chip.className = "chip" + (extraClass ? " " + extraClass : "");
          chip.textContent = map && map[value] ? map[value] : value;
          wrap.appendChild(chip);
        });
        return wrap;
      }

      function renderGames() {
        var body = document.getElementById("gamesBody");
        var summary = document.getElementById("gamesSummary");
        var labelMap = categoryLabelMap();
        var games = Array.isArray(state.catalog.games) ? state.catalog.games.slice() : [];

        games.sort(function (a, b) {
          return String(a.title || a.id).localeCompare(String(b.title || b.id));
        });

        var filtered = games.filter(function (game) {
          var categories = toStringArray(game.categories);
          var tags = toStringArray(game.tags);
          var searchable = [
            String(game.id || ""),
            String(game.title || ""),
            String(game.description || ""),
            tags.join(" "),
            categories.join(" ")
          ].join(" ").toLowerCase();

          if (state.query && searchable.indexOf(state.query) < 0) return false;
          if (state.category && categories.indexOf(state.category) < 0) return false;
          if (!state.showHidden && hiddenByAdmin(game)) return false;
          return true;
        });

        clearChildren(body);
        var hiddenInView = 0;

        filtered.forEach(function (game) {
          var isHidden = hiddenByAdmin(game);
          if (isHidden) hiddenInView += 1;

          var tr = document.createElement("tr");

          var gameTd = document.createElement("td");
          var link = document.createElement("a");
          link.className = "game-link";
          link.href = game.path ? String(game.path) : "../" + encodeURIComponent(String(game.id || "")) + "/";
          link.textContent = String(game.title || game.id || "Unknown");
          gameTd.appendChild(link);
          var idText = document.createElement("div");
          idText.style.color = "var(--muted)";
          idText.style.fontSize = "0.77rem";
          idText.textContent = String(game.id || "");
          gameTd.appendChild(idText);
          tr.appendChild(gameTd);

          var categoriesTd = document.createElement("td");
          categoriesTd.appendChild(createChipRow(toStringArray(game.categories), labelMap, "chip--category"));
          tr.appendChild(categoriesTd);

          var tagsTd = document.createElement("td");
          tagsTd.appendChild(createChipRow(toStringArray(game.tags), null, ""));
          tr.appendChild(tagsTd);

          var hiddenTd = document.createElement("td");
          hiddenTd.className = isHidden ? "hidden-yes" : "hidden-no";
          hiddenTd.textContent = isHidden ? "Yes" : "No";
          tr.appendChild(hiddenTd);

          var descTd = document.createElement("td");
          descTd.textContent = String(game.description || "");
          tr.appendChild(descTd);

          body.appendChild(tr);
        });

        if (filtered.length === 0) {
          var emptyRow = document.createElement("tr");
          var emptyCell = document.createElement("td");
          emptyCell.colSpan = 5;
          emptyCell.style.color = "var(--muted)";
          emptyCell.textContent = "No games match the current filters.";
          emptyRow.appendChild(emptyCell);
          body.appendChild(emptyRow);
        }

        summary.textContent =
          "Showing " + filtered.length + " of " + games.length + " games." +
          " Hidden by admin in this view: " + hiddenInView + ".";
      }

      Promise.all([
        fetchJson("../catalog.json", { categories: [], games: [] }),
        fetchJson("../admin.filters.json", { disabled_categories: [], disabled_games: [] })
      ]).then(function (results) {
        state.catalog = results[0] || { categories: [], games: [] };
        state.filters = normalizeFilters(results[1]);
        populateCategoryFilter();
        renderGames();
      }).catch(function () {
        document.getElementById("gamesSummary").textContent = "Failed to load game catalog.";
      });

      document.getElementById("searchInput").addEventListener("input", function (event) {
        state.query = String(event.target.value || "").toLowerCase().trim();
        renderGames();
      });

      document.getElementById("categoryFilter").addEventListener("change", function (event) {
        state.category = String(event.target.value || "");
        renderGames();
      });

      document.getElementById("showHiddenToggle").addEventListener("change", function (event) {
        state.showHidden = !!event.target.checked;
        renderGames();
      });
    })();
  </script>
</body>
</html>
HTML
}

write_admin_cgi() {
  cat > "$ADMIN_CGI_FILE" <<'CGI'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FILTERS_FILE="$SCRIPT_DIR/../admin.filters.json"

respond_json() {
  local status="$1"
  local payload="$2"
  printf 'Status: %s\r\n' "$status"
  printf 'Content-Type: application/json\r\n'
  printf 'Cache-Control: no-store\r\n'
  printf '\r\n'
  printf '%s\n' "$payload"
  exit 0
}

trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

json_escape() {
  local text="$1"
  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  text="${text//$'\n'/\\n}"
  text="${text//$'\r'/\\r}"
  text="${text//$'\t'/\\t}"
  printf '%s' "$text"
}

url_decode() {
  local input="${1//+/ }"
  printf '%b' "${input//%/\\x}"
}

json_array_from_values() {
  local value escaped
  local first=1
  local output=""
  for value in "$@"; do
    escaped="$(json_escape "$value")"
    if [ "$first" -eq 1 ]; then
      output="\"$escaped\""
      first=0
    else
      output="$output,\"$escaped\""
    fi
  done
  printf '%s' "$output"
}

parse_csv_unique() {
  local raw="$1"
  local mode="$2"
  local -n out_ref="$3"
  local -a parts=()
  local -A seen=()
  local part token

  out_ref=()
  IFS=',' read -ra parts <<< "$raw"
  for part in "${parts[@]}"; do
    token="$(trim_whitespace "$part")"
    [ -z "$token" ] && continue

    if [ "$mode" = "category" ]; then
      token="$(printf '%s' "$token" | tr '[:upper:]' '[:lower:]')"
      [[ "$token" =~ ^[a-z0-9][a-z0-9-]*$ ]] || continue
    else
      [[ "$token" =~ ^[A-Za-z0-9._-]+$ ]] || continue
    fi

    if [ -z "${seen[$token]+x}" ]; then
      seen["$token"]=1
      out_ref+=("$token")
    fi
  done
}

if [ "${REQUEST_METHOD:-}" != "POST" ]; then
  respond_json "405 Method Not Allowed" '{"ok":false,"error":"Use POST"}'
fi

if ! [[ "${CONTENT_LENGTH:-0}" =~ ^[0-9]+$ ]]; then
  respond_json "400 Bad Request" '{"ok":false,"error":"Invalid content length"}'
fi

if [ "${CONTENT_LENGTH:-0}" -gt 65535 ]; then
  respond_json "413 Payload Too Large" '{"ok":false,"error":"Payload too large"}'
fi

body=""
if [ "${CONTENT_LENGTH:-0}" -gt 0 ]; then
  IFS= read -r -n "${CONTENT_LENGTH}" body || true
fi

disabled_categories_raw=""
disabled_games_raw=""

IFS='&' read -ra pairs <<< "$body"
for pair in "${pairs[@]}"; do
  key="${pair%%=*}"
  value=""
  if [[ "$pair" == *"="* ]]; then
    value="${pair#*=}"
  fi
  key="$(url_decode "$key")"
  value="$(url_decode "$value")"
  case "$key" in
    disabled_categories) disabled_categories_raw="$value" ;;
    disabled_games) disabled_games_raw="$value" ;;
  esac
done

declare -a disabled_categories=()
declare -a disabled_games=()
parse_csv_unique "$disabled_categories_raw" "category" disabled_categories
parse_csv_unique "$disabled_games_raw" "game" disabled_games

tmp_file="$(mktemp "$SCRIPT_DIR/../admin.filters.json.tmp.XXXXXX")"
{
  printf '{\n'
  printf '  "disabled_categories": [%s],\n' "$(json_array_from_values "${disabled_categories[@]}")"
  printf '  "disabled_games": [%s]\n' "$(json_array_from_values "${disabled_games[@]}")"
  printf '}\n'
} > "$tmp_file"

mv "$tmp_file" "$FILTERS_FILE"
chmod 644 "$FILTERS_FILE"

respond_json "200 OK" "{\"ok\":true,\"disabled_categories\":${#disabled_categories[@]},\"disabled_games\":${#disabled_games[@]}}"
CGI

  chmod 755 "$ADMIN_CGI_FILE"
}

write_admin_index() {
  cat > "$ADMIN_INDEX_FILE" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>LAN Arcade Admin</title>
  <style>
    :root {
      --bg: #0c1724;
      --panel: #112235;
      --panel-soft: #0e1c2b;
      --border: #203043;
      --text: #eef3f8;
      --muted: #9aa8b8;
      --accent: #66bb6a;
      --danger: #ef5350;
      --radius: 12px;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: linear-gradient(180deg, #0f1e2f 0%, #09111b 100%);
      color: var(--text);
    }
    .wrap {
      max-width: 1200px;
      margin: 0 auto;
      padding: 1.4rem;
    }
    h1 {
      margin: 0 0 0.4rem;
      font-size: 1.8rem;
    }
    .subtitle {
      color: var(--muted);
      margin-bottom: 1rem;
      line-height: 1.35;
    }
    .toolbar {
      display: flex;
      flex-wrap: wrap;
      gap: 0.6rem;
      margin-bottom: 1rem;
    }
    button, .link-btn {
      background: rgba(20, 33, 49, 0.9);
      color: var(--text);
      border: 1px solid var(--border);
      border-radius: 999px;
      padding: 0.45rem 0.95rem;
      cursor: pointer;
      font-size: 0.86rem;
      text-decoration: none;
      display: inline-flex;
      align-items: center;
    }
    button:hover, .link-btn:hover {
      border-color: var(--accent);
    }
    .panel-grid {
      display: grid;
      grid-template-columns: 300px 1fr;
      gap: 1rem;
    }
    .panel {
      border: 1px solid var(--border);
      background: var(--panel-soft);
      border-radius: var(--radius);
      padding: 0.9rem;
      min-height: 280px;
    }
    .panel h2 {
      margin: 0 0 0.65rem;
      font-size: 1.05rem;
    }
    .help {
      color: var(--muted);
      font-size: 0.82rem;
      margin-top: -0.3rem;
      margin-bottom: 0.7rem;
    }
    .list {
      display: grid;
      gap: 0.4rem;
      max-height: 60vh;
      overflow: auto;
      padding-right: 0.25rem;
    }
    label.item {
      display: grid;
      grid-template-columns: auto 1fr;
      align-items: start;
      gap: 0.45rem;
      padding: 0.35rem 0.4rem;
      border-radius: 8px;
      background: rgba(23, 35, 52, 0.7);
      border: 1px solid transparent;
    }
    label.item:hover {
      border-color: var(--border);
    }
    .item-meta {
      color: var(--muted);
      font-size: 0.76rem;
      margin-top: 0.15rem;
      line-height: 1.3;
    }
    .search {
      width: 100%;
      margin-bottom: 0.7rem;
      border-radius: 10px;
      border: 1px solid var(--border);
      background: var(--panel);
      color: var(--text);
      padding: 0.5rem 0.6rem;
    }
    .status {
      margin-top: 0.7rem;
      min-height: 1.2rem;
      color: var(--muted);
      font-size: 0.9rem;
    }
    .status.error { color: var(--danger); }
    .status.ok { color: var(--accent); }
    @media (max-width: 900px) {
      .panel-grid { grid-template-columns: 1fr; }
      .list { max-height: 45vh; }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <h1>LAN Arcade Admin</h1>
    <div class="subtitle">
      Disable whole categories or specific games. Changes are saved to <code>admin.filters.json</code>
      and applied on the public index immediately.
    </div>

    <div class="toolbar">
      <button id="saveBtn" type="button">Save Changes</button>
      <button id="enableAllBtn" type="button">Enable All</button>
      <button id="reloadBtn" type="button">Reload From Disk</button>
      <a class="link-btn" href="../wiki/">Wiki</a>
      <a class="link-btn" href="../">Back To Arcade</a>
    </div>

    <div class="panel-grid">
      <section class="panel">
        <h2>Disable Categories</h2>
        <div class="help">Checking a category hides all games in that category.</div>
        <div id="categoriesList" class="list"></div>
      </section>

      <section class="panel">
        <h2>Disable Individual Games</h2>
        <input id="gameSearch" class="search" type="search" placeholder="Search games...">
        <div id="gamesList" class="list"></div>
      </section>
    </div>

    <div id="status" class="status"></div>
  </div>

  <script>
    (function () {
      "use strict";

      var state = {
        catalog: { categories: [], games: [] },
        filters: { disabled_categories: [], disabled_games: [] }
      };

      function toStringArray(value) {
        if (!Array.isArray(value)) return [];
        return value.map(function (item) { return String(item).trim(); }).filter(function (item) { return item.length > 0; });
      }

      function uniqueArray(items) {
        var seen = Object.create(null);
        var output = [];
        items.forEach(function (item) {
          if (!seen[item]) {
            seen[item] = true;
            output.push(item);
          }
        });
        return output;
      }

      function normalizeFilters(raw) {
        var source = raw || {};
        return {
          disabled_categories: uniqueArray(toStringArray(source.disabled_categories)),
          disabled_games: uniqueArray(toStringArray(source.disabled_games))
        };
      }

      function fetchJson(url, fallbackValue) {
        return fetch(url, { cache: "no-store" })
          .then(function (response) {
            if (!response.ok) throw new Error("HTTP " + response.status);
            return response.json();
          })
          .catch(function () {
            return fallbackValue;
          });
      }

      function categoryLabelMap() {
        var map = Object.create(null);
        (Array.isArray(state.catalog.categories) ? state.catalog.categories : []).forEach(function (category) {
          if (!category || !category.id) return;
          map[String(category.id)] = category.label ? String(category.label) : String(category.id);
        });
        return map;
      }

      function setStatus(message, tone) {
        var status = document.getElementById("status");
        status.textContent = message;
        status.className = "status";
        if (tone === "ok") status.classList.add("ok");
        if (tone === "error") status.classList.add("error");
      }

      function buildCategories() {
        var wrapper = document.getElementById("categoriesList");
        var disabledSet = new Set(state.filters.disabled_categories);
        wrapper.textContent = "";

        (Array.isArray(state.catalog.categories) ? state.catalog.categories : []).forEach(function (category) {
          var id = String(category.id || "");
          if (!id) return;

          var label = document.createElement("label");
          label.className = "item";

          var input = document.createElement("input");
          input.type = "checkbox";
          input.dataset.kind = "category";
          input.value = id;
          input.checked = disabledSet.has(id);

          var textWrap = document.createElement("span");
          textWrap.textContent = category.label ? String(category.label) : id;

          label.appendChild(input);
          label.appendChild(textWrap);
          wrapper.appendChild(label);
        });
      }

      function buildGames() {
        var wrapper = document.getElementById("gamesList");
        var disabledSet = new Set(state.filters.disabled_games);
        var labelsByCategory = categoryLabelMap();
        wrapper.textContent = "";

        var games = Array.isArray(state.catalog.games) ? state.catalog.games.slice() : [];
        games.sort(function (a, b) {
          return String(a.title || a.id).localeCompare(String(b.title || b.id));
        });

        games.forEach(function (game) {
          var id = String(game.id || "");
          if (!id) return;

          var label = document.createElement("label");
          label.className = "item game-item";
          label.dataset.search = (String(game.title || "") + " " + id).toLowerCase();

          var input = document.createElement("input");
          input.type = "checkbox";
          input.dataset.kind = "game";
          input.value = id;
          input.checked = disabledSet.has(id);

          var textWrap = document.createElement("span");
          textWrap.textContent = game.title ? String(game.title) : id;

          var meta = document.createElement("div");
          meta.className = "item-meta";
          var categoryLabels = toStringArray(game.categories).map(function (categoryId) {
            return labelsByCategory[categoryId] || categoryId;
          });
          meta.textContent = id + (categoryLabels.length ? " / " + categoryLabels.join(", ") : "");

          textWrap.appendChild(meta);
          label.appendChild(input);
          label.appendChild(textWrap);
          wrapper.appendChild(label);
        });
      }

      function collectDisabledValues(kind) {
        return uniqueArray(
          Array.from(document.querySelectorAll("input[data-kind='" + kind + "']:checked"))
            .map(function (checkbox) { return String(checkbox.value).trim(); })
            .filter(function (value) { return value.length > 0; })
        );
      }

      function applySearch() {
        var q = String(document.getElementById("gameSearch").value || "").toLowerCase().trim();
        Array.from(document.querySelectorAll(".game-item")).forEach(function (item) {
          item.hidden = q && String(item.dataset.search || "").indexOf(q) < 0;
        });
      }

      function reloadFromDisk() {
        setStatus("Reloading...", "");
        return Promise.all([
          fetchJson("../catalog.json", { categories: [], games: [] }),
          fetchJson("../admin.filters.json", { disabled_categories: [], disabled_games: [] })
        ]).then(function (results) {
          state.catalog = results[0] || { categories: [], games: [] };
          state.filters = normalizeFilters(results[1]);
          buildCategories();
          buildGames();
          applySearch();
          setStatus("Loaded " + (state.catalog.games || []).length + " games.", "");
        });
      }

      function saveFilters() {
        var disabledCategories = collectDisabledValues("category");
        var disabledGames = collectDisabledValues("game");
        var payload = new URLSearchParams();
        payload.set("disabled_categories", disabledCategories.join(","));
        payload.set("disabled_games", disabledGames.join(","));

        setStatus("Saving filters...", "");
        return fetch("./save_filters.cgi", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: payload.toString(),
          cache: "no-store"
        })
          .then(function (response) {
            return response.json().catch(function () { return {}; }).then(function (data) {
              if (!response.ok || !data.ok) {
                throw new Error(data.error || ("HTTP " + response.status));
              }
              state.filters = {
                disabled_categories: disabledCategories,
                disabled_games: disabledGames
              };
              setStatus("Saved. Public arcade now reflects these filters.", "ok");
            });
          })
          .catch(function (error) {
            setStatus("Save failed: " + error.message, "error");
          });
      }

      document.getElementById("saveBtn").addEventListener("click", function () {
        saveFilters();
      });

      document.getElementById("enableAllBtn").addEventListener("click", function () {
        Array.from(document.querySelectorAll("input[type='checkbox']")).forEach(function (checkbox) {
          checkbox.checked = false;
        });
        setStatus("All categories and games set to enabled. Click Save Changes to persist.", "");
      });

      document.getElementById("reloadBtn").addEventListener("click", function () {
        reloadFromDisk().catch(function () {
          setStatus("Could not reload catalog or filters.", "error");
        });
      });

      document.getElementById("gameSearch").addEventListener("input", applySearch);

      reloadFromDisk().catch(function () {
        setStatus("Failed to load catalog.", "error");
      });
    })();
  </script>
</body>
</html>
HTML
}

if [ "$LAN_ARCADE_SKIP_ADMIN_AUTH" = "1" ]; then
  echo "===== Skipping admin access setup because LAN_ARCADE_SKIP_ADMIN_AUTH=1 ====="
else
  echo "===== Preparing admin access ====="
  configure_admin_credentials
fi

# ---------- Mirror each game ----------
if [ "$LAN_ARCADE_SKIP_MIRROR" = "1" ]; then
  echo "===== Skipping game mirroring because LAN_ARCADE_SKIP_MIRROR=1 ====="
else
  echo "===== Mirroring games into $MIRRORS_DIR ====="

  for GAME in "${!GAMES[@]}"; do
    URL="${GAMES[$GAME]}"
    TARGET="$MIRRORS_DIR/$GAME"
    MARKER="$TARGET/$READY_MARKER"

    if [ -f "$MARKER" ]; then
      if [[ "$URL" == LOCAL_DIR::* ]]; then
        echo "Refreshing local bundled game $GAME"
        rm -rf "$TARGET"
      elif mirror_content_is_complete "$GAME" "$TARGET"; then
        patch_mirror_for_offline_use "$GAME" "$TARGET"
        echo "OK   $GAME already exists, skipping download"
        continue
      fi
      if [ -d "$TARGET" ]; then
        echo "WARN $GAME has a stale completion marker; re-downloading."
        rm -f "$MARKER"
      fi
    fi

    if [ -d "$TARGET" ] && [ -n "$(find "$TARGET" -mindepth 1 ! -name "$READY_MARKER" -print -quit 2>/dev/null || true)" ]; then
      echo "⚠️  $GAME has partial content but no completion marker; re-downloading."
      rm -rf "$TARGET"
    fi

    echo "🌐 Downloading $GAME from $URL"
    mkdir -p "$TARGET"
    if [ "$RUNNING_AS_ROOT" -eq 1 ]; then
      chown "$LOCAL_USER:$LOCAL_USER" "$TARGET"
    fi
    cd "$TARGET"
    download_ok=1

    local_source_dir=""
    if [[ "$URL" == LOCAL_DIR::* ]]; then
      local_spec="${URL#LOCAL_DIR::}"
      local_source_dir="$SCRIPT_DIR/$local_spec"
    fi

    git_repo=""
    git_branch=""
    if [[ "$URL" == GIT_GITHUB_REPO::* ]]; then
      git_spec="${URL#GIT_GITHUB_REPO::}"
      git_repo="${git_spec%%::*}"
      git_rest="${git_spec#*::}"
      if [ "$git_rest" != "$git_spec" ]; then
        git_branch="$git_rest"
      fi
    fi

    zip_repo=""
    zip_branch=""
    if [ "$URL" = "ZIP_GITHUB_REPO" ] && [ "$GAME" = "typing-test" ]; then
      zip_repo="KDvs123/Typing-Test"
      zip_branch="main"
    elif [[ "$URL" == ZIP_GITHUB_REPO::* ]]; then
      zip_spec="${URL#ZIP_GITHUB_REPO::}"
      zip_repo="${zip_spec%%::*}"
      zip_rest="${zip_spec#*::}"
      if [ "$zip_rest" != "$zip_spec" ]; then
        zip_branch="$zip_rest"
      fi
    fi

    if [ -n "$local_source_dir" ]; then
      if [ -d "$local_source_dir" ]; then
        shopt -s dotglob nullglob
        cp -a "$local_source_dir"/* "$TARGET"/ 2>/dev/null || true
        shopt -u dotglob nullglob
        promote_entrypoint_if_missing "$TARGET"
      else
        echo "⚠️ Local source directory not found for $GAME: $local_source_dir"
        download_ok=0
      fi
    elif [ -n "$git_repo" ]; then
      if [ -z "$git_branch" ]; then
        git_branch="main"
      fi
      clone_url="https://github.com/$git_repo.git"
      tmp_clone_dir="$(mktemp -d)"

      if git clone --depth 1 --branch "$git_branch" --recurse-submodules "$clone_url" "$tmp_clone_dir"; then
        shopt -s dotglob nullglob
        mv "$tmp_clone_dir"/* "$TARGET"/ 2>/dev/null || true
        shopt -u dotglob nullglob
        rm -rf "$tmp_clone_dir"

        # Remove git internals from mirrored content.
        find "$TARGET" -type d -name '.git' -prune -exec rm -rf {} + 2>/dev/null || true
        find "$TARGET" -type f -name '.git' -delete 2>/dev/null || true

        promote_entrypoint_if_missing "$TARGET"
      else
        echo "⚠️ Failed to clone repository for $GAME ($git_repo@$git_branch)."
        rm -rf "$tmp_clone_dir"
        download_ok=0
      fi
    elif [ -n "$zip_repo" ]; then
      if [ -z "$zip_branch" ]; then
        zip_branch="main"
      fi
      repo_name="${zip_repo##*/}"
      archive_name="${GAME}.zip"
      archive_url="https://github.com/$zip_repo/archive/refs/heads/$zip_branch.zip"

      if wget -O "$archive_name" "$archive_url"; then
        if unzip -q "$archive_name"; then
          src_dir="$(find . -maxdepth 1 -type d -name "${repo_name}-${zip_branch}*" | head -n1 || true)"
          if [ -n "$src_dir" ] && [ -d "$src_dir" ]; then
            shopt -s dotglob nullglob
            mv "$src_dir"/* "$TARGET"/ 2>/dev/null || true
            shopt -u dotglob nullglob
            rm -rf "$src_dir"

            # Some repos ship a differently named HTML entrypoint; promote one to index.html.
            promote_entrypoint_if_missing "$TARGET"
          else
            echo "⚠️ Could not locate extracted repo folder for $GAME ($zip_repo@$zip_branch)."
            download_ok=0
          fi
        else
          echo "⚠️ Failed to extract archive for $GAME ($archive_url)."
          download_ok=0
        fi
        rm -f "$archive_name"
      else
        echo "⚠️ Failed to download archive for $GAME ($archive_url)."
        download_ok=0
      fi
    elif [[ "$URL" == ZIP_GITHUB_FILE::* ]]; then
      spec="${URL#ZIP_GITHUB_FILE::}"
      repo="${spec%%::*}"
      rest="${spec#*::}"
      branch="${rest%%::*}"
      file_path="${rest#*::}"

      if [ -z "$repo" ] || [ "$rest" = "$spec" ] || [ -z "$branch" ] || [ "$file_path" = "$rest" ] || [ -z "$file_path" ]; then
        echo "⚠️ Invalid ZIP_GITHUB_FILE source for $GAME: $URL"
        download_ok=0
      else
        repo_name="${repo##*/}"
        archive_name="${GAME}.zip"
        archive_url="https://github.com/$repo/archive/refs/heads/$branch.zip"

        if wget -O "$archive_name" "$archive_url"; then
          if unzip -q "$archive_name"; then
            src_dir="$(find . -maxdepth 1 -type d -name "${repo_name}-${branch}*" | head -n1 || true)"
            src_file=""
            if [ -n "$src_dir" ] && [ -f "$src_dir/$file_path" ]; then
              src_file="$src_dir/$file_path"
            elif [ -n "$src_dir" ]; then
              src_file="$(find "$src_dir" -type f -name "$(basename "$file_path")" | head -n1 || true)"
            fi

            if [ -n "$src_file" ] && [ -f "$src_file" ]; then
              cp "$src_file" "$TARGET/index.html"
            else
              echo "⚠️ Could not locate '$file_path' in $repo@$branch for $GAME."
              download_ok=0
            fi

            [ -n "$src_dir" ] && rm -rf "$src_dir"
          else
            echo "⚠️ Failed to extract archive for $GAME ($archive_url)."
            download_ok=0
          fi
          rm -f "$archive_name"
        else
          echo "⚠️ Failed to download archive for $GAME ($archive_url)."
          download_ok=0
        fi
      fi
    else
      if ! wget \
        --mirror \
        --convert-links \
        --adjust-extension \
        --page-requisites \
        --no-parent \
        "$URL"; then
        echo "WARN wget reported fetch errors for $GAME; validating mirrored content before deciding completion."
      fi

      flatten_mirror "$URL" "$TARGET"
    fi

    patch_mirror_for_offline_use "$GAME" "$TARGET"

    if [ "$download_ok" -eq 1 ] && mirror_content_is_complete "$GAME" "$TARGET"; then
      touch "$MARKER"
    else
      rm -f "$MARKER"
      echo "⚠️ $GAME did not complete successfully; it will be retried next run."
    fi

    if [ "$RUNNING_AS_ROOT" -eq 1 ]; then
      chown -R www-data:www-data "$TARGET"
    fi
    # IdleAnt expects to be hosted at /IdleAnt/ (GitHub Pages base path); provide an alias.
    if [ "$RUNNING_AS_ROOT" -eq 1 ] && [ "$GAME" = "IdleAnt" ]; then
      ln -sfn "$TARGET" "/var/www/html/IdleAnt"
    fi
  done
fi

echo "===== Building catalog and pages in $INDEX_DIR ====="
build_catalog_json
ensure_filters_file
write_public_index
publish_companion_downloads
write_wiki_index
write_admin_cgi
write_admin_index
if [ "$LAN_ARCADE_SKIP_ADMIN_AUTH" = "1" ]; then
  echo "Skipping Apache admin auth because LAN_ARCADE_SKIP_ADMIN_AUTH=1"
else
  configure_admin_auth
fi
configure_tank_arena_service

if [ "$RUNNING_AS_ROOT" -eq 1 ]; then
  chown -R www-data:www-data "$INDEX_DIR"
fi
chmod 755 "$WIKI_DIR"
chmod 755 "$ADMIN_DIR"
chmod 755 "$DOWNLOADS_DIR"
chmod 755 "$DOWNLOAD_SCREENSHOTS_DIR"
chmod 644 "$INDEX_FILE"
chmod 644 "$CATALOG_FILE"
chmod 644 "$FILTERS_FILE"
chmod 644 "$WIKI_INDEX_FILE"
chmod 644 "$ADMIN_INDEX_FILE"
chmod 644 "$DOWNLOADS_INDEX_FILE"
chmod 755 "$ADMIN_CGI_FILE"

if [ "$LAN_ARCADE_SKIP_ADMIN_AUTH" != "1" ]; then
  if command -v systemctl >/dev/null 2>&1; then
    systemctl reload apache2 || true
  elif command -v apachectl >/dev/null 2>&1; then
    apachectl -k graceful || true
  fi
fi

echo
echo "Done."
echo "Arcade: http://<your-server-ip>/mirrors/games/"
echo "Wiki:   http://<your-server-ip>/mirrors/games/wiki/"
echo "Admin:  http://<your-server-ip>/mirrors/games/admin/ (HTTP Basic Auth)"
echo "APK:    http://<your-server-ip>/mirrors/games/downloads/lan-arcade-companion-debug.apk"
echo "Tank:   http://<your-server-ip>/mirrors/lan-tank-arena/ (service port ${LAN_TANK_PORT})"
