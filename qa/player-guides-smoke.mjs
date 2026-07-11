#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { chromium } from 'playwright';

const baseUrl = process.env.ARCADE_GUIDES_URL || 'http://192.168.1.106/mirrors/games/wiki/';
const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const reportDir = process.env.ARCADE_QA_REPORT_DIR || `qa/reports/player-guides-${stamp}`;
const result = { generatedAt: new Date().toISOString(), baseUrl, passed: false, checks: [], pageErrors: [], externalRequests: [] };
let browser;

try {
  await fs.mkdir(reportDir, { recursive: true });
  browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1280, height: 900 } });
  const allowed = new Set([new URL(baseUrl).hostname, '127.0.0.1', 'localhost', '192.168.1.106', 'gannannet.local']);
  await context.route('**/*', async (route) => {
    try {
      const url = new URL(route.request().url());
      if (['http:', 'https:'].includes(url.protocol) && !allowed.has(url.hostname)) {
        result.externalRequests.push(url.href);
        await route.abort('blockedbyclient');
        return;
      }
    } catch {}
    await route.continue();
  });

  const page = await context.newPage();
  page.on('pageerror', (error) => result.pageErrors.push(error.message));
  const response = await page.goto(baseUrl, { waitUntil: 'networkidle', timeout: 45000 });
  check('guides return HTTP 200', response?.status() === 200, response?.status());
  check('player title is visible', await page.getByRole('heading', { name: 'Guides & Manuals', exact: true }).isVisible());
  check('how-to panels are visible', await page.locator('.guide').count() === 6, await page.locator('.guide').count());
  check('available cards render', await page.locator('.game-card').count() > 0, await page.locator('.game-card').count());

  const body = (await page.locator('body').innerText()).toLowerCase();
  for (const forbidden of ['admin controls', 'core files', 'update flow', 'qa flow', 'show admin-hidden', 'service:', 'health check:']) {
    check('player page omits ' + forbidden, !body.includes(forbidden));
  }

  await page.fill('#searchInput', 'tank');
  await page.waitForTimeout(250);
  check('guide search narrows results', await page.locator('.game-card').count() > 0);
  check('no browser page errors', result.pageErrors.length === 0, result.pageErrors);
  check('no external requests', result.externalRequests.length === 0, result.externalRequests);
  await page.screenshot({ path: path.join(reportDir, 'guides.png'), fullPage: true });
  result.passed = result.checks.every((item) => item.passed);
} catch (error) {
  result.error = error?.stack || error?.message || String(error);
} finally {
  if (browser) await browser.close();
  await fs.mkdir(reportDir, { recursive: true });
  await fs.writeFile(path.join(reportDir, 'result.json'), JSON.stringify(result, null, 2) + '\n');
}

if (!result.passed) {
  console.error('Player guides smoke failed: ' + reportDir);
  process.exitCode = 1;
} else {
  console.log('Player guides smoke passed: ' + reportDir);
}

function check(name, passed, details = null) {
  result.checks.push({ name, passed: Boolean(passed), details });
}
