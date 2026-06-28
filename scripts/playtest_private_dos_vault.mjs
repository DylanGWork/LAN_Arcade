#!/usr/bin/env node
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { chromium } from 'playwright';

const args = process.argv.slice(2);
function argValue(name, fallback = undefined) {
  const prefix = name + '=';
  const hit = args.find((arg) => arg.startsWith(prefix));
  if (hit) return hit.slice(prefix.length);
  const idx = args.indexOf(name);
  if (idx >= 0 && idx + 1 < args.length) return args[idx + 1];
  return fallback;
}
function hasArg(name) { return args.includes(name); }
function esc(s) { return String(s ?? '').replace(/[&<>"']/g, (c) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
function sha(buf) { return crypto.createHash('sha256').update(buf).digest('hex'); }
function sleep(ms) { return new Promise((resolve) => setTimeout(resolve, ms)); }
function rel(from, file) { return path.relative(from, file).replaceAll(path.sep, '/'); }

const manifestPath = argValue('--manifest', '/var/www/html/mirrors/private-dos-vault/manifest.json');
const baseUrl = argValue('--base-url', 'http://127.0.0.1/mirrors/private-dos-vault');
const reportRoot = argValue('--report-root', 'qa/reports/private-dos-vault-playtest');
const only = argValue('--id', argValue('--only', '')).split(',').map((s) => s.trim()).filter(Boolean);
const limit = Number(argValue('--limit', '0')) || 0;
const failOnCrash = hasArg('--fail-on-crash');
const stamp = argValue('--run-id', '') || new Date().toISOString().replace(/[-:.]/g, '').slice(0, 15) + 'Z';
const reportDir = path.resolve(reportRoot, 'run-' + stamp);
const screenshotDir = path.join(reportDir, 'screenshots');
const reportJson = path.join(reportDir, 'report.json');
const reportMd = path.join(reportDir, 'REPORT.md');
const latestJson = path.resolve(reportRoot, 'latest.json');
const latestMd = path.resolve(reportRoot, 'latest.md');
const crashPattern = /\[panic\]|Backend crashed|memory access out of bounds|RangeError: offset is out of bounds|Target crashed|RuntimeError|Aborted|ReferenceError|TypeError|uncaught/i;

await fs.mkdir(screenshotDir, { recursive: true });
const manifest = JSON.parse(await fs.readFile(manifestPath, 'utf8'));
let games = (manifest.games || []).filter((g) => g.bundleUrl || g.packageUrl || only.includes(g.id));
if (only.length) games = games.filter((g) => only.includes(g.id) || only.includes(g.title));
if (limit > 0) games = games.slice(0, limit);

const inputPlans = {
  'lemmings-ma': ['Enter', 'Enter', '1', 'Enter', 'Enter'],
  'simant-ma': ['Enter', 'Enter'],
};
const defaultInputPlan = ['Enter', 'Enter', 'Space', 'ArrowDown', 'Enter'];

async function screenshot(page, file) {
  let buf;
  const game = page.locator('#game');
  if (await game.count().catch(() => 0)) buf = await game.screenshot({ path: file }).catch(() => null);
  if (!buf) buf = await page.screenshot({ path: file, fullPage: false });
  return { file, rel: rel(reportDir, file), bytes: buf.length, sha256: sha(buf) };
}

async function pressPlan(page, plan) {
  for (const key of plan) {
    await page.keyboard.press(key).catch(() => {});
    await page.waitForTimeout(450);
  }
}

async function domState(page) {
  return await page.evaluate(() => {
    const game = document.querySelector('#game');
    const canvas = document.querySelector('canvas');
    const text = document.body ? document.body.innerText : '';
    const gameText = game ? game.innerText : '';
    return {
      title: document.title,
      canvasCount: document.querySelectorAll('canvas').length,
      canvasWidth: canvas ? canvas.width : 0,
      canvasHeight: canvas ? canvas.height : 0,
      bodyText: text.slice(0, 4000),
      gameText: gameText.slice(0, 1500),
      hasDosPlayer: !!window.__dosPlayer,
      hasDosRuntime: typeof window.Dos === 'function',
    };
  });
}

async function testGame(browser, game, index) {
  const dir = path.join(screenshotDir, game.id);
  await fs.mkdir(dir, { recursive: true });
  const page = await browser.newPage({ viewport: { width: 1366, height: 900 }, deviceScaleFactor: 1 });
  page.setDefaultTimeout(30000);
  const consoleMessages = [];
  const pageErrors = [];
  const requestFailures = [];
  const externalRequests = [];
  page.on('console', (msg) => {
    const text = msg.text();
    if (['error', 'warning'].includes(msg.type()) || crashPattern.test(text)) {
      consoleMessages.push({ type: msg.type(), text: text.slice(0, 1000) });
    }
  });
  page.on('pageerror', (err) => pageErrors.push(String(err?.stack || err).slice(0, 1500)));
  page.on('requestfailed', (req) => {
    const url = req.url();
    if (!url.includes('/favicon')) requestFailures.push({ url, failure: req.failure()?.errorText || 'failed' });
  });
  const allowedHosts = new Set(['127.0.0.1', 'localhost', '192.168.1.106', new URL(baseUrl).hostname]);
  await page.route('**/*', async (route) => {
    const url = new URL(route.request().url());
    if (url.protocol.startsWith('http') && !allowedHosts.has(url.hostname)) {
      externalRequests.push(route.request().url());
      await route.abort();
      return;
    }
    await route.continue();
  });
  const url = baseUrl.replace(/\/$/, '') + '/play.html?id=' + encodeURIComponent(game.id);
  const started = Date.now();
  const result = {
    index,
    id: game.id,
    title: game.title,
    status: game.status,
    url,
    startedAt: new Date().toISOString(),
    consoleMessages,
    pageErrors,
    requestFailures,
    externalRequests,
    screenshots: [],
  };
  try {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });
    await page.waitForSelector('#game', { timeout: 30000 });
    await Promise.race([page.waitForSelector('canvas', { timeout: 25000 }), sleep(25000)]);
    await page.waitForTimeout(6000);
    result.screenshots.push(await screenshot(page, path.join(dir, '01-boot.png')));
    await page.locator('#game').click({ position: { x: 420, y: 280 } }).catch(async () => page.mouse.click(640, 420));
    await pressPlan(page, inputPlans[game.id] || defaultInputPlan);
    await page.waitForTimeout(6000);
    result.screenshots.push(await screenshot(page, path.join(dir, '02-after-input.png')));
    await page.waitForTimeout(3000);
    const state = await domState(page);
    result.dom = {
      title: state.title,
      canvasCount: state.canvasCount,
      canvasWidth: state.canvasWidth,
      canvasHeight: state.canvasHeight,
      hasDosPlayer: state.hasDosPlayer,
      hasDosRuntime: state.hasDosRuntime,
      gameText: state.gameText,
    };
    const allText = [state.bodyText, state.gameText, ...pageErrors, ...consoleMessages.map((m) => m.text)].join('\n');
    const hashes = new Set(result.screenshots.map((s) => s.sha256));
    const hasCrash = crashPattern.test(allText);
    const hasCanvas = state.canvasCount > 0;
    const networkProblem = externalRequests.length > 0;
    if (hasCrash) {
      result.verdict = 'runtime-crash';
      result.reason = 'The browser emulator reported a runtime/backend crash after boot or first input.';
    } else if (!hasCanvas) {
      result.verdict = 'failed-no-canvas';
      result.reason = 'The page loaded, but the emulator canvas never appeared.';
    } else if (networkProblem) {
      result.verdict = 'failed-offline';
      result.reason = 'The game attempted to load resources outside the LAN host during the smoke run.';
    } else if (requestFailures.length > 0 || pageErrors.length > 0) {
      result.verdict = 'needs-review';
      result.reason = 'The game rendered a canvas but produced browser errors or failed requests.';
    } else if (hashes.size <= 1) {
      result.verdict = 'started-needs-playtest';
      result.reason = 'The emulator stayed alive, but generic input did not visibly change the screen.';
    } else {
      result.verdict = 'browser-smoke-pass';
      result.reason = 'The game booted, accepted first input, stayed offline, and did not report a runtime crash.';
    }
  } catch (error) {
    const errorText = String(error?.stack || error);
    const crashText = [errorText, ...pageErrors, ...consoleMessages.map((m) => m.text)].join('\n');
    if (crashPattern.test(crashText)) {
      result.verdict = 'runtime-crash';
      result.reason = 'The browser emulator/page crashed during the launch flow.';
    } else {
      result.verdict = 'audit-error';
      result.reason = 'The audit could not complete the launch flow.';
    }
    result.error = errorText.slice(0, 2000);
  } finally {
    result.durationMs = Date.now() - started;
    await page.close().catch(() => {});
  }
  return result;
}

function markdown(report) {
  const lines = [];
  lines.push('# Classic PC Browser Launch Audit');
  lines.push('');
  lines.push('- Run: ' + report.runId);
  lines.push('- Base URL: ' + report.baseUrl);
  lines.push('- Tested: ' + report.results.length + ' / ' + report.planned);
  lines.push('- Counts: ' + JSON.stringify(report.counts));
  lines.push('');
  for (const r of report.results) {
    lines.push('## ' + r.title);
    lines.push('');
    lines.push('- ID: `' + r.id + '`');
    lines.push('- Verdict: `' + r.verdict + '`');
    lines.push('- Reason: ' + r.reason);
    lines.push('- URL: ' + r.url);
    if (r.screenshots?.length) lines.push('- Screenshots: ' + r.screenshots.map((s) => '[' + path.basename(s.file) + '](' + s.rel + ')').join(', '));
    if (r.pageErrors?.length) lines.push('- Page errors: ' + r.pageErrors.length);
    if (r.consoleMessages?.length) lines.push('- Console warnings/errors: ' + r.consoleMessages.length);
    if (r.externalRequests?.length) lines.push('- Blocked external requests: ' + r.externalRequests.length);
    lines.push('');
  }
  return lines.join('\n');
}

const results = [];
const browser = await chromium.launch({ headless: true, args: ['--disable-dev-shm-usage'] });
try {
  for (let i = 0; i < games.length; i += 1) {
    const game = games[i];
    process.stdout.write('[private-dos] ' + (i + 1) + '/' + games.length + ' ' + game.title + ' ... ');
    const result = await testGame(browser, game, i);
    results.push(result);
    console.log(result.verdict + ' (' + Math.round(result.durationMs / 1000) + 's)');
  }
} finally {
  await browser.close().catch(() => {});
}
const counts = results.reduce((acc, r) => { acc[r.verdict] = (acc[r.verdict] || 0) + 1; return acc; }, {});
const report = {
  generatedAt: new Date().toISOString(),
  runId: stamp,
  baseUrl,
  manifestPath,
  reportDir,
  planned: games.length,
  counts,
  results,
};
await fs.writeFile(reportJson, JSON.stringify(report, null, 2));
await fs.writeFile(reportMd, markdown(report));
await fs.mkdir(path.resolve(reportRoot), { recursive: true });
await fs.copyFile(reportJson, latestJson).catch(() => {});
await fs.copyFile(reportMd, latestMd).catch(() => {});
console.log('[private-dos] report ' + reportMd);
if (failOnCrash && results.some((r) => ['runtime-crash', 'failed-no-canvas', 'failed-offline', 'audit-error'].includes(r.verdict))) {
  process.exit(1);
}
