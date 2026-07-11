#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { chromium } from 'playwright';

const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const options = parseArgs(process.argv.slice(2));
const reportDir = options.reportDir || `qa/reports/library-discovery-smoke-${stamp}`;

let browser;
const result = {
  generatedAt: new Date().toISOString(),
  baseUrl: options.baseUrl,
  reportDir,
  passed: false,
  checks: [],
  pageErrors: [],
  consoleErrors: [],
  failedResponses: [],
  screenshots: [],
};

try {
  await fs.mkdir(path.join(reportDir, 'screenshots'), { recursive: true });
  browser = await chromium.launch({ headless: !options.headed });
  const context = await browser.newContext({
    ignoreHTTPSErrors: true,
    viewport: { width: 1440, height: 1000 },
  });
  const page = await context.newPage();

  page.on('pageerror', (error) => result.pageErrors.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error') result.consoleErrors.push(message.text());
  });
  page.on('response', (response) => {
    if (response.status() >= 400 && isLocalUrl(response.url(), options.baseUrl)) {
      result.failedResponses.push({ status: response.status(), url: response.url() });
    }
  });

  await page.goto(options.baseUrl, { waitUntil: 'networkidle', timeout: 30000 });
  await page.evaluate(() => {
    localStorage.removeItem('lanArcadeRecentlyPlayed.v1');
    localStorage.removeItem('lanArcadeFavorites.v1');
  });

  const bodyText = await page.locator('body').innerText();
  addCheck(result, 'no top-level card wording', !bodyText.includes('top-level cards'));
  addCheck(result, 'no Native / services wording', !bodyText.includes('Native / services'));
  addCheck(result, 'recent shelf initially hidden', await page.locator('#recentShelf').evaluate((el) => el.hidden));
  addCheck(result, 'player library has no operator tools link', !bodyText.includes('Operator Tools'));
  addCheck(result, 'player library has no family admin jargon', !bodyText.includes('family/admin'));

  await page.fill('#searchInput', options.query);
  await page.waitForTimeout(1000);
  await screenshot(page, result, '01-search-results');

  const cards = await page.locator('.game-card, .featured-card').evaluateAll((nodes) => nodes.map((node) => ({
    title: node.querySelector('.card-title')?.textContent?.trim() || '',
    href: node.href || node.querySelector('.card-link')?.href || '',
    launch: node.querySelector('.launch')?.textContent?.trim() || '',
    chips: Array.from(node.querySelectorAll('.detail-chip')).map((chip) => chip.textContent?.trim() || ''),
  })));
  const simant = cards.find((card) => card.title === 'SimAnt');
  addCheck(result, 'SimAnt search result appears', Boolean(simant));
  addCheck(result, 'SimAnt result is direct play link', Boolean(simant && simant.href.includes('/mirrors/private-dos-vault/play.html?id=simant-ma')));
  addCheck(result, 'SimAnt action is truthful Try', Boolean(simant && simant.launch === 'Try'));
  addCheck(result, 'SimAnt is not falsely promoted', Boolean(simant && simant.chips && simant.chips.includes('Needs play testing')));

  const simantCard = page.locator('.game-card, .featured-card').filter({ hasText: 'SimAnt' }).first();
  await simantCard.locator('.favorite-button').click();
  const favoriteStorageAfterSave = await page.evaluate(() => JSON.parse(localStorage.getItem('lanArcadeFavorites.v1') || '[]').map((item) => ({ title: item.title, path: item.path })));
  await page.fill('#searchInput', '');
  await page.waitForTimeout(800);
  const favoriteHidden = await page.locator('#favoriteShelf').evaluate((el) => el.hidden);
  const favoriteTitles = await page.locator('#favoriteGrid .card-title').evaluateAll((nodes) => nodes.map((node) => node.textContent?.trim() || ''));
  addCheck(result, 'favorite shelf appears after save', !favoriteHidden);
  addCheck(result, 'favorite shelf contains SimAnt', favoriteTitles.includes('SimAnt'));
  addCheck(result, 'favorite localStorage records SimAnt', favoriteStorageAfterSave.some((item) => item.title === 'SimAnt' && String(item.path || '').includes('simant-ma')));

  await page.fill('#searchInput', options.query);
  await page.waitForTimeout(500);
  await page.locator('#gameGrid .game-card').filter({ hasText: 'SimAnt' }).first().locator('.card-link').click();
  await page.waitForLoadState('domcontentloaded', { timeout: 30000 }).catch(() => {});
  await page.goto(options.baseUrl, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(800);
  await screenshot(page, result, '02-recently-played');

  const recentHidden = await page.locator('#recentShelf').evaluate((el) => el.hidden);
  const recentTitles = await page.locator('#recentGrid .card-title').evaluateAll((nodes) => nodes.map((node) => node.textContent?.trim() || ''));
  const recentStorage = await page.evaluate(() => JSON.parse(localStorage.getItem('lanArcadeRecentlyPlayed.v1') || '[]').map((item) => ({ title: item.title, path: item.path })));
  const recentLayout = await page.locator('#recentGrid .game-card').evaluateAll((nodes) => nodes.map((node) => {
    const media = node.querySelector('.media');
    const hiddenSelectors = ['.desc', '.tags', '.detail-chips'];
    return {
      cardWidth: node.getBoundingClientRect().width,
      mediaWidth: media ? media.getBoundingClientRect().width : 0,
      compactDetailsHidden: hiddenSelectors.every((selector) => {
        const child = node.querySelector(selector);
        return !child || getComputedStyle(child).display === 'none';
      }),
    };
  }));
  addCheck(result, 'recent shelf appears after launch', !recentHidden);
  addCheck(result, 'recent shelf contains SimAnt', recentTitles.includes('SimAnt'));
  addCheck(result, 'recent localStorage records SimAnt', recentStorage.some((item) => item.title === 'SimAnt' && String(item.path || '').includes('simant-ma')));
  addCheck(result, 'recent shelf contains at most four cards', recentTitles.length <= 4, recentTitles);
  addCheck(result, 'recent cards hide long details', recentLayout.every((item) => item.compactDetailsHidden), recentLayout);
  addCheck(result, 'recent media stays inside its card', recentLayout.every((item) => item.mediaWidth <= item.cardWidth + 1), recentLayout);

  addCheck(result, 'no page errors', result.pageErrors.length === 0, result.pageErrors);
  addCheck(result, 'no local HTTP failures', result.failedResponses.length === 0, result.failedResponses);
  result.searchCards = cards.slice(0, 12);
  result.recentTitles = recentTitles;
  result.recentStorage = recentStorage;
  result.favoriteTitles = typeof favoriteTitles === 'undefined' ? [] : favoriteTitles;
  result.favoriteStorage = typeof favoriteStorageAfterSave === 'undefined' ? [] : favoriteStorageAfterSave;
  result.passed = result.checks.every((check) => check.passed);
} catch (error) {
  result.error = error?.stack || error?.message || String(error);
  result.passed = false;
} finally {
  if (browser) await browser.close();
  await fs.mkdir(reportDir, { recursive: true });
  await fs.writeFile(path.join(reportDir, 'result.json'), `${JSON.stringify(result, null, 2)}\n`);
  await fs.writeFile(path.join(reportDir, 'result.md'), renderMarkdown(result));
}

