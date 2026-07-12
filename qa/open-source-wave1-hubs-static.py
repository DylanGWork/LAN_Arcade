#!/usr/bin/env python3
"""Static/offline checks for the six generated open-source wave 1 hubs."""
from __future__ import annotations
import hashlib
import json
import re
import subprocess
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"config/open-source-wave1-promotions.json"
REPORT=ROOT/"qa/reports/open-source-wave1-hubs"
URL_RE=re.compile(r"https?://",re.I)

class Links(HTMLParser):
    def __init__(self):
        super().__init__(); self.values=[]
    def handle_starttag(self,tag,attrs):
        for name,value in attrs:
            if name in {"href","src","action"} and value: self.values.append(value)

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    data=json.loads(DATA.read_text(encoding="utf-8"))
    failures=[]; rows=[]; outputs=[]
    for g in data["games"]:
        target=ROOT/"local-games"/g["id"]
        expected=[target/"index.html",target/"guide.html",target/"install-and-play.sh",target/"ATTRIBUTION.txt",target/"assets/gameplay.png"]
        for path in expected:
            if not path.is_file() or path.stat().st_size==0: failures.append(f"{g['id']}: missing or empty {path.name}")
            else: outputs.append(path)
        for name in ("index.html","guide.html"):
            page=target/name
            if not page.is_file(): continue
            text=page.read_text(encoding="utf-8")
            if URL_RE.search(text): failures.append(f"{g['id']}/{name}: public http(s) URL found")
            parser=Links(); parser.feed(text)
            for value in parser.values:
                if value.startswith(("http://","https://","//")): failures.append(f"{g['id']}/{name}: external link {value}")
                elif value.startswith(("#","/mirrors/","/browser-stream/","../games/")): continue
                else:
                    rel=value.split("#",1)[0]
                    if rel and not (target/rel).resolve().exists(): failures.append(f"{g['id']}/{name}: missing target {value}")
        launch=target/"install-and-play.sh"
        if launch.is_file(): subprocess.run(["sh","-n",str(launch)],check=True)
        url="http://127.0.0.1/mirrors/games/downloads/native/intake/open-source-wave1/debian-bookworm-pool/"+g["package_file"]
        try:
            with urllib.request.urlopen(urllib.request.Request(url,method="HEAD"),timeout=10) as response:
                if response.status!=200: failures.append(f"{g['id']}: package HTTP {response.status}")
        except Exception as exc: failures.append(f"{g['id']}: package unavailable: {exc}")
        rows.append({"id":g["id"],"files":len(expected),"package":g["package_file"]})
    before={str(p.relative_to(ROOT)):sha(p) for p in outputs}
    subprocess.run(["python3",str(ROOT/"scripts/generate_open_source_wave1_hubs.py")],check=True)
    after={str(p.relative_to(ROOT)):sha(p) for p in outputs}
    if before!=after: failures.append("generator output changed on second run")
    REPORT.mkdir(parents=True,exist_ok=True)
    payload={"games":rows,"failures":failures,"passed":not failures}
    (REPORT/"static-report.json").write_text(json.dumps(payload,indent=2)+"\n",encoding="utf-8")
    lines=["# Open-Source Wave 1 Hub Static Check","",f"Result: {'PASS' if not failures else 'FAIL'}",f"Games checked: {len(rows)}","","Checks: deterministic generation; local artwork and guides; no public external links; shell syntax; locally served package files."]
    if failures: lines+=["","## Failures",""]+["- "+x for x in failures]
    (REPORT/"static-report.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
    if failures:
        print("\n".join(failures)); return 1
    print(f"PASS: {len(rows)} hubs; report={REPORT/'static-report.md'}"); return 0
if __name__=="__main__": raise SystemExit(main())
