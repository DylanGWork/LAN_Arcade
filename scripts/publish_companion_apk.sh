#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APK_SOURCE="${APK_SOURCE:-$ROOT_DIR/releases/android/lan-arcade-companion-debug.apk}"
DOWNLOADS_DIR="${LAN_ARCADE_DOWNLOADS_DIR:-/var/www/html/mirrors/games/downloads}"
SCREENSHOTS_DIR="$DOWNLOADS_DIR/screenshots"

if [ ! -f "$APK_SOURCE" ]; then
  echo "APK not found: $APK_SOURCE" >&2
  echo "Run scripts/build_companion_apk.sh first." >&2
  exit 1
fi

mkdir -p "$DOWNLOADS_DIR"
cp "$APK_SOURCE" "$DOWNLOADS_DIR/lan-arcade-companion-debug.apk"
chmod 644 "$DOWNLOADS_DIR/lan-arcade-companion-debug.apk"

mkdir -p "$SCREENSHOTS_DIR"
for screenshot in \
  companion-catalog.png \
  companion-trailguard.png \
  companion-unciv-service.png \
  companion-mindustry-service.png; do
  if [ -f "$ROOT_DIR/docs/assets/$screenshot" ]; then
    cp "$ROOT_DIR/docs/assets/$screenshot" "$SCREENSHOTS_DIR/$screenshot"
    chmod 644 "$SCREENSHOTS_DIR/$screenshot"
  fi
done

cat > "$DOWNLOADS_DIR/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>LAN Arcade Downloads</title>
  <style>
    body { margin: 0; font-family: system-ui, sans-serif; background: #07101a; color: #eef4fa; }
    main { max-width: 760px; margin: 0 auto; padding: 2rem 1rem; }
    a { color: #6ee7d0; font-weight: 800; }
    .card { border: 1px solid #213245; border-radius: 8px; background: #101b2b; padding: 1rem; }
    .screens { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 0.75rem; margin-top: 0.75rem; }
    .screens img { width: 100%; border: 1px solid #213245; border-radius: 8px; background: #050b12; }
  </style>
</head>
<body>
  <main>
    <h1>LAN Arcade Downloads</h1>
    <div class="card">
      <h2>Android Companion APK</h2>
      <p><a href="./lan-arcade-companion-debug.apk">Download lan-arcade-companion-debug.apk</a></p>
      <p>Install this on Android phones that will connect to the LAN Arcade server.</p>
    </div>
    <div class="card">
      <h2>Screenshots</h2>
      <div class="screens">
        <a href="./screenshots/companion-catalog.png"><img src="./screenshots/companion-catalog.png" alt="Companion catalog screenshot"></a>
        <a href="./screenshots/companion-trailguard.png"><img src="./screenshots/companion-trailguard.png" alt="Trailguard TD screenshot"></a>
        <a href="./screenshots/companion-unciv-service.png"><img src="./screenshots/companion-unciv-service.png" alt="Unciv LAN Server screenshot"></a>
        <a href="./screenshots/companion-mindustry-service.png"><img src="./screenshots/companion-mindustry-service.png" alt="Mindustry LAN Server screenshot"></a>
      </div>
    </div>
  </main>
</body>
</html>
HTML

echo "Published APK to $DOWNLOADS_DIR/lan-arcade-companion-debug.apk"
