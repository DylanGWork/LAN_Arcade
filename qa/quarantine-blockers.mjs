#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const DEFAULT_REPORT = 'qa/reports/latest/smoke-report.json';
const DEFAULT_FILTERS = '/var/www/html/mirrors/games/admin.filters.json';

function parseArgs(argv) {
  const options = {
    reportFile: DEFAULT_REPORT,
    filtersFile: process.env.ARCADE_FILTERS_FILE || DEFAULT_FILTERS,
    dryRun: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    if (arg === '--report' && next) {
      options.reportFile = next;
      i += 1;
    } else if (arg === '--filters' && next) {
      options.filtersFile = next;
      i += 1;
    } else if (arg === '--dry-run') {
      options.dryRun = true;
    } else if (arg === '--help' || arg === '-h') {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown or incomplete argument: ${arg}`);
    }
  }

  return options;
}

function printHelp() {
  console.log(`Quarantine blocker games from a LAN Arcade smoke report

Usage:
  node qa/quarantine-blockers.mjs [options]

Options:
  --report <path>    Smoke report JSON. Default: ${DEFAULT_REPORT}
  --filters <path>   Admin filters JSON. Default: ${DEFAULT_FILTERS}
  --dry-run          Print planned changes without writing
`);
}

async function readJsonOrFallback(filePath, fallback) {
  try {
    return JSON.parse(await fs.readFile(filePath, 'utf8'));
  } catch {
    return fallback;
  }
}

function stringArray(value) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => String(item).trim()).filter(Boolean);
}

function uniqueSorted(values) {
  return [...new Set(values)].sort((a, b) => a.localeCompare(b));
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const report = await readJsonOrFallback(options.reportFile, null);
  if (!report || !Array.isArray(report.results)) {
    throw new Error(`Could not read smoke results from ${options.reportFile}`);
  }

  const filters = await readJsonOrFallback(options.filtersFile, {
    disabled_categories: [],
    disabled_games: [],
  });

  const blockers = report.results
    .filter((result) => result.playabilityStatus === 'blocker')
    .map((result) => String(result.id || '').trim())
    .filter(Boolean);

  const nextFilters = {
    disabled_categories: uniqueSorted(stringArray(filters.disabled_categories)),
    disabled_games: uniqueSorted([...stringArray(filters.disabled_games), ...blockers]),
  };

  const existingDisabled = new Set(stringArray(filters.disabled_games));
  const newlyDisabled = blockers.filter((id) => !existingDisabled.has(id));

  console.log(`Blockers in report: ${blockers.length}`);
  console.log(`New games to disable: ${newlyDisabled.length}`);
  if (newlyDisabled.length > 0) {
    console.log(newlyDisabled.map((id) => `  - ${id}`).join('\n'));
  }

  if (options.dryRun) {
    return;
  }

  await fs.mkdir(path.dirname(options.filtersFile), { recursive: true });
  await fs.writeFile(options.filtersFile, `${JSON.stringify(nextFilters, null, 2)}\n`);
  console.log(`Updated ${options.filtersFile}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
