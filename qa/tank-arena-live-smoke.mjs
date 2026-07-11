#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { chromium } from "playwright";

const baseUrl = process.env.TANK_LIVE_BASE_URL || "https://192.168.1.106/mirrors/lan-tank-arena/";
const reportDir = process.env.TANK_LIVE_QA_REPORT_DIR || "qa/readiness/evidence/tank-arena-live-20260711";
const room = "LIVEQA";
const result = { generatedAt: new Date().toISOString(), baseUrl, room, passed: false, errors: [], externalRequests: [], clients: {} };
let browser;

function localHost(hostname) {
  return ["192.168.1.106", "127.0.0.1", "localhost", "gannannet.local"].includes(hostname);
}
async function openClient(name, viewport) {
  const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport });
  await context.route("**/*", async function (route) {
    const url = new URL(route.request().url());
    if ((url.protocol === "http:" || url.protocol === "https:" || url.protocol === "ws:" || url.protocol === "wss:") && !localHost(url.hostname)) {
      result.externalRequests.push(url.href);
      await route.abort();
      return;
    }
    await route.continue();
  });
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", function (error) { errors.push("pageerror: " + error.message); });
  page.on("console", function (message) { if (message.type() === "error") errors.push("console: " + message.text()); });
  await page.goto(baseUrl + "?room=" + room, { waitUntil: "domcontentloaded", timeout: 20000 });
  await page.waitForFunction(function () { return Boolean(window.__lanTankQa); }, null, { timeout: 7000 });
  return { name, context, page, errors };
}

try {
  await fs.mkdir(path.join(reportDir, "screenshots"), { recursive: true });
  browser = await chromium.launch({ headless: true });
  const alpha = await openClient("Alpha", { width: 1280, height: 800 });
  const bravo = await openClient("Bravo", { width: 390, height: 844 });
  await alpha.page.evaluate(function (value) { window.__lanTankQa.join(value.name, value.room); }, { name: "Alpha", room });
  await bravo.page.evaluate(function (value) { window.__lanTankQa.join(value.name, value.room); }, { name: "Bravo", room });
  const counts = await Promise.all([
    alpha.page.evaluate(function () { return window.__lanTankQa.waitForPlayers(2); }),
    bravo.page.evaluate(function () { return window.__lanTankQa.waitForPlayers(2); })
  ]);
  const alphaBefore = await alpha.page.evaluate(function () { return window.__lanTankQa.snapshot(); });
  const bravoBefore = await bravo.page.evaluate(function () { return window.__lanTankQa.snapshot(); });
  await alpha.page.evaluate(function () { window.__lanTankQa.input({ up: true, fire: true }); });
  await bravo.page.evaluate(function () { window.__lanTankQa.input({ left: true, fire: true }); });
  await alpha.page.waitForTimeout(1200);
  await alpha.page.evaluate(function () { window.__lanTankQa.input({ up: false, fire: false }); });
  await bravo.page.evaluate(function () { window.__lanTankQa.input({ left: false, fire: false }); });
  await alpha.page.waitForTimeout(300);
  const alphaSnapshot = await alpha.page.evaluate(function () { return window.__lanTankQa.snapshot(); });
  const bravoSnapshot = await bravo.page.evaluate(function () { return window.__lanTankQa.snapshot(); });
  const alphaPlayerBefore = alphaBefore.state.players.find(function (player) { return player.id === alphaBefore.playerId; });
  const alphaPlayerAfter = alphaSnapshot.state.players.find(function (player) { return player.id === alphaSnapshot.playerId; });
  const bravoPlayerBefore = bravoBefore.state.players.find(function (player) { return player.id === bravoBefore.playerId; });
  const bravoPlayerAfter = bravoSnapshot.state.players.find(function (player) { return player.id === bravoSnapshot.playerId; });
  result.interaction = {
    alphaMoved: Boolean(alphaPlayerBefore && alphaPlayerAfter && (alphaPlayerBefore.x !== alphaPlayerAfter.x || alphaPlayerBefore.y !== alphaPlayerAfter.y)),
    bravoMoved: Boolean(bravoPlayerBefore && bravoPlayerAfter && (bravoPlayerBefore.x !== bravoPlayerAfter.x || bravoPlayerBefore.y !== bravoPlayerAfter.y || bravoPlayerBefore.angle !== bravoPlayerAfter.angle)),
    projectileObserved: alphaSnapshot.state.bullets.length > alphaBefore.state.bullets.length
      || bravoSnapshot.state.bullets.length > bravoBefore.state.bullets.length
  };

  const health = await alpha.page.evaluate(async function () {
    const response = await fetch("/tank-arena/healthz", { cache: "no-store" });
    return { status: response.status, body: await response.json() };
  });
  for (const client of [alpha, bravo]) {
    const image = path.join(reportDir, "screenshots", client.name.toLowerCase() + ".png");
    await client.page.screenshot({ path: image, fullPage: true });
    result.clients[client.name.toLowerCase()] = {
      screenshot: image,
      errors: client.errors,
      snapshot: client.name === "Alpha" ? alphaSnapshot : bravoSnapshot
    };
  }
  result.health = health;
  result.playerCounts = counts;
  result.passed = counts.every(function (count) { return count >= 2; })
    && alphaSnapshot.state.players.length >= 2
    && bravoSnapshot.state.players.length >= 2
    && health.status === 200
    && health.body.ok === true
    && alpha.errors.length === 0
    && result.interaction.alphaMoved
    && result.interaction.bravoMoved
    && result.interaction.projectileObserved
    && bravo.errors.length === 0
    && result.externalRequests.length === 0;
  await alpha.context.close();
  await bravo.context.close();
} catch (error) {
  result.errors.push(error.stack || error.message);
} finally {
  if (browser) await browser.close();
  await fs.mkdir(reportDir, { recursive: true });
  await fs.writeFile(path.join(reportDir, "tank-live-smoke.json"), JSON.stringify(result, null, 2) + "\n");
  await fs.writeFile(path.join(reportDir, "tank-live-smoke.md"), "# Tank Arena Live Two-Client Smoke\n\nResult: " + (result.passed ? "PASS" : "FAIL") + "\n\nOrigin: " + baseUrl + "\n\nPlayers: " + JSON.stringify(result.playerCounts || []) + "\n\nHealth: " + JSON.stringify(result.health || {}) + "\n\nExternal requests: " + result.externalRequests.length + "\n");
}
if (!result.passed) {
  console.error("Tank live smoke failed: " + reportDir);
  process.exit(1);
}
console.log("Tank live smoke passed: " + reportDir);
