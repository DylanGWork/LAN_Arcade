#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const DEFAULT_REPORT = 'qa/reports/latest/smoke-report.json';

function parseArgs(argv) {
  const options = {
    report: process.env.ARCADE_QA_REPORT || DEFAULT_REPORT,
    outputDir: null,
    filters: process.env.ARCADE_FILTERS_PATH || '/var/www/html/mirrors/games/admin.filters.json',
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    if (arg === '--report' && next) {
      options.report = next;
      i += 1;
    } else if (arg === '--output-dir' && next) {
      options.outputDir = next;
      i += 1;
    } else if (arg === '--filters' && next) {
      options.filters = next;
      i += 1;
    } else if (arg === '--help' || arg === '-h') {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown or incomplete argument: ${arg}`);
    }
  }

  if (!options.outputDir) {
    options.outputDir = path.dirname(options.report);
  }
  return options;
}

function printHelp() {
  console.log(`LAN Arcade QA summary

Usage:
  node qa/qa-summary.mjs --report qa/reports/latest/smoke-report.json

Options:
  --report <path>       Smoke report JSON. Default: ${DEFAULT_REPORT}
  --output-dir <path>   Directory for qa-summary.{json,md,html}. Default: report directory
  --filters <path>      Admin filters JSON for hidden-game context.
`);
}

async function readJson(file, fallback) {
  try {
    return JSON.parse(await fs.readFile(file, 'utf8'));
  } catch {
    return fallback;
  }
}

function actionFor(result) {
  const local = result.localFailures?.length || 0;
  const external = result.externalRequests?.length || 0;
  const errors = result.pageErrors?.length || 0;

  if (result.playabilityStatus === 'blocker') return 'quarantine';
  if (local >= 20) return 'replace-or-deep-repair';
  if (local > 0 && errors > 0) return 'repair-assets-and-runtime';
  if (local > 0) return 'repair-missing-assets';
  if (errors > 0) return 'add-recipe-or-runtime-shim';
  if (external > 0) return 'offline-patch-cdn-tracking';
  return 'keep';
}

function domainFor(value) {
  try {
    return new URL(value).hostname;
  } catch {
    return 'unknown';
  }
}

function shortUrl(value) {
  try {
    const parsed = new URL(value);
    return `${parsed.hostname}${parsed.pathname}`;
  } catch {
    return String(value);
  }
}

function buildSummary(report, filters) {
  const results = Array.isArray(report.results) ? report.results : [];
  const hiddenGames = new Set([
    ...asArray(filters.disabled_games),
  ]);

  const rows = results.map((result) => ({
    id: result.id,
    title: result.title || result.id,
    strict: result.strictStatus,
    playability: result.playabilityStatus,
    action: actionFor(result),
    hiddenByAdmin: hiddenGames.has(result.id),
    localFailures: result.localFailures?.length || 0,
    externalRequests: result.externalRequests?.length || 0,
    pageErrors: result.pageErrors?.length || 0,
    firstLocalFailure: result.localFailures?.[0] ? shortUrl(result.localFailures[0].url) : '',
    firstExternalRequest: result.externalRequests?.[0] ? shortUrl(result.externalRequests[0]) : '',
    firstPageError: result.pageErrors?.[0] ? String(result.pageErrors[0]).slice(0, 140) : '',
    notes: asArray(result.playabilityNotes).join(', '),
  }));

  const actions = countBy(rows, (row) => row.action);
  const playability = countBy(rows, (row) => row.playability);
  const externalDomains = new Map();
  const localFailures = new Map();

  for (const result of results) {
    for (const url of asArray(result.externalRequests)) {
      externalDomains.set(domainFor(url), (externalDomains.get(domainFor(url)) || 0) + 1);
    }
    for (const failure of asArray(result.localFailures)) {
      const key = shortUrl(failure.url);
      localFailures.set(key, (localFailures.get(key) || 0) + 1);
    }
  }

  return {
    generatedAt: new Date().toISOString(),
    sourceReport: report.summary || {},
    adminFilters: {
      disabledGames: asArray(filters.disabled_games),
      disabledCategories: asArray(filters.disabled_categories),
    },
    totals: {
      games: rows.length,
      strictPassed: rows.filter((row) => row.strict === 'pass').length,
      warnings: rows.filter((row) => row.playability === 'warning').length,
      blockers: rows.filter((row) => row.playability === 'blocker').length,
      hiddenByAdmin: rows.filter((row) => row.hiddenByAdmin).length,
    },
    actions,
    playability,
    topExternalDomains: topEntries(externalDomains, 20),
    topLocalFailures: topEntries(localFailures, 20),
    rows: rows.sort((a, b) => actionRank(a.action) - actionRank(b.action)
      || b.localFailures - a.localFailures
      || b.externalRequests - a.externalRequests
      || a.id.localeCompare(b.id)),
  };
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function countBy(rows, getter) {
  const counts = {};
  for (const row of rows) {
    const key = getter(row);
    counts[key] = (counts[key] || 0) + 1;
  }
  return counts;
}

function topEntries(map, limit) {
  return [...map.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, limit)
    .map(([key, count]) => ({ key, count }));
}

function actionRank(action) {
  return [
    'quarantine',
    'replace-or-deep-repair',
    'repair-assets-and-runtime',
    'repair-missing-assets',
    'add-recipe-or-runtime-shim',
    'offline-patch-cdn-tracking',
    'keep',
  ].indexOf(action);
}

function markdown(summary) {
  const lines = [
    '# LAN Arcade QA Summary',
    '',
    `Generated: ${summary.generatedAt}`,
    `Source report generated: ${summary.sourceReport.generatedAt || 'unknown'}`,
    '',
    `Strict passed: ${summary.totals.strictPassed}/${summary.totals.games}`,
    `Warnings: ${summary.totals.warnings}`,
    `Blockers: ${summary.totals.blockers}`,
    `Hidden by admin filters: ${summary.totals.hiddenByAdmin}`,
    '',
    '## Action Buckets',
    '',
    '| Action | Games |',
    '| --- | ---: |',
    ...Object.entries(summary.actions).map(([action, count]) => `| ${action} | ${count} |`),
    '',
    '## Top External Domains',
    '',
    '| Domain | Requests |',
    '| --- | ---: |',
    ...summary.topExternalDomains.map((entry) => `| ${entry.key} | ${entry.count} |`),
    '',
    '## Game Triage',
    '',
    '| Action | Playability | Game | Local | External | Errors | First example |',
    '| --- | --- | --- | ---: | ---: | ---: | --- |',
  ];

  for (const row of summary.rows) {
    const example = row.firstLocalFailure || row.firstExternalRequest || row.firstPageError || row.notes || 'OK';
    lines.push(`| ${row.action} | ${row.playability} | ${row.title} | ${row.localFailures} | ${row.externalRequests} | ${row.pageErrors} | ${escapeMd(example)} |`);
  }

  return `${lines.join('\n')}\n`;
}

function html(summary) {
  const rows = summary.rows.map((row) => `
      <tr>
        <td>${escapeHtml(row.action)}</td>
        <td>${escapeHtml(row.playability)}</td>
        <td>${escapeHtml(row.title)}</td>
        <td>${row.localFailures}</td>
        <td>${row.externalRequests}</td>
        <td>${row.pageErrors}</td>
        <td>${escapeHtml(row.firstLocalFailure || row.firstExternalRequest || row.firstPageError || row.notes || 'OK')}</td>
      </tr>`).join('');

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>LAN Arcade QA Summary</title>
  <style>
    body { font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 24px; color: #172033; background: #f7f8fb; }
    main { max-width: 1180px; margin: 0 auto; }
    h1, h2 { margin: 0 0 12px; }
    .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 12px; margin: 18px 0; }
    .stat { background: #fff; border: 1px solid #d9deea; border-radius: 8px; padding: 14px; }
    .stat strong { display: block; font-size: 1.7rem; }
    table { width: 100%; border-collapse: collapse; background: #fff; border: 1px solid #d9deea; border-radius: 8px; overflow: hidden; }
    th, td { padding: 9px 10px; border-bottom: 1px solid #e8ebf2; text-align: left; vertical-align: top; }
    th { background: #eef2f8; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.04em; }
    td:nth-child(4), td:nth-child(5), td:nth-child(6) { text-align: right; }
  </style>
</head>
<body>
<main>
  <h1>LAN Arcade QA Summary</h1>
  <p>Generated ${escapeHtml(summary.generatedAt)} from smoke report ${escapeHtml(summary.sourceReport.generatedAt || 'unknown')}.</p>
  <section class="stats">
    <div class="stat"><strong>${summary.totals.strictPassed}/${summary.totals.games}</strong> strict passed</div>
    <div class="stat"><strong>${summary.totals.warnings}</strong> warnings</div>
    <div class="stat"><strong>${summary.totals.blockers}</strong> blockers</div>
    <div class="stat"><strong>${summary.totals.hiddenByAdmin}</strong> hidden by admin</div>
  </section>
  <h2>Game Triage</h2>
  <table>
    <thead>
      <tr><th>Action</th><th>Playability</th><th>Game</th><th>Local</th><th>External</th><th>Errors</th><th>First example</th></tr>
    </thead>
    <tbody>${rows}
    </tbody>
  </table>
</main>
</body>
</html>
`;
}

function escapeMd(value) {
  return String(value).replace(/\|/g, '\\|');
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const report = await readJson(options.report, null);
  if (!report) throw new Error(`Could not read smoke report: ${options.report}`);
  const filters = await readJson(options.filters, { disabled_categories: [], disabled_games: [] });
  const summary = buildSummary(report, filters);

  await fs.mkdir(options.outputDir, { recursive: true });
  await fs.writeFile(path.join(options.outputDir, 'qa-summary.json'), `${JSON.stringify(summary, null, 2)}\n`);
  await fs.writeFile(path.join(options.outputDir, 'qa-summary.md'), markdown(summary));
  await fs.writeFile(path.join(options.outputDir, 'qa-summary.html'), html(summary));

  console.log(`QA summary written to ${options.outputDir}`);
  console.log(`Actions: ${Object.entries(summary.actions).map(([key, value]) => `${key}=${value}`).join(', ')}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
