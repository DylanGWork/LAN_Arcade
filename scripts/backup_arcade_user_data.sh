#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="${LAN_ARCADE_BACKUP_ROOT:-/home/dylan/backups/lan-arcade/user-data}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$BACKUP_ROOT/$STAMP"
DB="${LAN_ARCADE_DB_PATH:-/var/lib/lan-arcade/lan-arcade.sqlite}"
USER_DATA="${LAN_ARCADE_USER_DATA_DIR:-/srv/lan-arcade/user-data}"
MANIFEST="$OUT/MANIFEST.txt"

mkdir -p "$OUT"
{
  echo "LAN Arcade user data backup"
  echo "created_utc=$STAMP"
  echo "db=$DB"
  echo "user_data=$USER_DATA"
  echo
} > "$MANIFEST"

if [ -r "$DB" ]; then
  if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 "$DB" ".backup $OUT/lan-arcade.sqlite"
    echo "db_backup=sqlite3_backup" >> "$MANIFEST"
  else
    cp -a "$DB" "$OUT/lan-arcade.sqlite"
    echo "db_backup=plain_copy_sqlite3_missing" >> "$MANIFEST"
  fi
else
  echo "db_backup=skipped_not_readable_or_missing" >> "$MANIFEST"
fi

if [ -d "$USER_DATA" ] && [ -r "$USER_DATA" ]; then
  tar -C "$USER_DATA" -czf "$OUT/user-data.tgz" .
  echo "user_data_backup=tar_gzip" >> "$MANIFEST"
else
  echo "user_data_backup=skipped_not_present_or_not_readable" >> "$MANIFEST"
fi

{
  echo
  echo "sizes:"
  du -sh "$OUT" 2>/dev/null || true
  echo
  echo "checksums:"
  find "$OUT" -maxdepth 1 -type f ! -name MANIFEST.txt -print0 | sort -z | xargs -0r sha256sum
} >> "$MANIFEST"

echo "$OUT"
