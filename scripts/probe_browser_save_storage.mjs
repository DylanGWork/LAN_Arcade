#!/usr/bin/env node
import { chromium } from 'playwright';
import fs from 'node:fs/promises';

function parseArgs(argv) {
  const args = { url: '', output: '', waitMs: 2500, click: [], evaluate: '', viewport: 'desktop' };
  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--url') args.url = argv[++index] || '';
    else if (arg === '--output') args.output = argv[++index] || '';
    else if (arg === '--wait-ms') args.waitMs = Number.parseInt(argv[++index] || '2500', 10);
    else if (arg === '--click') args.click.push(argv[++index] || '');
    else if (arg === '--eval') args.evaluate = argv[++index] || '';
    else if (arg === '--mobile') args.viewport = 'mobile';
    else if (arg === '--help' || arg === '-h') usage(0);
    else usage(1, `Unknown argument: ${arg}`);
  }
  if (!args.url) usage(1, 'Missing --url');
  if (!/^https?:\/\//.test(args.url)) args.url = `http://127.0.0.1${args.url.startsWith('/') ? '' : '/'}${args.url}`;
  if (!Number.isFinite(args.waitMs) || args.waitMs < 0) args.waitMs = 2500;
  return args;
}

function usage(exitCode, message = '') {
  if (message) console.error(message);
  console.error('Usage: node scripts/probe_browser_save_storage.mjs --url URL [--output report.json] [--wait-ms 2500] [--click selector] [--eval js] [--mobile]');
  process.exit(exitCode);
}

async function collectStorage(page) {
  return page.evaluate(async () => {
    function storageEntries(storage) {
      const rows = [];
      for (let index = 0; index < storage.length; index += 1) {
        const key = storage.key(index);
        const value = key ? storage.getItem(key) || '' : '';
        rows.push({ key, bytes: new Blob([value]).size, sample: value.slice(0, 120) });
      }
      return rows.sort((a, b) => String(a.key).localeCompare(String(b.key)));
    }

    let indexedDatabases = [];
    try {
      if (indexedDB && indexedDB.databases) {
        indexedDatabases = await indexedDB.databases();
      }
    } catch (error) {
      indexedDatabases = [{ error: String(error && error.message ? error.message : error) }];
    }

    let cacheNames = [];
    try {
      if (typeof caches !== 'undefined' && caches.keys) cacheNames = await caches.keys();
    } catch (error) {
      cacheNames = [`error: ${String(error && error.message ? error.message : error)}`];
    }

    return {
      url: location.href,
      title: document.title,
      localStorage: storageEntries(localStorage),
      sessionStorage: storageEntries(sessionStorage),
      indexedDB: indexedDatabases,
      caches: cacheNames,
    };
  });
}

function summarize(snapshot) {
  return {
    localStorageKeys: snapshot.localStorage.length,
    sessionStorageKeys: snapshot.sessionStorage.length,
    indexedDBDatabases: snapshot.indexedDB.length,
    cacheNames: snapshot.caches.length,
  };
}

async function main() {
  const args = parseArgs(process.argv);
  const viewport = args.viewport === 'mobile'
    ? { width: 390, height: 844, isMobile: true, hasTouch: true }
    : { width: 1366, height: 768 };
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport });
  const page = await context.newPage();
  const pageErrors = [];
  const consoleWarnings = [];
  page.on('pageerror', (error) => pageErrors.push(String(error.message || error)));
  page.on('console', (message) => {
    if (['error', 'warning'].includes(message.type())) consoleWarnings.push({ type: message.type(), text: message.text() });
  });

  await page.goto(args.url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForTimeout(args.waitMs);
  for (const selector of args.click.filter(Boolean)) {
    await page.locator(selector).first().click({ timeout: 10000 });
    await page.waitForTimeout(args.waitMs);
  }
  if (args.evaluate) {
    await page.evaluate(args.evaluate);
    await page.waitForTimeout(args.waitMs);
  }
  const snapshot = await collectStorage(page);
  await browser.close();

  const report = {
    generatedAt: new Date().toISOString(),
    input: args,
    summary: summarize(snapshot),
    pageErrors,
    consoleWarnings,
    snapshot,
  };

  const text = JSON.stringify(report, null, 2) + '\n';
  if (args.output) await fs.writeFile(args.output, text, 'utf8');
  else process.stdout.write(text);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
