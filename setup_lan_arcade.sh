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
LAN_ARCADE_REGISTRY_INDEX_ONLY="${LAN_ARCADE_REGISTRY_INDEX_ONLY:-0}"
LAN_ARCADE_PAGES_ONLY="${LAN_ARCADE_PAGES_ONLY:-0}"
LAN_ARCADE_DEPLOYMENT_PROFILE="${LAN_ARCADE_DEPLOYMENT_PROFILE:-full}"
LAN_TANK_HOST="${LAN_TANK_HOST:-0.0.0.0}"
LAN_TANK_PORT="${LAN_TANK_PORT:-8787}"

case "$LAN_ARCADE_DEPLOYMENT_PROFILE" in
  full|pi) ;;
  *)
    echo "Unsupported LAN Arcade deployment profile: $LAN_ARCADE_DEPLOYMENT_PROFILE"
    echo "Choose full or pi."
    exit 1
    ;;
esac

# The lightweight profile never starts the optional live Tank service.
if [ "$LAN_ARCADE_DEPLOYMENT_PROFILE" = "pi" ]; then
  LAN_ARCADE_SKIP_TANK_SERVICE=1
fi

# Registry/index-only and pages-only modes are safe by definition. Keep this
# guard before any package, Apache, mirror, device, or service work.
if [ "$LAN_ARCADE_REGISTRY_INDEX_ONLY" = "1" ] || [ "$LAN_ARCADE_PAGES_ONLY" = "1" ]; then
  LAN_ARCADE_SKIP_PACKAGE_INSTALL=1
  LAN_ARCADE_SKIP_ADMIN_AUTH=1
  LAN_ARCADE_SKIP_MIRROR=1
  LAN_ARCADE_SKIP_DEVICE_CHECKS=1
  LAN_ARCADE_SKIP_TANK_SERVICE=1
  LAN_ARCADE_CATALOG_SOURCE=metadata-existing
fi

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
  board-game
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
  ["board-game"]="Board Game"
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
CANONICAL_REGISTRY_FILE="$INDEX_DIR/canonical-registry.json"
CANONICAL_REGISTRY_BUILDER="$SCRIPT_DIR/scripts/build_canonical_game_registry.py"
CANONICAL_REGISTRY_OVERRIDES="$SCRIPT_DIR/config/canonical-game-overrides.json"
READINESS_FILE="$INDEX_DIR/readiness.json"
READINESS_QUARANTINE_FILE="$INDEX_DIR/qa-quarantine.json"
READINESS_BUILDER="$SCRIPT_DIR/qa/readiness/build-readiness.mjs"
READINESS_POLICY="$SCRIPT_DIR/config/readiness-policy.json"
READINESS_EVIDENCE="$SCRIPT_DIR/qa/readiness/evidence.json"
DEPLOYMENT_PROFILES_SOURCE="$SCRIPT_DIR/config/deployment-profiles.json"
DEPLOYMENT_PROFILE_BUILDER="$SCRIPT_DIR/scripts/build_deployment_profile.mjs"
DEPLOYMENT_PROFILES_FILE="$INDEX_DIR/deployment-profiles.json"
DEPLOYMENT_PROFILE_FILE="$INDEX_DIR/deployment-profile.json"
LAUNCHER_ADAPTERS_FILE="$INDEX_DIR/launcher-adapters.json"
LAUNCHER_ADAPTERS_SOURCE="$SCRIPT_DIR/config/launcher-adapters.json"
FILTERS_FILE="$INDEX_DIR/admin.filters.json"
WIKI_DIR="$INDEX_DIR/wiki"
WIKI_INDEX_FILE="$WIKI_DIR/index.html"
DOWNLOADS_DIR="$INDEX_DIR/downloads"
DOWNLOADS_INDEX_FILE="$DOWNLOADS_DIR/index.html"
DOWNLOAD_SCREENSHOTS_DIR="$DOWNLOADS_DIR/screenshots"
ACCOUNT_DIR="$INDEX_DIR/account"
ACCOUNT_INDEX_FILE="$ACCOUNT_DIR/index.html"
SHARED_ASSETS_DIR="$MIRRORS_DIR/shared"
LOCAL_SHARED_ASSETS_DIR="$SCRIPT_DIR/local-games/shared"
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

if [ "$LAN_ARCADE_REGISTRY_INDEX_ONLY" = "1" ] || [ "$LAN_ARCADE_PAGES_ONLY" = "1" ]; then
  ARCADE_NAME_USE="${ARCADE_NAME:-$DEFAULT_ARCADE_NAME}"
elif [ -n "${ARCADE_NAME:-}" ]; then
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

mkdir -p "$MIRRORS_DIR" "$INDEX_DIR" "$WIKI_DIR" "$ACCOUNT_DIR" "$ADMIN_DIR"
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

