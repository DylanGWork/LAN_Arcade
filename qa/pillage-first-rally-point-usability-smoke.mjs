#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { chromium } from 'playwright';

const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const reportDir = process.env.PILLAGE_FIRST_REPORT_DIR || `qa/reports/pillage-first-rally-point-usability-${stamp}`;
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
  await page.locator('input[name="playerConfiguration.name"]').fill('Rally QA Agent');
  await page.getByRole('button', { name: /^Create world$/ }).click();
  await page.waitForURL(/\/mirrors\/pillage-first\/game\/[^/]+\/[^/]+\/resources\/?$/, { timeout: 30000 });
  await page.getByText(/Woodcutter|Wheat Field|Clay Pit|Iron Mine/).first().waitFor({ timeout: 15000 });
  await page.screenshot({ path: path.join(reportDir, 'screenshots', '01-new-world.png'), fullPage: true });

  const resourceUrl = page.url();
  const match = resourceUrl.match(/\/mirrors\/pillage-first\/game\/([^/]+)\/([^/]+)\/resources\/?$/);
  if (!match) throw new Error(`Could not parse created game URL: ${resourceUrl}`);
  const [, worldSlug, villageSlug] = match;
  const rallyBase = `game/${worldSlug}/${villageSlug}/village/39`;

  await assertRoute(page, `${rallyBase}?tab=farm-list`, '02-farm-list.png', [
    'Farm List',
    'Save repeat raid targets from the map',
    'Create new list',
  ], ['under development']);

  await assertRoute(page, `${rallyBase}?tab=troop-movements`, '03-troop-movements.png', [
    'Troop movements',
    'Active raids, attacks, reinforcements',
  ], ['under development']);

  await assertRoute(page, `${rallyBase}?tab=simulator`, '04-simulator.png', [
    'Simulator',
    'Attack power',
    'Defence power',
    'Estimated result',
  ], ['Lorem ipsum', 'under development']);

  await assertRoute(page, `${rallyBase}?tab=send-troops&rally-point-send-troops-tab=attack-or-raid&x=0&y=0`, '05-send-troops-scouting.png', [
    'Attack briefing',
    'Scout intel',
    'Scouting',
  ], []);

  const unexpectedPageErrors = pageErrors.filter((message) => !message.includes('Minified React error #418'));
  const passed = blocked.length === 0 && failedResponses.length === 0 && consoleErrors.length === 0 && unexpectedPageErrors.length === 0 && findings.every((finding) => finding.passed);
  const report = {
    generatedAt: new Date().toISOString(),
    passed,
    baseUrl,
    findings,
    blocked,
    failedResponses,
    consoleErrors,
    pageErrors,
    unexpectedPageErrors,
  };
  await fs.writeFile(path.join(reportDir, 'result.json'), `${JSON.stringify(report, null, 2)}\n`);
  await fs.writeFile(path.join(reportDir, 'result.md'), renderMarkdown(report));
  if (!passed) {
    console.error(`Pillage First rally point usability smoke failed. Report: ${reportDir}`);
    process.exitCode = 1;
  } else {
    console.log(`Pillage First rally point usability smoke passed. Report: ${reportDir}`);
  }

  async function assertRoute(page, relativeUrl, screenshotName, requiredTerms, forbiddenTerms) {
    const url = new URL(relativeUrl, baseUrl).toString();
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await page.waitForLoadState('networkidle', { timeout: 10000 }).catch(() => {});
    await page.screenshot({ path: path.join(reportDir, 'screenshots', screenshotName), fullPage: true });
    const bodyText = await page.locator('body').innerText();
    const missingTerms = requiredTerms.filter((term) => !bodyText.includes(term));
    const presentForbiddenTerms = forbiddenTerms.filter((term) => bodyText.toLowerCase().includes(term.toLowerCase()));
    findings.push({ url, screenshot: path.join(reportDir, 'screenshots', screenshotName), requiredTerms, missingTerms, forbiddenTerms, presentForbiddenTerms, passed: missingTerms.length === 0 && presentForbiddenTerms.length === 0 });
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
  return `# Pillage First Rally Point Usability Smoke\n\nGenerated: ${report.generatedAt}\nResult: ${report.passed ? 'pass' : 'fail'}\nBase URL: ${report.baseUrl}\n\nFindings:\n\n${report.findings.map((finding) => `- ${finding.passed ? 'PASS' : 'FAIL'} ${finding.url}\n  - missing: ${finding.missingTerms.join(', ') || 'none'}\n  - forbidden present: ${finding.presentForbiddenTerms.join(', ') || 'none'}\n  - screenshot: ${finding.screenshot}`).join('\n')}\n\nBlocked external requests: ${report.blocked.length}\nFailed LAN responses: ${report.failedResponses.length}\nConsole errors: ${report.consoleErrors.length}\nUnexpected page errors: ${report.unexpectedPageErrors.length}\n`;
}
