#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { chromium } from "playwright";

const baseUrl = process.env.ARCADE_LIBRARY_URL || "https://192.168.1.106/mirrors/games/";
const username = process.env.ARCADE_QA_USERNAME || "";
const password = process.env.ARCADE_QA_PASSWORD || "";
const reportDir = process.env.ARCADE_QA_REPORT_DIR || "qa/reports/family-account-browser";
const result = { generatedAt: new Date().toISOString(), baseUrl, passed: false, checks: [], pageErrors: [], externalRequests: [] };
let browser;

function check(name, passed, details = null) {
  result.checks.push({ name, passed: Boolean(passed), details });
}
function localHost(hostname) {
  return ["192.168.1.106", "127.0.0.1", "localhost", "gannannet.local"].includes(hostname);
}

try {
  if (!username || !password) throw new Error("Set ARCADE_QA_USERNAME and ARCADE_QA_PASSWORD");
  await fs.mkdir(reportDir, { recursive: true });
  browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1280, height: 900 } });
  await context.route("**/*", async function (route) {
    const url = new URL(route.request().url());
    if ((url.protocol === "http:" || url.protocol === "https:") && !localHost(url.hostname)) {
      result.externalRequests.push(url.href);
      await route.abort();
      return;
    }
    await route.continue();
  });
  const page = await context.newPage();
  page.on("pageerror", function (error) { result.pageErrors.push(error.message); });
  await page.goto(baseUrl, { waitUntil: "networkidle", timeout: 30000 });
  await page.evaluate(function () { localStorage.removeItem("lanArcadeAccount.v1"); });
  await page.reload({ waitUntil: "networkidle" });

  await page.locator("#accountPanel details").filter({ hasText: "Sign in" }).locator("summary").click();
  await page.fill("#accountLoginUsername", username);
  await page.fill("#accountLoginPassword", password);
  await page.locator("#accountPanel button").filter({ hasText: /^Sign in$/ }).click();
  await page.waitForFunction(function () {
    const name = document.querySelector("#accountPanel .account-name");
    return Boolean(name && name.textContent && !name.textContent.includes("Guest") && !name.textContent.includes("Checking"));
  }, null, { timeout: 10000 });

  const panelText = await page.locator("#accountPanel").innerText();
  check("signed-in player panel is visible", panelText.includes("Switch to guest"), panelText);
  check("family organizer controls are visible", panelText.includes("Add family player"), panelText);

  const access = await page.evaluate(async function () {
    const anonymous = await fetch("/arcade-api/accounts", { cache: "no-store" });
    const stored = JSON.parse(localStorage.getItem("lanArcadeAccount.v1") || "null");
    const authorized = await fetch("/arcade-api/accounts", {
      cache: "no-store",
      headers: { "x-arcade-account-session": stored ? stored.token : "" }
    });
    const body = authorized.ok ? await authorized.json() : {};
    return { anonymousStatus: anonymous.status, authorizedStatus: authorized.status, accountCount: Array.isArray(body.accounts) ? body.accounts.length : -1 };
  });
  check("anonymous account listing is denied", access.anonymousStatus === 401, access);
  check("authorized family listing works", access.authorizedStatus === 200 && access.accountCount >= 1, access);
  check("no browser errors", result.pageErrors.length === 0, result.pageErrors);
  check("no external requests", result.externalRequests.length === 0, result.externalRequests);
  result.passed = result.checks.every(function (item) { return item.passed; });

  const screenshot = path.join(reportDir, "family-account-panel.png");
  await page.screenshot({ path: screenshot, fullPage: true });
  result.screenshot = screenshot;
} catch (error) {
  result.error = error.stack || error.message;
} finally {
  if (browser) await browser.close();
  await fs.mkdir(reportDir, { recursive: true });
  await fs.writeFile(path.join(reportDir, "result.json"), JSON.stringify(result, null, 2) + "\n");
  await fs.writeFile(path.join(reportDir, "result.md"), "# Family Account Browser Smoke\n\nResult: " + (result.passed ? "PASS" : "FAIL") + "\n");
}
if (!result.passed) process.exit(1);
console.log("Family account browser smoke passed: " + reportDir);
