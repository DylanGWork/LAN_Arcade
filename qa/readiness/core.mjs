const SHA256_RE = /^[0-9a-f]{64}$/;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function isObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function nonEmptyString(value, label) {
  assert(typeof value === "string" && value.trim().length > 0, label + " must be a non-empty string");
}

function validTimestamp(value, label) {
  nonEmptyString(value, label);
  const parsed = Date.parse(value);
  assert(Number.isFinite(parsed), label + " must be an ISO-compatible timestamp");
  return parsed;
}

function newest(receipts) {
  return receipts.slice().sort(function (a, b) {
    const timeDelta = Date.parse(b.observedAt) - Date.parse(a.observedAt);
    return timeDelta || String(b.receiptId).localeCompare(String(a.receiptId));
  })[0] || null;
}

function sortedObject(entries) {
  const output = {};
  entries.slice().sort(function (a, b) {
    return a[0].localeCompare(b[0]);
  }).forEach(function (pair) {
    output[pair[0]] = pair[1];
  });
  return output;
}

export function validatePolicy(policy) {
  assert(isObject(policy), "Readiness policy must be an object");
  assert(policy.schemaVersion === 1, "Unsupported readiness policy schemaVersion");
  nonEmptyString(policy.policyId, "policyId");
  assert(isObject(policy.tiers), "Policy tiers must be an object");
  ["T0", "T1", "T2", "T3", "T4"].forEach(function (tier, rank) {
    assert(isObject(policy.tiers[tier]), "Policy is missing tier " + tier);
    assert(policy.tiers[tier].rank === rank, tier + " rank must be " + rank);
  });
  assert(Array.isArray(policy.outcomes), "Policy outcomes must be an array");
  ["pass", "partial", "fail", "blocked", "unverified"].forEach(function (outcome) {
    assert(policy.outcomes.includes(outcome), "Policy is missing outcome " + outcome);
  });
  assert(Array.isArray(policy.promotionStates), "Policy promotionStates must be an array");
  ["ready", "limited", "quarantined", "research"].forEach(function (state) {
    assert(policy.promotionStates.includes(state), "Policy is missing promotion state " + state);
  });
  assert(Array.isArray(policy.contentTypes), "Policy contentTypes must be an array");
  assert(isObject(policy.readyThresholds), "Policy readyThresholds must be an object");
  assert(isObject(policy.entrySources), "Policy entrySources must be an object");
  Object.entries(policy.entrySources).forEach(function (pair) {
    const source = pair[0];
    const rule = pair[1];
    assert(isObject(rule), "Entry-source rule must be an object: " + source);
    assert(typeof rule.prefix === "string", "Entry-source prefix must be a string: " + source);
    assert(Array.isArray(rule.recordTypes) && rule.recordTypes.length > 0, "Entry-source recordTypes missing: " + source);
    nonEmptyString(rule.collectionTarget, "collectionTarget for " + source);
    assert(rule.collectionTarget.startsWith("/mirrors/"), "Collection target must remain local: " + source);
  });
  assert(policy.requireOfflineForReady === true, "Ready promotion must require offline evidence");
  assert(policy.requireExplicitExpiry === true, "Receipts must have explicit expiry");
  return policy;
}

export function validateRegistry(registry) {
  assert(isObject(registry), "Canonical registry must be an object");
  assert(Array.isArray(registry.records), "Canonical registry records must be an array");
  assert(Array.isArray(registry.entities), "Canonical registry entities must be an array");
  assert(Array.isArray(registry.sources), "Canonical registry sources must be an array");
  nonEmptyString(registry.inputDigestSha256, "registry inputDigestSha256");
  assert(SHA256_RE.test(registry.inputDigestSha256), "Registry input digest must be SHA-256");
  return registry;
}

