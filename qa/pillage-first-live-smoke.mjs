#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { chromium } from 'playwright';

const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const reportDir = process.env.PILLAGE_FIRST_REPORT_DIR || `qa/reports/pillage-first-live-smoke-${stamp}`;
const baseUrl = normalizeBaseUrl(process.env.PILLAGE_FIRST_BASE_URL || 'http://127.0.0.1/mirrors/pillage-first/');
const allowedHosts = new Set(
  (process.env.PILLAGE_FIRST_ALLOWED_HOSTS || '127.0.0.1,localhost,192.168.1.106,gannannet.local')
    .split(',')
    .map((host) => host.trim())
    .filter(Boolean),
);

let browser;

try {
  await fs.mkdir(reportDir, { recursive: true });
  await fs.mkdir(path.join(reportDir, 'screenshots'), { recursive: true });

  browser = await chromium.launch();
  const context = await browser.newContext({
    ignoreHTTPSErrors: true,
    viewport: { width: 1280, height: 900 },
  });
  const page = await context.newPage();
  const blocked = [];
  const failed = [];
  const consoleErrors = [];
  const pageErrors = [];

  await page.route('**/*', async (route) => {
    const url = route.request().url();
    if (isAllowedUrl(url)) {
      await route.continue();
      return;
    }
    blocked.push({ method: route.request().method(), url });
    await route.abort('blockedbyclient');
  });

  page.on('response', (response) => {
    const status = response.status();
    if (status >= 400 && isAllowedUrl(response.url())) {
      failed.push({ status, url: response.url() });
    }
  });

  page.on('console', (message) => {
    if (message.type() === 'error') {
      consoleErrors.push({ type: message.type(), text: message.text() });
    }
  });

  page.on('pageerror', (error) => {
    pageErrors.push(error.message);
  });

  await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 20000 });
  await page.waitForLoadState('networkidle', { timeout: 10000 }).catch(() => {});
  await page.screenshot({ path: path.join(reportDir, 'screenshots', '01-home.png'), fullPage: true });

  await page.goto(new URL('game-worlds/create/', baseUrl).toString(), {
    waitUntil: 'domcontentloaded',
    timeout: 20000,
  });
  await page.locator('input[name="playerConfiguration.name"]').fill('LAN QA Agent');
  await page.screenshot({ path: path.join(reportDir, 'screenshots', '02-create-world.png'), fullPage: true });

  await page.getByRole('button', { name: /^Create world$/ }).click();
  await page.waitForURL(/\/mirrors\/pillage-first\/game\/[^/]+\/[^/]+\/resources\/?$/, { timeout: 30000 });
  await page.getByText(/Woodcutter|Wheat Field|Clay Pit|Iron Mine/).first().waitFor({ timeout: 15000 });
  await page.screenshot({ path: path.join(reportDir, 'screenshots', '03-resources.png'), fullPage: true });

  const bodyText = await page.locator('body').innerText();
  const requiredTerms = ['Woodcutter', 'Wheat Field', 'Clay Pit', 'Iron Mine'];
  const missingTerms = requiredTerms.filter((term) => !bodyText.includes(term));
  const finalUrl = page.url();
  const passed = blocked.length === 0
    && failed.length === 0
    && consoleErrors.length === 0
    && pageErrors.length === 0
    && missingTerms.length === 0
    && finalUrl.includes('/mirrors/pillage-first/game/');

  const report = {
    generatedAt: new Date().toISOString(),
    passed,
    baseUrl,
    finalUrl,
    requiredTerms,
    missingTerms,
    screenshots: [
      path.join(reportDir, 'screenshots', '01-home.png'),
      path.join(reportDir, 'screenshots', '02-create-world.png'),
      path.join(reportDir, 'screenshots', '03-resources.png'),
    ],
    blocked,
    failed,
    consoleErrors,
    pageErrors,
    bodyPreview: bodyText.slice(0, 2000),
  };

  await fs.writeFile(path.join(reportDir, 'result.json'), `${JSON.stringify(report, null, 2)}\n`);
  await fs.writeFile(path.join(reportDir, 'result.md'), renderMarkdown(report));

  if (!passed) {
    console.error(`Pillage First live smoke failed. Report: ${reportDir}`);
    process.exitCode = 1;
  } else {
    console.log(`Pillage First live smoke passed. Report: ${reportDir}`);
  }
} finally {
  if (browser) await browser.close().catch(() => {});
}

function normalizeBaseUrl(url) {
  return url.endsWith('/') ? url : `${url}/`;
}

function isAllowedUrl(rawUrl) {
  if (rawUrl.startsWith('data:') || rawUrl.startsWith('blob:') || rawUrl.startsWith('about:')) return true;
  let parsed;
  try {
    parsed = new URL(rawUrl);
  } catch {
    return false;
  }
  return ['http:', 'https:'].includes(parsed.protocol) && allowedHosts.has(parsed.hostname);
}

function renderMarkdown(report) {
  return `# Pillage First Live Smoke

Generated: ${report.generatedAt}
Result: ${report.passed ? 'pass' : 'fail'}
Base URL: ${report.baseUrl}
Final URL: ${report.finalUrl}

Screenshots:

${report.screenshots.map((screenshot) => `- ${screenshot}`).join('\n')}

Blocked external requests: ${report.blocked.length}
Failed LAN responses: ${report.failed.length}
Console errors: ${report.consoleErrors.length}
Page errors: ${report.pageErrors.length}
Missing gameplay terms: ${report.missingTerms.join(', ') || 'none'}
`;
}
