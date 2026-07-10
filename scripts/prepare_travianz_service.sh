#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/deploy/travianz.compose.yml"
SOURCE_ARCHIVE="${TRAVIANZ_SOURCE_ARCHIVE:-/var/www/html/mirrors/games/downloads/native/travian-like/travianz/travianz-d00826167857.tar.gz}"
SOURCE_COMMIT="${TRAVIANZ_SOURCE_COMMIT:-d00826167857df55dc213d46a61de171397feecc}"
SERVICE_ROOT="${TRAVIANZ_SERVICE_ROOT:-$HOME/.lan-arcade/services/travianz}"
APP_DIR="${TRAVIANZ_APP_DIR:-$SERVICE_ROOT/app}"
DB_DIR="${TRAVIANZ_DB_DIR:-$SERVICE_ROOT/mysql}"
ENV_FILE="${TRAVIANZ_ENV_FILE:-$SERVICE_ROOT/.env}"
HTTP_PORT="${TRAVIANZ_HTTP_PORT:-8092}"
PHPMYADMIN_PORT="${TRAVIANZ_PHPMYADMIN_PORT:-8093}"
ACTION="${1:-prepare}"

compose() {
  TRAVIANZ_APP_DIR="$APP_DIR" \
  TRAVIANZ_DB_DIR="$DB_DIR" \
  TRAVIANZ_HTTP_PORT="$HTTP_PORT" \
  TRAVIANZ_PHPMYADMIN_PORT="$PHPMYADMIN_PORT" \
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

apply_runtime_patches() {
  mkdir -p "$APP_DIR/install/img" "$APP_DIR/gpack/travian_default/lang/en/img"
  for asset in mt-full.js unx.js new.js; do
    if [ -f "$APP_DIR/$asset" ]; then
      cp "$APP_DIR/$asset" "$APP_DIR/install/$asset"
    fi
  done
  if [ -f "$APP_DIR/img/x.gif" ]; then
    cp "$APP_DIR/img/x.gif" "$APP_DIR/install/img/x.gif"
    [ -f "$APP_DIR/gpack/travian_default/lang/en/img/bg.gif" ] || cp "$APP_DIR/img/x.gif" "$APP_DIR/gpack/travian_default/lang/en/img/bg.gif"
  fi
  python3 - "$APP_DIR" <<'PATCH_PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
index = root / 'index.php'
if index.exists():
    s = index.read_text(errors='ignore')
    s = s.replace('src="https://i.creativecommons.org/l/by-nc-sa/3.0/88x31.png"', 'src="img/x.gif"')
    s = s.replace('href="https://creativecommons.org/licenses/by-nc-sa/3.0/"', 'href="agb.php"')
    index.write_text(s)
footer = root / 'Templates/footer.tpl'
if footer.exists():
    s = footer.read_text(errors='ignore')
    marker = "if (!defined('TZ_SERVER_RUNNING_ON')) { define('TZ_SERVER_RUNNING_ON', 'Server running on'); }"
    if marker not in s:
        s = s.replace("<?php\n", "<?php\n" + marker + "\n", 1)
    footer.write_text(s)
login = root / 'login.php'
if login.exists():
    s = login.read_text(errors='ignore')
    if 'name="w"' not in s:
        s = s.replace('<input type="hidden" name="ft" value="a4" />', '<input type="hidden" name="ft" value="a4" />\n<input type="hidden" name="w" value="" />', 1)
    login.write_text(s)
PATCH_PY
}

write_env() {
  mkdir -p "$SERVICE_ROOT"
  if [ -f "$ENV_FILE" ]; then
    return 0
  fi
  command -v openssl >/dev/null 2>&1 || {
    echo "openssl is required to generate TravianZ database credentials." >&2
    exit 1
  }
  local root_password app_password
  root_password="$(openssl rand -hex 32)"
  app_password="$(openssl rand -hex 32)"
  umask 077
  cat > "$ENV_FILE" <<EOF
TRAVIANZ_APP_DIR=$APP_DIR
TRAVIANZ_DB_DIR=$DB_DIR
TRAVIANZ_HTTP_PORT=$HTTP_PORT
TRAVIANZ_PHPMYADMIN_PORT=$PHPMYADMIN_PORT
MARIADB_ROOT_PASSWORD=$root_password
MARIADB_DATABASE=travian
MARIADB_USER=travianz
MARIADB_PASSWORD=$app_password
DB_HOST=db
DB_PORT=3306
EOF
  unset root_password app_password
  chmod 600 "$ENV_FILE"
}


protect_runtime_credentials() {
  local config="$APP_DIR/GameEngine/config.php"
  [ -f "$config" ] || return 0
  chmod 600 "$config"
  if command -v setfacl >/dev/null 2>&1; then
    setfacl -m u:33:r "$config"
  else
    chmod 604 "$config"
  fi
}

prepare_source() {
  [ -f "$SOURCE_ARCHIVE" ] || { echo "Missing TravianZ source archive: $SOURCE_ARCHIVE" >&2; exit 2; }
  mkdir -p "$SERVICE_ROOT" "$DB_DIR"
  if [ ! -f "$APP_DIR/.lan-arcade-source-commit" ] || [ "$(cat "$APP_DIR/.lan-arcade-source-commit" 2>/dev/null || true)" != "$SOURCE_COMMIT" ]; then
    tmp="$SERVICE_ROOT/app.tmp.$$"
    rm -rf "$tmp"
    mkdir -p "$tmp"
    tar -xzf "$SOURCE_ARCHIVE" -C "$tmp" --strip-components=1
    printf '%s
' "$SOURCE_COMMIT" > "$tmp/.lan-arcade-source-commit"
    rm -rf "$APP_DIR"
    mv "$tmp" "$APP_DIR"
  fi
  write_env
  apply_runtime_patches
  chmod -R u+rwX,go+rX "$APP_DIR" 2>/dev/null || true
  chmod -R a+rwX "$APP_DIR/var" "$APP_DIR/GameEngine" "$APP_DIR/install" 2>/dev/null || true
  mkdir -p "$APP_DIR/var/log"
  chmod -R a+rwX "$APP_DIR/var/log" 2>/dev/null || true
  protect_runtime_credentials
  echo "Prepared TravianZ source at $APP_DIR"
  echo "Compose env: $ENV_FILE"
}

case "$ACTION" in
  prepare)
    prepare_source
    compose config >/dev/null
    ;;
  start)
    prepare_source
    compose up -d --build db web
    ;;
  stop)
    write_env
    compose down
    ;;
  status)
    write_env
    compose ps
    ;;
  logs)
    write_env
    compose logs --tail=120 web db
    ;;
  admin-start)
    prepare_source
    compose --profile admin up -d --build db web phpmyadmin
    ;;
  *)
    echo "Usage: $0 [prepare|start|stop|status|logs|admin-start]" >&2
    exit 2
    ;;
esac
