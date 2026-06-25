#!/usr/bin/env node
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import { chromium } from 'playwright';

const args = process.argv.slice(2);
function argValue(name, fallback = undefined) {
  const prefix = `${name}=`;
  const hit = args.find((arg) => arg.startsWith(prefix));
  if (hit) return hit.slice(prefix.length);
  const idx = args.indexOf(name);
  if (idx >= 0 && idx + 1 < args.length) return args[idx + 1];
  return fallback;
}
function hasArg(name) { return args.includes(name); }

const manifestPath = argValue('--manifest', '/var/www/html/mirrors/private-rom-vault/manifest.json');
const baseUrl = argValue('--base-url', 'http://127.0.0.1/mirrors/private-rom-vault');
const reportRoot = argValue('--report-root', '/var/www/html/mirrors/private-rom-vault/reports');
const runIdArg = argValue('--run-id', '');
const limit = Number(argValue('--limit', '0')) || 0;
const startAt = Number(argValue('--start-at', '0')) || 0;
const only = argValue('--only', '').split(',').map((s) => s.trim()).filter(Boolean);
const screenshotMode = argValue('--screenshots', 'three');
const resume = hasArg('--resume');
const stamp = runIdArg || new Date().toISOString().replace(/[-:.]/g, '').slice(0, 15) + 'Z';
const reportDir = path.join(reportRoot, `run-${stamp}`);
const screenshotDir = path.join(reportDir, 'screenshots');
const statePath = path.join(reportDir, 'state.json');
const jsonPath = path.join(reportDir, 'report.json');
const htmlPath = path.join(reportDir, 'report.html');
const latestPath = path.join(reportRoot, 'latest.html');
const latestJsonPath = path.join(reportRoot, 'latest.json');
const summaryPath = path.join(reportRoot, 'qa-summary.html');
const latestRunPath = path.join(reportRoot, 'latest-run.txt');

await fs.mkdir(screenshotDir, { recursive: true });
const manifest = JSON.parse(await fs.readFile(manifestPath, 'utf8'));
let games = manifest.games || [];
if (only.length) games = games.filter((g) => only.includes(g.id) || only.includes(g.title));
if (startAt > 0) games = games.slice(startAt);
if (limit > 0) games = games.slice(0, limit);

let results = [];
if (resume) {
  try {
    const prior = JSON.parse(await fs.readFile(jsonPath, 'utf8'));
    results = prior.results || [];
  } catch {}
}
const completed = new Set(results.map((r) => r.id));

const keyPlanStart = ['Enter', 'Enter', 'z', 'z', 'x', 'Enter', 'ArrowDown', 'z', 'Enter'];
const keyPlanPlay = [
  'ArrowRight', 'ArrowRight', 'z', 'ArrowDown', 'x', 'ArrowLeft', 'z', 'ArrowUp',
  'ArrowRight', 'ArrowDown', 'z', 'ArrowLeft', 'x', 'ArrowUp', 'Enter', 'z',
];

