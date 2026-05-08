#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { spawn } from 'node:child_process';
import { chromium } from 'playwright';

const rootDir = process.cwd();
const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const reportDir = process.env.TANK_QA_REPORT_DIR || `qa/reports/tank-arena/${stamp}`;
const port = Number.parseInt(process.env.LAN_TANK_QA_PORT || '8791', 10);
const baseUrl = process.env.ARCADE_BASE_URL || 'http://127.0.0.1/mirrors/lan-tank-arena/';
const wsUrl = `ws://127.0.0.1:${port}/tank-arena/ws`;
const gameUrl = `${baseUrl}${baseUrl.includes('?') ? '&' : '?'}server=${encodeURIComponent(wsUrl)}&room=QA`;

const server = spawn(process.execPath, ['services/lan-tank-arena/server.mjs'], {
  cwd: rootDir,
  env: {
    ...process.env,
    LAN_TANK_PORT: String(port),
    LAN_TANK_HOST: '127.0.0.1',
  },
  stdio: ['ignore', 'pipe', 'pipe'],
});

const serverLogs = [];
server.stdout.on('data', (chunk) => serverLogs.push(chunk.toString()));
server.stderr.on('data', (chunk) => serverLogs.push(chunk.toString()));

let browser;

try {
  await fs.mkdir(path.join(reportDir, 'screenshots'), { recursive: true });
  await waitForHealth(`http://127.0.0.1:${port}/tank-arena/healthz`);

  browser = await chromium.launch();
  const alpha = await openClient(browser, 'Alpha');
  const bravo = await openClient(browser, 'Bravo');

  await alpha.page.evaluate(() => window.__lanTankQa.join('Alpha', 'QA'));
  await bravo.page.evaluate(() => window.__lanTankQa.join('Bravo', 'QA'));

  const counts = await Promise.all([
    alpha.page.evaluate(() => window.__lanTankQa.waitForPlayers(2)),
    bravo.page.evaluate(() => window.__lanTankQa.waitForPlayers(2)),
  ]);

  await alpha.page.evaluate(() => window.__lanTankQa.input({ up: true, fire: true }));
  await bravo.page.evaluate(() => window.__lanTankQa.input({ up: true, left: true, fire: true }));
  await alpha.page.waitForTimeout(1200);
  await alpha.page.evaluate(() => window.__lanTankQa.input({ up: true, right: true, fire: true }));
  await bravo.page.evaluate(() => window.__lanTankQa.input({ up: true, left: false, right: true, fire: true }));
  await alpha.page.waitForTimeout(1000);
  await alpha.page.evaluate(() => window.__lanTankQa.input({ up: false, right: false, fire: false }));
  await bravo.page.evaluate(() => window.__lanTankQa.input({ up: false, right: false, fire: false }));
  await alpha.page.waitForTimeout(500);

  await alpha.page.screenshot({
    path: path.join(reportDir, 'screenshots', 'lan-tank-arena-alpha.png'),
    fullPage: true,
  });
  await bravo.page.screenshot({
    path: path.join(reportDir, 'screenshots', 'lan-tank-arena-bravo.png'),
    fullPage: true,
  });

  const alphaSnapshot = await alpha.page.evaluate(() => window.__lanTankQa.snapshot());
  const bravoSnapshot = await bravo.page.evaluate(() => window.__lanTankQa.snapshot());
  const errors = [...alpha.errors, ...bravo.errors];
  const players = alphaSnapshot.state.players.length;
  const passed = counts.every((count) => count >= 2)
    && players >= 2
    && errors.length === 0;

  const report = {
    generatedAt: new Date().toISOString(),
    passed,
    gameUrl,
    wsUrl,
    players,
    alpha: {
      screenshot: path.join(reportDir, 'screenshots', 'lan-tank-arena-alpha.png'),
      snapshot: alphaSnapshot,
      errors: alpha.errors,
    },
    bravo: {
      screenshot: path.join(reportDir, 'screenshots', 'lan-tank-arena-bravo.png'),
      snapshot: bravoSnapshot,
      errors: bravo.errors,
    },
    serverLogs,
  };

  await fs.writeFile(path.join(reportDir, 'tank-smoke.json'), `${JSON.stringify(report, null, 2)}\n`);
  await fs.writeFile(path.join(reportDir, 'tank-smoke.md'), renderMarkdown(report));

  if (!passed) {
    console.error(`LAN Tank Arena smoke failed. Report: ${reportDir}`);
    process.exitCode = 1;
  } else {
    console.log(`LAN Tank Arena smoke passed. Report: ${reportDir}`);
  }
} finally {
  if (browser) await browser.close().catch(() => {});
  server.kill('SIGTERM');
}

async function openClient(browserInstance, name) {
  const context = await browserInstance.newContext({
    ignoreHTTPSErrors: true,
    viewport: name === 'Alpha' ? { width: 1280, height: 800 } : { width: 390, height: 844 },
    isMobile: name !== 'Alpha',
    hasTouch: name !== 'Alpha',
    deviceScaleFactor: name === 'Alpha' ? 1 : 2,
  });
  const page = await context.newPage();
  const errors = [];

  page.on('pageerror', (error) => errors.push(`pageerror: ${error.message}`));
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(`console: ${message.text()}`);
  });

  await page.goto(gameUrl, { waitUntil: 'domcontentloaded', timeout: 15000 });
  await page.waitForFunction(() => window.__lanTankQa, null, { timeout: 5000 });
  return { context, page, errors };
}

async function waitForHealth(url) {
  const started = Date.now();
  while (Date.now() - started < 7000) {
    try {
      const response = await fetch(url);
      if (response.ok) return;
    } catch {
      // keep waiting
    }
    await new Promise((resolve) => setTimeout(resolve, 150));
  }
  throw new Error(`Tank server did not become healthy at ${url}\n${serverLogs.join('')}`);
}

function renderMarkdown(report) {
  return `# LAN Tank Arena Smoke

Generated: ${report.generatedAt}
Result: ${report.passed ? 'pass' : 'fail'}
Game URL: ${report.gameUrl}
WebSocket: ${report.wsUrl}

Players observed: ${report.players}

Screenshots:

- Alpha: ${report.alpha.screenshot}
- Bravo: ${report.bravo.screenshot}

Errors:

${[...report.alpha.errors, ...report.bravo.errors].map((error) => `- ${error}`).join('\n') || '- none'}
`;
}