find_mirror_preview() {
  local target_dir="$1"
  local rel lower base score size best_score=999 best=""

  [ -d "$target_dir" ] || return 0

  while IFS= read -r rel; do
    lower="${rel,,}"
    base="${lower##*/}"

    case "$base" in
      favicon*|icon*|logo*|apple-touch*|mstile*|transparent*|blank*|loader*|loading*|spinner*)
        continue
        ;;
    esac
    case "$lower" in
      _offline_assets/*|*/_offline_assets/*|meta/*|*/meta/*|*/node_modules/*|*/vendor/*|*/emulatorjs-runtime/*|*/font*|*/fonts/*)
        continue
        ;;
    esac
    size="$(stat -c %s "$target_dir/$rel" 2>/dev/null || printf '0')"
    if [ "$size" -lt 4096 ]; then
      continue
    fi

    score=80
    [[ "$lower" == *cover* ]] && score=5
    [[ "$lower" == *hero* ]] && score=8
    [[ "$lower" == *screenshot* ]] && score=10
    [[ "$lower" == *screen* ]] && score=12
    [[ "$lower" == *title* ]] && score=18
    [[ "$lower" == *gallery* ]] && score=20
    [[ "$lower" == *demo* ]] && score=24
    [[ "$lower" == assets/* ]] && score=$(( score - 2 ))
    [[ "$lower" == img/* ]] && score=$(( score - 1 ))

    if [ "$score" -lt "$best_score" ]; then
      best_score="$score"
      best="$rel"
    fi
  done < <(find "$target_dir" -maxdepth 4 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.webp' \) -printf '%P\n' 2>/dev/null | LC_ALL=C sort)

  [ -n "$best" ] && printf '%s\n' "$best"
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
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only

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
  local entry_html rel_entry_dir play_path preview_rel preview_path
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
    preview_rel="$(find_mirror_preview "$MIRRORS_DIR/$dir_name" || true)"
    preview_path=""
    if [ -n "$preview_rel" ]; then
      preview_path="../$dir_name/$preview_rel"
    fi

    info="${GAME_INFO[$dir_name]:-}"
    if [ -n "$info" ]; then
      IFS='|' read -r title icon meta desc tags <<< "$info"
    else
      title="$(echo "$dir_name" | tr '-' ' ')"
      icon="Play"
      meta="HTML5 / Offline"
      desc="Offline-friendly browser game saved in the '$dir_name' folder."
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
    game_json="{\"id\":\"$(json_escape "$dir_name")\",\"title\":\"$(json_escape "$title")\",\"icon\":\"$(json_escape "$icon")\",\"meta\":\"$(json_escape "$meta")\",\"description\":\"$(json_escape "$desc")\",\"tags\":[${tags_json}],\"categories\":[${categories_json}],\"path\":\"$(json_escape "$play_path")\",\"preview\":\"$(json_escape "$preview_path")\"}"
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

  if [ -f "$LAUNCHER_ADAPTERS_SOURCE" ]; then
    cp "$LAUNCHER_ADAPTERS_SOURCE" "$LAUNCHER_ADAPTERS_FILE"
  else
    printf '{ "generatedAt": "", "games": {} }\n' > "$LAUNCHER_ADAPTERS_FILE"
  fi
  chmod 644 "$LAUNCHER_ADAPTERS_FILE"
}

build_canonical_registry() {
  if [ ! -f "$CANONICAL_REGISTRY_BUILDER" ]; then
    echo "Canonical registry builder is missing: $CANONICAL_REGISTRY_BUILDER"
    return 1
  fi
  if [ ! -f "$CANONICAL_REGISTRY_OVERRIDES" ]; then
    echo "Canonical registry overrides are missing: $CANONICAL_REGISTRY_OVERRIDES"
    return 1
  fi

  python3 "$CANONICAL_REGISTRY_BUILDER" \
    --catalog "$CATALOG_FILE" \
    --launcher-adapters "$LAUNCHER_ADAPTERS_FILE" \
    --game-boy-vault "$MIRRORS_DIR/private-rom-vault/manifest.json" \
    --game-boy-curated "$MIRRORS_DIR/private-rom-wave-1/manifest.json" \
    --board-games "$MIRRORS_DIR/board-games-wave-1/manifest.json" \
    --classic-pc "$MIRRORS_DIR/private-dos-vault/manifest.json" \
    --native-packages "$INDEX_DIR/downloads/native" \
    --overrides "$CANONICAL_REGISTRY_OVERRIDES" \
    --output "$CANONICAL_REGISTRY_FILE"
  chmod 644 "$CANONICAL_REGISTRY_FILE"
}

build_readiness_authority() {
  if [ ! -f "$READINESS_BUILDER" ] || [ ! -f "$READINESS_POLICY" ] || [ ! -f "$READINESS_EVIDENCE" ]; then
    echo "Readiness authority inputs are incomplete."
    return 1
  fi
  node "$READINESS_BUILDER" \
    --repo-root "$SCRIPT_DIR" \
    --registry "$CANONICAL_REGISTRY_FILE" \
    --policy "$READINESS_POLICY" \
    --evidence "$READINESS_EVIDENCE" \
    --output "$READINESS_FILE" \
    --quarantine "$READINESS_QUARANTINE_FILE"
  chmod 644 "$READINESS_FILE" "$READINESS_QUARANTINE_FILE"
}

write_deployment_profile() {
  if [ ! -f "$DEPLOYMENT_PROFILES_SOURCE" ] || [ ! -f "$DEPLOYMENT_PROFILE_BUILDER" ]; then
    echo "Deployment profile inputs are incomplete."
    return 1
  fi
  cp "$DEPLOYMENT_PROFILES_SOURCE" "$DEPLOYMENT_PROFILES_FILE"
  node "$DEPLOYMENT_PROFILE_BUILDER" \
    --profiles "$DEPLOYMENT_PROFILES_SOURCE" \
    --profile "$LAN_ARCADE_DEPLOYMENT_PROFILE" \
    --output "$DEPLOYMENT_PROFILE_FILE"
  chmod 644 "$DEPLOYMENT_PROFILES_FILE" "$DEPLOYMENT_PROFILE_FILE"
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
      color-scheme: dark;
      --bg: #090b0d;
      --side: #101514;
      --panel: #151a1d;
      --panel-soft: #1b2124;
      --card: #151b20;
      --card-strong: #20282d;
      --text: #f4f7f8;
      --muted: #a8b2b8;
      --line: #303a40;
      --green: #58d68d;
      --green-soft: rgba(88, 214, 141, 0.16);
      --amber: #f2c14e;
      --cyan: #52c7d8;
      --red: #ef767a;
      --radius: 8px;
    }
    * { box-sizing: border-box; }
    html, body { min-height: 100%; }
    body {
      margin: 0;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: linear-gradient(180deg, #111719 0%, var(--bg) 42%, #050607 100%);
      color: var(--text);
    }
    button, input, select { font: inherit; }
    .app {
      min-height: 100vh;
      display: grid;
      grid-template-columns: 260px minmax(0, 1fr);
    }
    .sidebar {
      position: sticky;
      top: 0;
      height: 100vh;
      overflow: auto;
      border-right: 1px solid var(--line);
      background: linear-gradient(180deg, #121817, #0d1111);
      padding: 18px 14px;
    }
    .brand {
      display: grid;
      gap: 4px;
      padding: 4px 4px 14px;
      border-bottom: 1px solid var(--line);
      margin-bottom: 14px;
    }
    .brand h1 {
      margin: 0;
      font-size: 21px;
      letter-spacing: 0;
      line-height: 1.1;
    }
    .brand span { color: var(--muted); font-size: 13px; line-height: 1.35; }
    .side-section { margin: 0 0 16px; }
    .side-title {
      margin: 0 0 8px;
      color: #d8e0e4;
      font-size: 12px;
      font-weight: 850;
      text-transform: uppercase;
      letter-spacing: 0.08em;
    }
    .side-list { display: grid; gap: 5px; }
    .side-button {
      width: 100%;
      min-height: 36px;
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      align-items: center;
      gap: 8px;
      border: 1px solid transparent;
      border-radius: var(--radius);
      background: transparent;
      color: var(--muted);
      padding: 7px 9px;
      cursor: pointer;
      text-align: left;
      text-decoration: none;
      font: inherit;
    }
    .side-button:hover { background: #182023; color: var(--text); }
    .side-button.active { background: var(--green-soft); border-color: rgba(88,214,141,.42); color: #dfffea; }
    .side-button span:first-child { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .count { color: #7f8b91; font-variant-numeric: tabular-nums; font-size: 12px; }
    .side-button.active .count { color: #bdf7d6; }
    .genre-search {
      width: 100%;
      min-height: 38px;
      border: 1px solid var(--line);
      border-radius: var(--radius);
      background: #0b0f10;
      color: var(--text);
      padding: 8px 9px;
      margin-bottom: 8px;
    }
    .side-links { display: grid; gap: 6px; }
    .side-link {
      color: var(--text);
      text-decoration: none;
      border: 1px solid var(--line);
      border-radius: var(--radius);
      background: #151c20;
      padding: 9px 10px;
      font-size: 14px;
    }
    .side-link:hover { border-color: var(--green); }
    .account-panel {
      display: grid;
      gap: 8px;
      border: 1px solid var(--line);
      border-radius: var(--radius);
      background: #101617;
      padding: 10px;
    }
    .account-name { font-weight: 850; color: var(--text); }
    .account-note { color: var(--muted); font-size: 12px; line-height: 1.35; }
    .account-actions { display: grid; gap: 6px; }
    .account-row { display: grid; gap: 6px; }
    .account-row input {
      width: 100%;
      min-height: 34px;
      border: 1px solid var(--line);
      border-radius: 6px;
      background: #0b0f10;
      color: var(--text);
      padding: 7px 8px;
      font-size: 13px;
    }
    .account-button {
      width: 100%;
      min-height: 34px;
      border: 1px solid rgba(88,214,141,.42);
      border-radius: 6px;
      background: var(--green-soft);
      color: #dfffea;
      font-weight: 850;
      cursor: pointer;
    }
    .account-button.secondary { border-color: var(--line); background: #151c20; color: var(--text); }
    .account-button:disabled { opacity: .55; cursor: wait; }
    .account-panel details { border-top: 1px solid var(--line); padding-top: 7px; }
    .account-panel summary { cursor: pointer; color: var(--text); font-weight: 800; font-size: 13px; }
    .account-error { color: #ffd1d3; font-size: 12px; line-height: 1.35; }
    .main {
      min-width: 0;
      padding: 18px 22px 36px;
    }
    .topbar {
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(280px, 430px) 170px;
      gap: 12px;
      align-items: end;
      margin-bottom: 14px;
    }
    .headline h2 { margin: 0 0 4px; font-size: clamp(24px, 3.2vw, 42px); line-height: 1.05; }
    .headline p { margin: 0; color: var(--muted); font-size: 14px; line-height: 1.4; }
    .control { display: grid; gap: 5px; min-width: 0; }
    .control span {
      color: var(--muted);
      font-size: 12px;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.08em;
    }
    .control input, .control select {
      width: 100%;
      min-height: 43px;
      border: 1px solid var(--line);
      border-radius: var(--radius);
      background: #0f1416;
      color: var(--text);
      padding: 9px 11px;
    }
    .control input:focus, .control select:focus { outline: 2px solid rgba(88,214,141,.32); border-color: var(--green); }
    .status-row {
      min-height: 27px;
      display: flex;
      flex-wrap: wrap;
      gap: 7px;
      align-items: center;
      margin: 0 0 12px;
      color: var(--muted);
      font-size: 13px;
    }
    .stat-pill {
      border: 1px solid var(--line);
      border-radius: 999px;
      background: #111719;
      padding: 5px 9px;
      color: var(--muted);
    }
    .stat-pill strong { color: var(--text); }
    .catalog-note {
      margin: -4px 0 14px;
      color: var(--muted);
      font-size: 13px;
      line-height: 1.45;
      max-width: 980px;
    }
    .shelf { margin: 0 0 18px; }
    .shelf-head {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 10px;
      margin: 0 0 9px;
    }
    .shelf h3 { margin: 0; font-size: 18px; letter-spacing: 0; }
    .shelf-note { color: var(--muted); font-size: 13px; }
    .featured-grid {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 12px;
    }
    #recentGrid.featured-grid, #favoriteGrid.featured-grid {
      grid-template-columns: repeat(auto-fill, minmax(210px, 1fr));
    }
    #recentGrid .game-card, #favoriteGrid .game-card { box-shadow: 0 10px 22px rgba(0,0,0,.22); }
    #recentGrid .launch-row, #favoriteGrid .launch-row { min-width: 0; }
    #recentGrid .game-card .media, #favoriteGrid .game-card .media { aspect-ratio: 16 / 6.6; }
    #recentGrid .desc, #favoriteGrid .desc,
    #recentGrid .tags, #favoriteGrid .tags,
    #recentGrid .detail-chips, #favoriteGrid .detail-chips { display: none; }
    #recentGrid .card-body, #favoriteGrid .card-body { gap: 5px; padding: 9px 10px 10px; }
    #recentGrid .card-title, #favoriteGrid .card-title { font-size: 15px; }
    #recentGrid .favorite-button, #favoriteGrid .favorite-button { display: none; }
    .featured-card, .game-card {
      position: relative;
      overflow: hidden;
      border: 1px solid var(--line);
      border-radius: var(--radius);
      background: var(--card);
      color: inherit;
      box-shadow: 0 16px 35px rgba(0,0,0,.28);
    }
    .card-link {
      color: inherit;
      text-decoration: none;
      display: grid;
      grid-template-rows: auto 1fr;
      min-height: 100%;
    }
    .featured-card:hover, .game-card:hover { border-color: var(--green); transform: translateY(-1px); }
    .media {
      position: relative;
      background: #060809;
      overflow: hidden;
    }
    .featured-card .media { aspect-ratio: 16 / 8.4; }
    .game-card .media { aspect-ratio: 16 / 9; }
    .media img {
      width: 100%;
      height: 100%;
      display: block;
      object-fit: cover;
      filter: saturate(1.05) contrast(1.02);
    }
    .fallback-media {
      width: 100%; height: 100%; display: grid; place-items: center;
      background: linear-gradient(135deg, #25302b, #11181c 62%, #271f13);
      color: #eaf6ee;
      font-size: 42px;
      font-weight: 900;
    }
    .status-badge {
      position: absolute;
      top: 8px;
      left: 8px;
      border-radius: 999px;
      background: rgba(5,8,9,.78);
      border: 1px solid rgba(255,255,255,.16);
      padding: 4px 8px;
      color: #e9f3ef;
      font-size: 12px;
      font-weight: 850;
    }
    .card-body { padding: 11px 12px 12px; display: grid; gap: 7px; }
    .card-title { margin: 0; font-size: 17px; line-height: 1.18; }
    .featured-card .card-title { font-size: 19px; }
    .meta { color: var(--muted); font-size: 12px; text-transform: uppercase; letter-spacing: 0.08em; }
    .desc { color: #c2ccd1; font-size: 14px; line-height: 1.38; margin: 0; }
    .tags { display: flex; flex-wrap: wrap; gap: 5px; }
    .tag {
      border-radius: 999px;
      background: #243036;
      color: #c7d2d8;
      padding: 3px 7px;
      font-size: 12px;
      line-height: 1.2;
    }
    .tag.primary { background: var(--green-soft); color: #c9f8dc; }
    .detail-chips { display: flex; flex-wrap: wrap; gap: 5px; }
    .detail-chip {
      border: 1px solid rgba(255,255,255,.12);
      border-radius: 6px;
      background: #172226;
      color: #d9e7df;
      padding: 3px 6px;
      font-size: 11px;
      line-height: 1.25;
    }
    .detail-chip.ready { background: rgba(88,214,141,.15); border-color: rgba(88,214,141,.44); color: #c9f8dc; }
    .detail-chip.warn { background: #2b2113; border-color: #6b5228; color: #ffe0a3; }
    .launch-row { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-top: 2px; }
    .favorite-button {
      position: absolute;
      top: 9px;
      right: 9px;
      z-index: 4;
      min-height: 30px;
      border: 1px solid rgba(255,255,255,.18);
      border-radius: 999px;
      background: rgba(5,8,9,.82);
      color: #f6fbf8;
      padding: 5px 9px;
      font-weight: 850;
      font-size: 12px;
      cursor: pointer;
      box-shadow: 0 10px 22px rgba(0,0,0,.28);
    }
    .favorite-button:hover, .favorite-button.saved { border-color: rgba(88,214,141,.62); background: rgba(18,63,39,.9); color: #dfffea; }
    .launch { display: inline-flex; align-items: center; gap: 6px; color: #f6fbf8; font-weight: 850; font-size: 13px; }
    .launch::before { content: ""; width: 7px; height: 7px; border-radius: 999px; background: var(--green); box-shadow: 0 0 0 3px rgba(88,214,141,.13); }
    .path { color: #7f8b91; font-size: 12px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .game-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(235px, 1fr));
      gap: 12px;
    }
    .empty-state {
      border: 1px dashed var(--line);
      border-radius: var(--radius);
      background: #111719;
      padding: 24px;
      text-align: center;
      color: var(--muted);
    }
    @media (max-width: 1050px) {
      .app { grid-template-columns: 1fr; }
      .main { order: 1; }
      .sidebar {
        order: 2;
        position: relative;
        height: auto;
        border-right: 0;
        border-top: 1px solid var(--line);
        border-bottom: 0;
      }
      .side-section { margin-bottom: 12px; }
      .side-list { grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); }
      .topbar { grid-template-columns: 1fr; }
      .featured-grid { grid-template-columns: 1fr; }
    }
    @media (max-width: 560px) {
      .main { padding: 14px 10px 28px; }
      .sidebar { padding: 12px 10px; }
      .game-grid { grid-template-columns: 1fr; }
      .path { display: none; }
    }
  </style>
</head>
<body>
  <div class="app">
    <aside class="sidebar" aria-label="Library navigation">
      <div class="brand">
        <h1>${arcade_name_html}</h1>
        <span>Offline LAN game library</span>
      </div>
      <section class="side-section">
        <h2 class="side-title">Player</h2>
        <div id="accountPanel" class="account-panel" aria-live="polite"></div>
      </section>
      <section class="side-section">
        <h2 class="side-title">Play Modes</h2>
        <div id="profileList" class="side-list"></div>
      </section>
      <section class="side-section">
        <h2 class="side-title">Collections &amp; Shelves</h2>
        <div id="shelfList" class="side-list"></div>
      </section>
      <section class="side-section">
        <h2 class="side-title">Genres</h2>
        <input id="genreSearch" class="genre-search" type="search" placeholder="Find genre..." autocomplete="off">
        <div id="genreList" class="side-list"></div>
      </section>
      <nav class="side-links" aria-label="Arcade links">
        <a class="side-link" href="./account/">Account</a>
        <a class="side-link" href="./wiki/">Guides & Manuals</a>
        <a class="side-link" href="./downloads/">Downloads</a>
      </nav>
    </aside>
    <main class="main">
      <header class="topbar">
        <div class="headline">
          <h2>Game Library</h2>
          <p>Find something playable by device, people, collection, or local multiplayer session from one offline game library.</p>
        </div>
        <label class="control">
          <span>Search</span>
          <input id="searchInput" type="search" placeholder="Search games, tags, systems, notes..." autocomplete="off">
        </label>
        <label class="control">
          <span>Sort</span>
          <select id="sortSelect">
            <option value="recommended">Recommended</option>
            <option value="title">Title A-Z</option>
            <option value="category">Genre</option>
            <option value="newer">Newest added</option>
          </select>
        </label>
      </header>
      <div id="status" class="status-row" aria-live="polite"></div>
      <section class="shelf" id="recentShelf" hidden>
        <div class="shelf-head"><h3>Recently played</h3><span id="recentShelfNote" class="shelf-note">Saved on this device</span></div>
        <div id="recentGrid" class="featured-grid"></div>
      </section>
      <section class="shelf" id="favoriteShelf" hidden>
        <div class="shelf-head"><h3>Favourites</h3><span id="favoriteShelfNote" class="shelf-note">Saved on this device</span></div>
        <div id="favoriteGrid" class="featured-grid"></div>
      </section>
      <p class="catalog-note">Search includes individual games inside the Game Boy and Classic PC shelves, including SimAnt and SimCity. Large collections stay nested so the home screen stays readable.</p>
      <section class="shelf" id="featuredShelf">
        <div class="shelf-head"><h3>Featured</h3><span class="shelf-note">Ready picks, collections, and high-interest LAN services</span></div>
        <div id="featuredGrid" class="featured-grid"></div>
      </section>
      <section class="shelf">
        <div class="shelf-head"><h3 id="libraryHeading">All Games</h3><span id="libraryNote" class="shelf-note"></span></div>
        <div id="gameGrid" class="game-grid" aria-live="polite"></div>
        <div id="emptyState" class="empty-state" hidden>No games match the current filters.</div>
      </section>
    </main>
  </div>
  <script>
    (function () {
      "use strict";

      var profiles = [
        { id: "all", label: "Full library", note: "Everything visible" },
        { id: "ready", label: "Ready now", note: "Low-friction browser, emulator, and collection picks" },
        { id: "guest", label: "Guest quick-play", note: "Family, casual, and low-setup choices" },
        { id: "pi", label: "Camping / Pi-friendly", note: "Lightweight picks for modest devices" },
        { id: "lan", label: "LAN multiplayer", note: "Multiplayer games and hosted sessions" },
        { id: "emulation", label: "Retro & emulators", note: "Game Boy, classic PC, and emulator collections" },
        { id: "native", label: "Installable & LAN games", note: "Games that use installers, desktop clients, or local multiplayer sessions" },
        { id: "research", label: "Needs setup", note: "Games waiting for files, fixes, or play testing" }
      ];
      var shelves = [
        { id: "game-boy-wave-1", label: "Curated Game Boy Picks", note: "201 vault picks", href: "../private-rom-wave-1/" },
        { id: "emulator-library", label: "Emulator Library", note: "All retro collections", href: "../emulator-library/" },
        { id: "game-boy-vault", label: "Game Boy Vault", note: "743 browser-ready editions", href: "../private-rom-vault/" },
        { id: "classic-pc-games", label: "Classic PC Games", note: "14 ready to try / 28 listed", href: "../private-dos-vault/" },
        { id: "board-games-wave-1", label: "Board Game Shelf", note: "200 board games", href: "../board-games-wave-1/" },
        { id: "ready-shelf", label: "Ready now", note: "Quick filter", action: "profile", value: "ready" },
        { id: "guest-shelf", label: "Guest friendly", note: "Quick filter", action: "profile", value: "guest" },
        { id: "lan-shelf", label: "LAN multiplayer", note: "Quick filter", action: "profile", value: "lan" },
        { id: "board-games", label: "Board games", note: "Catalog filter", action: "category", value: "board-game" },
        { id: "native-server", label: "Installed & LAN games", note: "Quick filter", action: "profile", value: "native" },
        { id: "research-shelf", label: "Needs setup", note: "Quick filter", action: "profile", value: "research" }
      ];
      var deepSearchSources = [
        { id: "classic-pc", label: "Classic PC Games", type: "dos", manifest: "../private-dos-vault/manifest.json", basePath: "../private-dos-vault/" },
        { id: "game-boy-vault", label: "Game Boy Vault", type: "rom", manifest: "../private-rom-vault/manifest.json", basePath: "../private-rom-vault/" },
        { id: "game-boy-wave-1", label: "Game Boy Wave 1", type: "rom", manifest: "../private-rom-wave-1/manifest.json", basePath: "../private-rom-wave-1/" },
        { id: "board-games-wave-1", label: "Board Games Wave 1", type: "board", manifest: "../board-games-wave-1/manifest.json", basePath: "../board-games-wave-1/" }
      ];
      var recentStorageBaseKey = "lanArcadeRecentlyPlayed.v1";
      var favoriteStorageBaseKey = "lanArcadeFavorites.v1";
      var accountStorageKey = "lanArcadeAccount.v1";
      var accountApiBase = window.location.origin + "/arcade-api/";
      var featuredIds = ["pillage-first-lan", "travianz-lan", "unciv-lan", "mindustry-lan", "evolab", "gene-garden", "zero-ad-lan", "wesnoth-lan", "openttd-lan", "life-engine", "apotris-gba"];
      var state = {
        catalog: { games: [], categories: [] },
        filters: { disabled_categories: [], disabled_games: [] },
        launcherAudit: { games: {} },
        registry: { metrics: {} },
        readiness: { metrics: {}, entries: {} },
        deployment: { selectedProfile: "full", defaultLibraryProfile: "all", label: "Home server" },
        deepGames: [],
        serverRecentGames: [],
        serverFavoriteGames: [],
        account: { mode: "guest", token: "", account: null, player: null, message: "Guest mode" },
        profile: "all",
        category: "",
        query: "",
        genreQuery: "",
        sort: "recommended"
      };

      function toStringArray(value) {
        if (!Array.isArray(value)) return [];
        return value.map(function (item) { return String(item).trim(); }).filter(function (item) { return item.length > 0; });
      }
      function uniqueArray(items) {
        var seen = Object.create(null); var output = [];
        items.forEach(function (item) { if (!seen[item]) { seen[item] = true; output.push(item); } });
        return output;
      }
      function normalizeFilters(raw) {
        var data = raw || {};
        return { disabled_categories: uniqueArray(toStringArray(data.disabled_categories)), disabled_games: uniqueArray(toStringArray(data.disabled_games)) };
      }
      function fetchJson(url, fallbackValue) {
        return fetch(url, { cache: "no-store" }).then(function (response) {
          if (!response.ok) throw new Error("HTTP " + response.status);
          return response.json();
        }).catch(function () { return fallbackValue; });
      }
      function clear(el) { el.textContent = ""; }
      function slugText(value) { return String(value || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""); }
      function compactGameForStorage(game) {
        return {
          id: String(game.id || ""),
          title: String(game.title || game.id || "Game"),
          icon: String(game.icon || "Play").slice(0, 4),
          meta: String(game.meta || "Offline game"),
          description: String(game.description || "Offline-friendly game saved on this arcade."),
          tags: toStringArray(game.tags).slice(0, 6),
          categories: toStringArray(game.categories).slice(0, 8),
          path: gameUrl(game),
          preview: String(game.preview || ""),
          deepType: String(game.deepType || ""),
          system: String(game.system || "")
        };
      }
      function currentRecentStorageKey() {
        return state.account && state.account.account ? recentStorageBaseKey + "." + state.account.account.id : recentStorageBaseKey;
      }
      function currentFavoriteStorageKey() {
        return state.account && state.account.account ? favoriteStorageBaseKey + "." + state.account.account.id : favoriteStorageBaseKey;
      }
      function loadRecentGames() {
        try {
          var data = JSON.parse(localStorage.getItem(currentRecentStorageKey()) || "[]");
          return Array.isArray(data) ? data.filter(function (game) { return game && game.id && game.path; }) : [];
        } catch (e) { return []; }
      }
      function loadFavoriteGames() {
        try {
          var data = JSON.parse(localStorage.getItem(currentFavoriteStorageKey()) || "[]");
          return Array.isArray(data) ? data.filter(function (game) { return game && game.id && game.path; }) : [];
        } catch (e) { return []; }
      }
      function saveFavoriteGames(items) {
        try { localStorage.setItem(currentFavoriteStorageKey(), JSON.stringify((items || []).slice(0, 100))); } catch (e) {}
      }
      function currentFavoriteGames() {
        if (state.account && state.account.account && state.serverFavoriteGames.length) return state.serverFavoriteGames;
        return loadFavoriteGames();
      }
      function isFavorite(game) {
        var id = String(game && game.id || "");
        return currentFavoriteGames().some(function (item) { return String(item.id || "") === id; });
      }
      function rememberGame(game) {
        try {
          var item = compactGameForStorage(game);
          var existing = loadRecentGames().filter(function (old) { return old.id !== item.id; });
          existing.unshift(item);
          localStorage.setItem(currentRecentStorageKey(), JSON.stringify(existing.slice(0, 12)));
          if (state.account && state.account.account && state.account.token) {
            state.serverRecentGames = [item].concat(state.serverRecentGames.filter(function (old) { return old.id !== item.id || old.path !== item.path; })).slice(0, 12);
            renderRecent();
            accountRequest("account/activity", {
              method: "POST",
              keepalive: true,
              headers: { "x-arcade-account-session": state.account.token },
              body: JSON.stringify(item)
            }).then(function (body) {
              if (body && body.activity) {
                var synced = recentGameFromActivity(body.activity);
                state.serverRecentGames = [synced].concat(state.serverRecentGames.filter(function (old) { return old.id !== synced.id || old.path !== synced.path; })).slice(0, 12);
                renderRecent();
              }
            }).catch(function () {});
          }
        } catch (e) {}
      }
      function loadStoredAccount() {
        try {
          var saved = JSON.parse(localStorage.getItem(accountStorageKey) || "null");
          return saved && saved.token ? saved : null;
        } catch (e) { return null; }
      }
      function saveStoredAccount(payload) {
        try { localStorage.setItem(accountStorageKey, JSON.stringify(payload)); } catch (e) {}
      }
      function clearStoredAccount() {
        try { localStorage.removeItem(accountStorageKey); } catch (e) {}
      }
      function favoriteGameFromRecord(favorite) {
        return recentGameFromActivity(favorite);
      }
      function recentGameFromActivity(activity) {
        return {
          id: String(activity.gameId || activity.id || ""),
          title: String(activity.title || activity.gameId || "Game"),
          icon: String(activity.title || activity.gameId || "Play").replace(/[^A-Za-z0-9]/g, "").slice(0, 4) || "Play",
          meta: String(activity.meta || "Offline game"),
          description: String(activity.description || "Offline-friendly game saved on this arcade."),
          tags: toStringArray(activity.tags).slice(0, 6),
          categories: toStringArray(activity.categories).slice(0, 8),
          path: String(activity.path || ""),
          preview: String(activity.preview || ""),
          deepType: String(activity.deepType || ""),
          system: String(activity.system || "")
        };
      }
      function accountRequest(path, options) {
        var requestOptions = options || {};
        requestOptions.headers = Object.assign({ "content-type": "application/json" }, requestOptions.headers || {});
        return fetch(accountApiBase + String(path || "").replace(/^\//, ""), requestOptions).then(function (response) {
          return response.text().then(function (raw) {
            var body = raw ? JSON.parse(raw) : {};
            if (!response.ok) throw new Error(body.error || ("HTTP " + response.status));
            return body;
          });
        });
      }
      function setAccountState(next) {
        state.account = Object.assign({ mode: "guest", token: "", account: null, player: null, message: "Guest mode" }, next || {});
        if (!state.account.account) { state.serverRecentGames = []; state.serverFavoriteGames = []; }
        renderAccountPanel();
        renderRecent();
        renderFavorites();
        if (state.account.account && state.account.token) { loadServerRecent(); loadServerFavorites(); }
      }
      function loadServerRecent() {
        if (!state.account || !state.account.token || !state.account.account) return Promise.resolve();
        return accountRequest("account/activity/recent?limit=12", { headers: { "x-arcade-account-session": state.account.token } }).then(function (body) {
          var rows = Array.isArray(body.activity) ? body.activity : [];
          state.serverRecentGames = rows.map(recentGameFromActivity).filter(function (game) { return game.id && game.path; });
          renderRecent();
        }).catch(function () {});
      }
      function loadServerFavorites() {
        if (!state.account || !state.account.token || !state.account.account) return Promise.resolve();
        return accountRequest("account/favorites?limit=100", { headers: { "x-arcade-account-session": state.account.token } }).then(function (body) {
          var rows = Array.isArray(body.favorites) ? body.favorites : [];
          state.serverFavoriteGames = rows.map(favoriteGameFromRecord).filter(function (game) { return game.id && game.path; });
          saveFavoriteGames(state.serverFavoriteGames);
          renderFavorites();
          render();
        }).catch(function () {});
      }
      function validateStoredAccount() {
        var saved = loadStoredAccount();
        if (!saved) { renderAccountPanel(); return Promise.resolve(); }
        setAccountState({ mode: "checking", token: saved.token, account: saved.account || null, player: saved.player || null, message: "Checking account..." });
        return accountRequest("auth/me", { headers: { "x-arcade-account-session": saved.token } }).then(function (body) {
          setAccountState({ mode: "signed-in", token: saved.token, account: body.account, player: body.player || null, message: "Signed in" });
          saveStoredAccount({ token: saved.token, account: body.account, player: body.player || null });
        }).catch(function () {
          clearStoredAccount();
          setAccountState({ mode: "guest", message: "Guest mode" });
        });
      }
      function accountInput(panel, id, placeholder, type) {
        var input = document.createElement("input");
        input.id = id;
        input.placeholder = placeholder;
        input.type = type || "text";
        input.autocomplete = type === "password" ? "current-password" : "username";
        panel.appendChild(input);
        return input;
      }
      function accountButton(label, className, onClick) {
        var button = document.createElement("button");
        button.type = "button";
        button.className = "account-button" + (className ? " " + className : "");
        button.textContent = label;
        button.addEventListener("click", onClick);
        return button;
      }
      function beginAccountSwitch(username) {
        clearStoredAccount();
        setAccountState({ mode: "guest", message: "Choose a player" });
        window.setTimeout(function () {
          var user = document.getElementById("accountLoginUsername");
          var password = document.getElementById("accountLoginPassword");
          if (!user || !password) return;
          user.value = String(username || "");
          var details = user.closest("details");
          if (details) details.open = true;
          password.focus();
        }, 0);
      }
      function loadFamilyAccounts(panel, current) {
        if (!current || !current.token || !current.account) return;
        accountRequest("accounts", { headers: { "x-arcade-account-session": current.token } }).then(function (body) {
          if (!state.account || !state.account.account || state.account.account.id !== current.account.id) return;
          var rows = Array.isArray(body.accounts) ? body.accounts.filter(function (account) { return account.id !== current.account.id; }) : [];
          if (!rows.length) return;
          var label = document.createElement("div"); label.className = "account-note"; label.textContent = "Switch player"; panel.appendChild(label);
          rows.forEach(function (account) {
            panel.appendChild(accountButton(account.displayName || account.username, "secondary", function () { beginAccountSwitch(account.username); }));
          });
        }).catch(function () {});
      }
      function appendChildAccountForm(panel, current) {
        if (!current || !current.account || ["admin", "adult"].indexOf(current.account.role) < 0) return;
        var details = document.createElement("details");
        var summary = document.createElement("summary"); summary.textContent = "Add family player"; details.appendChild(summary);
        var form = document.createElement("div"); form.className = "account-row"; details.appendChild(form);
        var username = accountInput(form, "familyCreateUsername", "Username", "text");
        var displayName = accountInput(form, "familyCreateDisplay", "Display name", "text");
        var password = accountInput(form, "familyCreatePassword", "Password", "password");
        var status = document.createElement("div"); status.className = "account-note";
        form.appendChild(accountButton("Create child account", "", function () {
          status.textContent = "Creating...";
          accountRequest("accounts", {
            method: "POST",
            headers: { "x-arcade-account-session": current.token },
            body: JSON.stringify({
              username: username.value,
              displayName: displayName.value || username.value,
              password: password.value,
              role: "child"
            })
          }).then(function () {
            status.textContent = "Family player created.";
            renderAccountPanel();
          }).catch(function (error) {
            status.textContent = error.message || "Could not create family player";
          });
        }));
        form.appendChild(status);
        panel.appendChild(details);
      }
      function mailboxStatusLabel(account) {
        var status = String(account && account.mailboxStatus || "pending");
        if (status === "ready") return "Mailbox ready";
        if (status === "alias") return "Mailbox routed to your family organizer";
        if (status === "disabled") return "Mailbox disabled";
        if (status === "error") return "Mailbox needs attention";
        return "Mailbox setup pending";
      }
      function emailVerificationLabel(account) {
        return account && account.emailVerifiedAt ? "Email verified " + new Date(account.emailVerifiedAt).toLocaleDateString() : "Email not verified yet";
      }
      function renderAccountPanel(errorMessage) {
        var panel = document.getElementById("accountPanel");
        if (!panel) return;
        clear(panel);
        var current = state.account || { mode: "guest" };
        if (current.account) {
          var name = document.createElement("div"); name.className = "account-name"; name.textContent = current.account.displayName || current.account.username; panel.appendChild(name);
          var email = document.createElement("div"); email.className = "account-note"; email.textContent = current.account.localEmail || "Local account"; panel.appendChild(email);
          var mailState = document.createElement("div"); mailState.className = "account-note"; mailState.textContent = mailboxStatusLabel(current.account) + " - " + emailVerificationLabel(current.account); panel.appendChild(mailState);
          appendChildAccountForm(panel, current);
          var note = document.createElement("div"); note.className = "account-note"; note.textContent = "Recent games and supported saves are kept separate for this account."; panel.appendChild(note);
          loadFamilyAccounts(panel, current);
          panel.appendChild(accountButton("Switch to guest", "secondary", function () { clearStoredAccount(); setAccountState({ mode: "guest", message: "Guest mode" }); }));
          return;
        }
        var title = document.createElement("div"); title.className = "account-name"; title.textContent = current.mode === "checking" ? "Checking account..." : "Guest mode"; panel.appendChild(title);
        var msg = document.createElement("div"); msg.className = "account-note"; msg.textContent = "Play without setup, or sign in for separate local activity and future saves."; panel.appendChild(msg);
        if (errorMessage) { var error = document.createElement("div"); error.className = "account-error"; error.textContent = errorMessage; panel.appendChild(error); }
        var signIn = document.createElement("details");
        var signInSummary = document.createElement("summary"); signInSummary.textContent = "Sign in"; signIn.appendChild(signInSummary);
        var signInForm = document.createElement("div"); signInForm.className = "account-row"; signIn.appendChild(signInForm);
        var loginUser = accountInput(signInForm, "accountLoginUsername", "Username", "text");
        var loginPassword = accountInput(signInForm, "accountLoginPassword", "Password", "password");
        signInForm.appendChild(accountButton("Sign in", "", function () {
          accountRequest("auth/login", { method: "POST", body: JSON.stringify({ username: loginUser.value, password: loginPassword.value }) }).then(function (body) {
            saveStoredAccount({ token: body.token, account: body.account, player: body.player || null });
            setAccountState({ mode: "signed-in", token: body.token, account: body.account, player: body.player || null, message: "Signed in" });
          }).catch(function (error) { renderAccountPanel(error.message || "Sign in failed"); });
        }));
        panel.appendChild(signIn);
        var create = document.createElement("details");
        var createSummary = document.createElement("summary"); createSummary.textContent = "Create account"; create.appendChild(createSummary);
        var createForm = document.createElement("div"); createForm.className = "account-row"; create.appendChild(createForm);
        var createUser = accountInput(createForm, "accountCreateUsername", "Username", "text");
        var createName = accountInput(createForm, "accountCreateDisplay", "Display name", "text");
        var createPassword = accountInput(createForm, "accountCreatePassword", "Password", "password");
        createForm.appendChild(accountButton("Create", "", function () {
          accountRequest("accounts", { method: "POST", body: JSON.stringify({ username: createUser.value, displayName: createName.value || createUser.value, password: createPassword.value }) }).then(function (body) {
            saveStoredAccount({ token: body.token, account: body.account, player: body.player || null });
            setAccountState({ mode: "signed-in", token: body.token, account: body.account, player: body.player || null, message: "Signed in" });
          }).catch(function (error) { renderAccountPanel(error.message || "Account creation failed"); });
        }));
        panel.appendChild(create);
      }
      function nestedPath(source, game) {
        var id = encodeURIComponent(String(game.id || ""));
        if (source.type === "dos") {
          if (game.bundleUrl || game.packageUrl || game.sourceState === "packaged") return source.basePath + "play.html?id=" + id;
          return source.basePath;
        }
        if (source.type === "rom") return source.basePath + String(game.playUrl || ("play.html?id=" + id)).replace(/^\.\//, "");
        return source.basePath;
      }
      function publicNestedStatus(status) {
        var labels = {
          "smoke-pass": "Play-tested",
          "source-ready": "Ready to try",
          "partial": "Starts, needs testing",
          "blocked": "Needs attention",
          "candidate": "Needs files"
        };
        return labels[String(status || "")] || String(status || "");
      }
      function normalizeNestedGame(source, game) {
        if (!game || !game.id) return null;
        var title = String(game.title || game.id || "Game");
        var rawGenres = toStringArray(game.genres || (game.genre ? [game.genre] : []));
        var statusText = publicNestedStatus(game.status);
        var tags = [source.label];
        if (game.system || game.platform) tags.push(String(game.system || game.platform));
        rawGenres.slice(0, 3).forEach(function (genre) { tags.push(genre); });
        if (statusText) tags.push(statusText);
        var categories = ["retro", "emulator", "private", "age-10-plus"];
        rawGenres.forEach(function (genre) { var slug = slugText(genre); if (slug) categories.push(slug); });
        if (source.type === "dos") categories.push("dos");
        if (source.type === "board") categories = ["board-game", "research", "age-10-plus"];
        var preview = "";
        if (source.type === "dos" && Array.isArray(game.screenshots) && game.screenshots[0] && game.screenshots[0].url) preview = source.basePath + String(game.screenshots[0].url);
        return {
          id: source.id + ":" + String(game.id),
          title: title,
          icon: title.replace(/[^A-Za-z0-9]/g, "").slice(0, 4) || source.label.slice(0, 4),
          meta: String(game.platform || game.system || source.label) + " - " + String(game.genre || rawGenres[0] || statusText || "offline game"),
          description: String(game.summary || game.notes || game.selectionReason || "Playable from the " + source.label + " shelf."),
          tags: uniqueArray(tags),
          categories: uniqueArray(categories),
          path: nestedPath(source, game),
          preview: preview,
          deepType: source.type,
          system: String(game.system || game.platform || source.label)
        };
      }
      function categoryLabelMap(catalog) {
        var map = Object.create(null);
        (Array.isArray(catalog.categories) ? catalog.categories : []).forEach(function (category) {
          if (!category || !category.id) return;
          map[String(category.id)] = category.label ? String(category.label) : String(category.id);
        });
        return map;
      }
      function gameEnabled(game) {
        var disabledGames = new Set(state.filters.disabled_games);
        var disabledCategories = new Set(state.filters.disabled_categories);
        if (disabledGames.has(String(game.id || ""))) return false;
        return !toStringArray(game.categories).some(function (category) { return disabledCategories.has(category); });
      }
      function hasCategory(game, category) { return toStringArray(game.categories).indexOf(category) >= 0; }
      function hasAnyCategory(game, categories) { return categories.some(function (category) { return hasCategory(game, category); }); }
      function textBlob(game) {
        return [String(game.id || ""), String(game.title || ""), String(game.meta || ""), String(game.description || ""), toStringArray(game.categories).join(" "), toStringArray(game.tags).join(" ")].join(" ").toLowerCase();
      }
      function hasText(game, needles) {
        var text = textBlob(game);
        return needles.some(function (needle) { return text.indexOf(needle) >= 0; });
      }
      function isRetro(game) { return hasCategory(game, "retro"); }
      function isEmulator(game) { return hasCategory(game, "emulator") || hasText(game, ["emulator", "game boy", "gbc", "gba", "dos shelf", "rom"]); }
      function isCollection(game) {
        var id = String(game.id || "").toLowerCase();
        if (["emulator-library", "private-gbc-vault", "private-dos-classics", "private-rom-wave-1", "board-games-wave-1", "retro-emulator-lab"].indexOf(id) >= 0) return true;
        return hasText(game, ["vault", "shelf", "collection", "wave 1", "intake"]) && (isEmulator(game) || hasCategory(game, "board-game") || hasCategory(game, "private"));
      }
      function launcherInfo(game) {
        if (!game || game.deepType) return null;
        var id = String(game.id || "");
        var games = state.launcherAudit && state.launcherAudit.games ? state.launcherAudit.games : {};
        return games[id] || null;
      }
      function readinessInfo(game) {
        if (!game) return null;
        var entries = state.readiness && state.readiness.entries ? state.readiness.entries : {};
        return entries[String(game.id || "")] || null;
      }
      function launcherAdapter(game) {
        var info = launcherInfo(game);
        return info ? String(info.adapter || "") : "";
      }
      function hasLauncherAdapter(game, adapters) {
        var adapter = launcherAdapter(game);
        return adapter && adapters.indexOf(adapter) >= 0;
      }
      function isServerService(game) {
        if (hasLauncherAdapter(game, ["hosted-lan"])) return true;
        return hasText(game, ["lan service", "lan server", "server", "hosted service"]);
      }
      function isNativeOrServerGame(game) {
        var info = launcherInfo(game);
        if (info) return hasLauncherAdapter(game, ["hosted-lan", "desktop-client", "linux-package", "browser-stream"]);
        var id = String(game.id || "").toLowerCase();
        return id.slice(-4) === "-lan" || isServerService(game) || hasText(game, ["native", "client required", "installer"]);
      }
      function isResearchEntry(game) {
        var readiness = readinessInfo(game);
        if (readiness) {
          if (readiness.promotionState === "research" || readiness.promotionState === "quarantined") return true;
          if (readiness.promotionState === "limited" && !isCollection(game)) return true;
          return false;
        }
        return true;
      }
      function isReadyNow(game) {
        var readiness = readinessInfo(game);
        return Boolean(readiness && readiness.promotionState === "ready");
      }
      function isGuestFriendly(game) {
        var info = launcherInfo(game);
        if (info && info.guestReady === false) return false;
        if (!isReadyNow(game)) return false;
        if (info && info.guestReady === true) return true;
        return hasAnyCategory(game, ["family", "casual", "mobile-friendly", "puzzle", "retro", "board-game", "age-5-plus"]);
      }
      function matchesProfile(game, profile) {
        if (profile === "ready") return isReadyNow(game);
        if (profile === "guest") return isGuestFriendly(game);
        if (profile === "lan") return hasLauncherAdapter(game, ["hosted-lan"]) || hasCategory(game, "multiplayer") || isServerService(game);
        if (profile === "emulation") return isEmulator(game) || isCollection(game);
        if (profile === "native") return isNativeOrServerGame(game);
        if (profile === "research") return isResearchEntry(game);
        if (profile === "pi") {
          if (!isReadyNow(game) || isNativeOrServerGame(game)) return false;
          return hasAnyCategory(game, ["mobile-friendly", "family", "casual", "puzzle", "retro", "age-5-plus"]);
        }
        return true;
      }
      function statusLabel(game) {
        if (game.deepType === "dos") return "Classic PC";
        if (game.deepType === "rom") return String(game.system || "Emulator");
        if (game.deepType === "board") return "Board game";
        var info = launcherInfo(game);
        if (info && info.statusLabel) return String(info.statusLabel);
        if (isCollection(game)) return "Collection";
        if (isServerService(game)) return "LAN service";
        if (isNativeOrServerGame(game)) return "Native hub";
        if (isEmulator(game)) return "Emulator";
        if (hasCategory(game, "board-game")) return "Board game";
        if (hasCategory(game, "mobile-friendly")) return "Phone friendly";
        return "Browser ready";
      }
      function readinessLabel(game) {
        var readiness = readinessInfo(game);
        return readiness ? String(readiness.displayLabel || "Needs play testing") : "Needs play testing";
      }
      function readinessTone(game) {
        var readiness = readinessInfo(game);
        if (!readiness) return "warn";
        return readiness.promotionState === "ready" ? "ready" : "warn";
      }
      function deviceLabel(game) {
        if (game.deepType === "dos") return "Browser DOSBox";
        if (game.deepType === "rom") return "Browser emulator";
        var info = launcherInfo(game);
        if (info && info.deviceLabel) return String(info.deviceLabel);
        if (hasCategory(game, "mobile-friendly")) return "Phone/browser";
        if (isCollection(game)) return "Shelf";
        if (isEmulator(game)) return "Emulator";
        if (isNativeOrServerGame(game)) return "Desktop/client";
        return "Browser";
      }
      function playerLabel(game) {
        if (hasCategory(game, "multiplayer")) return "Multiplayer";
        if (hasCategory(game, "board-game")) return "Tabletop";
        if (hasCategory(game, "family")) return "Family";
        return "Solo";
      }
      function ageLabel(game) {
        if (hasCategory(game, "age-5-plus")) return "Ages 5+";
        if (hasCategory(game, "age-13-plus")) return "Ages 13+";
        if (hasCategory(game, "age-10-plus")) return "Ages 10+";
        return "Age unset";
      }
      function primaryActionLabel(game) {
        var readiness = readinessInfo(game);
        if (readiness && readiness.actionLabel) return String(readiness.actionLabel);
        if (game.deepType === "dos" && game.path && game.path.indexOf("play.html") >= 0) return "Try";
        if (game.deepType === "rom") return "Play";
        var info = launcherInfo(game);
        if (info && info.primaryAction) return String(info.primaryAction);
        if (isResearchEntry(game)) return "Setup notes";
        if (isCollection(game)) return "Open collection";
        if (isServerService(game)) return "Start / join";
        if (isNativeOrServerGame(game)) return "Install / play";
        return "Play";
      }
      function detailChipData(game) {
        return [
          { label: readinessLabel(game), tone: readinessTone(game) },
          { label: deviceLabel(game), tone: "" },
          { label: playerLabel(game), tone: "" },
          { label: ageLabel(game), tone: "" }
        ];
      }
      function searchText(game, labelsByCategory) {
        var categories = toStringArray(game.categories);
        var labels = categories.map(function (id) { return labelsByCategory[id] || id; });
        return [String(game.id || ""), String(game.title || ""), String(game.meta || ""), String(game.description || ""), toStringArray(game.tags).join(" "), categories.join(" "), labels.join(" ")].join(" ").toLowerCase();
      }
      function filteredBaseGames() {
        var labels = categoryLabelMap(state.catalog);
        var query = String(state.query || "").toLowerCase().trim();
        var topLevel = (Array.isArray(state.catalog.games) ? state.catalog.games : []).filter(function (game) {
          if (!gameEnabled(game)) return false;
          if (!matchesProfile(game, state.profile)) return false;
          if (state.category && toStringArray(game.categories).indexOf(state.category) < 0) return false;
          if (query && searchText(game, labels).indexOf(query) < 0) return false;
          return true;
        });
        if (!query) return topLevel;
        var seen = Object.create(null);
        var seenNestedTitles = Object.create(null);
        topLevel.forEach(function (game) {
          seen[String(game.id || "")] = true;
          seenNestedTitles[String(game.title || "").toLowerCase() + "|" + String(game.system || game.meta || "").toLowerCase()] = true;
        });
        var deepMatches = state.deepGames.filter(function (game) {
          if (seen[String(game.id || "")]) return false;
          var nestedKey = String(game.title || "").toLowerCase() + "|" + String(game.system || game.meta || "").toLowerCase();
          if (seenNestedTitles[nestedKey]) return false;
          if (!matchesProfile(game, state.profile)) return false;
          if (state.category && toStringArray(game.categories).indexOf(state.category) < 0) return false;
          if (searchText(game, labels).indexOf(query) < 0) return false;
          seenNestedTitles[nestedKey] = true;
          return true;
        }).slice(0, 100);
        if (deepMatches.length) {
          topLevel = topLevel.filter(function (game) {
            var id = String(game.id || "");
            return ["emulator-library", "private-dos-classics", "private-rom-wave-1", "private-gbc-vault", "board-games-wave-1"].indexOf(id) < 0;
          });
        }
        return deepMatches.concat(topLevel);
      }
      function scoreGame(game) {
        var id = String(game.id || "");
        var score = 0;
        var featuredIndex = featuredIds.indexOf(id);
        if (featuredIndex >= 0) score += 1000 - featuredIndex * 20;
        if (game.preview) score += 80;
        if (isReadyNow(game)) score += 60;
        if (isCollection(game)) score += 35;
        if (isGuestFriendly(game)) score += 20;
        if (toStringArray(game.categories).indexOf("mobile-friendly") >= 0) score += 20;
        if (isServerService(game)) score += 25;
        if (isNativeOrServerGame(game)) score += 10;
        if (isResearchEntry(game)) score -= 120;
        return score;
      }
      function queryScore(game, query) {
        if (!query) return 0;
        var title = String(game.title || "").toLowerCase();
        var id = String(game.id || "").toLowerCase();
        var tags = toStringArray(game.tags).join(" ").toLowerCase();
        var meta = String(game.meta || "").toLowerCase();
        var desc = String(game.description || "").toLowerCase();
        var score = 0;
        if (title === query) score += 5000;
        if (title.indexOf(query) === 0) score += 3600;
        else if (title.indexOf(query) >= 0) score += 3000;
        if (id.indexOf(query) >= 0) score += 1800;
        if (tags.indexOf(query) >= 0) score += 900;
        if (meta.indexOf(query) >= 0) score += 500;
        if (desc.indexOf(query) >= 0) score += 180;
        if (game.deepType && title.indexOf(query) >= 0) score += 450;
        return score;
      }
      function sortGames(games) {
        var sorted = games.slice();
        var query = String(state.query || "").toLowerCase().trim();
        if (query) {
          sorted.sort(function (a, b) {
            return queryScore(b, query) - queryScore(a, query) || scoreGame(b) - scoreGame(a) || String(a.title || a.id).localeCompare(String(b.title || b.id));
          });
          return sorted;
        }
        if (state.sort === "newer") return sorted.reverse();
        if (state.sort === "category") {
          sorted.sort(function (a, b) {
            var aCat = toStringArray(a.categories)[0] || "";
            var bCat = toStringArray(b.categories)[0] || "";
            return aCat.localeCompare(bCat) || String(a.title || a.id).localeCompare(String(b.title || b.id));
          });
          return sorted;
        }
        if (state.sort === "title") {
          sorted.sort(function (a, b) { return String(a.title || a.id).localeCompare(String(b.title || b.id)); });
          return sorted;
        }
        sorted.sort(function (a, b) {
          return scoreGame(b) - scoreGame(a) || String(a.title || a.id).localeCompare(String(b.title || b.id));
        });
        return sorted;
      }
      function gameUrl(game) { var readiness = readinessInfo(game); if (readiness && readiness.actionTarget) return String(readiness.actionTarget); var info = launcherInfo(game); if (info && info.launcherUrl) return String(info.launcherUrl); return game.path ? String(game.path) : "../" + encodeURIComponent(String(game.id || "")) + "/"; }
      function launchHint(game) {
        var readiness = readinessInfo(game);
        if (readiness && readiness.launchHint) return String(readiness.launchHint);
        if (game.deepType === "dos") return game.path && game.path.indexOf("play.html") >= 0 ? "browser play" : "classic PC collection";
        if (game.deepType === "rom") return "browser emulator";
        if (game.deepType === "board") return "rules and table notes";
        var info = launcherInfo(game);
        if (info && info.launchHint) return String(info.launchHint);
        if (hasLauncherAdapter(game, ["browser-stream"])) return "streamed from arcade";
        if (isCollection(game)) return "collection";
        if (isServerService(game)) return "local server";
        if (isNativeOrServerGame(game)) return "desktop install";
        return "browser play";
      }
      function makeMedia(game) {
        var media = document.createElement("div"); media.className = "media";
        if (game.preview) {
          var img = document.createElement("img"); img.loading = "lazy"; img.src = String(game.preview); img.alt = String(game.title || game.id || "Game") + " preview"; media.appendChild(img);
        } else {
          var fallback = document.createElement("div"); fallback.className = "fallback-media"; fallback.textContent = String(game.icon || "Play").slice(0, 4); media.appendChild(fallback);
        }
        var badge = document.createElement("span"); badge.className = "status-badge"; badge.textContent = statusLabel(game); media.appendChild(badge);
        return media;
      }
      function makeTags(game, limit) {
        var tags = document.createElement("div"); tags.className = "tags";
        toStringArray(game.tags).slice(0, limit).forEach(function (tag, index) {
          var pill = document.createElement("span"); pill.className = index === 0 ? "tag primary" : "tag"; pill.textContent = tag; tags.appendChild(pill);
        });
        return tags;
      }
      function makeDetailChips(game) {
        var chips = document.createElement("div"); chips.className = "detail-chips";
        detailChipData(game).forEach(function (chip) {
          var pill = document.createElement("span");
          pill.className = "detail-chip" + (chip.tone ? " " + chip.tone : "");
          pill.textContent = chip.label;
          chips.appendChild(pill);
        });
        return chips;
      }
      function toggleFavorite(game) {
        var item = compactGameForStorage(game);
        if (!item.id) return;
        var favorites = currentFavoriteGames();
        var active = favorites.some(function (old) { return old.id === item.id; });
        var next = active ? favorites.filter(function (old) { return old.id !== item.id; }) : [item].concat(favorites.filter(function (old) { return old.id !== item.id; })).slice(0, 100);
        state.serverFavoriteGames = next;
        saveFavoriteGames(next);
        render();
        if (state.account && state.account.account && state.account.token) {
          var request = active
            ? accountRequest("account/favorites/" + encodeURIComponent(item.id), { method: "DELETE", headers: { "x-arcade-account-session": state.account.token } })
            : accountRequest("account/favorites", { method: "PUT", headers: { "x-arcade-account-session": state.account.token }, body: JSON.stringify(item) });
          request.then(loadServerFavorites).catch(function () {});
        }
      }
      function makeCard(game, featured) {
        var card = document.createElement("article"); card.className = featured ? "featured-card" : "game-card";
        var link = document.createElement("a"); link.className = "card-link"; link.href = gameUrl(game);
        link.setAttribute("aria-label", primaryActionLabel(game) + " " + String(game.title || game.id || "game"));
        link.addEventListener("click", function () { rememberGame(game); });
        link.appendChild(makeMedia(game));
        var body = document.createElement("div"); body.className = "card-body";
        var title = document.createElement("h4"); title.className = "card-title"; title.textContent = String(game.title || game.id || "Unknown"); body.appendChild(title);
        var meta = document.createElement("div"); meta.className = "meta"; meta.textContent = String(game.meta || "Offline game"); body.appendChild(meta);
        var desc = document.createElement("p"); desc.className = "desc"; desc.textContent = String(game.description || "Offline-friendly game saved on this arcade."); body.appendChild(desc);
        body.appendChild(makeTags(game, featured ? 4 : 3));
        body.appendChild(makeDetailChips(game));
        var launchRow = document.createElement("div"); launchRow.className = "launch-row";
        var launch = document.createElement("span"); launch.className = "launch"; launch.textContent = primaryActionLabel(game); launchRow.appendChild(launch);
        var path = document.createElement("span"); path.className = "path"; path.textContent = launchHint(game); path.title = gameUrl(game); launchRow.appendChild(path);
        body.appendChild(launchRow);
        link.appendChild(body);
        card.appendChild(link);
        var favorite = document.createElement("button");
        favorite.type = "button";
        favorite.className = "favorite-button" + (isFavorite(game) ? " saved" : "");
        favorite.textContent = isFavorite(game) ? "Saved" : "Save";
        favorite.title = isFavorite(game) ? "Remove from favourites" : "Save to favourites";
        favorite.setAttribute("aria-label", favorite.title + ": " + String(game.title || game.id || "game"));
        favorite.addEventListener("click", function (event) { event.preventDefault(); event.stopPropagation(); toggleFavorite(game); });
        card.appendChild(favorite);
        return card;
      }
      function renderRecent() {
        var shelf = document.getElementById("recentShelf");
        var grid = document.getElementById("recentGrid");
        if (!shelf || !grid) return;
        var recentSource = state.account && state.account.account && state.serverRecentGames.length ? state.serverRecentGames : loadRecentGames();
        var recent = recentSource.slice(0, 4);
        var note = document.getElementById("recentShelfNote");
        if (note) note.textContent = state.account && state.account.account ? "Synced for " + (state.account.account.displayName || state.account.account.username) + " on this arcade" : "Saved on this device";
        clear(grid);
        recent.forEach(function (game) { grid.appendChild(makeCard(game, false)); });
        shelf.hidden = recent.length === 0 || String(state.query || "").trim() || state.category;
      }
      function renderFavorites() {
        var shelf = document.getElementById("favoriteShelf");
        var grid = document.getElementById("favoriteGrid");
        if (!shelf || !grid) return;
        var favorites = currentFavoriteGames().slice(0, 4);
        var note = document.getElementById("favoriteShelfNote");
        if (note) note.textContent = state.account && state.account.account ? "Synced for " + (state.account.account.displayName || state.account.account.username) + " on this arcade" : "Saved on this device";
        clear(grid);
        favorites.forEach(function (game) { grid.appendChild(makeCard(game, false)); });
        shelf.hidden = favorites.length === 0 || String(state.query || "").trim() || state.category;
      }
      function renderProfiles() {
        var list = document.getElementById("profileList"); clear(list);
        profiles.forEach(function (profile) {
          var count = (Array.isArray(state.catalog.games) ? state.catalog.games : []).filter(function (game) { return gameEnabled(game) && matchesProfile(game, profile.id); }).length;
          var button = document.createElement("button"); button.type = "button"; button.className = "side-button" + (state.profile === profile.id ? " active" : "");
          var label = document.createElement("span"); label.textContent = profile.label; button.appendChild(label);
          var countEl = document.createElement("span"); countEl.className = "count"; countEl.textContent = count; button.appendChild(countEl);
          countEl.title = count + " library items";
          button.addEventListener("click", function () { state.profile = profile.id; state.category = ""; render(); });
          list.appendChild(button);
        });
      }
      function categoryCount(categoryId) {
        return (Array.isArray(state.catalog.games) ? state.catalog.games : []).filter(function (game) {
          return gameEnabled(game) && toStringArray(game.categories).indexOf(categoryId) >= 0;
        }).length;
      }
      function shelfCount(shelf) {
        if (shelf.action === "profile") {
          return (Array.isArray(state.catalog.games) ? state.catalog.games : []).filter(function (game) { return gameEnabled(game) && matchesProfile(game, shelf.value); }).length;
        }
        if (shelf.action === "category") return categoryCount(shelf.value);
        return shelf.note;
      }
      function shelfActive(shelf) {
        if (shelf.action === "profile") return state.profile === shelf.value && !state.category;
        if (shelf.action === "category") return state.category === shelf.value;
        return false;
      }
      function activateShelf(shelf) {
        if (shelf.action === "profile") {
          state.profile = shelf.value;
          state.category = "";
        } else if (shelf.action === "category") {
          state.profile = "all";
          state.category = shelf.value;
        }
        state.query = "";
        document.getElementById("searchInput").value = "";
        render();
      }
      function renderShelves() {
        var list = document.getElementById("shelfList"); clear(list);
        shelves.forEach(function (shelf) {
          var item = shelf.href ? document.createElement("a") : document.createElement("button");
          item.className = "side-button" + (shelfActive(shelf) ? " active" : "");
          if (shelf.href) item.href = shelf.href;
          if (!shelf.href) {
            item.type = "button";
            item.addEventListener("click", function () { activateShelf(shelf); });
          }
          var label = document.createElement("span"); label.textContent = shelf.label; item.appendChild(label);
          var count = document.createElement("span"); count.className = "count"; count.textContent = shelfCount(shelf); item.appendChild(count);
          list.appendChild(item);
        });
      }
      function renderGenres(baseGamesForProfile) {
        var list = document.getElementById("genreList"); var labels = categoryLabelMap(state.catalog); var counts = Object.create(null); clear(list);
        baseGamesForProfile.forEach(function (game) { toStringArray(game.categories).forEach(function (category) { counts[category] = (counts[category] || 0) + 1; }); });
        var genreQuery = String(state.genreQuery || "").toLowerCase().trim();
        var rows = Object.keys(counts).map(function (id) { return { id: id, label: labels[id] || id, count: counts[id] }; }).filter(function (row) { return !genreQuery || row.label.toLowerCase().indexOf(genreQuery) >= 0 || row.id.indexOf(genreQuery) >= 0; });
        rows.sort(function (a, b) { return b.count - a.count || a.label.localeCompare(b.label); });
        var all = document.createElement("button"); all.type = "button"; all.className = "side-button" + (state.category === "" ? " active" : "");
        all.innerHTML = "<span>All genres</span><span class=\"count\">" + baseGamesForProfile.length + "</span>";
        all.addEventListener("click", function () { state.category = ""; render(); }); list.appendChild(all);
        rows.slice(0, 28).forEach(function (row) {
          var button = document.createElement("button"); button.type = "button"; button.className = "side-button" + (state.category === row.id ? " active" : "");
          var label = document.createElement("span"); label.textContent = row.label; button.appendChild(label);
          var count = document.createElement("span"); count.className = "count"; count.textContent = row.count; button.appendChild(count);
          button.addEventListener("click", function () { state.category = row.id; render(); }); list.appendChild(button);
        });
      }
      function renderStatus(visible, profilePool, allEnabled) {
        var status = document.getElementById("status"); clear(status);
        var metrics = state.registry && state.registry.metrics ? state.registry.metrics : {};
        var canonicalTitles = Number(metrics.distinctCanonicalTitles);
        var localPayloadTitles = Number(metrics.localPayloadTitles);
        var collectionWrappers = Number(metrics.canonicalCollectionWrappers);
        var launchCandidates = Number(metrics.localLaunchCandidateTitles);
        var readyEntries = Number(state.readiness && state.readiness.metrics ? state.readiness.metrics.readyEntries : NaN);
        var launcherCards = Number(metrics.topLevelLauncherCards);
        if (!Number.isFinite(canonicalTitles)) canonicalTitles = allEnabled.length;
        if (!Number.isFinite(localPayloadTitles)) localPayloadTitles = 0;
        if (!Number.isFinite(collectionWrappers)) collectionWrappers = 0;
        if (!Number.isFinite(launchCandidates)) launchCandidates = profilePool.filter(isReadyNow).length;
        if (!Number.isFinite(readyEntries)) readyEntries = 0;
        if (!Number.isFinite(launcherCards)) launcherCards = allEnabled.length;
        var chips = [
          [canonicalTitles, "game titles across every shelf"],
          [collectionWrappers, "collections"],
          [localPayloadTitles, "with local files"],
          [launchCandidates, "launch paths to try"],
          [readyEntries, "ready to play"],
          [launcherCards, "library cards"],
          [visible.length, state.query ? "search results" : "shown in this view"]
        ];
        if (state.category) chips.push([visible.length, (categoryLabelMap(state.catalog)[state.category] || state.category)]);
        if (state.filters.disabled_categories.length || state.filters.disabled_games.length) chips.push([state.filters.disabled_games.length, "hidden by settings"]);
        chips.forEach(function (parts) {
          var chip = document.createElement("span"); chip.className = "stat-pill";
          chip.innerHTML = "<strong>" + String(parts[0]) + "</strong> " + String(parts[1]);
          status.appendChild(chip);
        });
      }
      function render() {
        var allGames = Array.isArray(state.catalog.games) ? state.catalog.games : [];
        var allEnabled = allGames.filter(gameEnabled);
        var profilePool = allEnabled.filter(function (game) { return matchesProfile(game, state.profile); });
        var visible = sortGames(filteredBaseGames());
        renderAccountPanel();
        renderRecent();
        renderFavorites();
        renderProfiles();
        renderShelves();
        renderGenres(profilePool);
        renderStatus(visible, profilePool, allEnabled);
        var featuredGrid = document.getElementById("featuredGrid"); clear(featuredGrid);
        var searchingOrDrilledIn = String(state.query || "").trim() || state.category;
        var featured = searchingOrDrilledIn ? [] : sortGames(profilePool).filter(function (game) { return featuredIds.indexOf(String(game.id || "")) >= 0 || game.preview; }).slice(0, 3);
        if (!featured.length && !searchingOrDrilledIn) featured = visible.slice(0, 3);
        featured.forEach(function (game) { featuredGrid.appendChild(makeCard(game, true)); });
        document.getElementById("featuredShelf").hidden = featured.length === 0;
        var heading = profiles.filter(function (profile) { return profile.id === state.profile; })[0];
        document.getElementById("libraryHeading").textContent = state.category ? (categoryLabelMap(state.catalog)[state.category] || state.category) : (heading ? heading.label : "All Games");
        document.getElementById("libraryNote").textContent = heading ? heading.note : "";
        var grid = document.getElementById("gameGrid"); clear(grid);
        visible.forEach(function (game) { grid.appendChild(makeCard(game, false)); });
        document.getElementById("emptyState").hidden = visible.length !== 0;
      }

      Promise.all([
        fetchJson("./catalog.json", { games: [], categories: [] }),
        fetchJson("./admin.filters.json", { disabled_categories: [], disabled_games: [] }),
        fetchJson("./launcher-adapters.json", { games: {} }),
        fetchJson("./canonical-registry.json", { metrics: {} }),
        fetchJson("./readiness.json", { metrics: {}, entries: {} }),
        fetchJson("./deployment-profile.json", { selectedProfile: "full", defaultLibraryProfile: "all", label: "Home server" })
      ].concat(deepSearchSources.map(function (source) { return fetchJson(source.manifest, { games: [] }).then(function (manifest) { return { source: source, manifest: manifest || { games: [] } }; }); }))).then(function (results) {
        state.catalog = results[0] || { games: [], categories: [] };
        state.filters = normalizeFilters(results[1]);
        state.launcherAudit = results[2] || { games: {} };
        state.registry = results[3] || { metrics: {} };
        state.readiness = results[4] || { metrics: {}, entries: {} };
        state.deployment = results[5] || { selectedProfile: "full", defaultLibraryProfile: "all", label: "Home server" };
        if (profiles.some(function (profile) { return profile.id === state.deployment.defaultLibraryProfile; })) {
          state.profile = state.deployment.defaultLibraryProfile;
        }
        state.deepGames = results.slice(6).flatMap(function (entry) {
          var games = Array.isArray(entry.manifest.games) ? entry.manifest.games : [];
          return games.map(function (game) { return normalizeNestedGame(entry.source, game); }).filter(Boolean);
        });
        render();
        validateStoredAccount().then(render);
      });
      document.getElementById("searchInput").addEventListener("input", function (event) { state.query = String(event.target.value || ""); render(); });
      document.getElementById("genreSearch").addEventListener("input", function (event) { state.genreQuery = String(event.target.value || ""); render(); });
      document.getElementById("sortSelect").addEventListener("change", function (event) { state.sort = String(event.target.value || "recommended"); render(); });
    })();
  </script>
</body>
</html>
HTML
}

write_account_index() {
  local arcade_name_html
  arcade_name_html="$(html_escape "$ARCADE_NAME_USE")"

  cat > "$ACCOUNT_INDEX_FILE" <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${arcade_name_html} Account</title>
  <style>
    :root { color-scheme: dark; --bg: #090d10; --panel: #141b20; --panel-soft: #192229; --line: #303a40; --text: #f4f7f8; --muted: #a8b2b8; --green: #58d68d; --green-soft: rgba(88,214,141,.16); --warn: #f2c14e; --radius: 8px; }
    * { box-sizing: border-box; }
    body { margin: 0; font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: linear-gradient(180deg, #101719, var(--bg)); color: var(--text); }
    main { width: min(980px, calc(100vw - 24px)); margin: 0 auto; padding: 24px 0 40px; }
    a { color: #dfffea; font-weight: 800; }
    .top { display: flex; justify-content: space-between; gap: 12px; align-items: flex-start; flex-wrap: wrap; margin-bottom: 16px; }
    h1 { margin: 0 0 6px; font-size: clamp(28px, 4vw, 46px); line-height: 1; }
    .muted { color: var(--muted); line-height: 1.45; }
    .button { min-height: 38px; border: 1px solid rgba(88,214,141,.42); border-radius: 6px; background: var(--green-soft); color: #dfffea; padding: 8px 12px; text-decoration: none; font-weight: 850; cursor: pointer; display: inline-flex; align-items: center; justify-content: center; }
    .button.secondary { border-color: var(--line); background: #151c20; color: var(--text); }
    .grid { display: grid; grid-template-columns: minmax(260px, 0.9fr) minmax(320px, 1.4fr); gap: 14px; align-items: start; }
    .card { border: 1px solid var(--line); border-radius: var(--radius); background: var(--panel); padding: 16px; }
    .card h2 { margin: 0 0 12px; font-size: 18px; }
    .fields { display: grid; gap: 9px; }
    .field { display: grid; grid-template-columns: 130px minmax(0, 1fr); gap: 10px; border-top: 1px solid rgba(255,255,255,.07); padding-top: 9px; }
    .field:first-child { border-top: 0; padding-top: 0; }
    .label { color: var(--muted); font-size: 13px; }
    .value { overflow-wrap: anywhere; }
    .empty { border: 1px dashed var(--line); border-radius: var(--radius); padding: 16px; color: var(--muted); background: #111719; }
    .recent-list { display: grid; gap: 10px; }
    .recent-item { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 12px; border: 1px solid var(--line); border-radius: 7px; background: var(--panel-soft); padding: 12px; text-decoration: none; color: var(--text); }
    .recent-item strong { display: block; margin-bottom: 4px; }
    .recent-meta { color: var(--muted); font-size: 13px; line-height: 1.35; }
    input, textarea { width: 100%; border: 1px solid var(--line); border-radius: 6px; background: #0f1519; color: var(--text); padding: 9px 10px; font: inherit; }
    textarea { min-height: 86px; resize: vertical; }
    .inline-form { display: grid; gap: 8px; margin-top: 12px; }
    .message-body { color: var(--text); margin-top: 6px; line-height: 1.4; overflow-wrap: anywhere; }
    .wide { grid-column: 1 / -1; }
    .count { color: #dfffea; font-weight: 850; white-space: nowrap; }
    .actions { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 12px; }
    .notice { border-left: 4px solid var(--warn); background: rgba(242,193,78,.1); padding: 10px 12px; border-radius: 7px; color: #ffe5a4; }
    @media (max-width: 760px) { .grid { grid-template-columns: 1fr; } .field { grid-template-columns: 1fr; gap: 3px; } .recent-item { grid-template-columns: 1fr; } }
  </style>
</head>
<body>
  <main>
    <div class="top">
      <div>
        <h1>Account</h1>
        <p class="muted">View the local player signed in on this browser and recent games synced to this arcade.</p>
      </div>
      <a class="button secondary" href="../">Back to Game Library</a>
    </div>
    <div class="grid">
      <section class="card">
        <h2>Player</h2>
        <div id="accountState" class="empty">Checking this browser...</div>
      </section>
      <section class="card">
        <h2>Recently played</h2>
        <div id="recentState" class="empty">Checking recent games...</div>
      </section>
      <section class="card">
        <h2>Friends</h2>
        <div id="friendState" class="empty">Checking friends...</div>
      </section>
      <section class="card wide">
        <h2>Messages & invites</h2>
        <div id="messageState" class="empty">Checking messages...</div>
      </section>
      <section class="card wide">
        <h2>Save vault</h2>
        <div id="saveState" class="empty">Checking synced saves...</div>
      </section>
    </div>
  </main>
  <script>
    (function () {
      "use strict";
      var accountStorageKey = "lanArcadeAccount.v1";
      var accountApiBase = window.location.origin + "/arcade-api/";
      function clear(el) { el.textContent = ""; }
      function storedAccount() { try { var saved = JSON.parse(localStorage.getItem(accountStorageKey) || "null"); return saved && saved.token ? saved : null; } catch (e) { return null; } }
      function forgetAccount() { try { localStorage.removeItem(accountStorageKey); } catch (e) {} window.location.reload(); }
      function request(path, token, options) {
        var requestOptions = options || {};
        requestOptions.headers = Object.assign({ "x-arcade-account-session": token, "content-type": "application/json" }, requestOptions.headers || {});
        requestOptions.cache = "no-store";
        return fetch(accountApiBase + path, requestOptions).then(function (response) {
          return response.text().then(function (raw) {
            var body = raw ? JSON.parse(raw) : {};
            if (!response.ok) throw new Error(body.error || "Request failed");
            return body;
          });
        });
      }
      function field(label, value) {
        var row = document.createElement("div"); row.className = "field";
        var key = document.createElement("div"); key.className = "label"; key.textContent = label; row.appendChild(key);
        var val = document.createElement("div"); val.className = "value"; val.textContent = value || "-"; row.appendChild(val);
        return row;
      }
      function mailboxStatusLabel(account) {
        var status = String(account && account.mailboxStatus || "pending");
        if (status === "ready") return "Ready";
        if (status === "alias") return "Routed to your family organizer";
        if (status === "disabled") return "Disabled";
        if (status === "error") return "Needs attention";
        return "Setup pending";
      }
      function emailVerificationLabel(account) {
        return account && account.emailVerifiedAt ? "Verified " + new Date(account.emailVerifiedAt).toLocaleString() : "Not verified yet";
      }
      function renderSignedOut() {
        var accountEl = document.getElementById("accountState");
        accountEl.className = "empty";
        accountEl.innerHTML = "No account is signed in on this browser. Use the Player panel on the Game Library page to sign in or create a local account.";
        var actions = document.createElement("div"); actions.className = "actions";
        var back = document.createElement("a"); back.className = "button"; back.href = "../"; back.textContent = "Go to Game Library"; actions.appendChild(back);
        accountEl.appendChild(actions);
        var recentEl = document.getElementById("recentState"); recentEl.className = "empty"; recentEl.textContent = "Recent games are only synced after signing in.";
        var friendEl = document.getElementById("friendState"); friendEl.className = "empty"; friendEl.textContent = "Friends are available after signing in.";
        var messageEl = document.getElementById("messageState"); messageEl.className = "empty"; messageEl.textContent = "Messages and game invites are available after signing in.";
        var saveEl = document.getElementById("saveState"); saveEl.className = "empty"; saveEl.textContent = "Synced saves will appear after signing in and playing save-aware games.";
      }
      function renderAccount(account, player) {
        var el = document.getElementById("accountState"); clear(el); el.className = "fields";
        el.appendChild(field("Display name", account.displayName));
        el.appendChild(field("Username", account.username));
        el.appendChild(field("Local email", account.localEmail));
        el.appendChild(field("Mailbox", mailboxStatusLabel(account)));
        el.appendChild(field("Email verification", emailVerificationLabel(account)));
        el.appendChild(field("Role", account.role));
        el.appendChild(field("Status", account.status));
        el.appendChild(field("Player", player ? player.displayName : "Not linked"));
        el.appendChild(field("Last login", account.lastLoginAt ? new Date(account.lastLoginAt).toLocaleString() : "Not recorded"));
        var note = document.createElement("div"); note.className = "notice"; note.textContent = "Password reset and email verification will be available here after the local mail workflow is connected."; el.appendChild(note);
        var actions = document.createElement("div"); actions.className = "actions";
        var signOut = document.createElement("button"); signOut.type = "button"; signOut.className = "button secondary"; signOut.textContent = "Sign out on this browser"; signOut.addEventListener("click", forgetAccount); actions.appendChild(signOut);
        el.appendChild(actions);
      }
      function renderRecent(rows) {
        var el = document.getElementById("recentState"); clear(el);
        if (!rows.length) { el.className = "empty"; el.textContent = "No synced recent games yet."; return; }
        el.className = "recent-list";
        rows.forEach(function (item) {
          var link = document.createElement("a"); link.className = "recent-item"; link.href = item.path || "../";
          var main = document.createElement("div");
          var title = document.createElement("strong"); title.textContent = item.title || item.gameId || "Game"; main.appendChild(title);
          var meta = document.createElement("div"); meta.className = "recent-meta"; meta.textContent = [item.meta, item.lastPlayedAt ? new Date(item.lastPlayedAt).toLocaleString() : ""].filter(Boolean).join(" | "); main.appendChild(meta);
          link.appendChild(main);
          var count = document.createElement("span"); count.className = "count"; count.textContent = String(item.playCount || 1) + " play" + ((item.playCount || 1) === 1 ? "" : "s"); link.appendChild(count);
          el.appendChild(link);
        });
      }

      function renderFriends(rows, token) {
        var el = document.getElementById("friendState"); clear(el);
        var list = Array.isArray(rows) ? rows : [];
        el.className = "recent-list";
        if (!list.length) {
          var empty = document.createElement("div"); empty.className = "empty"; empty.textContent = "No friends yet. Add another local arcade username to make invites easier."; el.appendChild(empty);
        }
        list.forEach(function (friend) {
          var row = document.createElement("div"); row.className = "recent-item";
          var main = document.createElement("div");
          var title = document.createElement("strong"); title.textContent = friend.displayName || friend.username; main.appendChild(title);
          var meta = document.createElement("div"); meta.className = "recent-meta"; meta.textContent = ["@" + friend.username, friend.lastSeenAt ? "last seen " + new Date(friend.lastSeenAt).toLocaleString() : "not seen yet"].join(" - "); main.appendChild(meta);
          row.appendChild(main);
          el.appendChild(row);
        });
        var form = document.createElement("form"); form.className = "inline-form";
        var input = document.createElement("input"); input.placeholder = "Friend username"; input.autocomplete = "username"; form.appendChild(input);
        var button = document.createElement("button"); button.type = "submit"; button.className = "button"; button.textContent = "Add friend"; form.appendChild(button);
        var status = document.createElement("div"); status.className = "recent-meta"; form.appendChild(status);
        form.addEventListener("submit", function (event) {
          event.preventDefault();
          status.textContent = "Adding...";
          request("account/friends", token, { method: "POST", body: JSON.stringify({ username: input.value }) }).then(function () { window.location.reload(); }).catch(function (error) { status.textContent = error.message || "Could not add friend"; });
        });
        el.appendChild(form);
      }
      function renderMessages(rows, token, account) {
        var el = document.getElementById("messageState"); clear(el);
        var list = Array.isArray(rows) ? rows : [];
        el.className = "recent-list";
        if (!list.length) {
          var empty = document.createElement("div"); empty.className = "empty"; empty.textContent = "No messages yet."; el.appendChild(empty);
        }
        list.slice(0, 12).forEach(function (message) {
          var row = document.createElement("div"); row.className = "recent-item";
          var main = document.createElement("div");
          var title = document.createElement("strong");
          var inbound = account && message.toUsername === account.username;
          title.textContent = (inbound ? "From " + message.fromDisplayName : "To " + message.toDisplayName) + (message.gameTitle ? " - " + message.gameTitle : "");
          main.appendChild(title);
          var meta = document.createElement("div"); meta.className = "recent-meta"; meta.textContent = message.createdAt ? new Date(message.createdAt).toLocaleString() : ""; main.appendChild(meta);
          var body = document.createElement("div"); body.className = "message-body"; body.textContent = message.body || ""; main.appendChild(body);
          row.appendChild(main);
          if (message.gamePath) { var play = document.createElement("a"); play.className = "button"; play.href = message.gamePath; play.textContent = "Open"; row.appendChild(play); }
          el.appendChild(row);
        });
        var form = document.createElement("form"); form.className = "inline-form";
        var to = document.createElement("input"); to.placeholder = "Username"; to.autocomplete = "username"; form.appendChild(to);
        var body = document.createElement("textarea"); body.placeholder = "Message or game invite"; form.appendChild(body);
        var button = document.createElement("button"); button.type = "submit"; button.className = "button"; button.textContent = "Send message"; form.appendChild(button);
        var status = document.createElement("div"); status.className = "recent-meta"; form.appendChild(status);
        form.addEventListener("submit", function (event) {
          event.preventDefault();
          status.textContent = "Sending...";
          request("account/messages", token, { method: "POST", body: JSON.stringify({ toUsername: to.value, body: body.value }) }).then(function () { window.location.reload(); }).catch(function (error) { status.textContent = error.message || "Could not send message"; });
        });
        el.appendChild(form);
      }
      function renderSaves(rows) {
        var el = document.getElementById("saveState"); clear(el);
        if (!rows.length) { el.className = "empty"; el.textContent = "No synced saves yet. Browser games, emulators, and DOS games will appear here as their save adapters are connected."; return; }
        el.className = "recent-list";
        rows.forEach(function (item) {
          var row = document.createElement("div"); row.className = "recent-item";
          var main = document.createElement("div");
          var title = document.createElement("strong"); title.textContent = item.label || item.slot || "Save slot"; main.appendChild(title);
          var meta = document.createElement("div"); meta.className = "recent-meta"; meta.textContent = [item.adapter, item.gameId, item.slot, item.updatedAt ? new Date(item.updatedAt).toLocaleString() : ""].filter(Boolean).join(" | "); main.appendChild(meta);
          row.appendChild(main);
          var size = document.createElement("span"); size.className = "count"; size.textContent = formatBytes(item.sizeBytes || 0); row.appendChild(size);
          el.appendChild(row);
        });
      }
      function formatBytes(value) {
        var bytes = Number(value) || 0;
        if (bytes < 1024) return String(bytes) + " B";
        if (bytes < 1024 * 1024) return String(Math.round(bytes / 1024)) + " KB";
        return String((bytes / 1024 / 1024).toFixed(1)) + " MB";
      }
      var saved = storedAccount();
      if (!saved) { renderSignedOut(); return; }
      request("auth/me", saved.token).then(function (body) {
        renderAccount(body.account, body.player || null);
        return Promise.all([
          request("account/activity/recent?limit=20", saved.token),
          request("account/friends?limit=50", saved.token),
          request("account/messages?limit=50", saved.token),
          request("account/saves?limit=20", saved.token)
        ]);
      }).then(function (results) {
        renderRecent(Array.isArray(results[0].activity) ? results[0].activity : []);
        renderFriends(Array.isArray(results[1].friends) ? results[1].friends : [], saved.token);
        renderMessages(Array.isArray(results[2].messages) ? results[2].messages : [], saved.token, saved.account || null);
        renderSaves(Array.isArray(results[3].saves) ? results[3].saves : []);
      }).catch(function () {
        forgetAccount();
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
      <a class="button-link" href="../wiki/">Guides & Manuals</a>
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
  <title>${arcade_name_html} Guides &amp; Manuals</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #0a0d0f;
      --panel: #151b1f;
      --panel-soft: #1b2328;
      --text: #f4f7f8;
      --muted: #aeb8bd;
      --line: #344047;
      --green: #58d68d;
      --green-soft: rgba(88,214,141,.14);
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    .wrap { width: min(1180px, calc(100% - 2rem)); margin: 0 auto; padding: 1.4rem 0 3rem; }
    h1 { margin: 0; font-size: clamp(1.8rem, 4vw, 2.7rem); }
    h2 { margin: 0; font-size: 1.12rem; }
    p { color: var(--muted); line-height: 1.5; }
    .toolbar { display: flex; gap: .55rem; flex-wrap: wrap; margin: 1rem 0 1.2rem; }
    .button, .game-link {
      display: inline-flex;
      align-items: center;
      min-height: 42px;
      border: 1px solid var(--line);
      border-radius: 6px;
      padding: .55rem .8rem;
      color: var(--text);
      background: var(--panel);
      text-decoration: none;
      font-weight: 700;
    }
    .button:hover, .game-link:hover { border-color: var(--green); }
    .guide-grid, .game-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(min(100%, 250px), 1fr));
      gap: .75rem;
    }
    .guide, .game-card {
      border: 1px solid var(--line);
      border-radius: 7px;
      background: var(--panel);
      padding: .9rem;
    }
    .guide p { margin: .45rem 0 0; }
    .library { margin-top: 1.4rem; }
    .library-head { display: flex; justify-content: space-between; gap: 1rem; align-items: end; flex-wrap: wrap; }
    .controls {
      display: grid;
      grid-template-columns: minmax(220px, 1fr) minmax(180px, 280px);
      gap: .6rem;
      margin: .8rem 0;
    }
    input, select {
      width: 100%;
      min-height: 44px;
      border: 1px solid var(--line);
      border-radius: 6px;
      background: var(--panel-soft);
      color: var(--text);
      padding: .55rem .7rem;
      font: inherit;
    }
    .game-card { display: grid; align-content: start; gap: .55rem; }
    .game-card h3 { margin: 0; font-size: 1rem; }
    .game-card p { margin: 0; font-size: .9rem; }
    .chips { display: flex; flex-wrap: wrap; gap: .3rem; }
    .chip {
      border-radius: 999px;
      background: var(--green-soft);
      color: #dfffea;
      padding: .15rem .45rem;
      font-size: .73rem;
    }
    .empty { color: var(--muted); padding: 1rem 0; }
    @media (max-width: 620px) {
      .controls { grid-template-columns: 1fr; }
      .wrap { width: min(100% - 1rem, 1180px); }
    }
  </style>
</head>
<body>
  <main class="wrap">
    <h1>Guides &amp; Manuals</h1>
    <p>Choose a game, learn what you need, and start playing without an internet connection.</p>

    <nav class="toolbar" aria-label="Arcade links">
      <a class="button" href="../">Back to game library</a>
      <a class="button" href="../downloads/">Get games and apps</a>
      <a class="button" href="../account/">Your account</a>
    </nav>

    <section class="guide-grid" aria-label="How to play">
      <article class="guide">
        <h2>Play in your browser</h2>
        <p>Select <strong>Play</strong> or <strong>Try</strong>. Click inside the game before using its keyboard, mouse, or controller.</p>
      </article>
      <article class="guide">
        <h2>Classic and retro games</h2>
        <p>Open the retro collection, choose a title, then use its on-screen controls. Each game page shows any special keys it needs.</p>
      </article>
      <article class="guide">
        <h2>Install on a computer</h2>
        <p>Select <strong>Install / play</strong>, choose the Windows or Linux download for your device, and follow the short local instructions.</p>
      </article>
      <article class="guide">
        <h2>Join a LAN game</h2>
        <p>Select <strong>Start / join</strong>. The game page shows whether you need a client, room code, server address, or another player.</p>
      </article>
      <article class="guide">
        <h2>Play together at a table</h2>
        <p>Board-game pages show player count, expected session length, and the locally saved rules or companion material available.</p>
      </article>
      <article class="guide">
        <h2>Keep your progress</h2>
        <p>Sign in before playing account-aware games. Guest progress may stay only on the current device and browser.</p>
      </article>
    </section>

    <section class="library">
      <div class="library-head">
        <div>
          <h2>Find a game guide</h2>
          <p id="gamesSummary">Loading available library cards...</p>
        </div>
      </div>
      <div class="controls">
        <input id="searchInput" type="search" placeholder="Search games, genres, or tags" aria-label="Search game guides">
        <select id="categoryFilter" aria-label="Filter by category"><option value="">All categories</option></select>
      </div>
      <div id="gameGrid" class="game-grid"></div>
      <div id="emptyState" class="empty" hidden>No available games match this search.</div>
    </section>
  </main>

  <script>
    (function () {
      "use strict";
      var state = { catalog: { categories: [], games: [] }, filters: { disabled_categories: [], disabled_games: [] }, query: "", category: "" };

      function array(value) {
        return Array.isArray(value) ? value.map(function (item) { return String(item).trim(); }).filter(Boolean) : [];
      }
      function fetchJson(url, fallback) {
        return fetch(url, { cache: "no-store" }).then(function (response) {
          if (!response.ok) throw new Error("HTTP " + response.status);
          return response.json();
        }).catch(function () { return fallback; });
      }
      function labels() {
        var map = Object.create(null);
        (state.catalog.categories || []).forEach(function (category) {
          if (category && category.id) map[String(category.id)] = String(category.label || category.id);
        });
        return map;
      }
      function available(game) {
        var disabledGames = new Set(array(state.filters.disabled_games));
        var disabledCategories = new Set(array(state.filters.disabled_categories));
        if (disabledGames.has(String(game.id || ""))) return false;
        return !array(game.categories).some(function (category) { return disabledCategories.has(category); });
      }
      function populateCategories() {
        var select = document.getElementById("categoryFilter");
        var map = labels();
        var used = new Set();
        (state.catalog.games || []).filter(available).forEach(function (game) {
          array(game.categories).forEach(function (category) { used.add(category); });
        });
        (state.catalog.categories || []).forEach(function (category) {
          var id = String(category && category.id || "");
          if (!id || !used.has(id)) return;
          var option = document.createElement("option");
          option.value = id;
          option.textContent = map[id] || id;
          select.appendChild(option);
        });
      }
      function chip(text) {
        var element = document.createElement("span");
        element.className = "chip";
        element.textContent = text;
        return element;
      }
      function render() {
        var map = labels();
        var games = (state.catalog.games || []).filter(available).filter(function (game) {
          var categories = array(game.categories);
          var search = [game.title, game.description, categories.join(" "), array(game.tags).join(" ")].join(" ").toLowerCase();
          return (!state.query || search.indexOf(state.query) >= 0) && (!state.category || categories.includes(state.category));
        }).sort(function (a, b) { return String(a.title || a.id).localeCompare(String(b.title || b.id)); });

        var grid = document.getElementById("gameGrid");
        grid.textContent = "";
        games.forEach(function (game) {
          var card = document.createElement("article");
          card.className = "game-card";
          var heading = document.createElement("h3");
          heading.textContent = String(game.title || game.id || "Game");
          card.appendChild(heading);
          var description = document.createElement("p");
          description.textContent = String(game.description || "Open the game page for play and setup details.");
          card.appendChild(description);
          var chips = document.createElement("div");
          chips.className = "chips";
          array(game.categories).slice(0, 4).forEach(function (category) { chips.appendChild(chip(map[category] || category)); });
          card.appendChild(chips);
          var link = document.createElement("a");
          link.className = "game-link";
          link.href = game.path ? String(game.path) : "../" + encodeURIComponent(String(game.id || "")) + "/";
          link.textContent = "Open game";
          card.appendChild(link);
          grid.appendChild(card);
        });
        document.getElementById("gamesSummary").textContent = "Showing " + games.length + " available library cards.";
        document.getElementById("emptyState").hidden = games.length !== 0;
      }

      Promise.all([
        fetchJson("../catalog.json", { categories: [], games: [] }),
        fetchJson("../admin.filters.json", { disabled_categories: [], disabled_games: [] })
      ]).then(function (results) {
        state.catalog = results[0] || { categories: [], games: [] };
        state.filters = results[1] || { disabled_categories: [], disabled_games: [] };
        populateCategories();
        render();
      });

      document.getElementById("searchInput").addEventListener("input", function (event) {
        state.query = String(event.target.value || "").toLowerCase().trim();
        render();
      });
      document.getElementById("categoryFilter").addEventListener("change", function (event) {
        state.category = String(event.target.value || "");
        render();
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

deploy_shared_local_assets() {
  if [ ! -d "$LOCAL_SHARED_ASSETS_DIR" ]; then
    return
  fi

  echo "===== Deploying shared browser game assets into $SHARED_ASSETS_DIR ====="
  mkdir -p "$SHARED_ASSETS_DIR"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$LOCAL_SHARED_ASSETS_DIR"/ "$SHARED_ASSETS_DIR"/
  else
    rm -rf "$SHARED_ASSETS_DIR"
    mkdir -p "$SHARED_ASSETS_DIR"
    shopt -s dotglob nullglob
    cp -a "$LOCAL_SHARED_ASSETS_DIR"/* "$SHARED_ASSETS_DIR"/ 2>/dev/null || true
    shopt -u dotglob nullglob
  fi
}

deploy_local_bundled_games() {
  local GAME URL TARGET MARKER local_spec local_source_dir

  echo "===== Deploying local bundled games into $MIRRORS_DIR ====="
  for GAME in "${!GAMES[@]}"; do
    URL="${GAMES[$GAME]}"
    [[ "$URL" == LOCAL_DIR::* ]] || continue

    local_spec="${URL#LOCAL_DIR::}"
    local_source_dir="$SCRIPT_DIR/$local_spec"
    TARGET="$MIRRORS_DIR/$GAME"
    MARKER="$TARGET/$READY_MARKER"

    if [ ! -d "$local_source_dir" ]; then
      echo "WARN local bundled game source missing for $GAME: $local_source_dir"
      continue
    fi

    echo "Local deploy $GAME"
    mkdir -p "$TARGET"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete --exclude "$READY_MARKER" "$local_source_dir"/ "$TARGET"/
    else
      rm -rf "$TARGET"
      mkdir -p "$TARGET"
      shopt -s dotglob nullglob
      cp -a "$local_source_dir"/* "$TARGET"/ 2>/dev/null || true
      shopt -u dotglob nullglob
    fi

    promote_entrypoint_if_missing "$TARGET"
    patch_mirror_for_offline_use "$GAME" "$TARGET"
    if mirror_content_is_complete "$GAME" "$TARGET"; then
      touch "$MARKER"
    else
      rm -f "$MARKER"
      echo "WARN local bundled game $GAME did not pass mirror completeness checks."
    fi
  done
}

if [ "$LAN_ARCADE_REGISTRY_INDEX_ONLY" = "1" ]; then
  echo "===== Regenerating canonical registry and public library index only ====="
  build_canonical_registry
  build_readiness_authority
  write_deployment_profile
  write_public_index
  chmod 644 "$CANONICAL_REGISTRY_FILE"
  chmod 644 "$INDEX_FILE"
  echo "Canonical registry and public library index regenerated."
  exit 0
fi

if [ "$LAN_ARCADE_PAGES_ONLY" = "1" ]; then
  echo "===== Regenerating public pages without rebuilding catalog or game payloads ====="
  build_canonical_registry
  build_readiness_authority
  write_deployment_profile
  write_public_index
  write_account_index
  write_wiki_index
  chmod 644 "$CANONICAL_REGISTRY_FILE" "$INDEX_FILE" "$ACCOUNT_INDEX_FILE" "$WIKI_INDEX_FILE"
  echo "Public library, account, and guide pages regenerated."
  exit 0
fi


deploy_shared_local_assets

# ---------- Mirror each game ----------
if [ "$LAN_ARCADE_SKIP_MIRROR" = "1" ]; then
  echo "===== Skipping remote game mirroring because LAN_ARCADE_SKIP_MIRROR=1 ====="
  deploy_local_bundled_games
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


if [ -x "$SCRIPT_DIR/scripts/build_lemmings_ts.py" ] && command -v python3 >/dev/null 2>&1; then
  echo "===== Building Lemmings browser adapter when private data is available ====="
  python3 "$SCRIPT_DIR/scripts/build_lemmings_ts.py" || echo "WARN Lemmings browser adapter build failed; the placeholder page may be shown."
fi

echo "===== Building catalog and pages in $INDEX_DIR ====="
build_catalog_json
build_canonical_registry
build_readiness_authority
write_deployment_profile
ensure_filters_file
write_public_index
write_account_index
publish_companion_downloads
write_wiki_index
write_admin_cgi
write_admin_index
if [ -x "$SCRIPT_DIR/scripts/sanitize_public_external_links.py" ] && command -v python3 >/dev/null 2>&1; then
  python3 "$SCRIPT_DIR/scripts/sanitize_public_external_links.py" --root "$MIRRORS_DIR" --report "$SCRIPT_DIR/qa/reports/offline-links/sanitize-latest.json" || echo "WARN public external-link sanitizer reported problems."
else
  echo "WARN public external-link sanitizer is unavailable."
fi
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
chmod 755 "$ACCOUNT_DIR"
chmod 755 "$ADMIN_DIR"
chmod 755 "$DOWNLOADS_DIR"
chmod 755 "$DOWNLOAD_SCREENSHOTS_DIR"
chmod 644 "$INDEX_FILE"
chmod 644 "$CATALOG_FILE"
chmod 644 "$CANONICAL_REGISTRY_FILE"
chmod 644 "$READINESS_FILE"
chmod 644 "$READINESS_QUARANTINE_FILE"
chmod 644 "$FILTERS_FILE"
chmod 644 "$WIKI_INDEX_FILE"
chmod 644 "$ACCOUNT_INDEX_FILE"
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
echo "Operator tools: http://<your-server-ip>/mirrors/games/admin/"
echo "APK:    http://<your-server-ip>/mirrors/games/downloads/lan-arcade-companion-debug.apk"
echo "Tank:   http://<your-server-ip>/mirrors/lan-tank-arena/ (service port ${LAN_TANK_PORT})"
