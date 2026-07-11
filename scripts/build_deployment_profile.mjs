#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const args = process.argv.slice(2);
function value(flag, fallback = "") {
  const index = args.indexOf(flag);
  return index >= 0 && args[index + 1] ? args[index + 1] : fallback;
}

const profilesPath = value("--profiles", "config/deployment-profiles.json");
const selected = value("--profile", process.env.LAN_ARCADE_DEPLOYMENT_PROFILE || "full");
const output = value("--output");
if (!output) throw new Error("--output is required");

const document = JSON.parse(fs.readFileSync(profilesPath, "utf8"));
if (document.schemaVersion !== 1 || !document.profiles || typeof document.profiles !== "object") {
  throw new Error("Invalid deployment profile document");
}
const profile = document.profiles[selected];
if (!profile) throw new Error("Unknown deployment profile: " + selected);
for (const field of ["label", "description", "defaultLibraryProfile", "accountMode", "emailMode", "hostedServices", "hardwareTarget"]) {
  if (typeof profile[field] !== "string" || !profile[field].trim()) throw new Error("Profile " + selected + " is missing " + field);
}

const result = {
  schemaVersion: 1,
  selectedProfile: selected,
  generatedAt: new Date().toISOString(),
  ...profile
};
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, JSON.stringify(result, null, 2) + "\n");
console.log(JSON.stringify(result));
