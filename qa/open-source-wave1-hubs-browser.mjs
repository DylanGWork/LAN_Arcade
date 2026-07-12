#!/usr/bin/env node
import { chromium } from "playwright";
import { spawn } from "node:child_process";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),"..");
const data=JSON.parse(await readFile(path.join(root,"config/open-source-wave1-promotions.json"),"utf8"));
const out=path.join(root,"qa/reports/open-source-wave1-hubs/browser");
await mkdir(path.join(out,"screenshots"),{recursive:true});
const server=spawn("python3",["-m","http.server","8946","--bind","127.0.0.1","--directory",root],{stdio:"ignore"});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
for(let i=0;i<30;i++){try{const r=await fetch("http://127.0.0.1:8946/");if(r.ok)break}catch{}await sleep(200)}
const browser=await chromium.launch({headless:true});
const results=[]; const failures=[];
try{
 for(const profile of [
  {name:"desktop",viewport:{width:1440,height:1000}},
  {name:"mobile",viewport:{width:390,height:844}}
 ]){
  const context=await browser.newContext({viewport:profile.viewport});
  for(const game of data.games){
   const blocked=[]; const errors=[];
   const page=await context.newPage();
   await page.route("**/*",async route=>{
    const url=new URL(route.request().url());
    if(url.hostname!=="127.0.0.1"){blocked.push(route.request().url());return route.abort()}
    return route.continue();
   });
   page.on("pageerror",error=>errors.push(String(error)));
   const base="http://127.0.0.1:8946/local-games/"+game.id+"/";
   const response=await page.goto(base,{waitUntil:"networkidle"});
   const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>document.documentElement.clientWidth+2);
   const hero=await page.locator("h1").textContent();
   const image=await page.locator("img").first().evaluate(el=>({complete:el.complete,width:el.naturalWidth,height:el.naturalHeight}));
   await page.screenshot({path:path.join(out,"screenshots",game.id+"-"+profile.name+".png"),fullPage:true});
   await page.locator("a[href='guide.html']").first().click();
   await page.waitForLoadState("networkidle");
   const guideHeading=await page.locator("h1").textContent();
   const guideOverflow=await page.evaluate(()=>document.documentElement.scrollWidth>document.documentElement.clientWidth+2);
   const ok=response?.status()===200 && hero?.includes(game.title) && image.complete && image.width>0 && !overflow && !guideOverflow && blocked.length===0 && errors.length===0 && guideHeading?.includes("Quick Guide");
   const row={id:game.id,profile:profile.name,status:response?.status(),image,overflow,guideOverflow,blocked,errors,ok};
   results.push(row);
   if(!ok) failures.push(row);
   await page.close();
  }
  await context.close();
 }
}finally{await browser.close();server.kill("SIGTERM")}
await writeFile(path.join(out,"browser-report.json"),JSON.stringify({passed:failures.length===0,results,failures},null,2)+"\n");
const md=["# Open-Source Wave 1 Hub Browser Check","",`Result: ${failures.length===0?"PASS":"FAIL"}`,"",...results.map(r=>`- ${r.id} / ${r.profile}: ${r.ok?"PASS":"FAIL"}`)];
await writeFile(path.join(out,"browser-report.md"),md.join("\n")+"\n");
if(failures.length){console.error(JSON.stringify(failures,null,2));process.exit(1)}
console.log(`PASS: ${results.length} desktop/mobile hub and guide checks`);
