#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { chromium } from 'playwright';

const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const reportRoot = process.env.TRAVIANZ_REPORT_DIR || `qa/reports/travianz-smoke-${stamp}`;
const baseUrl = normalizeBaseUrl(process.env.TRAVIANZ_BASE_URL || 'http://127.0.0.1:8092/');
const publicBaseUrl = normalizeBaseUrl(process.env.TRAVIANZ_PUBLIC_BASE_URL || 'http://192.168.1.106:8092/');
const appDir = process.env.TRAVIANZ_APP_DIR || `${process.env.HOME}/.lan-arcade/services/travianz/app`;
const installedMarker = path.join(appDir, 'var', 'installed');
const allowedHosts = new Set(['127.0.0.1', 'localhost', '192.168.1.106', 'gannannet.local', new URL(baseUrl).hostname, new URL(publicBaseUrl).hostname]);

await fs.mkdir(path.join(reportRoot, 'screenshots'), { recursive: true });
const report = {
  generatedAt: new Date().toISOString(),
  baseUrl,
  publicBaseUrl,
  passed: false,
  phase: 'start',
  screenshots: [],
  blocked: [],
  failedResponses: [],
  consoleErrors: [],
  pageErrors: [],
};

let browser;
try {
  browser = await chromium.launch();
  const context = await browser.newContext({ viewport: { width: 1366, height: 900 } });
  const page = await context.newPage();
  await page.route('**/*', async (route) => {
    const url = route.request().url();
    if (isAllowedUrl(url)) return route.continue();
    report.blocked.push({ method: route.request().method(), url });
    return route.abort('blockedbyclient');
  });
  page.on('response', (response) => {
    if (response.status() >= 400 && isAllowedUrl(response.url())) {
      report.failedResponses.push({ status: response.status(), url: response.url() });
    }
  });
  page.on('console', (message) => {
    if (message.type() === 'error') report.consoleErrors.push(message.text());
  });
  page.on('pageerror', (error) => report.pageErrors.push(error.message));

  await ensureInstalled(page);
  await smokeGameShell(page);

  report.passed = report.blocked.length === 0 && report.pageErrors.length === 0 && report.failedResponses.filter((r) => !/favicon\.ico$/.test(r.url)).length === 0;
  report.phase = report.passed ? 'passed' : 'failed-after-game-shell';
} catch (error) {
  report.error = error?.stack || error?.message || String(error);
  report.passed = false;
} finally {
  if (browser) await browser.close().catch(() => {});
  await fs.writeFile(path.join(reportRoot, 'result.json'), `${JSON.stringify(report, null, 2)}\n`);
  await fs.writeFile(path.join(reportRoot, 'result.md'), renderMarkdown(report));
  console.log(`TravianZ smoke ${report.passed ? 'passed' : 'failed'}: ${reportRoot}`);
  if (!report.passed) process.exitCode = 1;
}

