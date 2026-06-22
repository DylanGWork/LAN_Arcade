#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { chromium } from 'playwright';

const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const reportDir = process.env.PILLAGE_FIRST_REPORT_DIR || `qa/reports/pillage-first-tile-modal-${stamp}`;
const baseUrl = normalizeBaseUrl(process.env.PILLAGE_FIRST_BASE_URL || 'http://127.0.0.1/mirrors/pillage-first/');
const allowedHosts = new Set(['127.0.0.1', 'localhost', '192.168.1.106', 'gannannet.local', new URL(baseUrl).hostname]);

await fs.mkdir(path.join(reportDir, 'screenshots'), { recursive: true });

const blocked = [];
const failedResponses = [];
const consoleErrors = [];
const pageErrors = [];
let browser;
let modalText = '';
let clickedTile = null;

try {
  browser = await chromium.launch();
  const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1366, height: 900 } });
  const page = await context.newPage();

  await page.route('**/*', async (route) => {
    const url = route.request().url();
    if (isAllowedUrl(url)) return route.continue();
    blocked.push({ method: route.request().method(), url });
    return route.abort('blockedbyclient');
  });

  page.on('response', (response) => {
    if (response.status() >= 400 && isAllowedUrl(response.url())) failedResponses.push({ status: response.status(), url: response.url() });
  });
  page.on('console', (message) => {
    if (message.type() === 'error') consoleErrors.push(message.text());
  });
  page.on('pageerror', (error) => pageErrors.push(error.message));

  await page.goto(new URL('game-worlds/create/', baseUrl).toString(), { waitUntil: 'domcontentloaded', timeout: 20000 });
  await page.locator('input[name="playerConfiguration.name"]').fill('Tile Modal QA');
  await page.getByRole('button', { name: /^Create world$/ }).click();
  await page.waitForURL(/\/mirrors\/pillage-first\/game\/[^/]+\/[^/]+\/resources\/?$/, { timeout: 30000 });
  const resourceUrl = page.url();
  const match = resourceUrl.match(/\/mirrors\/pillage-first\/game\/([^/]+)\/([^/]+)\/resources\/?$/);
  if (!match) throw new Error(`Could not parse created game URL: ${resourceUrl}`);
  const [, worldSlug, villageSlug] = match;

  const mapUrl = new URL(`game/${worldSlug}/${villageSlug}/map`, baseUrl).toString();
  await page.goto(mapUrl, { waitUntil: 'domcontentloaded', timeout: 20000 });
  await page.waitForLoadState('networkidle', { timeout: 10000 }).catch(() => {});
  await page.screenshot({ path: path.join(reportDir, 'screenshots', '01-map.png'), fullPage: true });

  const occupiedTiles = page.locator('button[class*="_occupied-tile_"]');
  const count = await occupiedTiles.count();
  for (let i = 0; i < count; i += 1) {
    const tile = occupiedTiles.nth(i);
    const box = await tile.boundingBox();
    if (!box || box.x < 0 || box.y < 80 || box.x > 1280 || box.y > 820) continue;
    await tile.click({ force: true });
    await page.waitForTimeout(600);
    const bodyText = await page.locator('body').innerText();
    if (bodyText.includes('ReferenceError') || bodyText.includes('useFarmLists is not defined')) {
      throw new Error('Tile modal crashed with useFarmLists ReferenceError');
    }
    if (bodyText.includes('Attack or raid') && (bodyText.includes('Create a farm list') || bodyText.includes('Add to'))) {
      clickedTile = { index: i, box };
      modalText = bodyText.slice(0, 3000);
      await page.screenshot({ path: path.join(reportDir, 'screenshots', '02-tile-modal.png'), fullPage: true });
      break;
    }
    await page.keyboard.press('Escape').catch(() => {});
  }

  const unexpectedPageErrors = pageErrors.filter((message) => !message.includes('Minified React error #418'));
  const unexpectedConsoleErrors = consoleErrors.filter((message) => !message.includes('Failed to load resource'));
  const passed = Boolean(clickedTile)
    && blocked.length === 0
    && failedResponses.length === 0
    && unexpectedConsoleErrors.length === 0
    && unexpectedPageErrors.length === 0;

  const report = {
    generatedAt: new Date().toISOString(),
    passed,
    baseUrl,
    mapUrl,
    clickedTile,
    modalTextPreview: modalText,
    blocked,
    failedResponses,
    consoleErrors,
    unexpectedConsoleErrors,
    pageErrors,
    unexpectedPageErrors,
    screenshots: [
      path.join(reportDir, 'screenshots', '01-map.png'),
      path.join(reportDir, 'screenshots', '02-tile-modal.png'),
    ],
  };
  await fs.writeFile(path.join(reportDir, 'result.json'), `${JSON.stringify(report, null, 2)}\n`);
  await fs.writeFile(path.join(reportDir, 'result.md'), renderMarkdown(report));

  if (!passed) {
    console.error(`Pillage First tile modal smoke failed. Report: ${reportDir}`);
    process.exitCode = 1;
  } else {
    console.log(`Pillage First tile modal smoke passed. Report: ${reportDir}`);
  }
} finally {
  if (browser) await browser.close().catch(() => {});
}

function normalizeBaseUrl(url) {
  return url.endsWith('/') ? url : `${url}/`;
}

function isAllowedUrl(rawUrl) {
  if (rawUrl.startsWith('data:') || rawUrl.startsWith('blob:') || rawUrl.startsWith('about:')) return true;
  try {
    const parsed = new URL(rawUrl);
    return ['http:', 'https:'].includes(parsed.protocol) && allowedHosts.has(parsed.hostname);
  } catch {
    return false;
  }
}

function renderMarkdown(report) {
  return `# Pillage First Tile Modal Smoke\n\nGenerated: ${report.generatedAt}\nResult: ${report.passed ? 'pass' : 'fail'}\nBase URL: ${report.baseUrl}\nMap URL: ${report.mapUrl}\nClicked tile: ${report.clickedTile ? JSON.stringify(report.clickedTile) : 'none'}\n\nScreenshots:\n\n${report.screenshots.map((screenshot) => `- ${screenshot}`).join('\n')}\n\nBlocked external requests: ${report.blocked.length}\nFailed LAN responses: ${report.failedResponses.length}\nUnexpected console errors: ${report.unexpectedConsoleErrors.length}\nUnexpected page errors: ${report.unexpectedPageErrors.length}\n\nModal text preview:\n\n\`\`\`\n${report.modalTextPreview || ''}\n\`\`\`\n`;
}
