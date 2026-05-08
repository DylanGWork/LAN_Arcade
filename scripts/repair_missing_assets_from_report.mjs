#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const DEFAULT_REPORT = 'qa/reports/latest/smoke-report.json';
const DEFAULT_META = 'games.meta.sh';
const DEFAULT_MIRRORS_DIR = process.env.MIRRORS_DIR || '/var/www/html/mirrors';
const DEFAULT_WEB_ROOT = process.env.WEB_ROOT || '/var/www/html';

function parseArgs(argv) {
  const options = {
    report: process.env.ARCADE_QA_REPORT || DEFAULT_REPORT,
    meta: DEFAULT_META,
    mirrorsDir: DEFAULT_MIRRORS_DIR,
    webRoot: DEFAULT_WEB_ROOT,
    dryRun: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    if (arg === '--report' && next) {
      options.report = next;
      i += 1;
    } else if (arg === '--meta' && next) {
      options.meta = next;
      i += 1;
    } else if (arg === '--mirrors-dir' && next) {
      options.mirrorsDir = next;
      i += 1;
    } else if (arg === '--web-root' && next) {
      options.webRoot = next;
      i += 1;
    } else if (arg === '--dry-run') {
      options.dryRun = true;
    } else if (arg === '--help' || arg === '-h') {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown or incomplete argument: ${arg}`);
    }
  }

  return options;
}

function printHelp() {
  console.log(`Repair LAN Arcade missing runtime assets from a smoke report.

Usage:
  node scripts/repair_missing_assets_from_report.mjs --report qa/reports/full-catalog-review-desktop/smoke-report.json

Options:
  --report <path>       Smoke report JSON. Default: ${DEFAULT_REPORT}
  --meta <path>         games.meta.sh path. Default: ${DEFAULT_META}
  --mirrors-dir <path>  Mirrors directory. Default: ${DEFAULT_MIRRORS_DIR}
  --web-root <path>     Web root for root-relative assets. Default: ${DEFAULT_WEB_ROOT}
  --dry-run             Print planned downloads without writing files.
`);
}

async function readJson(file) {
  return JSON.parse(await fs.readFile(file, 'utf8'));
}

async function readSources(metaFile) {
  const raw = await fs.readFile(metaFile, 'utf8');
  const block = raw.match(/declare\s+-A\s+GAMES=\(([\s\S]*?)\n\)/);
  if (!block) throw new Error(`Could not find GAMES block in ${metaFile}`);

  const sources = new Map();
  const entryRe = /\["([^"]+)"\]="([^"]+)"/g;
  let match;
  while ((match = entryRe.exec(block[1]))) {
    sources.set(match[1], match[2]);
  }
  return sources;
}

function sourceCandidates(source, relPath) {
  if (!source || !relPath) return [];
  const cleanRel = relPath.replace(/^\/+/, '');

  if (source === 'ZIP_GITHUB_REPO') {
    return [`https://raw.githubusercontent.com/KDvs123/Typing-Test/main/${cleanRel}`];
  }

  for (const prefix of ['GIT_GITHUB_REPO::', 'ZIP_GITHUB_REPO::']) {
    if (source.startsWith(prefix)) {
      const spec = source.slice(prefix.length);
      const [repo, branch = 'main'] = spec.split('::');
      if (!repo) return [];
      return [`https://raw.githubusercontent.com/${repo}/${branch}/${cleanRel}`];
    }
  }

  if (source.startsWith('ZIP_GITHUB_FILE::')) {
    return [];
  }

  if (source.startsWith('http://') || source.startsWith('https://')) {
    const base = source.endsWith('/') ? source : `${source}/`;
    const url = new URL(cleanRel, base).href;
    const originUrl = new URL(source);
    const originCandidate = `${originUrl.origin}/${cleanRel}`;
    return [...new Set([url, originCandidate])];
  }

  return [];
}

function localRequestInfo(result, failure, options) {
  let parsed;
  try {
    parsed = new URL(failure.url);
  } catch {
    return null;
  }

  const gamePrefix = `/mirrors/${result.id}/`;
  const pathname = decodeURIComponent(parsed.pathname);
  let localPath;
  let relPath;

  if (pathname.startsWith(gamePrefix)) {
    relPath = pathname.slice(gamePrefix.length);
    localPath = path.join(options.mirrorsDir, result.id, relPath);
  } else if (pathname.startsWith('/mirrors/')) {
    relPath = pathname.slice('/mirrors/'.length);
    localPath = path.join(options.mirrorsDir, relPath);
  } else if (pathname.startsWith('/')) {
    relPath = pathname.slice(1);
    localPath = path.join(options.webRoot, relPath);
  } else {
    return null;
  }

  return {
    localPath: stripQueryFilename(localPath),
    relPath: stripQueryFilename(relPath),
  };
}

function stripQueryFilename(value) {
  return value.replace(/[?#].*$/, '');
}

async function exists(file) {
  try {
    await fs.access(file);
    return true;
  } catch {
    return false;
  }
}

async function copyQueryFilenameVariant(localPath, dryRun) {
  const dir = path.dirname(localPath);
  const base = path.basename(localPath);
  let entries;
  try {
    entries = await fs.readdir(dir);
  } catch {
    return false;
  }

  const variant = entries.find((entry) => entry.startsWith(`${base}?`) || entry.startsWith(`${base}%3F`));
  if (!variant) return false;

  const source = path.join(dir, variant);
  if (dryRun) {
    console.log(`would copy ${source} -> ${localPath}`);
    return true;
  }

  await fs.copyFile(source, localPath);
  console.log(`copied ${source} -> ${localPath}`);
  return true;
}

async function download(url, localPath, dryRun) {
  if (dryRun) {
    console.log(`would download ${url} -> ${localPath}`);
    return true;
  }

  const response = await fetch(url, { redirect: 'follow' });
  if (!response.ok) {
    return false;
  }

  const body = Buffer.from(await response.arrayBuffer());
  if (body.length === 0) return false;
  await fs.mkdir(path.dirname(localPath), { recursive: true });
  await fs.writeFile(localPath, body);
  console.log(`downloaded ${url} -> ${localPath} (${body.length} bytes)`);
  return true;
}

async function repair(options) {
  const [report, sources] = await Promise.all([
    readJson(options.report),
    readSources(options.meta),
  ]);

  let repaired = 0;
  let skippedExisting = 0;
  let failed = 0;

  for (const result of report.results || []) {
    for (const failure of result.localFailures || []) {
      const info = localRequestInfo(result, failure, options);
      if (!info) continue;
      if (await exists(info.localPath)) {
        skippedExisting += 1;
        continue;
      }

      if (await copyQueryFilenameVariant(info.localPath, options.dryRun)) {
        repaired += 1;
        continue;
      }

      const candidates = sourceCandidates(sources.get(result.id), info.relPath);
      let ok = false;
      for (const candidate of candidates) {
        try {
          ok = await download(candidate, info.localPath, options.dryRun);
        } catch {
          ok = false;
        }
        if (ok) break;
      }

      if (ok) {
        repaired += 1;
      } else {
        failed += 1;
        console.log(`missing ${result.id}: ${info.relPath}`);
      }
    }
  }

  console.log(`repair complete: repaired=${repaired}, existing=${skippedExisting}, failed=${failed}`);
}

repair(parseArgs(process.argv.slice(2))).catch((error) => {
  console.error(error.message);
  process.exit(1);
});
