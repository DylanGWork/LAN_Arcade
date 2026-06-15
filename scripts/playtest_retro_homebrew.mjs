#!/usr/bin/env node
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { chromium } from 'playwright';

const gameIds = process.argv.slice(2).filter((arg) => !arg.startsWith('--'));
const defaultIds = [
  'tobu-tobu-girl-deluxe',
  'skyland-gba',
  'gb-2048',
  'gb-wordyl',
  'apotris-gba',
  'aevilia-gbc',
  'crossconnect-gb',
  'grub-glide-gb',
  'plantboy-gb',
  'max-pirate-gb',
  'domination-gb',
];
const ids = gameIds.length ? gameIds : defaultIds;
const stamp = new Date().toISOString().replace(/[-:.]/g, '').replace('T', 'T').slice(0, 15) + 'Z';
const reportDir = path.resolve('qa/reports/retro-homebrew-playtest', `run-${stamp}`);
await fs.mkdir(reportDir, { recursive: true });

const baseUrl = process.env.LAN_ARCADE_BASE_URL || 'http://127.0.0.1/mirrors';
const browser = await chromium.launch({ headless: true });

const keyPlan = [
  'Enter', 'Enter', 'z', 'z', 'x',
  'ArrowRight', 'ArrowRight', 'z',
  'ArrowDown', 'ArrowLeft', 'z',
  'ArrowUp', 'x', 'Enter',
  'ArrowRight', 'ArrowDown', 'z',
];

function sha(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

async function screenshot(page, file) {
  const buf = await page.screenshot({ path: file, fullPage: false });
  return { bytes: buf.length, sha256: sha(buf) };
}

async function testGame(id) {
  const dir = path.join(reportDir, id);
  await fs.mkdir(dir, { recursive: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  const externalRequests = [];
  const requestFailures = [];
  const consoleErrors = [];
  const pageErrors = [];
  page.on('console', (msg) => {
    if (['error', 'warning'].includes(msg.type())) consoleErrors.push({ type: msg.type(), text: msg.text().slice(0, 500) });
  });
  page.on('pageerror', (err) => pageErrors.push(String(err).slice(0, 500)));
  page.on('requestfailed', (req) => requestFailures.push({ url: req.url(), failure: req.failure()?.errorText || 'failed' }));
  await page.route('**/*', async (route) => {
    const url = new URL(route.request().url());
    const local = ['127.0.0.1', 'localhost', '192.168.1.106'].includes(url.hostname);
    if (!local && url.protocol.startsWith('http')) {
      externalRequests.push(route.request().url());
      await route.abort();
      return;
    }
    await route.continue();
  });

  const url = `${baseUrl}/${id}/`;
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });
  await page.waitForSelector('canvas', { timeout: 45000 });
  await page.waitForTimeout(12000);
  const before = await screenshot(page, path.join(dir, 'before.png'));
  await page.locator('#game').click({ position: { x: 180, y: 180 } }).catch(() => page.mouse.click(360, 260));
  for (const key of keyPlan) {
    await page.keyboard.press(key);
    await page.waitForTimeout(350);
  }
  await page.waitForTimeout(6000);
  const mid = await screenshot(page, path.join(dir, 'after-input.png'));
  for (let i = 0; i < 8; i += 1) {
    await page.keyboard.press(i % 2 ? 'z' : 'ArrowRight');
    await page.waitForTimeout(500);
  }
  await page.waitForTimeout(5000);
  const after = await screenshot(page, path.join(dir, 'after-extra.png'));

  const dom = await page.evaluate(() => ({
    title: document.title,
    bodyTextLength: document.body.innerText.length,
    canvasCount: document.querySelectorAll('canvas').length,
    ejsParent: !!document.querySelector('.ejs_parent'),
    ejsStarted: !!window.EJS_emulator,
    playerText: document.querySelector('#game')?.innerText?.slice(0, 500) || '',
    gameClasses: document.querySelector('#game > *')?.className || '',
  }));
  await page.close();

  const changed = before.sha256 !== mid.sha256 || mid.sha256 !== after.sha256;
  const obviousProblem = externalRequests.length || requestFailures.some((r) => !r.url.includes('/favicon')) || pageErrors.length;
  const playable = dom.canvasCount > 0 && dom.ejsStarted && changed && !obviousProblem;
  return {
    id,
    url,
    screenshots: {
      before: { file: `${id}/before.png`, ...before },
      afterInput: { file: `${id}/after-input.png`, ...mid },
      afterExtra: { file: `${id}/after-extra.png`, ...after },
    },
    screenshotChanged: changed,
    dom,
    externalRequests,
    requestFailures,
    consoleErrors,
    pageErrors,
    verdict: playable ? 'playable-smoke' : 'needs-review',
  };
}

const results = [];
for (const id of ids) {
  process.stdout.write(`[retro] ${id} ... `);
  try {
    const result = await testGame(id);
    results.push(result);
    console.log(result.verdict);
  } catch (error) {
    results.push({ id, verdict: 'error', error: String(error?.stack || error) });
    console.log('error');
  }
}
await browser.close();

const report = { generatedAt: new Date().toISOString(), baseUrl, ids, results };
await fs.writeFile(path.join(reportDir, 'playtest-report.json'), JSON.stringify(report, null, 2));
const md = [
  '# Retro Homebrew Playtest Report',
  '',
  `Generated: ${report.generatedAt}`,
  `Base URL: ${baseUrl}`,
  '',
  '| Verdict | Game | Screenshot changed | External requests | Errors |',
  '| --- | --- | --- | --- | --- |',
  ...results.map((r) => `| ${r.verdict} | ${r.id} | ${r.screenshotChanged ?? ''} | ${(r.externalRequests || []).length} | ${(r.pageErrors || []).length + (r.error ? 1 : 0)} |`),
  '',
  'This is an automated short play smoke: boot, focus emulator, send controls, capture screenshots. It does not prove a full game completion or deep balance quality. Entries with `needs-review` are not considered playable and must not be promoted until manually cleared.',
].join('\n');
await fs.writeFile(path.join(reportDir, 'playtest-report.md'), md + '\n');
console.log(reportDir);
