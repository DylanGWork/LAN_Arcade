#!/usr/bin/env node

import { spawn } from 'node:child_process';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import { chromium } from 'playwright';

const reportDir = process.env.ARCADE_COMPANION_REPORT_DIR || 'qa/reports/companion';
const apiPort = Number.parseInt(process.env.ARCADE_COMPANION_API_PORT || '3210', 10);
const appPort = Number.parseInt(process.env.ARCADE_COMPANION_APP_PORT || '5174', 10);
const apiUrl = `http://127.0.0.1:${apiPort}/`;
const appUrl = `http://127.0.0.1:${appPort}/`;

async function main() {
  await fs.rm(reportDir, { recursive: true, force: true });
  await fs.mkdir(reportDir, { recursive: true });
  const fixture = await createFixture();
  const processes = [];

  try {
    await run('npm', ['run', 'build', '-w', '@lan-arcade/shared']);

    processes.push(spawnManaged('npm', ['run', 'dev', '-w', '@lan-arcade/arcade-api'], {
      ARCADE_API_HOST: '127.0.0.1',
      ARCADE_API_PORT: String(apiPort),
      LAN_ARCADE_DB_PATH: path.join(fixture, 'arcade.sqlite'),
      LAN_ARCADE_CATALOG_PATH: path.join(fixture, 'catalog.json'),
      LAN_ARCADE_FILTERS_PATH: path.join(fixture, 'admin.filters.json'),
      ARCADE_NAME: 'QA Arcade'
    }, 'api'));

    processes.push(spawnManaged('npx', ['vite', '--host', '127.0.0.1', '--port', String(appPort)], {}, 'app', 'apps/companion'));

    await waitFor(`${apiUrl}health`, 30000);
    await waitFor(appUrl, 30000);

    const browser = await chromium.launch();
    const page = await browser.newPage({ viewport: { width: 430, height: 860 }, isMobile: true, hasTouch: true });
    await page.addInitScript(() => window.localStorage.setItem('lanArcade.smokeMode', '1'));
    await page.goto(appUrl, { waitUntil: 'domcontentloaded' });
    await page.getByLabel('Server API').fill(apiUrl);
    await page.getByRole('button', { name: 'Connect' }).click();
    await page.getByText(/Connected to QA Arcade/).waitFor({ timeout: 15000 });

    await page.getByPlaceholder('New player name').fill('QA Camper');
    await page.getByRole('button', { name: 'Create' }).click();
    await page.locator('.selected-player span', { hasText: 'QA Camper' }).waitFor({ timeout: 15000 });

    await page.getByLabel('Catalog filter').selectOption('app');
    await page.getByRole('button', { name: 'Open Camp Colony' }).waitFor({ timeout: 15000 });
    await page.screenshot({ path: path.join(reportDir, 'companion-catalog.png'), fullPage: true });

    await page.getByRole('button', { name: 'Open Camp Colony' }).click();
    await page.getByTestId('camp-colony-game').waitFor({ timeout: 15000 });
    await clickFirstEnabled(page, [/Forage/]);
    await clickFirstEnabled(page, [/Garden/, /Forage/]);
    await clickFirstEnabled(page, [/Scout/, /Forage/]);
    await clickFirstEnabled(page, [/Watchtower/, /Solar/, /Forage/]);
    await page.getByRole('button', { name: 'Submit Camp Colony Score' }).waitFor({ timeout: 15000 });
    await page.getByRole('button', { name: 'Submit Camp Colony Score' }).click();
    await page.getByText(/Score submitted/).waitFor({ timeout: 15000 });
    await page.screenshot({ path: path.join(reportDir, 'companion-camp-colony.png'), fullPage: true });
    await page.getByRole('button', { name: 'Close' }).click();

    await page.getByLabel('Catalog filter').selectOption('all');
    await page.getByRole('button', { name: 'Open Mindustry LAN Server' }).click();
    await page.getByTestId('lan-service-panel').waitFor({ timeout: 15000 });
    await page.screenshot({ path: path.join(reportDir, 'companion-mindustry-service.png'), fullPage: true });
    await page.getByRole('button', { name: 'Close' }).click();

    await page.getByRole('button', { name: 'Open Unciv LAN Server' }).click();
    await page.getByTestId('lan-service-panel').waitFor({ timeout: 15000 });
    await page.screenshot({ path: path.join(reportDir, 'companion-unciv-service.png'), fullPage: true });
    await page.getByRole('button', { name: 'Close' }).click();

    await page.getByLabel('Catalog filter').selectOption('app');
    await page.getByRole('button', { name: 'Open Trailguard TD' }).click();
    await page.getByTestId('trailguard-game').waitFor({ timeout: 15000 });

    const canvas = page.locator('.phaser-wrap canvas').first();
    await canvas.waitFor({ timeout: 15000 });
    const box = await canvas.boundingBox();
    if (!box) throw new Error('Trailguard canvas did not render.');
    await page.mouse.click(box.x + box.width * 0.17, box.y + box.height * 0.69);
    await page.mouse.click(box.x + box.width * 0.29, box.y + box.height * 0.51);
    await page.mouse.click(box.x + box.width * 0.78, box.y + box.height * 0.08);
    await page.getByRole('button', { name: 'Submit Score' }).waitFor({ timeout: 25000 });
    await page.getByRole('button', { name: 'Submit Score' }).click();
    await page.getByText(/Score submitted/).waitFor({ timeout: 15000 });
    await page.screenshot({ path: path.join(reportDir, 'companion-trailguard.png'), fullPage: true });
    await browser.close();

    await fs.writeFile(path.join(reportDir, 'summary.json'), `${JSON.stringify({
      ok: true,
      apiUrl,
      appUrl,
      checked: [
        'connect',
        'create-player',
        'catalog',
        'camp-colony-render',
        'camp-colony-score-submit',
        'mindustry-service-card',
        'unciv-service-card',
        'trailguard-render',
        'trailguard-score-submit'
      ]
    }, null, 2)}\n`);
    console.log(`Companion smoke passed. Report: ${reportDir}`);
  } finally {
    processes.forEach(killManaged);
  }
}