export function buildPublicEntries(registry, policy) {
  validateRegistry(registry);
  validatePolicy(policy);
  const entities = new Map(registry.entities.map(function (entity) {
    return [String(entity.entityId), entity];
  }));
  const sourceFingerprints = new Map(registry.sources.map(function (source) {
    return [String(source.sourceCollection), String(source.contentSha256 || "")];
  }));
  const entries = new Map();

  registry.records.slice().sort(function (a, b) {
    return String(a.recordId).localeCompare(String(b.recordId));
  }).forEach(function (record) {
    const rule = policy.entrySources[record.sourceCollection];
    if (!rule || !rule.recordTypes.includes(record.recordType)) return;
    const entity = entities.get(String(record.entityId));
    assert(entity, "Record references missing entity: " + record.recordId);
    const entryId = String(rule.prefix) + String(record.sourceRecordId);
    assert(!entries.has(entryId), "Duplicate public entry ID: " + entryId);
    const sourceFingerprint = sourceFingerprints.get(String(record.sourceCollection));
    assert(SHA256_RE.test(sourceFingerprint || ""), "Missing source fingerprint for " + record.sourceCollection);
    const adapter = String((record.launcher && record.launcher.adapter) || "");
    const target = String((record.launcher && record.launcher.target) || "");
    assert(target.startsWith("/mirrors/"), "Public entry target must remain local: " + entryId);

    let contentType = "single-player";
    if (record.recordType === "research-row" || (record.dimensions && record.dimensions.researchOnly)) {
      contentType = "research";
    } else if (record.entityKind === "collection" || entity.kind === "collection") {
      contentType = "collection";
    } else if (policy.adapterContentTypes && policy.adapterContentTypes[adapter]) {
      contentType = policy.adapterContentTypes[adapter];
    }
    if (policy.contentTypeOverrides && policy.contentTypeOverrides[entryId]) {
      contentType = policy.contentTypeOverrides[entryId];
    }
    assert(policy.contentTypes.includes(contentType), "Unsupported content type for " + entryId);

    entries.set(entryId, {
      entryId,
      recordId: String(record.recordId),
      entityId: String(record.entityId),
      title: String(record.title || entity.canonicalTitle || entryId),
      sourceCollection: String(record.sourceCollection),
      sourceFingerprint,
      recordType: String(record.recordType),
      contentType,
      adapter,
      target,
      collectionTarget: String(rule.collectionTarget),
      nested: String(rule.prefix).length > 0,
      researchOnly: contentType === "research",
      collectionOnly: contentType === "collection"
    });
  });

  return entries;
}

