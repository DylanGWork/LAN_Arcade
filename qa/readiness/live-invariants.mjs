#!/usr/bin/env node

import fs from "node:fs/promises";
import assert from "node:assert/strict";
import { compileReadiness } from "./core.mjs";

const registryPath = process.env.ARCADE_CANONICAL_REGISTRY || "/var/www/html/mirrors/games/canonical-registry.json";
const [registry, policy, evidence] = await Promise.all([
  fs.readFile(registryPath, "utf8").then(JSON.parse),
  fs.readFile(new URL("../../config/readiness-policy.json", import.meta.url), "utf8").then(JSON.parse),
  fs.readFile(new URL("./evidence.json", import.meta.url), "utf8").then(JSON.parse)
]);
const result = compileReadiness({ registry, policy, evidence, generatedAt: new Date().toISOString() });
const entries = result.readiness.entries;
const expected = {
  "pillage-first-lan": "ready",
  "classic-pc:simcity-classic-dos-ma": "ready",
  "lemmings": "limited",
  "classic-pc:lemmings-ma": "quarantined",
  "classic-pc:simant-ma": "limited",
  "game-boy-vault:aladdin": "quarantined",
  "endless-sky-lan": "limited",
  "mindustry-lan": "limited",
  "unciv-lan": "limited",
  "lan-tank-arena": "ready",
  "veloren-lan": "quarantined"
};
for (const [id, state] of Object.entries(expected)) {
  assert(entries[id], "missing readiness entry " + id);
  assert.equal(entries[id].promotionState, state, id + " readiness");
}
const ready = Object.values(entries).filter(function (entry) { return entry.promotionState === "ready"; }).map(function (entry) { return entry.entryId; }).sort();
assert.deepEqual(ready, ["classic-pc:simcity-classic-dos-ma", "lan-tank-arena", "pillage-first-lan"]);
assert.equal(result.readiness.metrics.quarantinedEntries, 3);
assert(result.readiness.metrics.researchEntries >= 200);
assert(Object.values(entries).every(function (entry) { return entry.displayLabel !== "Quarantined"; }));
console.log(JSON.stringify(result.readiness.metrics));