function sha(buf) { return crypto.createHash('sha256').update(buf).digest('hex'); }
function esc(s) { return String(s ?? '').replace(/[&<>"']/g, (c) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
function fmtBytes(n) { return n < 1048576 ? `${Math.round(n / 1024)} KB` : `${(n / 1048576).toFixed(1)} MB`; }
function rel(file) { return path.relative(reportDir, file).replaceAll(path.sep, '/'); }
function sleep(ms) { return new Promise((resolve) => setTimeout(resolve, ms)); }

function paethPredictor(left, up, upLeft) {
  const p = left + up - upLeft;
  const pa = Math.abs(p - left);
  const pb = Math.abs(p - up);
  const pc = Math.abs(p - upLeft);
  if (pa <= pb && pa <= pc) return left;
  if (pb <= pc) return up;
  return upLeft;
}

function pngVisualStats(buf) {
  const sig = '89504e470d0a1a0a';
  if (buf.subarray(0, 8).toString('hex') !== sig) return { ok: false, reason: 'not-png' };
  let offset = 8;
  let width = 0;
  let height = 0;
  let bitDepth = 0;
  let colorType = 0;
  const idats = [];
  while (offset + 12 <= buf.length) {
    const length = buf.readUInt32BE(offset);
    const type = buf.subarray(offset + 4, offset + 8).toString('ascii');
    const data = buf.subarray(offset + 8, offset + 8 + length);
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8];
      colorType = data[9];
    } else if (type === 'IDAT') {
      idats.push(data);
    } else if (type === 'IEND') {
      break;
    }
    offset += 12 + length;
  }
  const channelsByType = { 0: 1, 2: 3, 4: 2, 6: 4 };
  const channels = channelsByType[colorType];
  if (!width || !height || bitDepth !== 8 || !channels || !idats.length) {
    return { ok: false, reason: `unsupported-png-${width}x${height}-bd${bitDepth}-ct${colorType}` };
  }
  const raw = zlib.inflateSync(Buffer.concat(idats));
  const stride = width * channels;
  let src = 0;
  let prev = Buffer.alloc(stride);
  let row = Buffer.alloc(stride);
  let sum = 0;
  let min = 255;
  let max = 0;
  let samples = 0;
  const buckets = new Set();
  const stepX = Math.max(1, Math.floor(width / 192));
  const stepY = Math.max(1, Math.floor(height / 144));
  for (let y = 0; y < height; y += 1) {
    const filter = raw[src++];
    const scan = raw.subarray(src, src + stride);
    src += stride;
    for (let x = 0; x < stride; x += 1) {
      const left = x >= channels ? row[x - channels] : 0;
      const up = prev[x];
      const upLeft = x >= channels ? prev[x - channels] : 0;
      let value = scan[x];
      if (filter === 1) value += left;
      else if (filter === 2) value += up;
      else if (filter === 3) value += Math.floor((left + up) / 2);
      else if (filter === 4) value += paethPredictor(left, up, upLeft);
      row[x] = value & 255;
    }
    if ((y % stepY) === 0) {
      for (let x = 0; x < width; x += stepX) {
        const px = x * channels;
        const r = row[px];
        const g = colorType === 0 ? r : row[px + 1];
        const b = colorType === 0 ? r : row[px + 2];
        const luma = Math.round((r + g + b) / 3);
        sum += luma;
        min = Math.min(min, luma);
        max = Math.max(max, luma);
        buckets.add(`${r >> 4},${g >> 4},${b >> 4}`);
        samples += 1;
      }
    }
    const tmp = prev;
    prev = row;
    row = tmp;
  }
  return { ok: true, width, height, meanLuma: +(sum / Math.max(1, samples)).toFixed(2), minLuma: min, maxLuma: max, colorBuckets: buckets.size, samples };
}

async function pageScreenshot(page, file) {
  const target = page.locator('#game');
  const count = await target.count().catch(() => 0);
  const buf = count ? await target.screenshot({ path: file }) : await page.screenshot({ path: file, fullPage: false });
  return { file: rel(file), bytes: buf.length, sha256: sha(buf), visual: pngVisualStats(buf) };
}

async function canvasStats(page) {
  return await page.evaluate(() => {
    const canvas = document.querySelector('canvas');
    if (!canvas) return { ok: false, reason: 'no-canvas' };
    try {
      const small = document.createElement('canvas');
      small.width = 64; small.height = 64;
      const ctx = small.getContext('2d', { willReadFrequently: true });
      ctx.drawImage(canvas, 0, 0, 64, 64);
      const data = ctx.getImageData(0, 0, 64, 64).data;
      let sum = 0, min = 255, max = 0;
      const buckets = new Set();
      for (let i = 0; i < data.length; i += 4) {
        const l = Math.round((data[i] + data[i + 1] + data[i + 2]) / 3);
        sum += l; min = Math.min(min, l); max = Math.max(max, l);
        buckets.add(`${data[i] >> 4},${data[i + 1] >> 4},${data[i + 2] >> 4}`);
      }
      return { ok: true, width: canvas.width, height: canvas.height, meanLuma: +(sum / 4096).toFixed(2), minLuma: min, maxLuma: max, colorBuckets: buckets.size };
    } catch (error) {
      return { ok: false, reason: String(error).slice(0, 300), width: canvas.width, height: canvas.height };
    }
  });
}

async function pressPlan(page, plan, delay = 270) {
  for (const key of plan) {
    await page.keyboard.press(key).catch(() => {});
    await page.waitForTimeout(delay);
  }
}

function isBlankVisualStats(stats) {
  if (!stats || !stats.ok) return false;
  const range = Number(stats.maxLuma || 0) - Number(stats.minLuma || 0);
  return Number(stats.colorBuckets || 0) <= 3 && range < 10;
}

async function testGame(browser, game, index, total) {
  const id = game.id;
  const dir = path.join(screenshotDir, id);
  await fs.mkdir(dir, { recursive: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 1024 }, deviceScaleFactor: 1 });
  page.setDefaultTimeout(45000);
  const externalRequests = [];
  const requestFailures = [];
  const consoleMessages = [];
  const pageErrors = [];
  page.on('console', (msg) => {
    if (['error', 'warning'].includes(msg.type())) consoleMessages.push({ type: msg.type(), text: msg.text().slice(0, 500) });
  });
  page.on('pageerror', (err) => {
    const text = String(err?.stack || err).slice(0, 500);
    if (/Wake Lock permission request denied|NotAllowedError/i.test(text)) return;
    pageErrors.push(text);
  });
  page.on('requestfailed', (req) => {
    const url = req.url();
    if (!url.includes('/favicon')) requestFailures.push({ url, failure: req.failure()?.errorText || 'failed' });
  });
  const allowedHosts = new Set(['127.0.0.1', 'localhost', '192.168.1.106', new URL(baseUrl).hostname]);
  await page.route('**/*', async (route) => {
    const url = new URL(route.request().url());
    const local = allowedHosts.has(url.hostname);
    if (!local && url.protocol.startsWith('http')) {
      externalRequests.push(route.request().url());
      await route.abort();
      return;
    }
    await route.continue();
  });
  const started = Date.now();
  const url = `${baseUrl}/play.html?id=${encodeURIComponent(id)}`;
  const result = {
    index,
    total,
    id,
    title: game.title,
    system: game.system,
    url,
    source: game.source,
    selectionReason: game.selectionReason,
    regions: game.regions || [],
    languages: game.languages || [],
    genres: game.genres || [],
    bytes: game.bytes,
    sha256: game.sha256,
    originalPath: game.originalPath,
    startedAt: new Date().toISOString(),
    externalRequests,
    requestFailures,
    consoleMessages,
    pageErrors,
  };
  try {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });
    await page.waitForSelector('canvas', { timeout: 45000 });
    await page.waitForTimeout(9000);
    const bootStats = await canvasStats(page);
    const boot = await pageScreenshot(page, path.join(dir, '01-boot.png'));
    await page.locator('#game').click({ position: { x: 420, y: 360 } }).catch(async () => page.mouse.click(640, 500));
    await pressPlan(page, keyPlanStart, 320);
    await page.waitForTimeout(5000);
    const startStats = await canvasStats(page);
    const afterStart = await pageScreenshot(page, path.join(dir, '02-after-start.png'));
    await pressPlan(page, keyPlanPlay, 260);
    await page.waitForTimeout(5000);
    const playStats = await canvasStats(page);
    const afterPlay = screenshotMode === 'one' ? null : await pageScreenshot(page, path.join(dir, '03-after-play.png'));
    const dom = await page.evaluate(() => ({
      title: document.title,
      canvasCount: document.querySelectorAll('canvas').length,
      ejsStarted: !!window.EJS_emulator,
      jsDosStarted: !!window.Dos && !!document.querySelector('#game canvas'),
      playerText: document.querySelector('#game')?.innerText?.slice(0, 500) || '',
      bodyTextLength: document.body.innerText.length,
    }));
    const screenshots = { boot, afterStart };
    if (afterPlay) screenshots.afterPlay = afterPlay;
    const hashes = Object.values(screenshots).map((s) => s.sha256);
    const screenshotChanged = new Set(hashes).size > 1;
    const statsChanged = JSON.stringify(boot.visual) !== JSON.stringify(afterStart.visual) || (afterPlay && JSON.stringify(afterStart.visual) !== JSON.stringify(afterPlay.visual));
    const visualBlank = Object.values(screenshots).every((s) => isBlankVisualStats(s.visual));
    const tinyStillScreenshots = Object.values(screenshots).every((s) => s.bytes < 8000) && !screenshotChanged;
    const blankRisk = visualBlank || tinyStillScreenshots;
    const playerStarted = dom.ejsStarted || dom.jsDosStarted;
    const loadProblems = pageErrors.length || requestFailures.length || externalRequests.length || dom.canvasCount < 1 || !playerStarted;
    const languageRisk = !(game.languages || []).includes('En') || (game.source || '').includes('translation') || (game.selectionReason || '').includes('translation');
    let verdict = 'playable-smoke';
    let reason = 'Booted in the browser player, stayed offline, no page crash, and screenshots changed after input.';
    if (loadProblems) {
      verdict = 'failed';
      reason = 'Load/runtime/network problem recorded.';
    } else if (blankRisk) {
      verdict = 'failed-black-screen';
      reason = 'Browser player shell loaded, but the sampled game canvas stayed visually blank.';
    } else if (!screenshotChanged && !statsChanged) {
      verdict = 'needs-manual-input';
      reason = 'Booted cleanly but the generic start/play input did not visibly change the screenshots.';
    } else if (languageRisk) {
      verdict = 'playable-language-review';
      reason = 'Playable smoke passed, but metadata comes from a translation or non-default language bucket; screenshot should be reviewed.';
    }
    Object.assign(result, {
      durationMs: Date.now() - started,
      screenshots,
      screenshotChanged,
      canvas: { boot: bootStats, afterStart: startStats, afterPlay: playStats },
      dom,
      blankRisk,
      statsChanged,
      languageRisk,
      verdict,
      reason,
    });
  } catch (error) {
    Object.assign(result, {
      durationMs: Date.now() - started,
      verdict: 'error',
      reason: 'Exception while loading or driving the game.',
      error: String(error?.stack || error).slice(0, 2000),
    });
  } finally {
    await page.close().catch(() => {});
  }
  return result;
}

