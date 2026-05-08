#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { chromium, firefox, webkit } from 'playwright';

const DEFAULT_BASE_URL = 'http://127.0.0.1/mirrors/games/';
const DEFAULT_REPORT_DIR = 'qa/reports/latest';
const GAME_RECIPES = {
  '2048': [
    { type: 'keys', keys: ['ArrowUp', 'ArrowRight', 'ArrowDown', 'ArrowLeft'] },
  ],
  floppybird: [
    { type: 'keys', keys: ['Space', 'Space', 'Space'] },
    { type: 'center-click' },
  ],
  'breachline-tactics': [
    { type: 'game-call', method: 'startRun' },
    { type: 'game-call', method: 'clickCell', args: [1, 2] },
    { type: 'game-call', method: 'setMode', args: ['move'] },
    { type: 'game-call', method: 'clickCell', args: [3, 2] },
    { type: 'game-call', method: 'clickCell', args: [1, 4] },
    { type: 'game-call', method: 'setMode', args: ['strike'] },
    { type: 'game-call', method: 'clickCell', args: [7, 3] },
    { type: 'game-call', method: 'endTurn' },
    { type: 'wait', ms: 900 },
  ],
  'circuit-foundry': [
    { type: 'game-call', method: 'setTool', args: ['generator'] },
    { type: 'game-call', method: 'clickCell', args: [0, 0] },
    { type: 'game-call', method: 'setTool', args: ['extractor'] },
    { type: 'game-call', method: 'setDirection', args: [0] },
    { type: 'game-call', method: 'clickCell', args: [1, 1] },
    { type: 'game-call', method: 'setTool', args: ['belt'] },
    { type: 'game-call', method: 'clickCell', args: [2, 1] },
    { type: 'game-call', method: 'setTool', args: ['smelter'] },
    { type: 'game-call', method: 'clickCell', args: [3, 1] },
    { type: 'game-call', method: 'setTool', args: ['assembler'] },
    { type: 'game-call', method: 'clickCell', args: [4, 1] },
    { type: 'game-call', method: 'run' },
    { type: 'wait', ms: 4200 },
    { type: 'game-call', method: 'setTool', args: ['erase'] },
  ],
  hextris: [
    { type: 'keys', keys: ['ArrowLeft', 'ArrowRight', 'ArrowLeft', 'ArrowRight'] },
  ],
  'outpost-siege': [
    { type: 'click-text', text: 'Cannon' },
    { type: 'canvas-click-ratio', x: 0.5, y: 0.5 },
    { type: 'click-text', text: 'Start Mission' },
    { type: 'wait', ms: 1200 },
    { type: 'click-text', text: 'Laser' },
    { type: 'canvas-click-ratio', x: 0.34, y: 0.62 },
    { type: 'keys', keys: ['Digit3', 'Digit4', 'Space', 'Space'] },
  ],
  pacman: [
    { type: 'keys', keys: ['Enter', 'ArrowRight', 'ArrowDown', 'ArrowLeft', 'ArrowUp'] },
  ],
  snake: [
    { type: 'keys', keys: ['Enter', 'ArrowRight', 'ArrowDown', 'ArrowLeft', 'ArrowUp'] },
  ],
  tetris: [
    { type: 'keys', keys: ['Enter', 'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Space'] },
  ],
};

