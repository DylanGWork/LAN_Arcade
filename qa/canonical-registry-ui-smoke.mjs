#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { chromium } from 'playwright';

const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const options = parseArgs(process.argv.slice(2));
const reportDir = options.reportDir || `qa/reports/canonical-registry-browser-${stamp}`;
const result = {
  generatedAt: new Date().toISOString(),
  baseUrl: options.baseUrl,
  reportDir,
  passed: false,
  checks: [],
  pageErrors: [],
  failedResponses: [],
  externalRequests: [],
  screenshots: [],
};

let browser;
try {
  await fs.mkdir(path.join(reportDir, 'screenshots'), { recursive: true });
  browser = await chromium.launch({ headless: !options.headed });
  const context = await browser.newContext({
    ignoreHTTPSErrors: true,
    viewport: { width: 1440, height: 1000 },
  });
  const allowedHosts = new Set([
    new URL(options.baseUrl).hostname,
    '127.0.0.1',
    'localhost',
    '192.168.1.106',
    'gannannet.local',
  ]);
  await context.route('**/*', async (route) => {
    const url = route.request().url();
    try {
      const parsed = new URL(url);
      if (['http:', 'https:'].includes(parsed.protocol) && !allowedHosts.has(parsed.hostname)) {
        result.externalRequests.push(url);
        await route.abort('blockedbyclient');
        return;
      }
    } catch {}
    await route.continue();
  });

  const page = await context.newPage();
  page.on('pageerror', (error) => result.pageErrors.push(error.message));
  page.on('response', (response) => {
    if (response.status() >= 400 && isLocalUrl(response.url(), options.baseUrl)) {
      result.failedResponses.push({ status: response.status(), url: response.url() });
    }
  });

  const response = await page.goto(options.baseUrl, { waitUntil: 'networkidle', timeout: 45000 });
  addCheck(result, 'library returns HTTP 200', response?.status() === 200, response?.status());
  await page.waitForFunction(() => document.querySelectorAll('#status .stat-pill').length >= 5, null, { timeout: 30000 });

  const registry = await page.evaluate(async () => {
    const response = await fetch('./canonical-registry.json', { cache: 'no-store' });
    return { status: response.status, body: await response.json() };
  });
  result.registryMetrics = registry.body.metrics;
  addCheck(result, 'canonical registry returns HTTP 200', registry.status === 200, registry.status);
  addCheck(result, 'canonical title count is 1106', registry.body.metrics.distinctCanonicalTitles === 1106, registry.body.metrics);
  addCheck(result, 'curated GB rows are memberships', registry.body.metrics.curatedGameBoyMemberships === 201, registry.body.metrics);

  const statusPills = await page.locator('#status .stat-pill').evaluateAll((nodes) => nodes.map((node) => node.textContent?.trim() || ''));
  result.statusPills = statusPills;
  addCheck(result, 'complete inventory is the leading count', statusPills[0] === '1106 titles across every shelf', statusPills);
  addCheck(result, 'local file count is explicit', statusPills[1] === '879 with local files', statusPills);
  addCheck(result, 'launch candidates do not claim readiness', statusPills[2] === '790 launch paths to try', statusPills);
  addCheck(result, 'meaningful action evidence is separate', statusPills[3] === '2 with recorded game actions', statusPills);
  addCheck(result, 'launch cards are a secondary metric', statusPills[4] === '153 library cards', statusPills);
  addCheck(result, 'status makes no ready-to-play total claim', !statusPills.some((text) => text.includes('ready to play')), statusPills);

  const bodyText = await page.locator('body').innerText();
  addCheck(result, 'page does not claim 153 games', !bodyText.includes('153 games'));
  addCheck(result, 'page does not claim unique games', !bodyText.toLowerCase().includes('unique games'));
  addCheck(result, 'curated subset is not a status total', !statusPills.some((text) => text.includes('curated Game Boy')));

  const initialCards = await page.locator('#gameGrid .game-card').count();
  addCheck(result, 'large collections remain nested', initialCards <= 153, initialCards);
  await screenshot(page, result, '01-library-inventory');

  const simant = await searchFor(page, 'simant', 'SimAnt');
  result.simantResult = simant;
  addCheck(result, 'SimAnt nested result appears', Boolean(simant), simant);
  addCheck(
    result,
    'SimAnt has a direct Classic PC launcher',
    Boolean(simant?.href.includes('/mirrors/private-dos-vault/play.html?id=simant-ma')),
    simant,
  );
  addCheck(result, 'SimAnt action is Play', simant?.action === 'Play', simant);
  await screenshot(page, result, '02-search-simant');
  if (simant) {
    const launch = await page.goto(simant.href, { waitUntil: 'domcontentloaded', timeout: 45000 });
    addCheck(result, 'SimAnt direct launcher loads', launch?.status() === 200, { status: launch?.status(), url: page.url() });
  }

  await page.goto(options.baseUrl, { waitUntil: 'networkidle', timeout: 45000 });
  const gameBoy = await searchFor(page, 'adventures of lolo', 'Adventures of Lolo');
  result.gameBoyResult = gameBoy;
  addCheck(result, 'Game Boy nested result appears', Boolean(gameBoy), gameBoy);
  addCheck(
    result,
    'Game Boy result has one direct vault launcher',
    Boolean(gameBoy?.href.includes('/mirrors/private-rom-vault/play.html?id=adventures-of-lolo')),
    gameBoy,
  );
  addCheck(result, 'Game Boy action is Play', gameBoy?.action === 'Play', gameBoy);
  await screenshot(page, result, '03-search-game-boy');
  if (gameBoy) {
    const launch = await page.goto(gameBoy.href, { waitUntil: 'domcontentloaded', timeout: 45000 });
    addCheck(result, 'Game Boy direct launcher loads', launch?.status() === 200, { status: launch?.status(), url: page.url() });
  }

  addCheck(result, 'no browser page errors', result.pageErrors.length === 0, result.pageErrors);
  addCheck(result, 'no local HTTP failures', result.failedResponses.length === 0, result.failedResponses);
  addCheck(result, 'no external requests', result.externalRequests.length === 0, result.externalRequests);
  result.passed = result.checks.every((check) => check.passed);
} catch (error) {
  result.error = error?.stack || error?.message || String(error);
  result.passed = false;
} finally {
  if (browser) await browser.close();
  await fs.mkdir(reportDir, { recursive: true });
  await fs.writeFile(path.join(reportDir, 'canonical-registry-result.json'), `${JSON.stringify(result, null, 2)}\n`);
  await fs.writeFile(path.join(reportDir, 'canonical-registry-result.md'), renderMarkdown(result));
}

