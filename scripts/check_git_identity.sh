#!/usr/bin/env bash
set -euo pipefail

name="$(git config --get user.name || true)"
email="$(git config --get user.email || true)"

approved_names='DylanGWork LAN Arcade Agent|DylanGWork|Codex'
approved_emails='dylan.gannan@pestsense.com|dylan@users.noreply.github.com|codex@openai.local'
blocked_emails='dylan@GannanNet.GannanNet'

if [ -z "$name" ] || [ -z "$email" ]; then
  echo "Git identity is incomplete. Set git config user.name and user.email before committing." >&2
  exit 1
fi

case "$email" in
  $blocked_emails)
    echo "Blocked Git author email: $email" >&2
    echo "Use: git config user.email dylan.gannan@pestsense.com" >&2
    exit 1
    ;;
esac

if ! printf '%s\n' "$approved_names" | tr '|' '\n' | grep -Fx -- "$name" >/dev/null; then
  echo "Unapproved Git author name: $name" >&2
  echo "Approved names: $approved_names" >&2
  exit 1
fi

if ! printf '%s\n' "$approved_emails" | tr '|' '\n' | grep -Fx -- "$email" >/dev/null; then
  echo "Unapproved Git author email: $email" >&2
  echo "Approved emails: $approved_emails" >&2
  exit 1
fi

if [ "$email" = "dylan@users.noreply.github.com" ]; then
  echo "Warning: $email is approved only for legacy compatibility. Prefer dylan.gannan@pestsense.com." >&2
fi

echo "Git identity OK: $name <$email>"