async function createFixture() {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'lan-arcade-companion-'));
  await fs.writeFile(path.join(dir, 'catalog.json'), JSON.stringify({
    generated_at: new Date().toISOString(),
    arcade_name: 'QA Arcade',
    categories: [
      { id: 'puzzle', label: 'Puzzle' },
      { id: 'arcade', label: 'Arcade' },
      { id: 'mobile-friendly', label: 'Mobile Friendly' }
    ],
    games: [
      {
        id: '2048',
        title: '2048',
        icon: '123',
        meta: 'Puzzle - Swipe',
        description: 'Merge tiles.',
        tags: ['Puzzle'],
        categories: ['puzzle', 'mobile-friendly'],
        path: '../2048/'
      },
      {
        id: 'snake',
        title: 'Snake',
        icon: 'S',
        meta: 'Arcade - Classic',
        description: 'Classic snake.',
        tags: ['Arcade'],
        categories: ['arcade', 'mobile-friendly'],
        path: '../snake/'
      }
    ]
  }, null, 2));
  await fs.writeFile(path.join(dir, 'admin.filters.json'), JSON.stringify({
    disabled_categories: [],
    disabled_games: []
  }, null, 2));
  return dir;
}

function spawnManaged(command, args, env = {}, label = command, cwd = '.') {
  const child = spawn(command, args, {
    cwd,
    env: { ...process.env, ...env },
    stdio: ['ignore', 'pipe', 'pipe'],
    detached: process.platform !== 'win32'
  });
  child.stdout.on('data', (chunk) => process.stdout.write(`[${label}] ${chunk}`));
  child.stderr.on('data', (chunk) => process.stderr.write(`[${label}] ${chunk}`));
  return child;
}

function killManaged(child) {
  if (child.exitCode !== null || child.killed) return;
  try {
    if (process.platform === 'win32') child.kill('SIGTERM');
    else process.kill(-child.pid, 'SIGTERM');
  } catch {
    try {
      child.kill('SIGTERM');
    } catch {
      // already gone
    }
  }
}

async function run(command, args) {
  await new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: 'inherit', env: process.env });
    child.on('exit', (code) => code === 0 ? resolve(undefined) : reject(new Error(`${command} ${args.join(' ')} failed with ${code}`)));
  });
}

async function waitFor(url, timeoutMs) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    try {
      const response = await fetch(url);
      if (response.ok) return;
    } catch {
      // keep waiting
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error(`Timed out waiting for ${url}`);
}

async function clickFirstEnabled(page, names) {
  for (const name of names) {
    const locator = page.getByRole('button', { name }).first();
    if ((await locator.count()) > 0 && await locator.isEnabled()) {
      await locator.click();
      return;
    }
  }
  throw new Error(`No enabled action found for ${names.join(', ')}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
