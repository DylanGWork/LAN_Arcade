#!/usr/bin/env bash
set -euo pipefail

target="${1:-}"
root="${2:-}"

fail() {
  echo "DEPLOY_TARGET_REFUSED: $*" >&2
  exit 1
}

[ -n "$target" ] || fail "target is empty"
[ -n "$root" ] || fail "allowed root is empty"
command -v realpath >/dev/null 2>&1 || fail "realpath is required"

target_real="$(realpath -m -- "$target")"
root_real="$(realpath -m -- "$root")"

[ "$root_real" != "/" ] || fail "filesystem root cannot be an allowed root"
[ "$target_real" != "$root_real" ] || fail "target cannot equal its allowed root"
case "$target_real" in
  "$root_real"/*) ;;
  *) fail "target escaped allowed root: $target_real" ;;
esac

if command -v findmnt >/dev/null 2>&1; then
  while IFS= read -r mount_target; do
    [ -n "$mount_target" ] || continue
    mount_real="$(realpath -m -- "$mount_target")"
    case "$mount_real" in
      "$target_real"|"$target_real"/*)
        fail "target is or contains a mount point: $mount_real"
        ;;
    esac
  done < <(findmnt -rn -o TARGET)
fi

printf 'DEPLOY_TARGET_SAFE target=%s root=%s\n' "$target_real" "$root_real"