export function validateReceipt(receipt, policy, label) {
  const prefix = label || "receipt";
  assert(isObject(receipt), prefix + " must be an object");
  nonEmptyString(receipt.receiptId, prefix + ".receiptId");
  assert(isObject(receipt.entry), prefix + ".entry must be an object");
  ["entryId", "recordId", "entityId"].forEach(function (key) {
    nonEmptyString(receipt.entry[key], prefix + ".entry." + key);
  });
  assert(policy.contentTypes.includes(receipt.contentType), prefix + ".contentType is invalid");
  nonEmptyString(receipt.target, prefix + ".target");
  assert(receipt.target.startsWith("/mirrors/"), prefix + ".target must remain under /mirrors/");
  assert(isObject(receipt.fingerprint), prefix + ".fingerprint must be an object");
  assert(receipt.fingerprint.algorithm === "sha256", prefix + ".fingerprint.algorithm must be sha256");
  assert(receipt.fingerprint.kind === "registry-source", prefix + ".fingerprint.kind must be registry-source");
  nonEmptyString(receipt.fingerprint.sourceCollection, prefix + ".fingerprint.sourceCollection");
  assert(SHA256_RE.test(receipt.fingerprint.value || ""), prefix + ".fingerprint.value must be SHA-256");
  assert(isObject(receipt.runner), prefix + ".runner must be an object");
  nonEmptyString(receipt.runner.name, prefix + ".runner.name");
  nonEmptyString(receipt.runner.commit, prefix + ".runner.commit");
  assert(isObject(receipt.environment), prefix + ".environment must be an object");
  nonEmptyString(receipt.environment.lanOrigin, prefix + ".environment.lanOrigin");
  nonEmptyString(receipt.environment.deviceProfile, prefix + ".environment.deviceProfile");
  assert(typeof receipt.environment.offline === "boolean", prefix + ".environment.offline must be boolean");
  assert(Object.prototype.hasOwnProperty.call(policy.tiers, receipt.tier), prefix + ".tier is invalid");
  assert(policy.outcomes.includes(receipt.outcome), prefix + ".outcome is invalid");
  assert(Array.isArray(receipt.assertions) && receipt.assertions.length > 0, prefix + ".assertions must not be empty");
  receipt.assertions.forEach(function (item, index) {
    assert(isObject(item), prefix + ".assertions[" + index + "] must be an object");
    nonEmptyString(item.id, prefix + ".assertions[" + index + "].id");
    nonEmptyString(item.description, prefix + ".assertions[" + index + "].description");
    assert(typeof item.passed === "boolean", prefix + ".assertions[" + index + "].passed must be boolean");
  });
  if (receipt.outcome === "pass") {
    assert(receipt.assertions.every(function (item) { return item.passed; }), prefix + " pass outcome cannot contain a failed assertion");
  }
  if (receipt.outcome === "fail") {
    assert(receipt.assertions.some(function (item) { return !item.passed; }), prefix + " fail outcome must contain a failed assertion");
  }
  const observed = validTimestamp(receipt.observedAt, prefix + ".observedAt");
  const recorded = validTimestamp(receipt.recordedAt, prefix + ".recordedAt");
  const expires = validTimestamp(receipt.expiresAt, prefix + ".expiresAt");
  assert(recorded >= observed, prefix + ".recordedAt cannot predate observedAt");
  assert(expires > observed, prefix + ".expiresAt must be later than observedAt");
  assert(Array.isArray(receipt.evidencePaths) && receipt.evidencePaths.length > 0, prefix + ".evidencePaths must not be empty");
  receipt.evidencePaths.forEach(function (evidencePath, index) {
    nonEmptyString(evidencePath, prefix + ".evidencePaths[" + index + "]");
    assert(!String(evidencePath).startsWith("/"), prefix + ".evidencePaths must be repo-relative");
    assert(!String(evidencePath).includes(".."), prefix + ".evidencePaths cannot traverse directories");
  });
  return receipt;
}

export function validateEvidenceDocument(evidence, policy) {
  assert(isObject(evidence), "Readiness evidence document must be an object");
  assert(evidence.schemaVersion === 1, "Unsupported readiness evidence schemaVersion");
  assert(Array.isArray(evidence.receipts), "Readiness evidence receipts must be an array");
  const ids = new Set();
  evidence.receipts.forEach(function (receipt, index) {
    validateReceipt(receipt, policy, "receipts[" + index + "]");
    assert(!ids.has(receipt.receiptId), "Duplicate receipt ID: " + receipt.receiptId);
    ids.add(receipt.receiptId);
  });
  return evidence;
}

function semanticReceiptStatus(receipt, entry, now) {
  const identityMatches = receipt.entry.recordId === entry.recordId
    && receipt.entry.entityId === entry.entityId
    && receipt.contentType === entry.contentType
    && receipt.target === entry.target
    && receipt.fingerprint.sourceCollection === entry.sourceCollection;
  const fingerprintMatches = identityMatches && receipt.fingerprint.value === entry.sourceFingerprint;
  if (!identityMatches || !fingerprintMatches) return "mismatched";
  if (Date.parse(receipt.expiresAt) <= now) return "expired";
  return "current";
}

