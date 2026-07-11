#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const DEFAULT_READINESS = "/var/www/html/mirrors/games/readiness.json";
const DEFAULT_FILTERS = "/var/www/html/mirrors/games/admin.filters.json";

function parseArgs(argv) {
  const options = {
    readinessFile: process.env.ARCADE_READINESS_FILE || DEFAULT_READINESS,
    filtersFile: process.env.ARCADE_FILTERS_FILE || DEFAULT_FILTERS,
    dryRun: false
  };
  for (let i = 0; i < argv.length; i += 1) {
    const next = argv[i + 1];
    if (argv[i] === "--readiness" && next) { options.readinessFile = next; i += 1; }
    else if (argv[i] === "--filters" && next) { options.filtersFile = next; i += 1; }
    else if (argv[i] === "--dry-run") options.dryRun = true;
    else throw new Error("Unknown or incomplete argument: " + argv[i]);
  }
  return options;
}

async function readJson(file, fallback) {
  try {
    return JSON.parse(await fs.readFile(file, "utf8"));
  } catch (error) {
    if (fallback !== undefined) return fallback;
    throw new Error("Could not read " + file + ": " + error.message);
  }
}

function strings(value) {
  return Array.isArray(value) ? value.map(String).map(function (item) { return item.trim(); }).filter(Boolean) : [];
}

function sorted(values) {
  return [...new Set(values)].sort(function (a, b) { return a.localeCompare(b); });
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const readiness = await readJson(options.readinessFile);
  if (!readiness.entries || typeof readiness.entries !== "object") {
    throw new Error("Readiness authority has no entries object: " + options.readinessFile);
  }
  const blockers = Object.values(readiness.entries)
    .filter(function (entry) { return entry && entry.promotionState === "quarantined"; })
    .map(function (entry) { return String(entry.entryId || "").trim(); })
    .filter(Boolean);
  const filters = await readJson(options.filtersFile, { disabled_categories: [], disabled_games: [] });
  const existing = new Set(strings(filters.disabled_games));
  const newlyDisabled = blockers.filter(function (id) { return !existing.has(id); });
  const next = {
    disabled_categories: sorted(strings(filters.disabled_categories)),
    disabled_games: sorted([...existing, ...blockers])
  };
  console.log("Current readiness blockers: " + blockers.length);
  console.log("New games to hide: " + newlyDisabled.length);
  newlyDisabled.forEach(function (id) { console.log("  - " + id); });
  if (options.dryRun) return;
  await fs.mkdir(path.dirname(options.filtersFile), { recursive: true });
  const temp = options.filtersFile + ".tmp-" + process.pid;
  await fs.writeFile(temp, JSON.stringify(next, null, 2) + "\n");
  await fs.rename(temp, options.filtersFile);
  console.log("Updated " + options.filtersFile);
}

main().catch(function (error) {
  console.error(error.stack || error.message);
  process.exit(1);
});