if (!result.passed) {
  console.error(`Library discovery smoke failed. Report: ${reportDir}`);
  process.exitCode = 1;
} else {
  console.log(`Library discovery smoke passed. Report: ${reportDir}`);
}

function parseArgs(argv) {
  const parsed = {
    baseUrl: process.env.ARCADE_LIBRARY_URL || 'http://127.0.0.1/mirrors/games/',
    reportDir: process.env.ARCADE_QA_REPORT_DIR || '',
    query: process.env.ARCADE_DISCOVERY_QUERY || 'simant',
    headed: process.env.ARCADE_QA_HEADED === '1',
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    if (arg === '--base-url' && next) { parsed.baseUrl = next; i += 1; }
    else if (arg === '--report-dir' && next) { parsed.reportDir = next; i += 1; }
    else if (arg === '--query' && next) { parsed.query = next; i += 1; }
    else if (arg === '--headed') parsed.headed = true;
  }
  if (!parsed.baseUrl.endsWith('/')) parsed.baseUrl += '/';
  return parsed;
}

function addCheck(report, name, passed, details = null) {
  report.checks.push({ name, passed: Boolean(passed), details });
}

async function screenshot(page, report, name) {
  const file = path.join(report.reportDir, 'screenshots', `${name}.png`);
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
  return `# Library Discovery Smoke\n\nGenerated: ${report.generatedAt}\n\nBase URL: ${report.baseUrl}\n\nResult: ${report.passed ? 'PASS' : 'FAIL'}\n\n| Status | Check | Details |\n| --- | --- | --- |\n${rows}\n\nScreenshots:\n\n${report.screenshots.map((shot) => `- ${shot}`).join('\n')}\n`;
}

function escapePipe(value) {
  return String(value).replace(/\|/g, '\\|');
}
