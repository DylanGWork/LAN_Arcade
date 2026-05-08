#!/usr/bin/env bash

set -euo pipefail

MIRRORS_DIR="${1:-${MIRRORS_DIR:-/var/www/html/mirrors}}"
GAME_FILTER="${2:-${LAN_ARCADE_PATCH_GAME:-}}"
DOWNLOAD_EXTERNAL="${LAN_ARCADE_PATCH_DOWNLOAD_EXTERNAL:-1}"
CATALOG_FILE="${LAN_ARCADE_CATALOG_FILE:-$MIRRORS_DIR/games/catalog.json}"
WEB_ROOT="${WEB_ROOT:-/var/www/html}"

if [ ! -d "$MIRRORS_DIR" ]; then
  echo "Mirrors directory not found: $MIRRORS_DIR" >&2
  exit 1
fi

if ! command -v perl >/dev/null 2>&1; then
  echo "WARN offline patcher needs perl; skipping mirror patch pass." >&2
  exit 0
fi

asset_name_for_url() {
  local url="$1"
  local clean base hash

  clean="${url%%\#*}"
  clean="${clean%%\?*}"
  base="${clean##*/}"
  if [ -z "$base" ] || [ "$base" = "$clean" ]; then
    base="asset"
  fi

  base="$(printf '%s' "$base" | tr -c 'A-Za-z0-9._-' '_')"
  if command -v sha1sum >/dev/null 2>&1; then
    hash="$(printf '%s' "$url" | sha1sum | awk '{print substr($1, 1, 10)}')"
  else
    hash="$(printf '%s' "$url" | cksum | awk '{print $1}')"
  fi

  printf '%s-%s' "$hash" "$base"
}

