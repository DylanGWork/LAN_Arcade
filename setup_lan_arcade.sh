#!/usr/bin/env bash
# ===============================================================
# 🕹️ LAN Arcade – Auto-mirroring + pretty index.html
#   - Mirrors HTML/JS games into /var/www/html/mirrors
#   - Keeps index at /var/www/html/mirrors/games/index.html
#   - Uses games.meta.sh for URLs + metadata
# ===============================================================

set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "Please run this script as root, e.g.: sudo bash $0"
  exit 1
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
  idle
  clicker
  strategy
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
  ["idle"]="Idle"
  ["clicker"]="Clicker"
  ["strategy"]="Strategy"
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
ADMIN_DIR="$INDEX_DIR/admin"
ADMIN_INDEX_FILE="$ADMIN_DIR/index.html"
ADMIN_CGI_FILE="$ADMIN_DIR/save_filters.cgi"
ADMIN_HTPASSWD="/etc/apache2/.lan_arcade_admin_htpasswd"
ADMIN_APACHE_CONF="/etc/apache2/conf-available/lan-arcade-admin.conf"
DEFAULT_ADMIN_USER="arcadeadmin"
READY_MARKER=".mirror_ok"

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

# ---------- Base packages ----------
apt-get update -y
apt-get install -y apache2 apache2-utils wget unzip

if command -v systemctl >/dev/null 2>&1; then
  systemctl enable --now apache2 || true
fi

mkdir -p "$MIRRORS_DIR" "$INDEX_DIR" "$ADMIN_DIR"
chown -R "$LOCAL_USER:$LOCAL_USER" "$MIRRORS_DIR"

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

discover_mirror_dirs() {
  local -n out_ref="$1"
  out_ref=()
  while IFS= read -r dir_name; do
    [ "$dir_name" = "games" ] && continue
    out_ref+=("$dir_name")
  done < <(find "$MIRRORS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort)
}

ensure_filters_file() {
  if [ -f "$FILTERS_FILE" ]; then
    return 0
  fi

  cat > "$FILTERS_FILE" <<'JSON'
{
  "disabled_categories": [],
  "disabled_games": []
}
JSON
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
  local tags_json categories_json game_json
  local generated_at tmp_file idx category_id category_label

  discover_mirror_dirs mirror_dirs

  for dir_name in "${mirror_dirs[@]}"; do
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
    game_json="{\"id\":\"$(json_escape "$dir_name")\",\"title\":\"$(json_escape "$title")\",\"icon\":\"$(json_escape "$icon")\",\"meta\":\"$(json_escape "$meta")\",\"description\":\"$(json_escape "$desc")\",\"tags\":[${tags_json}],\"categories\":[${categories_json}]}"
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
      <a class="toolbar-link" href="./admin/">Admin Panel</a>
    </div>
  </header>
  <main>
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
        card.href = "../" + encodeURIComponent(game.id) + "/";

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
        pathHint.textContent = "/mirrors/" + game.id + "/...";
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

echo "===== Preparing admin access ====="
configure_admin_credentials

# ---------- Mirror each game ----------
echo "===== Mirroring games into $MIRRORS_DIR ====="

for GAME in "${!GAMES[@]}"; do
  URL="${GAMES[$GAME]}"
  TARGET="$MIRRORS_DIR/$GAME"
  MARKER="$TARGET/$READY_MARKER"

  if [ -f "$MARKER" ]; then
    echo "✅ $GAME already exists, skipping download"
    continue
  fi

  if [ -d "$TARGET" ] && [ -n "$(find "$TARGET" -mindepth 1 ! -name "$READY_MARKER" -print -quit 2>/dev/null || true)" ]; then
    echo "⚠️  $GAME has partial content but no completion marker; re-downloading."
    rm -rf "$TARGET"
  fi

  echo "🌐 Downloading $GAME from $URL"
  mkdir -p "$TARGET"
  chown "$LOCAL_USER:$LOCAL_USER" "$TARGET"
  cd "$TARGET"
  download_ok=1

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

  if [ -n "$zip_repo" ]; then
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
      echo "⚠️ wget reported an error for $GAME; check manually if needed."
      download_ok=0
    fi

    flatten_mirror "$URL" "$TARGET"
  fi

  if [ "$download_ok" -eq 1 ] && [ -n "$(find "$TARGET" -mindepth 1 ! -name "$READY_MARKER" -print -quit 2>/dev/null || true)" ]; then
    touch "$MARKER"
  else
    rm -f "$MARKER"
    echo "⚠️ $GAME did not complete successfully; it will be retried next run."
  fi

  chown -R www-data:www-data "$TARGET"
  # IdleAnt expects to be hosted at /IdleAnt/ (GitHub Pages base path); provide an alias.
  if [ "$GAME" = "IdleAnt" ]; then
    ln -sfn "$TARGET" "/var/www/html/IdleAnt"
  fi
done

echo "===== Building catalog and pages in $INDEX_DIR ====="
build_catalog_json
ensure_filters_file
write_public_index
write_admin_cgi
write_admin_index
configure_admin_auth

chown -R www-data:www-data "$INDEX_DIR"
chmod 755 "$ADMIN_DIR"
chmod 755 "$ADMIN_CGI_FILE"

if command -v systemctl >/dev/null 2>&1; then
  systemctl reload apache2 || true
elif command -v apachectl >/dev/null 2>&1; then
  apachectl -k graceful || true
fi

echo
echo "Done."
echo "Arcade: http://<your-server-ip>/mirrors/games/"
echo "Admin:  http://<your-server-ip>/mirrors/games/admin/ (HTTP Basic Auth)"