function displayFor(entry, state, policy) {
  const labels = policy.publicLabels || {};
  if (entry.collectionOnly) {
    return { label: labels.collection || "Open collection", actionLabel: "Open collection", actionTarget: entry.target, launchHint: "Browse this collection" };
  }
  if (state === "ready") {
    return { label: labels.ready || "Ready to play", actionLabel: entry.contentType === "single-player" ? "Play" : "Start / join", actionTarget: entry.target, launchHint: "Played successfully without internet" };
  }
  if (state === "quarantined") {
    return { label: labels.quarantined || "Not ready", actionLabel: entry.nested ? "Back to collection" : "View issue", actionTarget: entry.nested ? entry.collectionTarget : entry.target, launchHint: "A known problem prevents normal play" };
  }
  if (state === "research") {
    return { label: labels.research || "Planning only", actionLabel: "Read details", actionTarget: entry.collectionTarget, launchHint: "Not yet available to play" };
  }
  return { label: labels.limited || "Needs play testing", actionLabel: "Try", actionTarget: entry.target, launchHint: "Launch exists, but gameplay has not been fully verified" };
}

function limitedReason(receipts, current, expired, mismatched, policy, entry) {
  if (receipts.length === 0) return "missing-evidence";
  if (current.length === 0 && expired.length > 0 && mismatched.length === 0) return "stale-evidence";
  if (current.length === 0 && mismatched.length > 0) return "fingerprint-or-identity-mismatch";
  const passes = current.filter(function (receipt) { return receipt.outcome === "pass"; });
  if (passes.some(function (receipt) { return !receipt.environment.offline; })) return "offline-pass-required";
  const threshold = policy.readyThresholds[entry.contentType];
  if (threshold && passes.some(function (receipt) {
    return policy.tiers[receipt.tier].rank < policy.tiers[threshold].rank;
  })) return "tier-below-" + threshold;
  if (current.some(function (receipt) { return receipt.outcome === "partial"; })) return "partial-evidence";
  if (current.some(function (receipt) { return receipt.outcome === "unverified"; })) return "unverified-evidence";
  return "no-qualifying-pass";
}

function decisionForEntry(entry, receipts, policy, generatedAt) {
  const now = Date.parse(generatedAt);
  const current = [];
  const expired = [];
  const mismatched = [];
  receipts.forEach(function (receipt) {
    const status = semanticReceiptStatus(receipt, entry, now);
    if (status === "current") current.push(receipt);
    else if (status === "expired") expired.push(receipt);
    else mismatched.push(receipt);
  });

  let state = "limited";
  let reason = "missing-evidence";
  let acceptedPass = null;
  let acceptedBlocker = null;
  const threshold = policy.readyThresholds[entry.contentType] || null;

  if (entry.researchOnly) {
    state = "research";
    reason = "research-row";
  } else if (entry.collectionOnly) {
    state = "limited";
    reason = "collection-navigation-only";
  } else {
    const qualifyingPasses = current.filter(function (receipt) {
      return receipt.outcome === "pass"
        && receipt.environment.offline === true
        && threshold
        && policy.tiers[receipt.tier].rank >= policy.tiers[threshold].rank;
    });
    const blockers = current.filter(function (receipt) {
      return receipt.outcome === "fail" || receipt.outcome === "blocked";
    });
    acceptedPass = newest(qualifyingPasses);
    acceptedBlocker = newest(blockers);
    if (acceptedBlocker && (!acceptedPass || Date.parse(acceptedBlocker.observedAt) >= Date.parse(acceptedPass.observedAt))) {
      state = "quarantined";
      reason = "newer-" + acceptedBlocker.outcome;
    } else if (acceptedPass) {
      state = "ready";
      reason = "offline-" + acceptedPass.tier + "-pass";
    } else {
      state = "limited";
      reason = limitedReason(receipts, current, expired, mismatched, policy, entry);
    }
  }

  const display = displayFor(entry, state, policy);
  return {
    entryId: entry.entryId,
    recordId: entry.recordId,
    entityId: entry.entityId,
    title: entry.title,
    sourceCollection: entry.sourceCollection,
    recordType: entry.recordType,
    contentType: entry.contentType,
    adapter: entry.adapter,
    target: entry.target,
    sourceFingerprint: {
      algorithm: "sha256",
      kind: "registry-source",
      sourceCollection: entry.sourceCollection,
      value: entry.sourceFingerprint
    },
    promotionState: state,
    reason,
    requiredTier: threshold,
    displayLabel: display.label,
    actionLabel: display.actionLabel,
    actionTarget: display.actionTarget,
    launchHint: display.launchHint,
    evidence: {
      acceptedPassReceiptId: acceptedPass ? acceptedPass.receiptId : null,
      acceptedBlockerReceiptId: acceptedBlocker ? acceptedBlocker.receiptId : null,
      latestCurrentReceiptId: newest(current) ? newest(current).receiptId : null,
      currentReceiptIds: current.map(function (receipt) { return receipt.receiptId; }).sort(),
      expiredReceiptIds: expired.map(function (receipt) { return receipt.receiptId; }).sort(),
      mismatchedReceiptIds: mismatched.map(function (receipt) { return receipt.receiptId; }).sort()
    }
  };
}

