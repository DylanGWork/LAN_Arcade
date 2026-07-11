#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { compileReadiness } from "./core.mjs";

function args(argv) {
  const repo = path.resolve(path.dirname(new URL(import.meta.url).pathname), "../..");
  const parsed = {
    repo,
    registry: process.env.ARCADE_CANONICAL_REGISTRY || "/var/www/html/mirrors/games/canonical-registry.json",
    policy: path.join(repo, "config/readiness-policy.json"),
    evidence: path.join(repo, "qa/readiness/evidence.json"),
    output: process.env.ARCADE_READINESS_OUTPUT || "/var/www/html/mirrors/games/readiness.json",
    quarantine: process.env.ARCADE_QUARANTINE_OUTPUT || "/var/www/html/mirrors/games/qa-quarantine.json",
    generatedAt: ""
  };
  const names = { "--registry": "registry", "--policy": "policy", "--evidence": "evidence", "--output": "output", "--quarantine": "quarantine", "--generated-at": "generatedAt", "--repo-root": "repo" };
  for (let i = 0; i < argv.length; i += 1) {
    const key = names[argv[i]];
    if (!key || !argv[i + 1]) throw new Error("Unknown or incomplete argument: " + argv[i]);
    parsed[key] = path.resolve(argv[i + 1]);
    if (key === "generatedAt") parsed[key] = argv[i + 1];
    i += 1;
  }
  return parsed;
}

async function readJson(file, label) {
  let raw;
  try {
    raw = await fs.readFile(file, "utf8");
  } catch (error) {
    throw new Error("Missing " + label + ": " + file + " (" + error.message + ")");
  }
  try {
    return JSON.parse(raw);
  } catch (error) {
    throw new Error("Invalid JSON in " + label + ": " + file + " (" + error.message + ")");
  }
}

async function writeAtomic(file, value) {
  await fs.mkdir(path.dirname(file), { recursive: true });
  const temp = file + ".tmp-" + process.pid;
  await fs.writeFile(temp, JSON.stringify(value, null, 2) + "\n");
  await fs.rename(temp, file);
}

async function main() {
  const options = args(process.argv.slice(2));
  const registry = await readJson(options.registry, "canonical registry");
  const policy = await readJson(options.policy, "readiness policy");
  const evidence = await readJson(options.evidence, "readiness evidence");
  for (const receipt of evidence.receipts || []) {
    for (const relative of receipt.evidencePaths || []) {
      const absolute = path.resolve(options.repo, relative);
      if (absolute !== options.repo && !absolute.startsWith(options.repo + path.sep)) {
        throw new Error("Evidence path escapes repository: " + relative);
      }
      try {
        await fs.access(absolute);
      } catch {
        throw new Error("Evidence file is missing for " + receipt.receiptId + ": " + relative);
      }
    }
  }
  const compiled = compileReadiness({
    registry,
    policy,
    evidence,
    generatedAt: options.generatedAt || new Date().toISOString()
  });
  await writeAtomic(options.output, compiled.readiness);
  await writeAtomic(options.quarantine, compiled.quarantine);
  console.log(JSON.stringify({
    readiness: options.output,
    quarantine: options.quarantine,
    metrics: compiled.readiness.metrics
  }));
}

main().catch(function (error) {
  console.error(error.stack || error.message);
  process.exit(1);
});
