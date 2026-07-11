#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { chromium } from 'playwright';

const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const reportRoot = process.env.PILLAGE_FIRST_REPORT_DIR || `qa/reports/pillage-first-live-smoke-${stamp}`;
const baseUrls = parseBaseUrls();
const allowedHosts = new Set([
  '127.0.0.1',
  'localhost',
  '192.168.1.106',
  'gannannet.local',
  ...baseUrls.map((baseUrl) => new URL(baseUrl).hostname),
  ...(process.env.PILLAGE_FIRST_ALLOWED_HOSTS || '')
    .split(',')
    .map((host) => host.trim())
    .filter(Boolean),
]);

const summaries = [];
let failed = false;
await fs.mkdir(reportRoot, { recursive: true });

for (const baseUrl of baseUrls) {
  const label = hostLabel(baseUrl);
  const reportDir = path.join(reportRoot, label);
  const report = await runSmoke(baseUrl, reportDir).catch(async (error) => {
    const failure = {
      generatedAt: new Date().toISOString(),
      passed: false,
      baseUrl,
      error: error?.stack || error?.message || String(error),
    };
    await fs.mkdir(reportDir, { recursive: true });
    await fs.writeFile(path.join(reportDir, 'result.json'), `${JSON.stringify(failure, null, 2)}\n`);
    await fs.writeFile(path.join(reportDir, 'result.md'), renderMarkdown(failure));
    return failure;
  });
  summaries.push({ baseUrl, reportDir, passed: report.passed });
  if (!report.passed) failed = true;
}

await fs.writeFile(path.join(reportRoot, 'summary.json'), `${JSON.stringify({ generatedAt: new Date().toISOString(), passed: !failed, reports: summaries }, null, 2)}\n`);

if (failed) {
  console.error(`Pillage First live smoke failed. Report: ${reportRoot}`);
  process.exitCode = 1;
} else {
  console.log(`Pillage First live smoke passed. Report: ${reportRoot}`);
}

async function runSmoke(rawBaseUrl, reportDir) {
  const baseUrl = normalizeBaseUrl(rawBaseUrl);
  let browser;
  const blocked = [];
  const failedResponses = [];
  const consoleErrors = [];
  const pageErrors = [];

  try {
    await fs.mkdir(reportDir, { recursive: true });
    await fs.mkdir(path.join(reportDir, 'screenshots'), { recursive: true });

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
    const gamePath = `${new URL(baseUrl).pathname.replace(/\/$/, '')}/game/`;
    await page.waitForURL((url) => (
      url.pathname.startsWith(gamePath)
      && /\/game\/[^/]+\/[^/]+\/resources\/?$/.test(url.pathname)
    ), { timeout: 30000 });
    await page.getByText(/Woodcutter|Wheat Field|Clay Pit|Iron Mine/).first().waitFor({ timeout: 15000 });
    await page.screenshot({ path: path.join(reportDir, 'screenshots', '03-resources.png'), fullPage: true });

    const bodyText = await page.locator('body').innerText();
    const requiredTerms = ['Woodcutter', 'Wheat Field', 'Clay Pit', 'Iron Mine'];
    const missingTerms = requiredTerms.filter((term) => !bodyText.includes(term));
    const finalUrl = page.url();
    const passed = blocked.length === 0
      && failedResponses.length === 0
      && consoleErrors.length === 0
      && pageErrors.length === 0
      && missingTerms.length === 0
      && new URL(finalUrl).pathname.startsWith(gamePath);

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
      failed: failedResponses,
      consoleErrors,
      pageErrors,
      bodyPreview: bodyText.slice(0, 2000),
    };

    await fs.writeFile(path.join(reportDir, 'result.json'), `${JSON.stringify(report, null, 2)}\n`);
    await fs.writeFile(path.join(reportDir, 'result.md'), renderMarkdown(report));
    return report;
  } finally {
    if (browser) await browser.close().catch(() => {});
  }
}

function parseBaseUrls() {
  const configured = process.env.PILLAGE_FIRST_BASE_URLS
    || process.env.PILLAGE_FIRST_BASE_URL
    || 'http://127.0.0.1/mirrors/pillage-first/,https://192.168.1.106/mirrors/pillage-first/';
  return configured
    .split(',')
    .map((url) => url.trim())
    .filter(Boolean)
    .map((url) => normalizeBaseUrl(url));
}

function normalizeBaseUrl(url) {
  return url.endsWith('/') ? url : `${url}/`;
}

function hostLabel(rawUrl) {
  const url = new URL(rawUrl);
  return url.host.replace(/[^a-zA-Z0-9.-]+/g, '_');
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
Final URL: ${report.finalUrl || 'not reached'}

Screenshots:

${(report.screenshots || []).map((screenshot) => `- ${screenshot}`).join('\n') || '- none'}

Blocked external requests: ${report.blocked?.length || 0}
Failed LAN responses: ${report.failed?.length || 0}
Console errors: ${report.consoleErrors?.length || 0}
Page errors: ${report.pageErrors?.length || 0}
Missing gameplay terms: ${report.missingTerms?.join(', ') || 'none'}
${report.error ? `\nError:\n\n\`\`\`\n${report.error}\n\`\`\`\n` : ''}`;
}
