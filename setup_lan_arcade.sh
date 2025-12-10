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

# Pull in GAMES and GAME_INFO
source "$SCRIPT_DIR/games.meta.sh"

MIRRORS_DIR="/var/www/html/mirrors"
INDEX_DIR="$MIRRORS_DIR/games"
INDEX_FILE="$INDEX_DIR/index.html"

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

# ---------- Mirror each game ----------
echo "===== Mirroring games into $MIRRORS_DIR ====="

for GAME in "${!GAMES[@]}"; do
  URL="${GAMES[$GAME]}"
  TARGET="$MIRRORS_DIR/$GAME"

  if [ -d "$TARGET" ] && [ -n "$(ls -A "$TARGET" 2>/dev/null || true)" ]; then
    echo "✅ $GAME already exists, skipping download"
    continue
  fi

  echo "🌐 Downloading $GAME from $URL"
  mkdir -p "$TARGET"
  chown "$LOCAL_USER:$LOCAL_USER" "$TARGET"
  cd "$TARGET"

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
    wget \
      --mirror \
      --convert-links \
      --adjust-extension \
      --page-requisites \
      --no-parent \
      "$URL" || echo "⚠️ wget reported an error for $GAME; check manually if needed."

    flatten_mirror "$URL" "$TARGET"
  fi

  chown -R www-data:www-data "$TARGET"
done

# ---------- Build pretty index.html ----------
echo "===== Rebuilding index at $INDEX_FILE ====="

cat > "$INDEX_FILE" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>${ARCADE_NAME_USE} LAN Arcade</title>
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
    <h1>${ARCADE_NAME_USE} LAN Arcade</h1>
    <div class="subtitle">
      Offline-friendly games hosted on your home server.<br>
      Tap a game to launch it in your browser or “Add to Home Screen” on mobile.
    </div>
  </header>
  <main>
    <section class="grid">
HTML

# Append a card for each folder under /var/www/html/mirrors
for DIR in $(ls -1 "$MIRRORS_DIR" | sort); do
  [ -d "$MIRRORS_DIR/$DIR" ] || continue

  info="${GAME_INFO[$DIR]:-}"
  if [ -n "$info" ]; then
    IFS='|' read -r title icon meta desc tags <<< "$info"
  else
    title="$(echo "$DIR" | tr '-' ' ')"
    icon="▶"
    meta="HTML5 · Offline"
    desc="Offline-friendly browser game mirrored in the \"$DIR\" folder."
    tags="Offline"
  fi

  echo "      <a class=\"game-card\" href=\"../$DIR/\">" >> "$INDEX_FILE"
  echo "        <div class=\"game-title\">$title</div>" >> "$INDEX_FILE"
  echo "        <div class=\"game-meta\">$meta</div>" >> "$INDEX_FILE"
  echo "        <div class=\"game-desc\">" >> "$INDEX_FILE"
  echo "          $desc" >> "$INDEX_FILE"
  echo "        </div>" >> "$INDEX_FILE"
  echo "        <div class=\"pill-row\">" >> "$INDEX_FILE"

  IFS=',' read -ra tag_arr <<< "$tags"
  first_tag=1
  for tag in "${tag_arr[@]}"; do
    trimmed="$(echo "$tag" | sed 's/^ *//;s/ *$//')"
    [ -z "$trimmed" ] && continue
    if [ "$first_tag" -eq 1 ]; then
      echo "          <div class=\"pill pill--primary\">$trimmed</div>" >> "$INDEX_FILE"
      first_tag=0
    else
      echo "          <div class=\"pill\">$trimmed</div>" >> "$INDEX_FILE"
    fi
  done

  echo "        </div>" >> "$INDEX_FILE"
  echo "        <div class=\"play-row\">" >> "$INDEX_FILE"
  echo "          <button class=\"play-btn\" type=\"button\">" >> "$INDEX_FILE"
  echo "            <span>$icon</span> Play" >> "$INDEX_FILE"
  echo "          </button>" >> "$INDEX_FILE"
  echo "          <span style=\"font-size:0.75rem;color:var(--muted);\">" >> "$INDEX_FILE"
  echo "            /mirrors/$DIR/..." >> "$INDEX_FILE"
  echo "          </span>" >> "$INDEX_FILE"
  echo "        </div>" >> "$INDEX_FILE"
  echo "      </a>" >> "$INDEX_FILE"
done

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
