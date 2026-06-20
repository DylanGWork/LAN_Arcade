#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { chromium } from 'playwright';

const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const reportDir = process.env.PILLAGE_FIRST_REPORT_DIR || `qa/reports/pillage-first-attack-briefing-${stamp}`;
const baseUrl = normalizeBaseUrl(process.env.PILLAGE_FIRST_BASE_URL || 'http://127.0.0.1/mirrors/pillage-first/');
const allowedHosts = new Set([
  '127.0.0.1',
  'localhost',
  '192.168.1.106',
  'gannannet.local',
  new URL(baseUrl).hostname,
]);

await fs.mkdir(path.join(reportDir, 'screenshots'), { recursive: true });

const blocked = [];
const failedResponses = [];
const consoleErrors = [];
const pageErrors = [];
let browser;

try {
  browser = await chromium.launch();
  const context = await browser.newContext({
    ignoreHTTPSErrors: true,
    viewport: { width: 1280, height: 900 },
  });
  const page = await context.newPage();

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
      failedResponses.push({ status, url: response.url() });
    }
  });
  page.on('console', (message) => {
    if (message.type() === 'error') consoleErrors.push(message.text());
  });
  page.on('pageerror', (error) => pageErrors.push(error.message));

  await page.goto(new URL('game-worlds/create/', baseUrl).toString(), {
    waitUntil: 'domcontentloaded',
    timeout: 20000,
  });
  await page.locator('input[name="playerConfiguration.name"]').fill('Attack Briefing QA');
  await page.getByRole('button', { name: /^Create world$/ }).click();
  await page.waitForURL(/\/mirrors\/pillage-first\/game\/[^/]+\/[^/]+\/resources\/?$/, { timeout: 30000 });
  await page.getByText(/Woodcutter|Wheat Field|Clay Pit|Iron Mine/).first().waitFor({ timeout: 15000 });
  await page.screenshot({ path: path.join(reportDir, 'screenshots', '01-new-world.png'), fullPage: true });

  const resourceUrl = page.url();
  const match = resourceUrl.match(/\/mirrors\/pillage-first\/game\/([^/]+)\/([^/]+)\/resources\/?$/);
  if (!match) throw new Error(`Could not parse created game URL: ${resourceUrl}`);
  const [, worldSlug, villageSlug] = match;
  const attackUrl = new URL(`game/${worldSlug}/${villageSlug}/village/39?tab=send-troops&rally-point-send-troops-tab=attack-or-raid&x=0&y=0`, baseUrl).toString();

  await page.goto(attackUrl, { waitUntil: 'domcontentloaded', timeout: 20000 });
  await page.getByText('Attack briefing').waitFor({ timeout: 15000 });
  await page.getByText('Selected troops').waitFor({ timeout: 15000 });
  await page.getByText(/Select at least one troop before confirming\.|Detected defenders|No defenders detected|Choose a target/).first().waitFor({ timeout: 15000 });
  await page.screenshot({ path: path.join(reportDir, 'screenshots', '02-attack-briefing.png'), fullPage: true });

  const bodyText = await page.locator('body').innerText();
  const requiredTerms = ['Attack or raid', 'Attack briefing', 'Selected troops', 'Scout intel'];
  const missingTerms = requiredTerms.filter((term) => !bodyText.includes(term));
  const knownHydrationWarnings = pageErrors.filter((message) =>
    message.includes('Minified React error #418')
  );
  const unexpectedPageErrors = pageErrors.filter((message) =>
    !message.includes('Minified React error #418')
  );
  const passed = blocked.length === 0
    && failedResponses.length === 0
    && consoleErrors.length === 0
    && unexpectedPageErrors.length === 0
    && missingTerms.length === 0;

  const report = {
    generatedAt: new Date().toISOString(),
    passed,
    baseUrl,
    attackUrl,
    requiredTerms,
    missingTerms,
    blocked,
    failedResponses,
    consoleErrors,
    pageErrors,
    knownHydrationWarnings,
    unexpectedPageErrors,
    screenshots: [
      path.join(reportDir, 'screenshots', '01-new-world.png'),
      path.join(reportDir, 'screenshots', '02-attack-briefing.png'),
    ],
    bodyPreview: bodyText.slice(0, 2200),
  };
  await fs.writeFile(path.join(reportDir, 'result.json'), `${JSON.stringify(report, null, 2)}\n`);
  await fs.writeFile(path.join(reportDir, 'result.md'), renderMarkdown(report));

  if (!passed) {
    console.error(`Pillage First attack briefing smoke failed. Report: ${reportDir}`);
    process.exitCode = 1;
  } else {
    console.log(`Pillage First attack briefing smoke passed. Report: ${reportDir}`);
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
  return `# Pillage First Attack Briefing Smoke\n\nGenerated: ${report.generatedAt}\nResult: ${report.passed ? 'pass' : 'fail'}\nBase URL: ${report.baseUrl}\nAttack URL: ${report.attackUrl}\n\nScreenshots:\n\n${report.screenshots.map((screenshot) => `- ${screenshot}`).join('\n')}\n\nBlocked external requests: ${report.blocked.length}\nFailed LAN responses: ${report.failedResponses.length}\nConsole errors: ${report.consoleErrors.length}\nPage errors: ${report.pageErrors.length}\nKnown route hydration warnings: ${report.knownHydrationWarnings?.length || 0}\nUnexpected page errors: ${report.unexpectedPageErrors?.length || 0}\nMissing gameplay terms: ${report.missingTerms.join(', ') || 'none'}\n`;
}
