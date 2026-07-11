#!/usr/bin/env node

import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

const root = process.cwd();
const profiles = path.join(root, "config/deployment-profiles.json");
const builder = path.join(root, "scripts/build_deployment_profile.mjs");
const temp = fs.mkdtempSync(path.join(os.tmpdir(), "lan-arcade-profile-"));

for (const expected of [
  { id: "full", defaultLibraryProfile: "all", emailMode: "local-mail-recommended", hostedServices: "on-demand" },
  { id: "pi", defaultLibraryProfile: "pi", emailMode: "not-required", hostedServices: "disabled-by-default" }
]) {
  const output = path.join(temp, expected.id + ".json");
  execFileSync(process.execPath, [builder, "--profiles", profiles, "--profile", expected.id, "--output", output], { stdio: "pipe" });
  const result = JSON.parse(fs.readFileSync(output, "utf8"));
  assert.equal(result.selectedProfile, expected.id);
  assert.equal(result.defaultLibraryProfile, expected.defaultLibraryProfile);
  assert.equal(result.emailMode, expected.emailMode);
  assert.equal(result.hostedServices, expected.hostedServices);
}
assert.throws(function () {
  execFileSync(process.execPath, [builder, "--profiles", profiles, "--profile", "unknown", "--output", path.join(temp, "bad.json")], { stdio: "pipe" });
});
console.log("Deployment profile contract passed.");