normalize_download_url() {
  local url="$1"
  if [[ "$url" == //* ]]; then
    printf 'https:%s' "$url"
  else
    printf '%s' "$url"
  fi
}

classify_external_ref() {
  local url="$1"
  case "$url" in
    *googletagmanager.com*|*google-analytics.com*|*googlesyndication.com*|*doubleclick.net*|*googletagservices.com*|*cloudflareinsights.com*)
      printf 'shim'
      ;;
    *fonts.googleapis.com*|*fonts.gstatic.com*)
      printf 'blank-css'
      ;;
    *workbox-cdn/releases/*/workbox-sw.js|*yummy.nebez.dev/script.js*)
      printf 'shim'
      ;;
    *st.chatango.com/js/gz/emb.js*|*chatango.com/js/gz/emb.js*)
      printf 'shim'
      ;;
    *code.jquery.com*|*ajax.googleapis.com/ajax/libs/*|*cdnjs.cloudflare.com*|*cdn.jsdelivr.net*|*stackpath.bootstrapcdn.com*|*maxcdn.bootstrapcdn.com*|*hammerjs.github.io/dist/*|*idle-js-games.github.io*)
      printf 'localize'
      ;;
    *)
      printf 'keep'
      ;;
  esac
}

context_for_ref() {
  local html_file="$1"
  local ref="$2"
  local line
  line="$(grep -F -i -m 1 "$ref" "$html_file" || true)"

  case "$line" in
    *"<a"*|*"<A"*) printf 'asset' ;;
    *"<script"*|*"<SCRIPT"*) printf 'script' ;;
    *"<link"*|*"<LINK"*) printf 'css' ;;
    *"<img"*|*"<IMG"*) printf 'image' ;;
    *"<audio"*|*"<AUDIO"*|*"<source"*|*"<SOURCE"*) printf 'media' ;;
    *) printf 'asset' ;;
  esac
}

context_from_tag_attr() {
  local tag="$1"
  local attr="$2"

    if [ "$attr" = "src" ]; then
    case "$tag" in
      script) printf 'script' ;;
      img|image|input) printf 'image' ;;
      audio|video|source) printf 'media' ;;
      iframe) printf 'asset' ;;
      *) printf 'asset' ;;
    esac
    return 0
  fi

  if [ "$tag" = "link" ]; then
    printf 'css'
    return 0
  fi

  printf 'asset'
}

write_common_assets() {
  local assets_dir="$1"
  mkdir -p "$assets_dir"

  cat > "$assets_dir/offline-shims.js" <<'JS'
(function () {
  "use strict";
  var noop = function () {};
  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || noop;
  window.ga = window.ga || noop;
  window.adsbygoogle = window.adsbygoogle || [];
  window.emailjs = window.emailjs || {
    init: noop,
    send: function () { return Promise.resolve({ status: 200, text: "offline shim" }); },
    sendForm: function () { return Promise.resolve({ status: 200, text: "offline shim" }); }
  };
  window.anchors = window.anchors || {
    options: {},
    add: function () { return this; },
    remove: function () { return this; },
    removeAll: function () { return this; }
  };
  if (window.HTMLMediaElement && window.HTMLMediaElement.prototype && window.HTMLMediaElement.prototype.play) {
    var originalPlay = window.HTMLMediaElement.prototype.play;
    window.HTMLMediaElement.prototype.play = function () {
      try {
        var result = originalPlay.apply(this, arguments);
        if (result && result.catch) result.catch(noop);
        return result;
      } catch (error) {
        return Promise.resolve();
      }
    };
  }
})();
JS

  : > "$assets_dir/blank.css"
  printf '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>\n' > "$assets_dir/transparent.svg"
  printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=' | base64 -d > "$assets_dir/transparent.png" 2>/dev/null || true
  printf '{"name":"LAN Arcade offline placeholder","icons":[]}\n' > "$assets_dir/manifest.webmanifest"
}

write_shared_common_assets() {
  write_common_assets "$MIRRORS_DIR/_offline_assets"

  if mkdir -p "$WEB_ROOT/_offline_assets" 2>/dev/null; then
    write_common_assets "$WEB_ROOT/_offline_assets"
  else
    echo "WARN cannot write $WEB_ROOT/_offline_assets; root-relative fallback assets will be skipped."
  fi
}

is_html_document() {
  local html_file="$1"
  grep -Eiq '<!doctype|<html|<head|<body' "$html_file"
}

strip_fragment_shims() {
  local html_file="$1"
  if is_html_document "$html_file"; then
    return 0
  fi

  perl -0pi -e "s#\\s*<script\\b[^>]*\\bsrc=[\"'][^\"']*_offline_assets/offline-shims\\.js(?:\\?[^\"']*)?[\"'][^>]*>\\s*</script>\\s*##ig" "$html_file"
}

relative_asset_path() {
  local from_dir="$1"
  local to_file="$2"
  if command -v realpath >/dev/null 2>&1; then
    realpath --relative-to="$from_dir" "$to_file"
  else
    printf '%s' "$to_file"
  fi
}

replace_ref() {
  local html_file="$1"
  local old_ref="$2"
  local new_ref="$3"
  if [[ "$old_ref" == //* ]]; then
    OLD_REF="$old_ref" NEW_REF="$new_ref" perl -0pi -e 's/(?<!https:)(?<!http:)\Q$ENV{OLD_REF}\E/$ENV{NEW_REF}/g' "$html_file"
  else
    OLD_REF="$old_ref" NEW_REF="$new_ref" perl -0pi -e 's/\Q$ENV{OLD_REF}\E/$ENV{NEW_REF}/g' "$html_file"
  fi
}

decode_mirror_filename_ref() {
  local ref="$1"
  ref="${ref//%3F/?}"
  ref="${ref//%3f/?}"
  ref="${ref//%3D/=}"
  ref="${ref//%3d/=}"
  ref="${ref//%26/&}"
  printf '%s' "$ref"
}

resolve_local_ref() {
  local html_dir="$1"
  local ref="$2"
  if [[ "$ref" == /* ]]; then
    printf '%s/%s' "${WEB_ROOT%/}" "${ref#/}"
  else
    printf '%s/%s' "$html_dir" "$ref"
  fi
}

local_ref_exists() {
  local html_dir="$1"
  local ref="$2"
  local resolved decoded decoded_resolved

  resolved="$(resolve_local_ref "$html_dir" "$ref")"
  [ -e "$resolved" ] && return 0

  decoded="$(decode_mirror_filename_ref "$ref")"
  decoded_resolved="$(resolve_local_ref "$html_dir" "$decoded")"
  [ -e "$decoded_resolved" ] && return 0

  return 1
}

placeholder_for_local_gap() {
  local ref="$1"
  local context="$2"
  local assets_dir="$3"
  local lower

  lower="$(printf '%s' "$ref" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    *showads.js|*cordova.js|*es5-shim.js|*json3.min.js|*keybindings.js)
      printf '%s/offline-shims.js' "$assets_dir"
      ;;
    *apple-touch-icon*|*favicon*|*safari-pinned-tab.svg|*your.png)
      if [[ "$lower" == *.svg ]]; then
        printf '%s/transparent.svg' "$assets_dir"
      else
        printf '%s/transparent.png' "$assets_dir"
      fi
      ;;
    *site.webmanifest|*manifest.json)
      printf '%s/manifest.webmanifest' "$assets_dir"
      ;;
    *bootstrap.min.css|*bootstrap-standart.css)
      printf '%s/blank.css' "$assets_dir"
      ;;
    *)
      if [ "$context" = "image" ] && [[ "$lower" == *.png || "$lower" == *.jpg || "$lower" == *.jpeg || "$lower" == *.gif || "$lower" == *.ico ]]; then
        printf '%s/transparent.png' "$assets_dir"
      fi
      ;;
  esac
}

patch_known_local_gaps() {
  local html_file="$1"
  local assets_dir="$2"
  local html_dir tag attr ref normalized context target rel

  html_dir="$(dirname "$html_file")"

  while IFS='|' read -r tag attr ref; do
    [ -z "$ref" ] && continue
    normalized="${ref%%\#*}"
    [ -z "$normalized" ] && continue

    case "$normalized" in
      data:*|javascript:*|mailto:*|tel:*|http://*|https://*|//*)
        continue
        ;;
    esac

    if [[ "$normalized" =~ ^[A-Za-z][A-Za-z0-9+.-]*: ]]; then
      continue
    fi

    if [ "$attr" != "src" ] && [ "$tag" != "link" ]; then
      continue
    fi

    local_ref_exists "$html_dir" "$normalized" && continue

    context="$(context_for_ref "$html_file" "$ref")"
    target="$(placeholder_for_local_gap "$normalized" "$context" "$assets_dir")"
    [ -z "$target" ] && continue
    [ -e "$target" ] || continue

    rel="$(relative_asset_path "$html_dir" "$target")"
    replace_ref "$html_file" "$ref" "$rel"
  done < <(perl -ne 'while (/<([a-zA-Z0-9]+)\b[^>]*\b(src|href)\s*=\s*["'\'']([^"'\'']+)["'\'']/ig) { print lc($1)."|".lc($2)."|$3\n" }' "$html_file" | LC_ALL=C sort -u)
}

patch_inline_tracking_refs() {
  local html_file="$1"
  local assets_dir="$2"
  local html_dir rel_shim rel_css

  html_dir="$(dirname "$html_file")"
  rel_shim="$(relative_asset_path "$html_dir" "$assets_dir/offline-shims.js")"
  rel_css="$(relative_asset_path "$html_dir" "$assets_dir/blank.css")"

  for ref in \
    "http://www.google-analytics.com/analytics.js" \
    "https://www.google-analytics.com/analytics.js" \
    "//www.google-analytics.com/analytics.js" \
    "http://www.google-analytics.com/ga.js" \
    "https://www.google-analytics.com/ga.js" \
    "//www.google-analytics.com/ga.js" \
    "https://connect.facebook.net/en_US/fbevents.js" \
    "http://platform.twitter.com/widgets.js" \
    "https://platform.twitter.com/widgets.js" \
    "//platform.twitter.com/widgets.js"; do
    replace_ref "$html_file" "$ref" "$rel_shim"
  done

  for ref in \
    "http://orteil.dashnet.org/cookieconsent.css" \
    "https://orteil.dashnet.org/cookieconsent.css" \
    "//orteil.dashnet.org/cookieconsent.css"; do
    replace_ref "$html_file" "$ref" "$rel_css"
  done

  REL_SHIM="$rel_shim" perl -0pi -e 's#ga\.src\s*=\s*\([^;]*google-analytics\.com/ga\.js["'\'']\s*;#ga.src = "$ENV{REL_SHIM}";#g' "$html_file"
}

patch_runtime_tracking_refs() {
  local game_dir="$1"
  local file

  write_common_assets "$game_dir/_offline_assets"
  while IFS= read -r -d '' file; do
    perl -0pi -e 's#(?:https?:)?//www\.google-analytics\.com/(?:analytics|ga)\.js#_offline_assets/offline-shims.js#g; s#ga\.src\s*=\s*\([^;]*google-analytics\.com/ga\.js["'\'']\s*;#ga.src = "_offline_assets/offline-shims.js";#g; s#https://connect\.facebook\.net/en_US/fbevents\.js#_offline_assets/offline-shims.js#g; s#(?:https?:)?//platform\.twitter\.com/widgets\.js#_offline_assets/offline-shims.js#g; s#http://hextris\.io/a\.js#_offline_assets/offline-shims.js#g; s#(?:https?:)?//orteil\.dashnet\.org/cookieconsent\.css#_offline_assets/blank.css#g' "$file"
  done < <(find "$game_dir" -type f -name '*.js*' -print0 2>/dev/null)

  while IFS= read -r -d '' file; do
    perl -0pi -e 's#@import\s+url\(["'\'']?(?:https?:)?//fonts\.googleapis\.com/[^)]*\);\s*##g' "$file"
  done < <(find "$game_dir" -type f -name '*.css' -print0 2>/dev/null)
}

download_if_missing() {
  local target="$1"
  local url="$2"

  [ -s "$target" ] && return 0
  [ "$DOWNLOAD_EXTERNAL" = "1" ] || return 1

  mkdir -p "$(dirname "$target")"
  if wget -q -T 20 -O "$target.tmp" "$url"; then
    mv "$target.tmp" "$target"
    return 0
  fi

  rm -f "$target.tmp"
  return 1
}

repair_solaris_build() {
  local game_dir="$1"
  local workdir

  if [ ! -f "$game_dir/dist/bundle.js" ]; then
    :
  elif ! grep -Fq 'Cannot find module "/tmp/solaris/src/main.js"' "$game_dir/dist/bundle.js" \
    && ! grep -Fq 'fonts.googleapis.com/css?family=Muli' "$game_dir/dist/bundle.js"; then
    return 0
  fi

  if [ "${LAN_ARCADE_SKIP_SOLARIS_BUILD:-0}" = "1" ]; then
    echo "WARN Solaris bundle is broken upstream; skipping source rebuild because LAN_ARCADE_SKIP_SOLARIS_BUILD=1."
    return 0
  fi

  if ! command -v git >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    echo "WARN Solaris bundle is broken upstream; git and npm are needed for a source rebuild."
    return 0
  fi

  workdir="$(mktemp -d)"
  if (
    git clone --depth 1 https://github.com/idle-js-games/solaris.git "$workdir/solaris" >/dev/null 2>&1 &&
    cd "$workdir/solaris" &&
    ln -sf Main.js src/main.js &&
    perl -0pi -e 's/WebFont\.load\(\{.*?active: this\.fontsLoaded\s*\}\)/setTimeout(this.fontsLoaded, 0)/s' src/states/Boot.js &&
    npm install --no-audit --no-fund >/dev/null 2>&1 &&
    ./node_modules/.bin/webpack --config webpack.production.config.js >/dev/null 2>&1
  ); then
    mkdir -p "$game_dir/dist"
    cp "$workdir/solaris/dist/bundle.js" "$workdir/solaris/dist/vendor.bundle.js" "$game_dir/dist/"
    cp -R "$workdir/solaris/resources" "$game_dir/"
  else
    echo "WARN could not rebuild Solaris from source."
  fi
  rm -rf "$workdir"
}

repair_level13_source() {
  local game_dir="$1"
  local workdir

  if [ -f "$game_dir/src/utils/MapElements.js" ] && [ -f "$game_dir/img/map/map-beacon.png" ]; then
    return 0
  fi

  if [ "${LAN_ARCADE_SKIP_LEVEL13_SOURCE:-0}" = "1" ]; then
    echo "WARN Level 13 mirror is missing source assets; skipping source repair because LAN_ARCADE_SKIP_LEVEL13_SOURCE=1."
    return 0
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "WARN Level 13 mirror is missing source assets; git is needed for a source repair."
    return 0
  fi

  workdir="$(mktemp -d)"
  if git clone --depth 1 https://github.com/nroutasuo/level13.git "$workdir/level13" >/dev/null 2>&1; then
    cp -R "$workdir/level13/." "$game_dir/"
    rm -rf "$game_dir/.git"
  else
    echo "WARN could not repair Level 13 from source."
  fi
  rm -rf "$workdir"
}

localize_csgoclicker_images() {
  local game_dir="$1"
  local file url asset target rel base_dir

  mkdir -p "$game_dir/img/offline"
  while IFS= read -r -d '' file; do
    case "$file" in
      *.js|*.js\?*) base_dir="$game_dir" ;;
      *) base_dir="$(dirname "$file")" ;;
    esac

    while IFS= read -r url; do
      [ -z "$url" ] && continue
      asset="$(asset_name_for_url "$url")"
      if [[ "$asset" != *.* ]]; then
        asset="$asset.png"
      fi
      target="$game_dir/img/offline/$asset"
      if ! download_if_missing "$target" "$url" && [ -s "$game_dir/_offline_assets/transparent.png" ]; then
        cp "$game_dir/_offline_assets/transparent.png" "$target"
      fi
      [ -s "$target" ] || continue
      rel="$(relative_asset_path "$base_dir" "$target")"
      replace_ref "$file" "$url" "$rel"
    done < <(perl -ne 'while (m#https?://(?:i\.imgur\.com|steamcommunity-a\.akamaihd\.net)[^"'\''\s)]+#g) { print "$&\n" }' "$file" | LC_ALL=C sort -u)
  done < <(find "$game_dir" -type f \( -name '*.html' -o -name '*.css' -o -name '*.js' -o -name '*.js?*' \) -print0 2>/dev/null)
}

patch_game_specific_assets() {
  local game_dir="$1"
  local game_name

  game_name="$(basename "$game_dir")"
  case "$game_name" in
    balloon-pop-maths)
      while IFS= read -r -d '' file; do
        perl -0pi -e 's#_offline_assets/[^"'"'"']*-7863bec69d\.js#_offline_assets/offline-shims.js#g' "$file"
      done < <(find "$game_dir" -maxdepth 1 -type f \( -name '*.html' -o -name '*.htm' \) -print0 2>/dev/null)
      ;;
    BuildASpaceShip)
      if [ -f "$game_dir/style.css" ]; then
        perl -0pi -e 's#url\(["'"'"']?http://img4\.hostingpics\.net/pics/(?:144421stars|352884twinkling)\.png["'"'"']?\)#url("_offline_assets/transparent.png")#g' "$game_dir/style.css"
      fi
      ;;
    c64clicker)
      mkdir -p "$game_dir/js/thirdparty" "$game_dir/img"
      download_if_missing "$game_dir/js/thirdparty/jquery.min.js" "https://ajax.googleapis.com/ajax/libs/jquery/1.11.1/jquery.min.js" || true
      download_if_missing "$game_dir/js/thirdparty/jquery.powertip.min.js" "https://idle-js-games.github.io/c64clicker/js/thirdparty/jquery.powertip.min.js" || true
      download_if_missing "$game_dir/js/thirdparty/jquery.nodoubletapzoom.js" "https://idle-js-games.github.io/c64clicker/js/thirdparty/jquery.nodoubletapzoom.js" || true
      download_if_missing "$game_dir/rom/game.zip" "https://idle-js-games.github.io/c64clicker/rom/game.zip" || true
      if [ -f "$game_dir/js/main.js" ]; then
        perl -0pi -e "s#jquery:\\s*'//ajax\\.googleapis\\.com/ajax/libs/jquery/1\\.11\\.1/jquery\\.min'#jquery: 'thirdparty/jquery.min'#g; s#'/rom/'#'rom/'#g" "$game_dir/js/main.js"
      fi
      if [ -f "$game_dir/js/c64/main.js" ]; then
        perl -0pi -e "s#'/rom/game\\.zip'#'rom/game.zip'#g" "$game_dir/js/c64/main.js"
      fi
      if ! download_if_missing "$game_dir/img/cclicker.png" "https://idle-js-games.github.io/img/cclicker.png" && [ -s "$game_dir/_offline_assets/transparent.png" ]; then
        cp "$game_dir/_offline_assets/transparent.png" "$game_dir/img/cclicker.png"
      fi
      if [ -f "$game_dir/css/index.css" ]; then
        perl -0pi -e 's#https://idle-js-games\.github\.io/img/cclicker\.png#../img/cclicker.png#g' "$game_dir/css/index.css"
      fi
      ;;
    CSGOClicker)
      write_common_assets "$game_dir/_offline_assets"
      localize_csgoclicker_images "$game_dir"
      if [ -f "$game_dir/js/script.js" ]; then
        perl -0pi -e 's#\s*\+\s*"/240fx182f"##g' "$game_dir/js/script.js"
      fi
      ;;
    citygame-clicker)
      if ! download_if_missing "$game_dir/img/sprites.json" "https://idle-js-games.github.io/citygame-clicker/img/sprites.json"; then
        echo "WARN could not localize dynamic sprite atlas JSON for $game_name"
      fi
      if ! download_if_missing "$game_dir/img/sprites.png" "https://idle-js-games.github.io/citygame-clicker/img/sprites.png"; then
        echo "WARN could not localize dynamic sprite atlas PNG for $game_name"
      fi
      ;;
    crossword-puzzle-maker)
      download_if_missing "$game_dir/_offline_assets/fonts/bootstrap-icons.woff2" "https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/fonts/bootstrap-icons.woff2" || true
      download_if_missing "$game_dir/_offline_assets/fonts/bootstrap-icons.woff" "https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/fonts/bootstrap-icons.woff" || true
      ;;
    dolla_idle_game)
      if [ -f "$game_dir/index.html" ]; then
        replace_ref "$game_dir/index.html" "https://idle-js-games.github.io/dolla_idle_game/local/dummy.js" "_offline_assets/offline-shims.js"
      fi
      ;;
    edukiz)
      if [ -f "$game_dir/service-worker.js" ]; then
        printf '/* LAN Arcade offline: service worker disabled. */\n' > "$game_dir/service-worker.js"
      fi
      ;;
    hextris|particle-clicker)
      download_if_missing "$game_dir/fonts/fontawesome-webfont.woff" "https://cdn.jsdelivr.net/npm/font-awesome@4.7.0/fonts/fontawesome-webfont.woff" || true
      download_if_missing "$game_dir/fonts/fontawesome-webfont.ttf" "https://cdn.jsdelivr.net/npm/font-awesome@4.7.0/fonts/fontawesome-webfont.ttf" || true
      if [ "$game_name" = "hextris" ]; then
        download_if_missing "$game_dir/_offline_assets/fonts/Exo2-Regular.otf" "https://hextris.github.io/hextris/style/fonts/Exo2-Regular.otf" || true
        download_if_missing "$game_dir/_offline_assets/fonts/Exo2-ExtraLight.otf" "https://hextris.github.io/hextris/style/fonts/Exo2-ExtraLight.otf" || true
        download_if_missing "$game_dir/_offline_assets/fonts/Exo2-SemiBold.otf" "https://hextris.github.io/hextris/style/fonts/Exo2-SemiBold.otf" || true
      else
        for asset in CPV unknown Jpsi tau b gluons weak t BBbar H Dstar_s Xi_b; do
          if [ -s "$game_dir/assets/icons/png/$asset.png" ] && [ ! -s "$game_dir/assets/icons/png/$asset@2x.png" ]; then
            cp "$game_dir/assets/icons/png/$asset.png" "$game_dir/assets/icons/png/$asset@2x.png"
          fi
        done
        if [ -f "$game_dir/index.html" ]; then
          replace_ref "$game_dir/index.html" "https://github.com/particle-clicker/particle-clicker/issues" "#"
          replace_ref "$game_dir/index.html" "https://github.com/particle-clicker/particle-clicker/" "#"
          replace_ref "$game_dir/index.html" "https://github.com/particle-clicker/particle-clicker" "#"
        fi
      fi
      ;;
    cookieclicker)
      if [ -f "$game_dir/main.js" ]; then
        perl -0pi -e "s#ajax\\('/patreon/grab\\.php'#ajax('patreon/grab.php'#g" "$game_dir/main.js"
      fi
      mkdir -p "$game_dir/patreon"
      printf '{"herald":0,"grandma":""}\n' > "$game_dir/patreon/grab.php"
      ;;
    fallen-warrior)
      if [ -f "$game_dir/css/main.css" ]; then
        perl -0pi -e 's#url\(["'"'"']?/images/bg\.jpg["'"'"']?\)#url("../images/bg.jpg")#g' "$game_dir/css/main.css"
      fi
      if [ -f "$game_dir/index.html" ]; then
        perl -0pi -e 's#_offline_assets/[^"'"'"']*-emb\.js#_offline_assets/offline-shims.js#g' "$game_dir/index.html"
      fi
      while IFS= read -r -d '' file; do
        perl -0pi -e 's#^(\s*)(myAudio(?:Start)?\.play\(\));#$1try { (function (p) { if (p && p.catch) p.catch(function () {}); })($2); } catch (e) {}#mg' "$file"
      done < <(find "$game_dir/js" -type f -name '*.js' -print0 2>/dev/null)
      ;;
    goomyclicker)
      if [ -f "$game_dir/index.html" ]; then
        replace_ref "$game_dir/index.html" "http://joezeng.github.io/gc2/" "../goomyclicker2/"
      fi
      ;;
    goomyclicker2)
      write_common_assets "$game_dir/_offline_assets"
      mkdir -p "$game_dir/img"
      for asset in daycare.png cave.png trench.png cloninglab.png church.png gcminer.png photoncollider.png; do
        if [ ! -s "$game_dir/img/$asset" ] && [ -s "$game_dir/_offline_assets/transparent.png" ]; then
          cp "$game_dir/_offline_assets/transparent.png" "$game_dir/img/$asset"
        fi
      done
      ;;
    IdleAnt)
      if [ -f "$game_dir/index.html" ]; then
        perl -0pi -e 's#reload\(\)\s*=\s*function\s*\(\)#window.reload = function ()#g' "$game_dir/index.html"
      fi
      ;;
    farm-clicker)
      write_common_assets "$game_dir/_offline_assets"
      if [ -f "$game_dir/index.html" ]; then
        replace_ref "$game_dir/index.html" "https://idle-js-games.github.io/farm-clicker/assets/favicon.ico" "_offline_assets/transparent.png"
      fi
      for asset in Pitchfork.png worker.png horse-head.png tractor.png carrot.png wheat.png corn.png barn.png; do
        download_if_missing "$game_dir/assets/img/$asset" "https://idle-js-games.github.io/farm-clicker/assets/img/$asset" || true
      done
      while IFS= read -r -d '' file; do
        perl -0pi -e 's#(["\x27])\/modules/#$1modules/#g; s#\$http\.get\(/var/www/html/mirrors/farm-clickermodules/#\$http.get(\x27modules/#g; s#\.\./\.\./assets/img/#assets/img/#g' "$file"
      done < <(find "$game_dir/modules" -type f \( -name '*.js' -o -name '*.json' \) -print0 2>/dev/null)
      ;;
    incremancer)
      write_common_assets "$game_dir/_offline_assets"
      if [ -f "$game_dir/index.html" ]; then
        replace_ref "$game_dir/index.html" "https://idle-js-games.github.io/favicon.ico" "_offline_assets/transparent.png"
      fi
      ;;
    koutoftimer-idle-miner)
      download_if_missing "$game_dir/js/app/config/levels.json" "https://idle-js-games.github.io/koutoftimer-idle-miner/js/app/config/levels.json" || true
      ;;
    level13)
      repair_level13_source "$game_dir"
      if [ -f "$game_dir/src/utils/MapElements.js" ]; then
        perl -0pi -e 's#location\.origin\s*\+\s*"/img/map/"\s*\+\s*name\s*\+#"img/map/" + name +#g' "$game_dir/src/utils/MapElements.js"
      fi
      ;;
    racing-clicker)
      write_common_assets "$game_dir/_offline_assets"
      if [ -f "$game_dir/index.html" ]; then
        perl -0pi -e 's#https://idle-js-games\.github\.io/(?:apple-touch-icon-[^"'"'"'?]+|android-chrome-[^"'"'"'?]+|favicon-[^"'"'"'?]+|favicon\.ico)(?:\?[^"'"'"']*)?#_offline_assets/transparent.png#g; s#https://idle-js-games\.github\.io/manifest\.json(?:\?[^"'"'"']*)?#_offline_assets/manifest.webmanifest#g' "$game_dir/index.html"
      fi
      if [ -f "$game_dir/scripts/scripts.c2e39265.js" ]; then
        perl -0pi -e 's/window\.location\.protocol="https"/window.__lanArcadeHttpsRedirectDisabled=true/g' "$game_dir/scripts/scripts.c2e39265.js"
      fi
      ;;
    sandcastle-builder)
      write_common_assets "$game_dir/_offline_assets"
      mkdir -p "$game_dir/img"
      for asset in \
        boost_expando_grey_icon.png \
        boost_chromatic_grey_icon.png \
        boost_sand_grey_icon.png \
        boost_castles_grey_icon.png \
        tool_bucket_dark_icon.png \
        tool_newpixbot_dark_icon.png; do
        if [ ! -s "$game_dir/img/$asset" ] && [ -s "$game_dir/_offline_assets/transparent.png" ]; then
          cp "$game_dir/_offline_assets/transparent.png" "$game_dir/img/$asset"
        fi
      done
      download_if_missing "$game_dir/img/xkcd-frame-1.png" "http://xkcd.mscha.org/frame/1" || true
      if [ -f "$game_dir/style.css?v=1.css" ]; then
        perl -0pi -e 's#url\(["'"'"']?http://code\.jquery\.com/ui/1\.10\.3/themes/smoothness/images/ui-icons_222222_256x240\.png["'"'"']?\)#url("_offline_assets/transparent.png")#g' "$game_dir/style.css?v=1.css"
      fi
      while IFS= read -r -d '' file; do
        perl -0pi -e "s#'http://xkcd\\.mscha\\.org/(?:frame/|tmp/np0\\.png|otcstories/)'?\\s*\\+[^;\\n]+#'img/xkcd-frame-1.png'#g; s#'http://xkcd\\.mscha\\.org/tmp/np0\\.png'#'img/xkcd-frame-1.png'#g" "$file"
      done < <(find "$game_dir" -type f -name '*.js*' -print0 2>/dev/null)
      ;;
    santas-workshop)
      mkdir -p "$game_dir/fonts"
      download_if_missing "$game_dir/fonts/glyphicons-halflings-regular.woff" "https://cdn.jsdelivr.net/npm/bootstrap@3.3.7/dist/fonts/glyphicons-halflings-regular.woff" || true
      download_if_missing "$game_dir/fonts/glyphicons-halflings-regular.ttf" "https://cdn.jsdelivr.net/npm/bootstrap@3.3.7/dist/fonts/glyphicons-halflings-regular.ttf" || true
      if [ -f "$game_dir/cdn/bootstrap3.3.1.min.css" ]; then
        perl -0pi -e 's#https://idle-js-games\.github\.io/santas-workshop/fonts/#../fonts/#g' "$game_dir/cdn/bootstrap3.3.1.min.css"
      fi
      ;;
    second-derivative-clicker)
      if [ -f "$game_dir/main.js" ]; then
        perl -0pi -e "s/loadExternalKnockoutTemplates\\('\\/kot\\/'/loadExternalKnockoutTemplates('kot\\/'/g" "$game_dir/main.js"
      fi
      download_if_missing "$game_dir/font/fontawesome-webfont.woff" "https://cdn.jsdelivr.net/npm/font-awesome@4.7.0/fonts/fontawesome-webfont.woff" || true
      download_if_missing "$game_dir/font/fontawesome-webfont.ttf" "https://cdn.jsdelivr.net/npm/font-awesome@4.7.0/fonts/fontawesome-webfont.ttf" || true
      ;;
    solaris)
      download_if_missing "$game_dir/dist/vendor.bundle.js" "https://raw.githubusercontent.com/idle-js-games/solaris/master/dist/vendor.bundle.js" || echo "WARN could not localize Solaris vendor bundle"
      download_if_missing "$game_dir/dist/bundle.js" "https://raw.githubusercontent.com/idle-js-games/solaris/master/dist/bundle.js" || echo "WARN could not localize Solaris game bundle"
      if [ -f "$game_dir/index.html" ]; then
        replace_ref "$game_dir/index.html" "https://idle-js-games.github.io/solaris/dist/vendor.bundle.js" "dist/vendor.bundle.js"
        replace_ref "$game_dir/index.html" "https://idle-js-games.github.io/solaris/dist/bundle.js" "dist/bundle.js"
      fi
      repair_solaris_build "$game_dir"
      ;;
    sudoku)
      if [ -f "$game_dir/registerSW.js" ]; then
        printf '/* LAN Arcade offline: service worker registration disabled. */\n' > "$game_dir/registerSW.js"
      fi
      while IFS= read -r -d '' file; do
        printf '/* LAN Arcade offline: analytics disabled. */\n' > "$file"
      done < <(find "$game_dir/_offline_assets" -type f -name '*beacon*.js' -print0 2>/dev/null)
      ;;
    technomancy)
      write_common_assets "$game_dir/_offline_assets"
      if [ -f "$game_dir/index.html" ]; then
        replace_ref "$game_dir/index.html" "https://idle-js-games.github.io/Technomancy/Technomancy/favicon.ico" "_offline_assets/transparent.png"
      fi
      ;;
    watercompany)
      if [ -f "$game_dir/js/upgrades.js" ]; then
        perl -0pi -e 's#Error\("Not enough money";\)#Error("Not enough money");#g' "$game_dir/js/upgrades.js"
      fi
      if [ -f "$game_dir/js/save.js" ]; then
        perl -0pi -e 's#if\(!JSON\.parse\(localStorage\.settings\)\)#if (!localStorage.settings || localStorage.settings === "undefined" || !JSON.parse(localStorage.settings))#g' "$game_dir/js/save.js"
      fi
      ;;
  esac
}

