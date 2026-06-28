import { chromium } from "playwright";
import fs from "node:fs/promises";

const reportDir = process.env.LEMMINGS_SMOKE_REPORT_DIR || "qa/reports/lemmings-ts-smoke";
const baseUrl = process.env.LEMMINGS_SMOKE_URL || "http://127.0.0.1/mirrors/lemmings/";
const allowedHosts = new Set(["127.0.0.1", "localhost", "192.168.1.106", "gannannet.local"]);

async function runScenario(name, openFn) {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  const external = [];
  const pageErrors = [];
  const badResponses = [];

  page.on("request", (request) => {
    const url = new URL(request.url());
    if (!allowedHosts.has(url.hostname)) external.push(request.url());
  });
  page.on("response", (response) => {
    const url = new URL(response.url());
    if (url.pathname.includes("/mirrors/lemmings") && response.status() >= 400) {
      badResponses.push({ status: response.status(), path: url.pathname });
    }
  });
  page.on("pageerror", (error) => pageErrors.push(error.stack || error.message));
  page.on("console", (message) => {
    if (message.type() === "error") pageErrors.push(`${message.type()}: ${message.text()}`);
  });

  await openFn(page);
  await page.waitForSelector("canvas", { timeout: 15000 });
  await page.getByRole("button", { name: "start" }).click({ timeout: 10000 });
  await page.waitForTimeout(8000);

  const summary = await page.evaluate(() => {
    const canvas = document.querySelector("canvas");
    return {
      url: location.href,
      text: document.body.innerText.slice(0, 1200),
      canvasCount: document.querySelectorAll("canvas").length,
      canvasSize: canvas ? { width: canvas.width, height: canvas.height } : null,
      buttons: Array.from(document.querySelectorAll("button"))
        .map((button) => button.textContent?.trim())
        .filter(Boolean),
      helpTextPresent: document.body.innerText.includes("The bottom icons are skills, not checkboxes"),
    };
  });

  await page.screenshot({ path: `${reportDir}/${name}.png`, fullPage: true });
  await fs.writeFile(
    `${reportDir}/${name}.json`,
    JSON.stringify({ external, pageErrors, badResponses, summary }, null, 2),
  );
  await browser.close();

  return {
    name,
    externalCount: external.length,
    pageErrorCount: pageErrors.length,
    badResponseCount: badResponses.length,
    canvasCount: summary.canvasCount,
    helpTextPresent: summary.helpTextPresent,
    canvasSize: summary.canvasSize,
    url: summary.url,
    report: `${reportDir}/${name}.json`,
    screenshot: `${reportDir}/${name}.png`,
  };
}

await fs.mkdir(reportDir, { recursive: true });
const normalizedBase = baseUrl.endsWith("/") ? baseUrl : `${baseUrl}/`;
const results = [];
results.push(
  await runScenario("normal-click-start", async (page) => {
    await page.goto(normalizedBase, { waitUntil: "networkidle", timeout: 30000 });
    await page.locator('a[href$="/game/1"]').click({ timeout: 10000 });
  }),
);
results.push(
  await runScenario("direct-route-start", async (page) => {
    await page.goto(new URL("game/1/", normalizedBase).toString(), {
      waitUntil: "networkidle",
      timeout: 30000,
    });
  }),
);

console.log(JSON.stringify(results, null, 2));
if (results.some((result) => result.externalCount || result.pageErrorCount || result.badResponseCount || result.canvasCount === 0 || !result.helpTextPresent)) {
  process.exit(1);
}
