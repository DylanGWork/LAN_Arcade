#!/usr/bin/env node
import { chromium } from "playwright";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),"..");
const data=JSON.parse(await readFile(path.join(root,"config/browser-stream-games.json"),"utf8"));
const out=path.join(root,"qa/reports/browser-stream-ui");
await mkdir(path.join(out,"screenshots"),{recursive:true});
const browser=await chromium.launch({headless:true});
const results=[], failures=[];
try {
  for (const [gameId, game] of Object.entries(data.games)) {
    const context=await browser.newContext({viewport:{width:1440,height:960}});
    const page=await context.newPage();
    const external=[], errors=[];
    await page.route("**/*", route => {
      const url=new URL(route.request().url());
      if (url.hostname!=="127.0.0.1") {
        external.push(route.request().url());
        return route.abort();
      }
      return route.continue();
    });
    page.on("pageerror", error=>errors.push(String(error)));
    page.on("console", msg=>{if(msg.type()==="error")errors.push(msg.text());});
    try {
      const hub=await page.goto("http://127.0.0.1/mirrors/"+gameId+"/",{waitUntil:"networkidle"});
      if(!hub?.ok()) throw new Error("hub HTTP "+hub?.status());
      const play=page.getByRole("link",{name:"Play in browser"}).first();
      await play.click();
      await page.waitForURL(url=>url.pathname==="/browser-stream/" && url.searchParams.get("game")===gameId);
      await page.locator("#status").filter({hasText:"Playing "}).waitFor({timeout:90000});
      await page.locator("#player").waitFor({state:"visible"});
      await page.frameLocator("#player").locator("#noVNC_container canvas").waitFor({state:"visible",timeout:30000});
      const status=await page.locator("#status").textContent();
      await page.screenshot({path:path.join(out,"screenshots",gameId+".png"),fullPage:true});
      await page.getByRole("button",{name:"Stop current game"}).click();
      await page.locator("#status").filter({hasText:"No game is running."}).waitFor({timeout:30000});
      if(external.length)throw new Error("external requests: "+external.join(", "));
      if(errors.length)throw new Error("browser errors: "+errors.join(" | "));
      results.push({gameId,title:game.title,status,result:"PASS"});
    } catch (error) {
      failures.push({gameId,error:String(error),external,errors});
      results.push({gameId,title:game.title,result:"FAIL"});
      try { await page.getByRole("button",{name:"Stop current game"}).click({timeout:2000}); } catch {}
    }
    await context.close();
  }
} finally {
  await browser.close();
}
await writeFile(path.join(out,"results.json"),JSON.stringify({results,failures},null,2)+"\n");
const lines=["# Browser Stream Player UI QA","",`Result: ${failures.length?"FAIL":"PASS"}`,""];
for(const result of results)lines.push(`- **${result.result}** ${result.title}: hub Play action, auto-launch, protected noVNC canvas, screenshot, and Stop action.`);
if(failures.length)lines.push("","## Failures","",...failures.map(x=>"- "+x.gameId+": "+x.error));
await writeFile(path.join(out,"report.md"),lines.join("\n")+"\n");
if(failures.length){console.error(JSON.stringify(failures,null,2));process.exit(1)}
console.log("BROWSER_STREAM_UI_PASS");