async function ensureInstalled(page) {
  if (await exists(installedMarker)) {
    report.phase = 'already-installed';
    return;
  }

  report.phase = 'install-intro';
  await page.goto(new URL('install/', baseUrl).toString(), { waitUntil: 'domcontentloaded', timeout: 30000 });
  await settle(page);
  await shot(page, '01-install-intro.png');
  await page.locator('a[href="?s=1"]').click();

  report.phase = 'install-config';
  await page.waitForSelector('form#dataform input[name="servername"]', { timeout: 20000 });
  await page.selectOption('select[name="wmax"]', '10');
  await fillIfPresent(page, 'input[name="servername"]', 'GannanNet TravianZ');
  await fillIfPresent(page, 'input[name="speed"]', '5');
  await fillIfPresent(page, 'input[name="incspeed"]', '5');
  await fillIfPresent(page, 'input[name="sserver"]', 'db');
  await fillIfPresent(page, 'input[name="sport"]', '3306');
  await fillIfPresent(page, 'input[name="suser"]', 'travianz');
  await fillIfPresent(page, 'input[name="spass"]', 'travianzpass');
  await fillIfPresent(page, 'input[name="sdb"]', 'travian');
  await fillIfPresent(page, 'input[name="prefix"]', 's1_');
  await fillIfPresent(page, 'input[name="server"]', publicBaseUrl);
  await fillIfPresent(page, 'input[name="domain"]', publicBaseUrl);
  await fillIfPresent(page, 'input[name="homepage"]', publicBaseUrl);
  await shot(page, '02-install-config.png');
  await Promise.all([
    page.waitForURL(/install\/index\.php\?s=2/, { timeout: 45000 }),
    page.locator('form#dataform').evaluate((form) => form.submit()),
  ]);

  report.phase = 'install-structure';
  await shot(page, '03-install-structure.png');
  await Promise.all([
    page.waitForURL(/install\/index\.php\?s=3/, { timeout: 120000 }),
    page.locator('form#dataform').evaluate((form) => form.submit()),
  ]);

  report.phase = 'install-world-data';
  await shot(page, '04-install-world.png');
  await Promise.all([
    page.waitForURL(/install\/index\.php\?s=3&startCroppers=1|install\/index\.php\?s=4/, { timeout: 180000 }),
    page.locator('form#dataform').evaluate((form) => form.submit()),
  ]);
  if (!/s=4/.test(page.url())) {
    await page.waitForURL(/install\/index\.php\?s=4/, { timeout: 180000 }).catch(() => {});
  }

  report.phase = 'install-accounts';
  await page.goto(new URL('install/index.php?s=4', baseUrl).toString(), { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForSelector('input[name="mhpw"]', { timeout: 30000 });
  await fillIfPresent(page, 'input[name="mhpw"]', 'lanarcade-pass');
  await fillIfPresent(page, 'input[name="spw"]', 'lanarcade-pass');
  await fillIfPresent(page, 'input[name="aname"]', 'LANAdmin');
  await fillIfPresent(page, 'input[name="aemail"]', 'admin@gannannet.local');
  await fillIfPresent(page, 'input[name="apass"]', 'lanarcade-pass');
  await shot(page, '05-install-accounts.png');
  await Promise.all([
    page.waitForURL(/install\/index\.php\?s=5/, { timeout: 60000 }),
    page.locator('form#dataform').evaluate((form) => form.submit()),
  ]);
  await shot(page, '06-install-complete.png');
  if (!(await exists(installedMarker))) throw new Error(`installer completed page but marker missing: ${installedMarker}`);
}

async function smokeGameShell(page) {
  report.phase = 'game-home';
  await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await settle(page);
  await shot(page, '07-home.png');
  const homeText = await page.locator('body').innerText({ timeout: 10000 });
  report.homePreview = homeText.slice(0, 1600);
  if (!/TravianZ|Register|Login|GannanNet TravianZ/i.test(homeText)) {
    throw new Error('TravianZ home page did not expose expected game entry text');
  }

  report.phase = 'register-page';
  await page.goto(new URL('anmelden.php', baseUrl).toString(), { waitUntil: 'domcontentloaded', timeout: 30000 });
  await settle(page);
  await shot(page, '08-register.png');
  const registerText = await page.locator('body').innerText({ timeout: 10000 });
  if (!/Register|Romans|Teutons|Gauls|Nickname/i.test(registerText)) {
    throw new Error('TravianZ register page did not expose expected playable account fields');
  }

  if (process.env.TRAVIANZ_SKIP_PLAYER_SMOKE === '1') return;

  report.phase = 'player-registration';
  const username = `qa${Date.now().toString().slice(-8)}`;
  const password = 'lanarcade-pass';
  report.playerSmoke = { username };
  await fillIfPresent(page, 'input[name="name"]', username);
  await fillIfPresent(page, 'input[name="email"]', `${username}@gannannet.local`);
  await fillIfPresent(page, 'input[name="pw"]', password);
  if (await page.locator('input[name="vid"][value="1"]').count()) await page.check('input[name="vid"][value="1"]');
  if (await page.locator('input[name="agb"]').count()) await page.check('input[name="agb"]');
  await shot(page, '09-register-filled.png');
  await Promise.all([
    page.waitForLoadState('domcontentloaded').catch(() => {}),
    page.locator('#btn_signup').click(),
  ]);
  await page.waitForTimeout(3000);
  await shot(page, '10-after-register.png');

  let bodyText = await page.locator('body').innerText({ timeout: 10000 }).catch(() => '');
  report.playerSmoke.afterRegisterUrl = page.url();
  report.playerSmoke.afterRegisterPreview = bodyText.slice(0, 1600);

  if (!/dorf1\.php|dorf2\.php|karte\.php/.test(page.url())) {
    await page.goto(new URL('login.php', baseUrl).toString(), { waitUntil: 'domcontentloaded', timeout: 30000 });
    if (await page.locator('input[name="user"]').count()) {
      await fillIfPresent(page, 'input[name="user"]', username);
      await fillIfPresent(page, 'input[name="pw"]', password);
      await shot(page, '11-login-filled.png');
      await Promise.all([
        page.waitForLoadState('domcontentloaded').catch(() => {}),
        page.locator('#btn_login').click(),
      ]).catch(() => {});
      await page.waitForTimeout(3000);
    }
  }

  await shot(page, '12-player-final.png');
  bodyText = await page.locator('body').innerText({ timeout: 10000 }).catch(() => '');
  report.playerSmoke.finalUrl = page.url();
  report.playerSmoke.finalPreview = bodyText.slice(0, 2000);
  if (!/dorf1\.php|dorf2\.php|karte\.php|Village|Wood|Clay|Iron|Crop|Lumber|Main Building/i.test(bodyText + page.url())) {
    throw new Error('TravianZ player smoke did not reach recognizable village gameplay');
  }
}

async function settle(page) {
  await page.waitForLoadState('networkidle', { timeout: 10000 }).catch(() => {});
}

async function shot(page, name) {
  const file = path.join(reportRoot, 'screenshots', name);
  await page.screenshot({ path: file, fullPage: true });
  report.screenshots.push(file);
}

async function fillIfPresent(page, selector, value) {
  const locator = page.locator(selector).first();
  if (await locator.count()) await locator.fill(value);
}

async function exists(file) {
  try { await fs.access(file); return true; } catch { return false; }
}

function normalizeBaseUrl(url) {
  return url.endsWith('/') ? url : `${url}/`;
}

function isAllowedUrl(rawUrl) {
  if (rawUrl.startsWith('data:') || rawUrl.startsWith('blob:') || rawUrl.startsWith('about:')) return true;
  let parsed;
  try { parsed = new URL(rawUrl); } catch { return false; }
  return ['http:', 'https:'].includes(parsed.protocol) && allowedHosts.has(parsed.hostname);
}

function renderMarkdown(data) {
  return `# TravianZ Smoke\n\nGenerated: ${data.generatedAt}\nResult: ${data.passed ? 'pass' : 'fail'}\nPhase: ${data.phase}\nBase URL: ${data.baseUrl}\nPublic URL: ${data.publicBaseUrl}\n\nScreenshots:\n${data.screenshots.map((s) => `- ${s}`).join('\n') || '- none'}\n\nBlocked external requests: ${data.blocked.length}\nFailed LAN responses: ${data.failedResponses.length}\nConsole errors: ${data.consoleErrors.length}\nPage errors: ${data.pageErrors.length}\n${data.error ? `\nError:\n\n\`\`\`\n${data.error}\n\`\`\`\n` : ''}`;
}
