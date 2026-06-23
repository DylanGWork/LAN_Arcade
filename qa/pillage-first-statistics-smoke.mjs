#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { chromium } from 'playwright';

const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const reportDir = process.env.PILLAGE_FIRST_REPORT_DIR || `qa/reports/pillage-first-statistics-${stamp}`;
const baseUrl = normalizeBaseUrl(process.env.PILLAGE_FIRST_BASE_URL || 'http://127.0.0.1/mirrors/pillage-first/');
const allowedHosts = new Set(['127.0.0.1', 'localhost', '192.168.1.106', 'gannannet.local', new URL(baseUrl).hostname]);

await fs.mkdir(path.join(reportDir, 'screenshots'), { recursive: true });

const blocked = [];
const failedResponses = [];
const consoleErrors = [];
const pageErrors = [];
const findings = [];
let browser;

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
  await page.locator('input[name="playerConfiguration.name"]').fill('Statistics QA Agent');
  await page.getByRole('button', { name: /^Create world$/ }).click();
  await page.waitForURL(/\/mirrors\/pillage-first\/game\/[^/]+\/[^/]+\/resources\/?$/, { timeout: 30000 });
  await page.getByText(/Woodcutter|Wheat Field|Clay Pit|Iron Mine/).first().waitFor({ timeout: 15000 });

  const resourceUrl = page.url();
  const match = resourceUrl.match(/\/mirrors\/pillage-first\/game\/([^/]+)\/([^/]+)\/resources\/?$/);
  if (!match) throw new Error(`Could not parse created game URL: ${resourceUrl}`);
  const [, worldSlug, villageSlug] = match;
  const statsUrl = new URL(`game/${worldSlug}/${villageSlug}/statistics?tab=my-stats`, baseUrl).toString();

  await page.goto(statsUrl, { waitUntil: 'domcontentloaded', timeout: 20000 });
  await page.waitForLoadState('networkidle', { timeout: 10000 }).catch(() => {});
  await page.screenshot({ path: path.join(reportDir, 'screenshots', '01-my-stats.png'), fullPage: true });
  const bodyText = await page.locator('body').innerText();

  const requiredTerms = [
    'My stats',
    'Total loot',
    'Enemies killed',
    'Troops lost',
    'Troops trained',
    'Minimum accounted troops',
    'Kills by enemy type',
    'Troop accounting',
  ];
  const forbiddenTerms = ['ReferenceError', 'Application Error', 'invalid_union'];
  const missingTerms = requiredTerms.filter((term) => !bodyText.includes(term));
  const presentForbiddenTerms = forbiddenTerms.filter((term) => bodyText.includes(term));
  findings.push({ url: statsUrl, requiredTerms, missingTerms, forbiddenTerms, presentForbiddenTerms, passed: missingTerms.length === 0 && presentForbiddenTerms.length === 0 });

  const unexpectedPageErrors = pageErrors.filter((message) => !message.includes('Minified React error #418'));
  const unexpectedConsoleErrors = consoleErrors.filter((message) => !message.includes('Failed to load resource'));
  const passed = blocked.length === 0 && failedResponses.length === 0 && unexpectedConsoleErrors.length === 0 && unexpectedPageErrors.length === 0 && findings.every((finding) => finding.passed);
  const report = {
    generatedAt: new Date().toISOString(),
    passed,
    baseUrl,
    findings,
    blocked,
    failedResponses,
    consoleErrors,
    unexpectedConsoleErrors,
    pageErrors,
    unexpectedPageErrors,
    screenshots: [path.join(reportDir, 'screenshots', '01-my-stats.png')],
  };
  await fs.writeFile(path.join(reportDir, 'result.json'), `${JSON.stringify(report, null, 2)}\n`);
  await fs.writeFile(path.join(reportDir, 'result.md'), renderMarkdown(report));

  if (!passed) {
    console.error(`Pillage First statistics smoke failed. Report: ${reportDir}`);
    process.exitCode = 1;
  } else {
    console.log(`Pillage First statistics smoke passed. Report: ${reportDir}`);
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
  return `# Pillage First Statistics Smoke\n\nGenerated: ${report.generatedAt}\nResult: ${report.passed ? 'pass' : 'fail'}\nBase URL: ${report.baseUrl}\n\nFindings:\n\n${report.findings.map((finding) => `- ${finding.passed ? 'PASS' : 'FAIL'} ${finding.url}\n  - missing: ${finding.missingTerms.join(', ') || 'none'}\n  - forbidden present: ${finding.presentForbiddenTerms.join(', ') || 'none'}`).join('\n')}\n\nScreenshots:\n\n${report.screenshots.map((screenshot) => `- ${screenshot}`).join('\n')}\n\nBlocked external requests: ${report.blocked.length}\nFailed LAN responses: ${report.failedResponses.length}\nUnexpected console errors: ${report.unexpectedConsoleErrors.length}\nUnexpected page errors: ${report.unexpectedPageErrors.length}\n`;
}
