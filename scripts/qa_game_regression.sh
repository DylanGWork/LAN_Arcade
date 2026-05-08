#!/usr/bin/env bash

set -euo pipefail

GAME_ID="${1:-}"
REPORT_ROOT="${REPORT_ROOT:-qa/reports/game-regression}"

if [ -z "$GAME_ID" ]; then
  echo "Usage: bash scripts/qa_game_regression.sh <game-id>" >&2
  exit 2
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
desktop_dir="$REPORT_ROOT/$GAME_ID-$timestamp-desktop"
mobile_dir="$REPORT_ROOT/$GAME_ID-$timestamp-mobile"

echo "===== Static mirror audit ====="
npm run qa:static

echo "===== Desktop smoke: $GAME_ID ====="
npm run qa:smoke -- --catalog --game "$GAME_ID" --screenshot-all --report-dir "$desktop_dir"
npm run qa:summary -- --report "$desktop_dir/smoke-report.json" --output-dir "$desktop_dir"

echo "===== Mobile smoke: $GAME_ID ====="
npm run qa:smoke -- --catalog --mobile --game "$GAME_ID" --screenshot-all --report-dir "$mobile_dir"
npm run qa:summary -- --report "$mobile_dir/smoke-report.json" --output-dir "$mobile_dir"

node - "$GAME_ID" "$desktop_dir/smoke-report.json" "$mobile_dir/smoke-report.json" <<'NODE'
const fs = require('node:fs');

const [, , gameId, ...reports] = process.argv;
let failed = false;

for (const reportPath of reports) {
  const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  const summary = report.summary || {};
  const label = `${summary.profile || 'unknown'} ${reportPath}`;

  if (summary.total < 1) {
    console.error(`FAIL ${label}: no matching games found for ${gameId}`);
    failed = true;
    continue;
  }
  if (summary.failed !== 0 || summary.warnings !== 0 || summary.blockers !== 0) {
    console.error(`FAIL ${label}: failed=${summary.failed}, warnings=${summary.warnings}, blockers=${summary.blockers}`);
    failed = true;
  } else {
    console.log(`OK ${label}: ${summary.passed}/${summary.total} strict, ${summary.playable} playable`);
  }
}

if (failed) process.exit(1);
NODE

echo "Reports:"
echo "  $desktop_dir"
echo "  $mobile_dir"
