#!/usr/bin/env node

import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import { chromium } from "playwright";

const reportDir = process.env.ACCOUNT_SAVE_QA_REPORT_DIR || "qa/reports/account-save-isolation";
const result = { generatedAt: new Date().toISOString(), passed: false, checks: [], errors: [] };
let browser;

function check(name, passed, details) {
  result.checks.push({ name, passed: Boolean(passed), details: details ?? null });
  assert(passed, name);
}

try {
  await fs.mkdir(reportDir, { recursive: true });
  browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 900, height: 620 } });
  const page = await context.newPage();
  await page.goto("https://192.168.1.106/mirrors/games/", { waitUntil: "domcontentloaded", timeout: 20000 });
  await page.evaluate(function () {
    document.body.innerHTML = "<main><h1>Account save isolation</h1><p id=\"status\">Running</p></main>";
    window.__qaServerSaves = {};
    window.fetch = async function (url, options) {
      const request = options || {};
      const headers = request.headers || {};
      const token = headers["x-arcade-account-session"] || "";
      const suffix = String(url).split("/arcade-api/account/saves/")[1] || "";
      if (request.method === "PUT") {
        const body = JSON.parse(request.body);
        const key = [token, body.adapter, body.gameId, body.slot].join("|");
        window.__qaServerSaves[key] = { ...body, updatedAt: new Date().toISOString() };
        return { ok: true, status: 200, json: async function () { return { save: window.__qaServerSaves[key] }; } };
      }
      const key = [token].concat(suffix.split("/").map(decodeURIComponent)).join("|");
      const save = window.__qaServerSaves[key];
      if (!save) return { ok: false, status: 404, json: async function () { return { error: "Save not found" }; } };
      return { ok: true, status: 200, json: async function () { return { save }; } };
    };
  });
  await page.addScriptTag({ path: path.resolve("local-games/shared/account-save.js") });

  async function selectAccount(id, token, name) {
    await page.evaluate(function (account) {
      localStorage.setItem("lanArcadeAccount.v1", JSON.stringify({
        token: account.token,
        account: { id: account.id, username: account.name.toLowerCase(), displayName: account.name }
      }));
    }, { id, token, name });
  }

  await selectAccount("account-a", "token-a", "Alex");
  const accountA = await page.evaluate(function () {
    const slot = window.LanArcadeAccountSaves.createSlot({
      legacyKey: "qa.game.save",
      gameId: "qa-game",
      slot: "main"
    });
    slot.save({ owner: "A", score: 10 });
    return { key: slot.key };
  });
  await page.waitForTimeout(450);

  await selectAccount("account-b", "token-b", "Blair");
  const accountB = await page.evaluate(async function () {
    const slot = window.LanArcadeAccountSaves.createSlot({
      legacyKey: "qa.game.save",
      gameId: "qa-game",
      slot: "main"
    });
    const hydrated = await slot.hydrate();
    slot.save({ owner: "B", score: 20 });
    return { key: slot.key, hydrated };
  });
  await page.waitForTimeout(450);

  await selectAccount("account-a", "token-a", "Alex");
  const restoredA = await page.evaluate(async function () {
    window.__qaApplied = null;
    const slot = window.LanArcadeAccountSaves.createSlot({
      legacyKey: "qa.game.save",
      gameId: "qa-game",
      slot: "main",
      applyPayload: function (payload) { window.__qaApplied = payload; }
    });
    const hydrated = await slot.hydrate();
    return { key: slot.key, hydrated, payload: window.__qaApplied, server: window.__qaServerSaves };
  });

  check("account-local keys differ", accountA.key !== accountB.key, { accountA: accountA.key, accountB: accountB.key });
  check("account B starts without account A save", accountB.hydrated.mode === "empty", accountB.hydrated);
  check("account A restores its own payload", restoredA.hydrated.mode === "loaded" && restoredA.payload?.owner === "A" && restoredA.payload?.score === 10, restoredA.payload);
  check("server slots remain isolated by token", Object.keys(restoredA.server).length === 2
    && restoredA.server["token-a|browser-localstorage|qa-game|main"].payload.includes('"owner":"A"')
    && restoredA.server["token-b|browser-localstorage|qa-game|main"].payload.includes('"owner":"B"'), Object.keys(restoredA.server));

  result.passed = result.checks.every(function (item) { return item.passed; });
  await page.evaluate(function () { document.getElementById("status").textContent = "PASS: account saves are isolated"; });
  const screenshot = path.join(reportDir, "account-save-isolation.png");
  await page.screenshot({ path: screenshot, fullPage: true });
  result.screenshot = screenshot;
} catch (error) {
  result.errors.push(error.stack || error.message);
} finally {
  if (browser) await browser.close();
  await fs.mkdir(reportDir, { recursive: true });
  await fs.writeFile(path.join(reportDir, "result.json"), JSON.stringify(result, null, 2) + "\n");
  await fs.writeFile(path.join(reportDir, "result.md"), "# Account Save Isolation Smoke\n\nResult: " + (result.passed ? "PASS" : "FAIL") + "\n");
}

if (!result.passed) process.exit(1);
console.log("Account save isolation smoke passed: " + reportDir);