function parseArgs(argv) {
  const options = {
    baseUrl: process.env.ARCADE_BASE_URL || DEFAULT_BASE_URL,
    reportDir: process.env.ARCADE_QA_REPORT_DIR || DEFAULT_REPORT_DIR,
    browserName: process.env.ARCADE_QA_BROWSER || 'chromium',
    blockExternal: process.env.ARCADE_ALLOW_EXTERNAL !== '1',
    limit: null,
    offset: 0,
    gameFilter: null,
    discoverCatalog: process.env.ARCADE_QA_DISCOVER_CATALOG === '1',
    headed: process.env.ARCADE_QA_HEADED === '1',
    screenshotAll: process.env.ARCADE_QA_SCREENSHOT_ALL === '1',
    mobile: process.env.ARCADE_QA_MOBILE === '1',
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    if (arg === '--base-url' && next) {
      options.baseUrl = next;
      i += 1;
    } else if (arg === '--report-dir' && next) {
      options.reportDir = next;
      i += 1;
    } else if (arg === '--browser' && next) {
      options.browserName = next;
      i += 1;
    } else if (arg === '--limit' && next) {
      options.limit = Number.parseInt(next, 10);
      i += 1;
    } else if (arg === '--offset' && next) {
      options.offset = Math.max(0, Number.parseInt(next, 10) || 0);
      i += 1;
    } else if (arg === '--game' && next) {
      options.gameFilter = next.toLowerCase();
      i += 1;
    } else if (arg === '--allow-external') {
      options.blockExternal = false;
    } else if (arg === '--catalog') {
      options.discoverCatalog = true;
    } else if (arg === '--headed') {
      options.headed = true;
    } else if (arg === '--screenshot-all') {
      options.screenshotAll = true;
    } else if (arg === '--mobile') {
      options.mobile = true;
    } else if (arg === '--help' || arg === '-h') {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown or incomplete argument: ${arg}`);
    }
  }

  options.baseUrl = ensureTrailingSlash(options.baseUrl);
  return options;
}

function printHelp() {
  console.log(`LAN Arcade browser smoke test

Usage:
  npm run qa:smoke -- [options]

Options:
  --base-url <url>       Arcade index URL. Default: ${DEFAULT_BASE_URL}
  --report-dir <path>    Output directory. Default: ${DEFAULT_REPORT_DIR}
  --browser <name>       chromium, firefox, or webkit. Default: chromium
  --limit <n>            Test only the first n discovered games
  --offset <n>           Skip the first n discovered games before applying --limit
  --game <text>          Test games whose id/title/url includes text
  --catalog              Discover every catalog entry instead of public links
  --allow-external       Do not block or fail remote requests
  --headed               Show the browser
  --screenshot-all       Save screenshots for passing games too
  --mobile               Use a phone-sized touch viewport and mobile gestures
`);
}

function ensureTrailingSlash(value) {
  return value.endsWith('/') ? value : `${value}/`;
}

function browserTypeFor(name) {
  if (name === 'chromium') return chromium;
  if (name === 'firefox') return firefox;
  if (name === 'webkit') return webkit;
  throw new Error(`Unsupported browser '${name}'. Use chromium, firefox, or webkit.`);
}

function isHttpUrl(value) {
  return value.startsWith('http://') || value.startsWith('https://');
}

function safeFilename(value) {
  return value.replace(/[^A-Za-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '') || 'game';
}

function classifyRequest(url, baseOrigin) {
  if (!isHttpUrl(url)) return 'local';
  const parsed = new URL(url);
  return parsed.origin === baseOrigin ? 'local' : 'external';
}

function gameIdFromUrl(url) {
  const parsed = new URL(url);
  const parts = parsed.pathname.split('/').filter(Boolean);
  const mirrorIndex = parts.indexOf('mirrors');
  if (mirrorIndex >= 0 && parts[mirrorIndex + 1]) {
    return parts[mirrorIndex + 1];
  }
  return parts.at(-1) || parsed.hostname;
}

function normalizeGameUrl(href, baseUrl) {
  const url = new URL(href, baseUrl);
  url.hash = '';
  return ensureTrailingSlash(url.href);
}

async function discoverGames(browser, options) {
  const context = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await context.newPage();
  const baseOrigin = new URL(options.baseUrl).origin;
  const catalogUrl = new URL('catalog.json', options.baseUrl).href;

  let catalogGames = [];
  try {
    const response = await context.request.get(catalogUrl, { timeout: 5000 });
    if (response.ok()) {
      const catalog = await response.json();
      if (Array.isArray(catalog.games)) {
        catalogGames = catalog.games.map((game) => ({
          id: String(game.id || '').trim(),
          title: String(game.title || game.id || '').trim(),
          url: normalizeGameUrl(game.path || `../${game.id}/`, options.baseUrl),
          source: 'catalog.json',
        })).filter((game) => game.id && game.url);
      }
    }
  } catch {
    catalogGames = [];
  }

  if (options.discoverCatalog && catalogGames.length > 0) {
    await context.close();
    return filterAndLimitGames(dedupeGames(catalogGames), options);
  }

  await page.goto(options.baseUrl, { waitUntil: 'domcontentloaded', timeout: 15000 });
  await page.waitForTimeout(1000);

  const scrapedGames = await page.$$eval('a[href]', (links) => links.map((link) => {
    const titleNode = link.querySelector('.game-title');
    const title = titleNode ? titleNode.textContent : link.textContent;
    return {
      href: link.getAttribute('href'),
      title: (title || '').replace(/\s+/g, ' ').trim(),
    };
  }));
  await context.close();

  const games = scrapedGames
    .map((game) => {
      try {
        const url = normalizeGameUrl(game.href, options.baseUrl);
        const parsed = new URL(url);
        if (parsed.origin !== baseOrigin) return null;
        if (!parsed.pathname.includes('/mirrors/')) return null;
        if (parsed.pathname.startsWith('/mirrors/games/')) return null;
        return {
          id: gameIdFromUrl(url),
          title: game.title || gameIdFromUrl(url),
          url,
          source: 'index links',
        };
      } catch {
        return null;
      }
    })
    .filter(Boolean);

  return filterAndLimitGames(dedupeGames(games), options);
}

function dedupeGames(games) {
  const seen = new Set();
  const deduped = [];
  for (const game of games) {
    const key = game.url;
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(game);
  }
  return deduped.sort((a, b) => a.id.localeCompare(b.id));
}

function filterAndLimitGames(games, options) {
  let filtered = games;
  if (options.gameFilter) {
    filtered = filtered.filter((game) => {
      const haystack = `${game.id} ${game.title} ${game.url}`.toLowerCase();
      return haystack.includes(options.gameFilter);
    });
  }
  if (Number.isInteger(options.offset) && options.offset > 0) {
    filtered = filtered.slice(options.offset);
  }
  if (Number.isInteger(options.limit) && options.limit > 0) {
    filtered = filtered.slice(0, options.limit);
  }
  return filtered;
}

async function testGame(browser, game, options) {
  const baseOrigin = new URL(options.baseUrl).origin;
  const context = await browser.newContext({
    ignoreHTTPSErrors: true,
    viewport: options.mobile ? { width: 390, height: 844 } : { width: 1280, height: 800 },
    isMobile: options.mobile,
    hasTouch: options.mobile,
    deviceScaleFactor: options.mobile ? 2 : 1,
  });

  const result = {
    id: game.id,
    title: game.title,
    url: game.url,
    source: game.source,
    status: 'unknown',
    reasons: [],
    consoleErrors: [],
    pageErrors: [],
    localFailures: [],
    externalRequests: [],
    render: {},
    interactions: [],
    screenshot: null,
    strictStatus: 'unknown',
    playabilityStatus: 'unknown',
    playabilityNotes: [],
    profile: options.mobile ? 'mobile' : 'desktop',
  };

  if (options.blockExternal) {
    await context.route('**/*', async (route) => {
      const requestUrl = route.request().url();
      if (classifyRequest(requestUrl, baseOrigin) === 'external') {
        result.externalRequests.push(requestUrl);
        await route.abort('blockedbyclient');
        return;
      }
      await route.continue();
    });
  }

  const page = await context.newPage();
  page.setDefaultTimeout(5000);
  page.on('console', (message) => {
    if (message.type() === 'error') {
      result.consoleErrors.push(message.text());
    }
  });
  page.on('pageerror', (error) => {
    result.pageErrors.push(error.message);
  });
  page.on('response', (response) => {
    const url = response.url();
    const status = response.status();
    if (status >= 400 && classifyRequest(url, baseOrigin) === 'local') {
      if (!url.endsWith('/favicon.ico')) {
        result.localFailures.push({ url, status });
      }
    }
  });
  page.on('requestfailed', (request) => {
    const url = request.url();
    if (classifyRequest(url, baseOrigin) === 'local') {
      const failure = request.failure()?.errorText || 'request failed';
      if (request.resourceType() === 'media' && failure === 'net::ERR_ABORTED') {
        return;
      }
      result.localFailures.push({
        url,
        failure,
      });
    }
  });

  try {
    const response = await page.goto(game.url, { waitUntil: 'domcontentloaded', timeout: 15000 });
    if (!response) {
      result.reasons.push('No main document response.');
    } else if (response.status() >= 400) {
      result.reasons.push(`Main document returned HTTP ${response.status()}.`);
    }

    await page.waitForTimeout(900);
    result.render = await collectRenderInfo(page);
    await performBasicInteractions(page, result);
    await performGameRecipe(page, result, game.id);
    if (options.mobile) {
      await performMobileInteractions(page, result);
    }
    await assertPageResponsive(page, result);
  } catch (error) {
    result.reasons.push(`Navigation or interaction failed: ${error.message}`);
  }

  dedupeResultDetails(result);
  applyResultStatus(result, options);

  if (result.status !== 'pass' || options.screenshotAll) {
    const screenshotPath = path.join(options.reportDir, 'screenshots', `${safeFilename(result.id)}.png`);
    await fs.mkdir(path.dirname(screenshotPath), { recursive: true });
    try {
      await page.screenshot({ path: screenshotPath, fullPage: true, timeout: 5000 });
      result.screenshot = screenshotPath;
    } catch (error) {
      result.reasons.push(`Could not capture screenshot: ${error.message}`);
    }
  }

  await context.close();
  return result;
}

async function collectRenderInfo(page) {
  return page.evaluate(() => {
    const isVisible = (element) => {
      const style = window.getComputedStyle(element);
      const rect = element.getBoundingClientRect();
      return style.visibility !== 'hidden'
        && style.display !== 'none'
        && rect.width > 0
        && rect.height > 0;
    };

    const canvases = Array.from(document.querySelectorAll('canvas'));
    const iframes = Array.from(document.querySelectorAll('iframe'));
    const interactive = Array.from(document.querySelectorAll('button, a, input, select, textarea, [role="button"]'));
    const images = Array.from(document.images);
    const bodyText = document.body ? document.body.innerText || '' : '';

    return {
      title: document.title || '',
      readyState: document.readyState,
      bodyTextLength: bodyText.trim().length,
      canvasCount: canvases.length,
      visibleCanvasCount: canvases.filter(isVisible).length,
      iframeCount: iframes.length,
      visibleIframeCount: iframes.filter(isVisible).length,
      imageCount: images.length,
      loadedImageCount: images.filter((img) => img.complete && img.naturalWidth > 0).length,
      interactiveCount: interactive.length,
      visibleInteractiveCount: interactive.filter(isVisible).length,
      bodyChildCount: document.body ? document.body.children.length : 0,
      looksLikeDirectoryIndex: /^Index of \//i.test(bodyText.trim()) || /^Index of \//i.test(document.title || ''),
    };
  });
}

async function performBasicInteractions(page, result) {
  const actions = [
    async () => clickFirstMatchingText(page, /new game|start game|start|play|begin|continue|restart/i),
    async () => clickFirstVisible(page, 'button, [role="button"], input[type="button"], input[type="submit"]'),
    async () => clickFirstVisible(page, 'canvas'),
    async () => clickViewportCenter(page),
    async () => pressKeys(page, ['Enter', 'Space', 'ArrowUp', 'ArrowRight', 'ArrowDown', 'ArrowLeft']),
  ];

  for (const action of actions) {
    try {
      const label = await action();
      if (label) result.interactions.push({ action: label, ok: true });
    } catch (error) {
      result.interactions.push({ action: 'basic interaction', ok: false, error: error.message });
    }
    await page.waitForTimeout(150);
  }
}

async function performGameRecipe(page, result, gameId) {
  const recipe = GAME_RECIPES[gameId] || [];
  for (const step of recipe) {
    try {
      if (step.type === 'keys') {
        await pressKeys(page, step.keys);
        result.interactions.push({ action: `recipe ${gameId}: pressed ${step.keys.join(', ')}`, ok: true });
      } else if (step.type === 'center-click') {
        const label = await clickViewportCenter(page);
        result.interactions.push({ action: `recipe ${gameId}: ${label}`, ok: true });
      } else if (step.type === 'click-text') {
        const label = await clickFirstMatchingText(page, new RegExp(escapeRegex(step.text), 'i'));
        result.interactions.push({ action: `recipe ${gameId}: ${label || `text not found: ${step.text}`}`, ok: Boolean(label) });
      } else if (step.type === 'canvas-click-ratio') {
        const label = await clickCanvasRatio(page, step.x, step.y);
        result.interactions.push({ action: `recipe ${gameId}: ${label}`, ok: true });
      } else if (step.type === 'wait') {
        await page.waitForTimeout(step.ms);
        result.interactions.push({ action: `recipe ${gameId}: waited ${step.ms}ms`, ok: true });
      } else if (step.type === 'game-call') {
        const called = await callGameHook(page, step.method, step.args || []);
        result.interactions.push({ action: `recipe ${gameId}: called ${step.method}`, ok: called });
      }
    } catch (error) {
      result.interactions.push({ action: `recipe ${gameId}`, ok: false, error: error.message });
    }
    await page.waitForTimeout(250);
  }
}

async function clickFirstMatchingText(page, matcher) {
  const handle = await page.evaluateHandle((source) => {
    const regex = new RegExp(source, 'i');
    const selectors = ['button', 'a', '[role="button"]', 'input[type="button"]', 'input[type="submit"]'];
    const nodes = selectors.flatMap((selector) => Array.from(document.querySelectorAll(selector)));
    const visible = (element) => {
      const style = window.getComputedStyle(element);
      const rect = element.getBoundingClientRect();
      return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
    };
    return nodes.find((node) => visible(node) && regex.test(node.innerText || node.value || node.textContent || '')) || null;
  }, matcher.source);

  const element = handle.asElement();
  if (!element) return null;
  await element.click({ timeout: 2000 });
  return 'clicked start/play-like control';
}

function escapeRegex(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

async function clickFirstVisible(page, selector) {
  const locator = page.locator(selector).filter({ hasNotText: /^\s*$/ }).first();
  const count = await page.locator(selector).count();
  if (count === 0) return null;
  try {
    await locator.click({ timeout: 2000, force: true });
    return `clicked ${selector}`;
  } catch {
    return null;
  }
}

async function clickViewportCenter(page) {
  const viewport = page.viewportSize();
  if (!viewport) return null;
  await page.mouse.click(Math.floor(viewport.width / 2), Math.floor(viewport.height / 2));
  return 'clicked viewport center';
}

async function clickCanvasRatio(page, xRatio, yRatio) {
  const canvas = page.locator('canvas').first();
  await canvas.waitFor({ state: 'visible', timeout: 2000 });
  const box = await canvas.boundingBox();
  if (!box) return 'canvas not found';
  await page.mouse.click(
    Math.floor(box.x + box.width * xRatio),
    Math.floor(box.y + box.height * yRatio),
  );
  return `clicked canvas at ${xRatio}, ${yRatio}`;
}

async function callGameHook(page, method, args) {
  return page.evaluate(({ methodName, methodArgs }) => {
    const api = window.__lanArcadeGame;
    if (!api || typeof api[methodName] !== 'function') return false;
    api[methodName](...(Array.isArray(methodArgs) ? methodArgs : []));
    return true;
  }, { methodName: method, methodArgs: args });
}

async function pressKeys(page, keys) {
  for (const key of keys) {
    await page.keyboard.press(key);
  }
  return `pressed ${keys.join(', ')}`;
}

async function performMobileInteractions(page, result) {
  const actions = [
    async () => tapViewportCenter(page),
    async () => dragViewport(page, 0.75, 0.5, 0.25, 0.5, 'swiped left'),
    async () => dragViewport(page, 0.25, 0.5, 0.75, 0.5, 'swiped right'),
    async () => dragViewport(page, 0.5, 0.75, 0.5, 0.25, 'swiped up'),
    async () => dragViewport(page, 0.5, 0.25, 0.5, 0.75, 'swiped down'),
  ];

  for (const action of actions) {
    try {
      const label = await action();
      if (label) result.interactions.push({ action: label, ok: true });
    } catch (error) {
      result.interactions.push({ action: 'mobile interaction', ok: false, error: error.message });
    }
    await page.waitForTimeout(150);
  }
}

async function tapViewportCenter(page) {
  const viewport = page.viewportSize();
  if (!viewport) return null;
  await page.touchscreen.tap(Math.floor(viewport.width / 2), Math.floor(viewport.height / 2));
  return 'touch tapped viewport center';
}

async function dragViewport(page, startXRatio, startYRatio, endXRatio, endYRatio, label) {
  const viewport = page.viewportSize();
  if (!viewport) return null;
  const startX = Math.floor(viewport.width * startXRatio);
  const startY = Math.floor(viewport.height * startYRatio);
  const endX = Math.floor(viewport.width * endXRatio);
  const endY = Math.floor(viewport.height * endYRatio);
  await page.mouse.move(startX, startY);
  await page.mouse.down();
  await page.mouse.move(endX, endY, { steps: 12 });
  await page.mouse.up();
  return label;
}

async function assertPageResponsive(page, result) {
  try {
    const responsive = await page.evaluate(() => new Promise((resolve) => {
      window.requestAnimationFrame(() => {
        window.setTimeout(() => resolve(document.readyState), 100);
      });
    }));
    result.interactions.push({ action: `responsiveness check (${responsive})`, ok: true });
  } catch (error) {
    result.reasons.push(`Page became non-responsive: ${error.message}`);
  }
}

function dedupeResultDetails(result) {
  result.consoleErrors = [...new Set(result.consoleErrors)];
  result.pageErrors = [...new Set(result.pageErrors)];
  result.externalRequests = [...new Set(result.externalRequests)];

  const seenFailures = new Set();
  result.localFailures = result.localFailures.filter((failure) => {
    const key = `${failure.url}|${failure.status || ''}|${failure.failure || ''}`;
    if (seenFailures.has(key)) return false;
    seenFailures.add(key);
    return true;
  });
}

function applyResultStatus(result, options) {
  const render = result.render || {};
  const hasRenderEvidence = render.visibleCanvasCount > 0
    || render.visibleIframeCount > 0
    || render.visibleInteractiveCount > 0
    || render.loadedImageCount > 0
    || render.bodyTextLength > 25;

  if (!hasRenderEvidence) {
    result.reasons.push('No strong render evidence after load.');
  }
  if (render.looksLikeDirectoryIndex) {
    result.reasons.push('Loaded a web server directory listing, not a playable game.');
  }
  if (result.pageErrors.length > 0) {
    result.reasons.push(`${result.pageErrors.length} page error(s).`);
  }
  if (result.localFailures.length > 0) {
    result.reasons.push(`${result.localFailures.length} local request failure(s).`);
  }
  if (options.blockExternal && result.externalRequests.length > 0) {
    result.reasons.push(`${result.externalRequests.length} blocked external request(s).`);
  }

  result.strictStatus = result.reasons.length === 0 ? 'pass' : 'fail';
  result.playabilityStatus = classifyPlayability(result, hasRenderEvidence);
  result.status = result.strictStatus;
}

function classifyPlayability(result, hasRenderEvidence) {
  const notes = result.playabilityNotes;
  const mainDocumentFailed = result.reasons.some((reason) => reason.startsWith('Main document returned HTTP'));
  const nonResponsive = result.reasons.some((reason) => reason.startsWith('Page became non-responsive'));
  const directoryIndex = result.reasons.some((reason) => reason.includes('directory listing'));

  if (mainDocumentFailed || nonResponsive || directoryIndex || !hasRenderEvidence) {
    if (mainDocumentFailed) notes.push('main document did not load');
    if (nonResponsive) notes.push('page became non-responsive');
    if (directoryIndex) notes.push('opened directory listing instead of game');
    if (!hasRenderEvidence) notes.push('no strong render evidence');
    return 'blocker';
  }

  if (result.strictStatus === 'pass') {
    notes.push('strict offline checks passed');
    return 'playable';
  }

  if (result.pageErrors.length > 0) {
    notes.push('runtime errors need cleanup');
  }
  if (result.localFailures.length > 0) {
    notes.push('missing local assets or requests');
  }
  if (result.externalRequests.length > 0) {
    notes.push('external requests blocked offline');
  }
  if (notes.length === 0) {
    notes.push('rendered but strict checks found issues');
  }
  return 'warning';
}

async function writeReports(results, options) {
  await fs.mkdir(options.reportDir, { recursive: true });

  const summary = {
    generatedAt: new Date().toISOString(),
    baseUrl: options.baseUrl,
    browser: options.browserName,
    profile: options.mobile ? 'mobile' : 'desktop',
    blockExternal: options.blockExternal,
    total: results.length,
    passed: results.filter((result) => result.status === 'pass').length,
    failed: results.filter((result) => result.status !== 'pass').length,
    playable: results.filter((result) => result.playabilityStatus === 'playable').length,
    warnings: results.filter((result) => result.playabilityStatus === 'warning').length,
    blockers: results.filter((result) => result.playabilityStatus === 'blocker').length,
  };

  await fs.writeFile(
    path.join(options.reportDir, 'smoke-report.json'),
    `${JSON.stringify({ summary, results }, null, 2)}\n`,
  );

  const lines = [
    '# LAN Arcade Smoke Report',
    '',
    `Generated: ${summary.generatedAt}`,
    `Base URL: ${summary.baseUrl}`,
    `Browser: ${summary.browser}`,
    `Profile: ${summary.profile}`,
    `External requests blocked: ${summary.blockExternal ? 'yes' : 'no'}`,
    '',
    `Strict result: ${summary.passed}/${summary.total} passed`,
    `Playability: ${summary.playable} playable, ${summary.warnings} playable with warnings, ${summary.blockers} blockers`,
    '',
    '| Strict | Playability | Game | Notes |',
    '| --- | --- | --- | --- |',
  ];

  for (const result of results) {
    const notes = markdownNotesFor(result);
    lines.push(`| ${result.strictStatus} | ${result.playabilityStatus} | [${result.title || result.id}](${result.url}) | ${notes} |`);
  }

  await fs.writeFile(path.join(options.reportDir, 'smoke-report.md'), `${lines.join('\n')}\n`);
}

function markdownNotesFor(result) {
  if (result.reasons.length === 0) return 'OK';

  const notes = result.reasons.map((reason) => reason.replace(/\|/g, '\\|'));
  const examples = [];

  if (result.playabilityNotes.length > 0) {
    examples.push(`playability: ${result.playabilityNotes.join(', ')}`);
  }

  if (result.localFailures.length > 0) {
    examples.push(`local: ${shortUrl(result.localFailures[0].url)} (${result.localFailures[0].status || result.localFailures[0].failure})`);
  }
  if (result.externalRequests.length > 0) {
    examples.push(`external: ${shortUrl(result.externalRequests[0])}`);
  }
  if (result.pageErrors.length > 0) {
    examples.push(`error: ${result.pageErrors[0].slice(0, 100)}`);
  }

  if (examples.length > 0) {
    notes.push(`Examples: ${examples.map((example) => example.replace(/\|/g, '\\|')).join('; ')}`);
  }

  return notes.join('<br>');
}

function shortUrl(value) {
  try {
    const parsed = new URL(value);
    return `${parsed.origin}${parsed.pathname}`;
  } catch {
    return String(value);
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const browserType = browserTypeFor(options.browserName);
  await fs.rm(options.reportDir, { recursive: true, force: true });
  await fs.mkdir(options.reportDir, { recursive: true });
  const browser = await browserType.launch({ headless: !options.headed });

  try {
    const games = await discoverGames(browser, options);
    if (games.length === 0) {
      throw new Error(`No games discovered from ${options.baseUrl}`);
    }

    console.log(`Discovered ${games.length} game(s) from ${options.baseUrl}`);
    const results = [];
    for (const [index, game] of games.entries()) {
      process.stdout.write(`[${index + 1}/${games.length}] ${game.id} ... `);
      const result = await testGame(browser, game, options);
      results.push(result);
      await writeReports(results, options);
      console.log(`strict=${result.strictStatus} playability=${result.playabilityStatus}`);
    }

    await writeReports(results, options);
    const failed = results.filter((result) => result.status !== 'pass');
    const playable = results.filter((result) => result.playabilityStatus === 'playable');
    const warnings = results.filter((result) => result.playabilityStatus === 'warning');
    const blockers = results.filter((result) => result.playabilityStatus === 'blocker');
    console.log(`\nSmoke report written to ${options.reportDir}`);
    console.log(`Strict: ${results.length - failed.length}/${results.length} passed`);
    console.log(`Playability: ${playable.length} playable, ${warnings.length} warning, ${blockers.length} blocker`);

    if (failed.length > 0) {
      process.exitCode = 1;
    }
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
