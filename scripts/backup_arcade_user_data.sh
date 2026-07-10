#!/usr/bin/env bash
set -euo pipefail
umask 077

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
  elif command -v python3 >/dev/null 2>&1; then
    python3 - "$DB" "$OUT/lan-arcade.sqlite" <<'PY'
import sqlite3
import sys

source_path, output_path = sys.argv[1:3]
source = sqlite3.connect(f"file:{source_path}?mode=ro", uri=True)
output = sqlite3.connect(output_path)
source.backup(output)
output.commit()
output.execute("pragma wal_checkpoint(truncate)")
output.execute("pragma journal_mode=delete")
source.close()
output.close()
PY
    echo "db_backup=python_sqlite_online_backup" >> "$MANIFEST"
  else
    echo "db_backup=failed_no_online_backup_tool" >> "$MANIFEST"
    echo "Neither sqlite3 nor python3 is available for a transaction-consistent backup." >&2
    exit 1
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$OUT/lan-arcade.sqlite" "$OUT/lan-arcade-db-verification.txt" <<'PY'
import sqlite3
import sys

database_path, report_path = sys.argv[1:3]
database = sqlite3.connect(f"file:{database_path}?mode=ro&immutable=1", uri=True)
quick_check = database.execute("pragma quick_check").fetchone()[0]
tables = [
    row[0]
    for row in database.execute(
        "select name from sqlite_master "
        "where type='table' and name not like 'sqlite_%' order by name"
    )
]
with open(report_path, "w", encoding="utf-8") as report:
    report.write(f"quick_check={quick_check}\n")
    report.write(f"table_count={len(tables)}\n")
    for table in tables:
        escaped = table.replace('"', '""')
        count = database.execute(f'select count(*) from "{escaped}"').fetchone()[0]
        report.write(f"{table}={count}\n")
database.close()
if quick_check != "ok":
    raise SystemExit("SQLite backup verification failed")
PY
    echo "db_verification=python_quick_check_and_counts" >> "$MANIFEST"
  elif [ "$(sqlite3 "$OUT/lan-arcade.sqlite" "pragma quick_check;")" = "ok" ]; then
    echo "db_verification=sqlite3_quick_check" >> "$MANIFEST"
  else
    echo "db_verification=failed" >> "$MANIFEST"
    exit 1
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