if (!result.passed) {
  console.error(`Canonical registry UI smoke failed. Report: ${reportDir}`);
  process.exitCode = 1;
} else {
  console.log(`Canonical registry UI smoke passed. Report: ${reportDir}`);
}

async function searchFor(page, query, expectedTitle) {
  await page.fill('#searchInput', query);
  await page.waitForFunction(
    (title) => [...document.querySelectorAll('#gameGrid .card-title')].some((node) => node.textContent?.trim() === title),
    expectedTitle,
    { timeout: 15000 },
  );
  return page.locator('#gameGrid .game-card').evaluateAll((cards, title) => {
    const card = cards.find((node) => node.querySelector('.card-title')?.textContent?.trim() === title);
    if (!card) return null;
    return {
      title,
      href: card.querySelector('.card-link')?.href || '',
      action: card.querySelector('.launch')?.textContent?.trim() || '',
    };
  }, expectedTitle);
}

function parseArgs(argv) {
  const parsed = {
    baseUrl: process.env.ARCADE_LIBRARY_URL || 'http://192.168.1.106/mirrors/games/',
    reportDir: process.env.ARCADE_QA_REPORT_DIR || '',
    headed: process.env.ARCADE_QA_HEADED === '1',
  };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    const next = argv[index + 1];
    if (arg === '--base-url' && next) { parsed.baseUrl = next; index += 1; }
    else if (arg === '--report-dir' && next) { parsed.reportDir = next; index += 1; }
    else if (arg === '--headed') parsed.headed = true;
  }
  if (!parsed.baseUrl.endsWith('/')) parsed.baseUrl += '/';
  return parsed;
}

function addCheck(report, name, passed, details = null) {
  report.checks.push({ name, passed: Boolean(passed), details });
}

async function screenshot(page, report, name) {
  const file = path.join(report.reportDir, 'screenshots', `canonical-registry-${name}.png`);
  await page.screenshot({ path: file, fullPage: true });
  report.screenshots.push(file);
}

function isLocalUrl(rawUrl, baseUrl) {
  try {
    const url = new URL(rawUrl);
    const base = new URL(baseUrl);
    return url.hostname === base.hostname || ['127.0.0.1', 'localhost', '192.168.1.106', 'gannannet.local'].includes(url.hostname);
  } catch {
    return false;
  }
}

function renderMarkdown(report) {
  const rows = report.checks.map((check) => `| ${check.passed ? 'pass' : 'fail'} | ${check.name} | ${check.details ? escapePipe(JSON.stringify(check.details)) : ''} |`).join('\n');
  return `# Canonical Registry UI Smoke\n\nGenerated: ${report.generatedAt}\n\nBase URL: ${report.baseUrl}\n\nResult: ${report.passed ? 'PASS' : 'FAIL'}\n\n| Status | Check | Details |\n| --- | --- | --- |\n${rows}\n`;
}

function escapePipe(value) {
  return String(value).replace(/\|/g, '\\|');
}
