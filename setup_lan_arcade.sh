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

# Load metadata in a separate shell. If running via sudo, execute as the
# invoking non-root user so metadata cannot run with root privileges.
declare -A GAMES=()
declare -A GAME_INFO=()

load_metadata() {
  local dump quoted_meta
  local -a runner=()

  if [ ! -f "$META_FILE" ]; then
    echo "Metadata file not found: $META_FILE"
    exit 1
  fi

  quoted_meta="$(printf '%q' "$META_FILE")"

  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ] && command -v sudo >/dev/null 2>&1; then
    runner=(sudo -u "$SUDO_USER")
  fi

  if ! dump="$("${runner[@]}" bash -lc "set -euo pipefail; source $quoted_meta; declare -p GAMES GAME_INFO" 2>&1)"; then
    echo "Failed to load metadata from $META_FILE"
    echo "$dump"
    exit 1
  fi

  if ! printf '%s\n' "$dump" | grep -q '^declare -A GAMES=' \
    || ! printf '%s\n' "$dump" | grep -q '^declare -A GAME_INFO='; then
    echo "Unexpected metadata output from $META_FILE"
    exit 1
  fi

  # shellcheck disable=SC1090
  eval "$dump"
}

load_metadata

MIRRORS_DIR="/var/www/html/mirrors"
INDEX_DIR="$MIRRORS_DIR/games"
INDEX_FILE="$INDEX_DIR/index.html"
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
apt-get install -y apache2 wget unzip

if command -v systemctl >/dev/null 2>&1; then
  systemctl enable --now apache2 || true
fi

mkdir -p "$MIRRORS_DIR" "$INDEX_DIR"
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

  if [ "$URL" = "ZIP_GITHUB_REPO" ] && [ "$GAME" = "typing-test" ]; then
    wget -O typing-test.zip "https://github.com/KDvs123/Typing-Test/archive/refs/heads/main.zip"
    unzip -q typing-test.zip
    src_dir="$(find . -maxdepth 1 -type d -name 'Typing-Test*' | head -n1 || true)"
    if [ -n "$src_dir" ]; then
      shopt -s dotglob nullglob
      mv "$src_dir"/* "$TARGET"/ 2>/dev/null || true
      shopt -u dotglob nullglob
      rm -rf "$src_dir"
    fi
    rm -f typing-test.zip
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

# ---------- Build pretty index.html ----------
echo "===== Rebuilding index at $INDEX_FILE ====="

ARCADE_NAME_HTML="$(html_escape "$ARCADE_NAME_USE")"

cat > "$INDEX_FILE" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>${ARCADE_NAME_HTML} LAN Arcade</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
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
    main {
      padding: 1rem 1.5rem 2rem;
      max-width: 1100px;
      width: 100%;
      margin: 0 auto;
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
      cursor: pointer;
    }
    .play-btn span {
      font-size: 1rem;
    }
    .hint {
      font-size: 0.8rem;
      color: var(--muted);
      text-align: center;
      margin-top: 1rem;
      opacity: 0.8;
    }
    @media (max-width: 600px) {
      header { padding: 1.25rem 1rem 0.5rem; }
      main { padding: 0.5rem 1rem 1.5rem; }
    }
  </style>
</head>
<body>
  <header>
    <h1>${ARCADE_NAME_HTML} LAN Arcade</h1>
    <div class="subtitle">
      Offline-friendly games hosted on your home server.<br>
      Tap a game to launch it in your browser or 'Add to Home Screen' on mobile.
    </div>
  </header>
  <main>
    <section class="grid">
HTML

# Append a card for each folder under /var/www/html/mirrors
while IFS= read -r DIR; do
  [ "$DIR" = "games" ] && continue

  info="${GAME_INFO[$DIR]:-}"
  if [ -n "$info" ]; then
    IFS='|' read -r title icon meta desc tags <<< "$info"
  else
    title="$(echo "$DIR" | tr '-' ' ')"
    icon="Play"
    meta="HTML5 / Offline"
    desc="Offline-friendly browser game mirrored in the \"$DIR\" folder."
    tags="Offline"
  fi

  dir_html="$(html_escape "$DIR")"
  title_html="$(html_escape "$title")"
  icon_html="$(html_escape "$icon")"
  meta_html="$(html_escape "$meta")"
  desc_html="$(html_escape "$desc")"

  echo "      <a class=\"game-card\" href=\"../$dir_html/\">" >> "$INDEX_FILE"
  echo "        <div class=\"game-title\">$title_html</div>" >> "$INDEX_FILE"
  echo "        <div class=\"game-meta\">$meta_html</div>" >> "$INDEX_FILE"
  echo "        <div class=\"game-desc\">" >> "$INDEX_FILE"
  echo "          $desc_html" >> "$INDEX_FILE"
  echo "        </div>" >> "$INDEX_FILE"
  echo "        <div class=\"pill-row\">" >> "$INDEX_FILE"

  IFS=',' read -ra tag_arr <<< "$tags"
  first_tag=1
  for tag in "${tag_arr[@]}"; do
    trimmed="${tag#"${tag%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    [ -z "$trimmed" ] && continue
    tag_html="$(html_escape "$trimmed")"
    if [ "$first_tag" -eq 1 ]; then
      echo "          <div class=\"pill pill--primary\">$tag_html</div>" >> "$INDEX_FILE"
      first_tag=0
    else
      echo "          <div class=\"pill\">$tag_html</div>" >> "$INDEX_FILE"
    fi
  done

  echo "        </div>" >> "$INDEX_FILE"
  echo "        <div class=\"play-row\">" >> "$INDEX_FILE"
  echo "          <span class=\"play-btn\" aria-hidden=\"true\">" >> "$INDEX_FILE"
  echo "            <span>$icon_html</span> Play" >> "$INDEX_FILE"
  echo "          </span>" >> "$INDEX_FILE"
  echo "          <span style=\"font-size:0.75rem;color:var(--muted);\">" >> "$INDEX_FILE"
  echo "            /mirrors/$dir_html/..." >> "$INDEX_FILE"
  echo "          </span>" >> "$INDEX_FILE"
  echo "        </div>" >> "$INDEX_FILE"
  echo "      </a>" >> "$INDEX_FILE"
done < <(find "$MIRRORS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort)

cat >> "$INDEX_FILE" <<'HTML'
    </section>
    <div class="hint">
      To add more games, update <code>games.meta.sh</code>, then rerun the setup script.
    </div>
  </main>
</body>
</html>
HTML

chown -R www-data:www-data "$INDEX_DIR"

echo
echo "✅ Done! Visit:  http://<your-server-ip>/mirrors/games/  to see the LAN arcade."
