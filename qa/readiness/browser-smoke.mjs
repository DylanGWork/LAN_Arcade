#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { chromium } from "playwright";

const baseUrl = process.env.ARCADE_LIBRARY_URL || "https://192.168.1.106/mirrors/games/";
const reportDir = process.env.ARCADE_QA_REPORT_DIR || "qa/reports/phase3-readiness-browser-20260711";
const result = { generatedAt: new Date().toISOString(), baseUrl, passed: false, checks: [], pageErrors: [], consoleErrors: [], externalRequests: [], screenshots: [] };
let browser;

function check(name, passed, details = null) {
  result.checks.push({ name, passed: Boolean(passed), details });
}
function localHost(hostname) {
  return ["192.168.1.106", "127.0.0.1", "localhost", "gannannet.local"].includes(hostname);
}
async function shot(page, name) {
  const file = path.join(reportDir, "screenshots", name + ".png");
  await page.screenshot({ path: file, fullPage: true });
  result.screenshots.push(file);
}
async function cards(page) {
  return page.locator(".game-card, .featured-card").evaluateAll(function (nodes) {
    return nodes.map(function (node) {
      return {
        title: node.querySelector(".card-title")?.textContent?.trim() || "",
        href: node.querySelector(".card-link")?.href || node.href || "",
        action: node.querySelector(".launch")?.textContent?.trim() || "",
        chips: Array.from(node.querySelectorAll(".detail-chip")).map(function (chip) { return chip.textContent.trim(); })
      };
    });
  });
}

try {
  await fs.mkdir(path.join(reportDir, "screenshots"), { recursive: true });
  browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1440, height: 1000 } });
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
  page.on("console", function (message) { if (message.type() === "error") result.consoleErrors.push(message.text()); });
  await page.goto(baseUrl, { waitUntil: "networkidle", timeout: 30000 });

  const readiness = await page.evaluate(async function () {
    const response = await fetch("./readiness.json", { cache: "no-store" });
    return response.json();
  });
  check("readiness authority loads", readiness.authority === "lan-arcade-qa-readiness-v1");
  check("truthful readiness counts", readiness.metrics.readyEntries === 2 && readiness.metrics.quarantinedEntries === 4, readiness.metrics);
  check("public status reports two ready titles", (await page.locator("#status").innerText()).includes("2 ready to play"));

  await page.fill("#searchInput", "simcity");
  await page.waitForTimeout(400);
  const simcity = (await cards(page)).find(function (card) { return card.title === "SimCity Classic DOS"; });
  check("SimCity is ready with Play action", Boolean(simcity && simcity.action === "Play" && simcity.chips.includes("Ready to play")), simcity);
  await shot(page, "01-simcity-ready");

  await page.fill("#searchInput", "simant");
  await page.waitForTimeout(400);
  const simant = (await cards(page)).find(function (card) { return card.title === "SimAnt"; });
  check("SimAnt is tryable but not promoted", Boolean(simant && simant.action === "Try" && simant.chips.includes("Needs play testing")), simant);

  await page.fill("#searchInput", "lemmings");
  await page.waitForTimeout(400);
  const lemmings = await cards(page);
  check("browser Lemmings remains limited", lemmings.some(function (card) { return card.title === "Lemmings" && card.action === "Try" && card.chips.includes("Needs play testing"); }), lemmings);
  check("known broken Lemmings route is not ready", lemmings.some(function (card) { return card.title === "Lemmings" && card.chips.includes("Not ready"); }), lemmings);
  await shot(page, "02-lemmings-mixed-status");

  await page.fill("#searchInput", "lan tank arena");
  await page.waitForTimeout(400);
  const tank = (await cards(page)).find(function (card) { return card.title === "LAN Tank Arena"; });
  check("Tank backend blocker is visible", Boolean(tank && tank.action === "View issue" && tank.chips.includes("Not ready")), tank);

  check("no outbound network requests", result.externalRequests.length === 0, result.externalRequests);
  check("no page errors", result.pageErrors.length === 0, result.pageErrors);
  result.passed = result.checks.every(function (item) { return item.passed; });
} catch (error) {
  result.error = error.stack || error.message;
} finally {
  if (browser) await browser.close();
  await fs.mkdir(reportDir, { recursive: true });
  await fs.writeFile(path.join(reportDir, "result.json"), JSON.stringify(result, null, 2) + "\n");
  const rows = result.checks.map(function (item) { return "| " + (item.passed ? "pass" : "fail") + " | " + item.name + " | " + (item.details ? JSON.stringify(item.details).replace(/\|/g, "\\|") : "") + " |"; }).join("\n");
  await fs.writeFile(path.join(reportDir, "result.md"), "# Phase 3 Readiness Browser Smoke\n\nResult: " + (result.passed ? "PASS" : "FAIL") + "\n\n| Status | Check | Details |\n| --- | --- | --- |\n" + rows + "\n");
}
if (!result.passed) {
  console.error("Phase 3 browser smoke failed: " + reportDir);
  process.exit(1);
}
console.log("Phase 3 browser smoke passed: " + reportDir);
