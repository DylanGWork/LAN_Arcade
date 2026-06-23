#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const sourcePath = process.env.PILLAGE_FIRST_RESOLVER_SOURCE
  || '/tmp/lan-arcade-pillage-first-build/packages/api/src/http/events/resolvers/troop-movement-resolver.ts';
const mapControllerPath = process.env.PILLAGE_FIRST_MAP_CONTROLLER_SOURCE
  || '/tmp/lan-arcade-pillage-first-build/packages/api/src/http/controllers/map-controllers.ts';
const reportDir = process.env.PILLAGE_FIRST_REPORT_DIR || 'qa/reports/pillage-first-npc-growth-source';

const required = [
  'last_developed_at INTEGER',
  'last_conflict_at INTEGER',
  'resource_upgrade_streak INTEGER',
  'currentResourceUpgradeStreak >= 3',
  'const storageCandidates = candidates.filter',
  'calculatePopulationDifference',
  'updatePopulationEffectQuery',
  'updateBuildingEffectQuery',
  'getLanArcadeNpcDevelopmentPriority',
  "building.category === 'resource-production'",
  "row.buildingId === 'WAREHOUSE' || row.buildingId === 'GRANARY'",
  'simulateLanArcadeNpcRegionalConflict',
  'removeLanArcadeNpcDefenders',
  'addVillageResourcesAt(database, target.villageId',
  'refreshLanArcadeNpcVillagesForMap(database, Date.now())',
  'LIMIT 12',
  'ABS(target_tile.x - player_tile.x) <= 12',
  'export const refreshLanArcadeNpcVillagesForMap',
  'growthHoursPerUpgrade',
];

const source = fs.readFileSync(sourcePath, 'utf8');
const mapControllerSource = fs.readFileSync(mapControllerPath, 'utf8');
const combinedSource = `${source}
${mapControllerSource}`;
const missing = required.filter((needle) => !combinedSource.includes(needle));
const duplicateRefresh = source.includes(
  'refreshLanArcadeNpcVillage(database, targetTileId, resolvesAt);\n  refreshLanArcadeNpcVillage(database, targetTileId, resolvesAt);',
);
const refreshCount = source.match(/refreshLanArcadeNpcVillage\(database, targetTileId, resolvesAt\);/g)?.length ?? 0;
const resourcePriorityIndex = source.indexOf("building.category === 'resource-production'");
const militaryPriorityIndex = source.indexOf("return building.category === 'military'");
const resourceBeforeMilitary = resourcePriorityIndex !== -1
  && militaryPriorityIndex !== -1
  && resourcePriorityIndex < militaryPriorityIndex;

const passed = missing.length === 0
  && !duplicateRefresh
  && refreshCount === 2
  && resourceBeforeMilitary;

const report = {
  generatedAt: new Date().toISOString(),
  passed,
  sourcePath,
  mapControllerPath,
  missing,
  duplicateRefresh,
  refreshCount,
  resourceBeforeMilitary,
};

fs.mkdirSync(reportDir, { recursive: true });
fs.writeFileSync(path.join(reportDir, 'result.json'), `${JSON.stringify(report, null, 2)}\n`);
fs.writeFileSync(path.join(reportDir, 'result.md'), renderMarkdown(report));

if (!passed) {
  console.error(`Pillage First NPC growth regression failed. Report: ${reportDir}`);
  process.exit(1);
}

console.log(`Pillage First NPC growth regression passed. Report: ${reportDir}`);

function renderMarkdown(report) {
  return `# Pillage First NPC Growth Regression\n\nGenerated: ${report.generatedAt}\nResult: ${report.passed ? 'pass' : 'fail'}\nSource: ${report.sourcePath}\nMap controller: ${report.mapControllerPath}\nRefresh hook count: ${report.refreshCount}\nResource priority before military: ${report.resourceBeforeMilitary}\nDuplicate refresh hook: ${report.duplicateRefresh}\nMissing required markers: ${report.missing.length ? report.missing.join(', ') : 'none'}\n`;
}
