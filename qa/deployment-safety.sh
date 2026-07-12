#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT/scripts/assert_safe_deploy_target.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
  echo "DEPLOYMENT_SAFETY_FAIL: $*" >&2
  exit 1
}

[ -x "$GUARD" ] || fail "missing deployment guard"

"$GUARD" "$TMP_ROOT/child" "$TMP_ROOT" >/dev/null

if "$GUARD" "$TMP_ROOT" "$TMP_ROOT" >/dev/null 2>&1; then
  fail "guard accepted the deployment root itself"
fi

if "$GUARD" "$TMP_ROOT/../escape" "$TMP_ROOT" >/dev/null 2>&1; then
  fail "guard accepted a path outside the deployment root"
fi

if findmnt -rn -T /var/www/html/mirrors/games/downloads/native >/dev/null 2>&1; then
  if "$GUARD" /var/www/html/mirrors/games /var/www/html/mirrors >/dev/null 2>&1; then
    fail "guard accepted a target containing the native-download NFS mount"
  fi
fi

if grep -n 'rsync -a --delete' "$ROOT/setup_lan_arcade.sh" "$ROOT/scripts/deploy_local_game_hubs.sh"; then
  fail "destructive rsync remains in public deployment entrypoints"
fi

if grep -n 'chown -R' "$ROOT/setup_lan_arcade.sh"; then
  fail "recursive chown remains in the installer"
fi

echo "DEPLOYMENT_SAFETY_PASS"