export function compileReadiness(input) {
  const registry = validateRegistry(input.registry);
  const policy = validatePolicy(input.policy);
  const evidence = validateEvidenceDocument(input.evidence, policy);
  const generatedAt = input.generatedAt || new Date().toISOString();
  validTimestamp(generatedAt, "generatedAt");
  const entries = buildPublicEntries(registry, policy);
  const grouped = new Map();

  evidence.receipts.forEach(function (receipt) {
    const entry = entries.get(receipt.entry.entryId);
    assert(entry, "Receipt references unknown public entry: " + receipt.entry.entryId);
    if (!grouped.has(entry.entryId)) grouped.set(entry.entryId, []);
    grouped.get(entry.entryId).push(receipt);
  });

  const decisions = [];
  entries.forEach(function (entry) {
    decisions.push(decisionForEntry(entry, grouped.get(entry.entryId) || [], policy, generatedAt));
  });
  decisions.sort(function (a, b) { return a.entryId.localeCompare(b.entryId); });

  const stateCount = function (state) {
    return decisions.filter(function (decision) { return decision.promotionState === state; }).length;
  };
  const currentReceiptIds = new Set();
  decisions.forEach(function (decision) {
    decision.evidence.currentReceiptIds.forEach(function (receiptId) { currentReceiptIds.add(receiptId); });
  });

  const readiness = {
    schemaVersion: 1,
    authority: policy.policyId,
    generatedAt,
    registry: {
      schemaVersion: registry.schemaVersion,
      inputDigestSha256: registry.inputDigestSha256
    },
    tiers: policy.tiers,
    metrics: {
      publicEntries: decisions.length,
      readyEntries: stateCount("ready"),
      limitedEntries: stateCount("limited"),
      quarantinedEntries: stateCount("quarantined"),
      researchEntries: stateCount("research"),
      structuredReceipts: evidence.receipts.length,
      currentReceipts: currentReceiptIds.size
    },
    entries: sortedObject(decisions.map(function (decision) {
      return [decision.entryId, decision];
    }))
  };

  const quarantineEntries = decisions.filter(function (decision) {
    return decision.promotionState === "quarantined";
  }).map(function (decision) {
    return {
      entryId: decision.entryId,
      recordId: decision.recordId,
      entityId: decision.entityId,
      title: decision.title,
      target: decision.target,
      safeActionTarget: decision.actionTarget,
      reason: decision.reason,
      receiptId: decision.evidence.acceptedBlockerReceiptId
    };
  });
  const quarantine = {
    schemaVersion: 1,
    authority: policy.policyId,
    generatedAt,
    registryInputDigestSha256: registry.inputDigestSha256,
    entries: quarantineEntries
  };
  return { readiness, quarantine };
}