inject_shims() {
  local html_file="$1"
  local assets_dir="$2"
  local html_dir rel shim_tag

  if ! is_html_document "$html_file"; then
    return 0
  fi

  if grep -Fq '_offline_assets/offline-shims.js' "$html_file"; then
    return 0
  fi

  html_dir="$(dirname "$html_file")"
  rel="$(relative_asset_path "$html_dir" "$assets_dir/offline-shims.js")"
  shim_tag="<script src=\"$rel\"></script>"
  SHIM_TAG="$shim_tag" perl -0pi -e '
    if (s#</head>#$ENV{SHIM_TAG}\n</head>#i) { next; }
    if (s#</body>#$ENV{SHIM_TAG}\n</body>#i) { next; }
    $_ .= "\n$ENV{SHIM_TAG}\n";
  ' "$html_file"
}

patch_html_file() {
  local game_dir="$1"
  local html_file="$2"
  local assets_dir="$game_dir/_offline_assets"
  local tag attr ref action context target_file rel download_url asset_name

  write_common_assets "$assets_dir"
  strip_fragment_shims "$html_file"
  perl -0pi -e 's#https:(_offline_assets/)#$1#g; s#http:(_offline_assets/)#$1#g' "$html_file"

  while IFS='|' read -r tag attr ref; do
    [ -z "$ref" ] && continue
    context="$(context_from_tag_attr "$tag" "$attr")"
    action="$(classify_external_ref "$ref")"
    if [ "$action" = "keep" ]; then
      case "$context" in
        script|css|image|media)
          action="localize"
          ;;
      esac
    fi
    [ "$action" = "keep" ] && continue

    case "$action" in
      shim)
        target_file="$assets_dir/offline-shims.js"
        ;;
      blank-css)
        if [ "$context" = "script" ]; then
          target_file="$assets_dir/offline-shims.js"
        elif [ "$context" = "image" ]; then
          target_file="$assets_dir/transparent.svg"
        else
          target_file="$assets_dir/blank.css"
        fi
        ;;
      localize)
        asset_name="$(asset_name_for_url "$ref")"
        target_file="$assets_dir/$asset_name"
        if [ ! -s "$target_file" ] && [ "$DOWNLOAD_EXTERNAL" = "1" ]; then
          download_url="$(normalize_download_url "$ref")"
          if wget -q -T 20 -O "$target_file.tmp" "$download_url"; then
            mv "$target_file.tmp" "$target_file"
          else
            rm -f "$target_file.tmp"
            echo "WARN could not localize $ref for $(basename "$game_dir")"
            case "$context" in
              script)
                target_file="$assets_dir/offline-shims.js"
                ;;
              css)
                target_file="$assets_dir/blank.css"
                ;;
              image)
                target_file="$assets_dir/transparent.png"
                ;;
              *)
                continue
                ;;
            esac
          fi
        fi
        [ -s "$target_file" ] || continue
        ;;
      *)
        continue
        ;;
    esac

    rel="$(relative_asset_path "$(dirname "$html_file")" "$target_file")"
    replace_ref "$html_file" "$ref" "$rel"
  done < <(perl -ne 'while (/<([a-zA-Z0-9]+)\b[^>]*\b(src|href)\s*=\s*["'\'']((?:https?:)?\/\/[^"'\'']+)["'\'']/ig) { print lc($1)."|".lc($2)."|$3\n" }' "$html_file" | awk -F'|' '{ print length($3), $0 }' | LC_ALL=C sort -rn | cut -d' ' -f2- | awk '!seen[$0]++')

  patch_inline_tracking_refs "$html_file" "$assets_dir"
  patch_known_local_gaps "$html_file" "$assets_dir"
  inject_shims "$html_file" "$assets_dir"
}

