#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { chromium } from 'playwright';

const baseUrl = ensureSlash(process.env.ARCADE_LIBRARY_URL || 'http://192.168.1.106/mirrors/games/');
const expectedProfile = process.env.EXPECTED_DEPLOYMENT_PROFILE || 'full';
const expectedLibraryProfile = expectedProfile === 'pi' ? 'pi' : 'all';
const expectedHeading = expectedProfile === 'pi' ? 'Camping / Pi-friendly' : 'Full library';
const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const reportDir = process.env.ARCADE_QA_REPORT_DIR || `qa/reports/deployment-profile-browser-${expectedProfile}-${stamp}`;
const result = {
  generatedAt: new Date().toISOString(),
  baseUrl,
  expectedProfile,
  passed: false,
  checks: [],
  pageErrors: [],
  externalRequests: [],
};

let browser;
try {
  await fs.mkdir(reportDir, { recursive: true });
  browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1440, height: 1000 } });
  const allowedHosts = new Set([new URL(baseUrl).hostname, '127.0.0.1', 'localhost', '192.168.1.106', 'gannannet.local']);
  await context.route('**/*', async (route) => {
    const url = route.request().url();
    try {
      const parsed = new URL(url);
      if (['http:', 'https:'].includes(parsed.protocol) && !allowedHosts.has(parsed.hostname)) {
        result.externalRequests.push(url);
        await route.abort('blockedbyclient');
        return;
      }
    } catch {}
    await route.continue();
  });

  const page = await context.newPage();
  page.on('pageerror', (error) => result.pageErrors.push(error.message));
  const response = await page.goto(baseUrl, { waitUntil: 'networkidle', timeout: 45000 });
  check('library returns HTTP 200', response?.status() === 200, response?.status());

  const deployment = await page.evaluate(async () => {
    const response = await fetch('./deployment-profile.json', { cache: 'no-store' });
    return { status: response.status, body: await response.json() };
  });
  check('deployment profile JSON returns HTTP 200', deployment.status === 200, deployment.status);
  check('selected deployment profile matches', deployment.body.selectedProfile === expectedProfile, deployment.body);
  check('default library profile matches', deployment.body.defaultLibraryProfile === expectedLibraryProfile, deployment.body);

  await page.waitForFunction((heading) => document.querySelector('#libraryHeading')?.textContent?.trim() === heading, expectedHeading, { timeout: 15000 });
  const heading = await page.locator('#libraryHeading').textContent();
  check('first library heading matches deployment', heading?.trim() === expectedHeading, heading);

  const activeProfile = await page.locator('#profileList .side-button.active').textContent();
  check('active sidebar mode matches deployment', activeProfile?.includes(expectedHeading), activeProfile);
  check('no browser page errors', result.pageErrors.length === 0, result.pageErrors);
  check('no external network requests', result.externalRequests.length === 0, result.externalRequests);

  await page.screenshot({ path: path.join(reportDir, `deployment-${expectedProfile}.png`), fullPage: true });
  result.passed = result.checks.every((item) => item.passed);
} catch (error) {
  result.error = error?.stack || error?.message || String(error);
} finally {
  if (browser) await browser.close();
  await fs.mkdir(reportDir, { recursive: true });
  await fs.writeFile(path.join(reportDir, 'result.json'), `${JSON.stringify(result, null, 2)}\n`);
}

if (!result.passed) {
  console.error(`Deployment profile browser smoke failed: ${reportDir}`);
  process.exitCode = 1;
} else {
  console.log(`Deployment profile browser smoke passed: ${reportDir}`);
}

function check(name, passed, details = null) {
  result.checks.push({ name, passed: Boolean(passed), details });
}

function ensureSlash(value) {
  return value.endsWith('/') ? value : `${value}/`;
}