function verdictClass(v) {
  if (v === 'playable-smoke') return 'ok';
  if (v === 'playable-language-review') return 'warn';
  if (v === 'failed-black-screen') return 'bad';
  if (v === 'needs-manual-input' || v === 'needs-review') return 'review';
  return 'bad';
}

async function writeReports(inProgress = true) {
  const counts = results.reduce((acc, r) => { acc[r.verdict] = (acc[r.verdict] || 0) + 1; return acc; }, {});
  const report = {
    generatedAt: new Date().toISOString(),
    runId: stamp,
    baseUrl,
    manifestPath,
    reportDir,
    status: inProgress ? 'in-progress' : 'complete',
    tested: results.length,
    planned: games.length,
    counts,
    selectionPolicy: manifest.selectionPolicy,
    manifestCounts: manifest.counts,
    results,
  };
  await fs.writeFile(jsonPath, JSON.stringify(report, null, 2));
  await fs.writeFile(statePath, JSON.stringify({ updatedAt: report.generatedAt, status: report.status, tested: report.tested, planned: report.planned, counts }, null, 2));
  const rows = results.map((r) => {
    const shot = r.screenshots || {};
    const imgs = [shot.boot, shot.afterStart, shot.afterPlay].filter(Boolean).map((s) => `<a href="${esc(s.file)}"><img loading="lazy" src="${esc(s.file)}" alt="${esc(r.title)} screenshot"></a>`).join('');
    return `<article class="game ${verdictClass(r.verdict)}"><div class="head"><h2>${esc(r.index + 1)}. ${esc(r.title)}</h2><span>${esc(r.verdict)}</span></div><div class="meta"><b>${esc(r.system)}</b> ? ${esc((r.genres || []).join(', '))} ? ${esc((r.regions || []).join(', '))} ? ${esc((r.languages || []).join(', '))} ? ${fmtBytes(r.bytes || 0)}</div><p>${esc(r.reason || '')}</p><div class="thumbs">${imgs || '<em>No screenshots captured</em>'}</div><details><summary>Technical details</summary><pre>${esc(JSON.stringify({id:r.id, source:r.source, selectionReason:r.selectionReason, originalPath:r.originalPath, screenshotChanged:r.screenshotChanged, statsChanged:r.statsChanged, blankRisk:r.blankRisk, languageRisk:r.languageRisk, canvas:r.canvas, externalRequests:r.externalRequests, requestFailures:r.requestFailures, pageErrors:r.pageErrors, consoleMessages:(r.consoleMessages||[]).slice(0,4), error:r.error}, null, 2))}</pre></details></article>`;
  }).join('\n');
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Private Emulator Vault Playtest ${esc(stamp)}</title><style>
    :root{color-scheme:dark;--bg:#090d12;--panel:#121922;--line:#314357;--text:#edf5ff;--muted:#9fb0c4;--ok:#35d07f;--warn:#ffca55;--bad:#ff6b6b;--review:#7dd3fc}*{box-sizing:border-box}body{margin:0;background:#090d12;color:var(--text);font-family:system-ui,-apple-system,Segoe UI,sans-serif}header{position:sticky;top:0;background:rgba(9,13,18,.96);border-bottom:1px solid var(--line);z-index:5}.bar{width:min(1500px,96vw);margin:0 auto;padding:14px 0;display:grid;gap:8px}h1{margin:0;font-size:clamp(24px,3vw,40px)}p{color:var(--muted);line-height:1.45}.counts{display:flex;flex-wrap:wrap;gap:8px}.pill{border:1px solid var(--line);background:#151f2b;border-radius:999px;padding:6px 10px}.pill b{color:#fff}main{width:min(1500px,96vw);margin:0 auto;padding:14px 0 40px}.game{border:1px solid var(--line);background:var(--panel);border-radius:8px;margin:0 0 12px;overflow:hidden}.head{display:flex;justify-content:space-between;gap:12px;align-items:start;padding:12px;border-bottom:1px solid var(--line)}.head h2{font-size:18px;margin:0}.head span{font-weight:900;text-transform:uppercase;font-size:12px;border-radius:999px;padding:5px 8px;background:#1d2937;white-space:nowrap}.ok .head span{color:#a7f3d0}.warn .head span{color:#fde68a}.review .head span{color:#bae6fd}.bad .head span{color:#fecaca}.meta{padding:9px 12px;color:var(--muted);font-size:13px;border-bottom:1px solid rgba(49,67,87,.55)}.game p{padding:0 12px;margin:10px 0}.thumbs{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;padding:0 12px 12px}.thumbs img{width:100%;height:220px;object-fit:contain;background:#020617;border:1px solid #26374a;border-radius:6px}details{border-top:1px solid rgba(49,67,87,.55);padding:10px 12px}summary{cursor:pointer;color:#c9d8ea;font-weight:800}pre{white-space:pre-wrap;overflow:auto;color:#cbd5e1;background:#071019;border:1px solid #26374a;border-radius:6px;padding:10px}@media(max-width:860px){.thumbs{grid-template-columns:1fr}.head{display:block}.head span{display:inline-block;margin-top:8px}.thumbs img{height:auto}}
  </style></head><body><header><div class="bar"><h1>Private Emulator Vault Playtest</h1><p>Run ${esc(stamp)} | ${esc(report.status)} | ${results.length} of ${games.length} games tested. This is a one-by-one EmulatorJS smoke/play run with network blocked outside the LAN host. Language is screened from ROM archive metadata, with screenshots included for visual review.</p><div class="counts">${Object.entries(counts).map(([k,v])=>`<span class="pill"><b>${v}</b> ${esc(k)}</span>`).join('')}<span class="pill"><b>${games.length}</b> planned</span></div></div></header><main>${rows || '<p>No results yet.</p>'}</main></body></html>`;
  const summaryRows = Object.entries(counts).sort((a, b) => b[1] - a[1]).map(([name, value]) => `<tr><td>${esc(name)}</td><td>${value}</td></tr>`).join('');
  const summaryHtml = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Private Vault QA Summary</title><style>body{margin:0;background:#090d12;color:#edf5ff;font-family:system-ui}main{max-width:920px;margin:0 auto;padding:36px 20px}a{color:#8ecbff}p,td{color:#9fb0c4}table{width:100%;border-collapse:collapse;background:#121922;border:1px solid #314357}td,th{padding:10px;border-bottom:1px solid #314357;text-align:left}.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:10px}.card{border:1px solid #314357;background:#121922;border-radius:8px;padding:14px}.card strong{display:block;font-size:28px;color:#fff}</style></head><body><main><h1>Private Vault QA Summary</h1><p>Run ${esc(stamp)} is ${esc(report.status)}.</p><div class="cards"><div class="card"><strong>${report.tested}</strong> tested</div><div class="card"><strong>${report.planned}</strong> planned</div><div class="card"><strong>${counts['playable-smoke'] || 0}</strong> playable smoke</div><div class="card"><strong>${(counts.failed || 0) + (counts['failed-black-screen'] || 0) + (counts.error || 0)}</strong> failed/error</div></div><p><a href="latest.html">Open visual report</a> | <a href="../">Back to vault</a></p><table><thead><tr><th>Verdict</th><th>Count</th></tr></thead><tbody>${summaryRows}</tbody></table></main></body></html>`;
  await fs.writeFile(htmlPath, html);
  await fs.mkdir(reportRoot, { recursive: true });
  await fs.writeFile(latestRunPath, stamp + '\n');
  await fs.writeFile(summaryPath, summaryHtml);
  await fs.copyFile(htmlPath, latestPath).catch(() => {});
  await fs.copyFile(jsonPath, latestJsonPath).catch(() => {});
}

console.log(`[private-vault] run ${stamp}`);
console.log(`[private-vault] report ${htmlPath}`);
await writeReports(true);
let browser = await chromium.launch({ headless: true, args: ['--disable-dev-shm-usage'] });
try {
  for (let i = 0; i < games.length; i += 1) {
    const game = games[i];
    if (completed.has(game.id)) {
      console.log(`[private-vault] ${i + 1}/${games.length} ${game.title} ... skipped`);
      continue;
    }
    process.stdout.write(`[private-vault] ${i + 1}/${games.length} ${game.title} ... `);
    const result = await testGame(browser, game, i, games.length);
    results.push(result);
    console.log(`${result.verdict} (${Math.round(result.durationMs / 1000)}s)`);
    await writeReports(true);
    if ((results.length % 40) === 0) {
      await browser.close().catch(() => {});
      await sleep(1000);
      browser = await chromium.launch({ headless: true, args: ['--disable-dev-shm-usage'] });
    }
  }
} finally {
  await browser.close().catch(() => {});
}
await writeReports(false);
console.log(`[private-vault] complete ${htmlPath}`);