patch_game_dir() {
  local game_dir="$1"
  local html_file count=0

  patch_game_specific_assets "$game_dir"
  patch_runtime_tracking_refs "$game_dir"

  while IFS= read -r -d '' html_file; do
    patch_html_file "$game_dir" "$html_file"
    count=$((count + 1))
  done < <(find "$game_dir" -type f \( -iname '*.html' -o -iname '*.htm' \) -print0)

  if [ "$count" -gt 0 ]; then
    echo "Patched $(basename "$game_dir") for offline browser use ($count HTML file(s))."
  fi
}

list_catalog_game_dirs() {
  if [ -f "$CATALOG_FILE" ] && command -v node >/dev/null 2>&1; then
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
  try {
    const url = new URL(gamePath, baseUrl);
    const relPath = decodeURIComponent(url.pathname)
      .replace(/^\/mirrors\/?/, '')
      .replace(/\/$/, '');
    const dir = path.join(mirrorsDir, relPath);
    if (fs.existsSync(dir) && fs.statSync(dir).isDirectory()) {
      console.log(dir);
    }
  } catch {
    continue;
  }
}
NODE
  else
    find "$MIRRORS_DIR" -mindepth 1 -maxdepth 1 -type d ! -name games -print | LC_ALL=C sort
  fi
}

if [ -n "$GAME_FILTER" ]; then
  write_shared_common_assets

  if [ -d "$MIRRORS_DIR/$GAME_FILTER" ]; then
    patch_game_dir "$MIRRORS_DIR/$GAME_FILTER"
  else
    echo "Game mirror not found: $MIRRORS_DIR/$GAME_FILTER" >&2
    exit 1
  fi
else
  write_shared_common_assets

  while IFS= read -r game_dir; do
    [ -z "$game_dir" ] && continue
    patch_game_dir "$game_dir"
  done < <(list_catalog_game_dirs)
fi
