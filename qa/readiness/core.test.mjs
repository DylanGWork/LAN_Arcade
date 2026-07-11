import test from "node:test";
import assert from "node:assert/strict";
import { compileReadiness } from "./core.mjs";

const HASH = "a".repeat(64);
const OTHER_HASH = "b".repeat(64);
const NOW = "2026-07-11T00:00:00Z";

function policy() {
  return {
    schemaVersion: 1,
    policyId: "test-policy",
    tiers: {
      T0: { rank: 0 }, T1: { rank: 1 }, T2: { rank: 2 }, T3: { rank: 3 }, T4: { rank: 4 }
    },
    outcomes: ["pass", "partial", "fail", "blocked", "unverified"],
    promotionStates: ["ready", "limited", "quarantined", "research"],
    contentTypes: ["single-player", "hosted", "multiplayer", "collection", "research"],
    readyThresholds: { "single-player": "T3", hosted: "T4", multiplayer: "T4" },
    requireOfflineForReady: true,
    requireExplicitExpiry: true,
    entrySources: {
      catalog: { prefix: "", recordTypes: ["launcher-card"], collectionTarget: "/mirrors/games/" },
      board: { prefix: "board:", recordTypes: ["research-row"], collectionTarget: "/mirrors/board/" }
    },
    adapterContentTypes: { browser: "single-player", "hosted-lan": "hosted" }
  };
}

function record(id, adapter = "browser", kind = "title", source = "catalog", type = "launcher-card") {
  return {
    recordId: "record:" + source + ":" + id,
    entityId: "entity:" + id,
    entityKind: kind,
    recordType: type,
    sourceCollection: source,
    sourceRecordId: id,
    title: id,
    launcher: { adapter, target: "/mirrors/" + id + "/" },
    dimensions: { researchOnly: type === "research-row" }
  };
}

function registry(records) {
  return {
    schemaVersion: 2,
    inputDigestSha256: HASH,
    records,
    entities: records.map(function (row) {
      return { entityId: row.entityId, kind: row.entityKind, canonicalTitle: row.title };
    }),
    sources: [
      { sourceCollection: "catalog", contentSha256: HASH },
      { sourceCollection: "board", contentSha256: HASH }
    ]
  };
}

function receipt(row, options = {}) {
  return {
    receiptId: options.id || row.sourceRecordId + "-" + (options.outcome || "pass") + "-" + (options.observedAt || "2026"),
    entry: { entryId: (row.sourceCollection === "board" ? "board:" : "") + row.sourceRecordId, recordId: row.recordId, entityId: row.entityId },
    contentType: options.contentType || (row.launcher.adapter === "hosted-lan" ? "hosted" : "single-player"),
    target: row.launcher.target,
    fingerprint: { algorithm: "sha256", kind: "registry-source", sourceCollection: row.sourceCollection, value: options.hash || HASH },
    runner: { name: "test", commit: "test" },
    environment: { lanOrigin: "http://127.0.0.1", deviceProfile: "desktop", offline: options.offline !== false },
    tier: options.tier || "T3",
    outcome: options.outcome || "pass",
    assertions: [{ id: "action", description: "meaningful action", passed: options.outcome !== "fail" }],
    observedAt: options.observedAt || "2026-07-10T00:00:00Z",
    recordedAt: options.recordedAt || options.observedAt || "2026-07-10T00:00:00Z",
    expiresAt: options.expiresAt || "2027-07-10T00:00:00Z",
    evidencePaths: ["qa/example.json"]
  };
}

function decision(rows, receipts, id) {
  const result = compileReadiness({ registry: registry(rows), policy: policy(), evidence: { schemaVersion: 1, receipts }, generatedAt: NOW });
  return result.readiness.entries[id];
}

test("offline T3 single-player pass promotes ready", function () {
  const row = record("solo");
  assert.equal(decision([row], [receipt(row)], "solo").promotionState, "ready");
});

test("T2 launch-only pass remains limited", function () {
  const row = record("launch-only");
  const value = decision([row], [receipt(row, { tier: "T2" })], "launch-only");
  assert.equal(value.promotionState, "limited");
  assert.equal(value.reason, "tier-below-T3");
});

test("hosted content needs T4", function () {
  const row = record("server", "hosted-lan");
  assert.equal(decision([row], [receipt(row, { tier: "T3", contentType: "hosted" })], "server").promotionState, "limited");
  assert.equal(decision([row], [receipt(row, { tier: "T4", contentType: "hosted" })], "server").promotionState, "ready");
});

test("newer blocker overrides an older pass", function () {
  const row = record("broken");
  const pass = receipt(row, { id: "older-pass", observedAt: "2026-07-01T00:00:00Z" });
  const fail = receipt(row, { id: "newer-fail", outcome: "fail", observedAt: "2026-07-10T00:00:00Z" });
  const value = decision([row], [pass, fail], "broken");
  assert.equal(value.promotionState, "quarantined");
  assert.equal(value.evidence.acceptedBlockerReceiptId, "newer-fail");
});

test("newer repaired pass supersedes an older blocker", function () {
  const row = record("repaired");
  const fail = receipt(row, { id: "older-fail", outcome: "fail", observedAt: "2026-07-01T00:00:00Z" });
  const pass = receipt(row, { id: "newer-pass", observedAt: "2026-07-10T00:00:00Z" });
  assert.equal(decision([row], [fail, pass], "repaired").promotionState, "ready");
});

test("expired evidence and changed source fingerprints cannot promote", function () {
  const stale = record("stale");
  const changed = record("changed");
  assert.equal(decision([stale], [receipt(stale, { expiresAt: "2026-07-10T12:00:00Z" })], "stale").reason, "stale-evidence");
  assert.equal(decision([changed], [receipt(changed, { hash: OTHER_HASH })], "changed").reason, "fingerprint-or-identity-mismatch");
});

test("missing evidence is limited and research rows remain research", function () {
  const missing = record("missing");
  const research = record("idea", "browser", "title", "board", "research-row");
  const result = compileReadiness({ registry: registry([missing, research]), policy: policy(), evidence: { schemaVersion: 1, receipts: [] }, generatedAt: NOW });
  assert.equal(result.readiness.entries.missing.promotionState, "limited");
  assert.equal(result.readiness.entries["board:idea"].promotionState, "research");
});
