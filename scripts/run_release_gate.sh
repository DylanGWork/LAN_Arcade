#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

run() {
  printf '\n===== %s =====\n' "$1"
  shift
  "$@"
}

run "Git identity" bash scripts/check_git_identity.sh
run "Tracked secret scan" python3 scripts/check_tracked_secrets.py
run "Deployment profile contract" npm run qa:deployment-profiles
run "Readiness authority" npm run qa:readiness
run "Canonical inventory and nested search" node qa/canonical-registry-ui-smoke.mjs
run "Library discovery" npm run qa:library-discovery
run "Player guides" npm run qa:player-guides
run "Blocked-guide and external-link checks" npm run qa:offline-links
run "Account and save isolation" npm run qa:account-saves
run "Tank Arena live multiplayer" npm run qa:tank:live

run "Tank Arena health" curl --fail --silent --show-error http://127.0.0.1:8787/tank-arena/healthz

if [ -n "${ARCADE_QA_USERNAME:-}" ] && [ -n "${ARCADE_QA_PASSWORD:-}" ]; then
  run "Credentialed family account browser flow" npm run qa:family-accounts
else
  printf '\nSKIP credentialed family browser flow (set ARCADE_QA_USERNAME and ARCADE_QA_PASSWORD to include it).\n'
fi

printf '\nLAN Arcade release gate passed.\n'
