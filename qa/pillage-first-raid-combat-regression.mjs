#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';

const workdir = process.env.PILLAGE_FIRST_WORKDIR || '/tmp/lan-arcade-pillage-first-build';
const generatedTestPath = 'packages/api/src/http/events/resolvers/__tests__/lan-arcade-raid-combat.test.ts';
const packageTestPath = 'src/http/events/resolvers/__tests__/lan-arcade-raid-combat.test.ts';
const testPath = path.join(workdir, generatedTestPath);
const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const reportDir = process.env.PILLAGE_FIRST_REPORT_DIR || path.join('qa/reports', `pillage-first-raid-combat-regression-${stamp}`);
const testSource = "import { describe, expect, test } from 'vitest';\nimport { z } from 'zod';\nimport { prepareTestDatabase } from '@pillage-first/db';\nimport {\n  createTroopMovementAttackEventMock,\n  createTroopMovementRaidEventMock,\n} from '@pillage-first/mocks/event';\nimport type { DbFacade } from '@pillage-first/utils/facades/database';\nimport { attackMovementResolver, raidMovementResolver } from '../troop-movement-resolver';\n\nconst sourceVillageId = 1;\n\nconst getVillageTileId = (database: DbFacade, villageId: number) =>\n  database.selectValue({\n    sql: 'SELECT tile_id FROM villages WHERE id = $village_id;',\n    bind: { $village_id: villageId },\n    schema: z.number(),\n  })!;\n\nconst getTargetVillage = (database: DbFacade) =>\n  database.selectObject({\n    sql: `\n      SELECT id AS villageId, tile_id AS tileId\n      FROM villages\n      WHERE id != $source_village_id\n      ORDER BY id\n      LIMIT 1;\n    `,\n    bind: { $source_village_id: sourceVillageId },\n    schema: z.strictObject({ villageId: z.number(), tileId: z.number() }),\n  })!;\n\nconst resetTarget = (\n  database: DbFacade,\n  targetTileId: number,\n  defenders: { unitId: string; amount: number }[] = [],\n) => {\n  database.exec({\n    sql: 'DELETE FROM troops WHERE tile_id = $target_tile_id;',\n    bind: { $target_tile_id: targetTileId },\n  });\n  database.exec({\n    sql: `\n      INSERT INTO resource_sites (tile_id, wood, clay, iron, wheat, updated_at)\n      VALUES ($target_tile_id, 10000, 10000, 10000, 10000, 0)\n      ON CONFLICT(tile_id) DO UPDATE SET\n        wood = 10000,\n        clay = 10000,\n        iron = 10000,\n        wheat = 10000,\n        updated_at = 0;\n    `,\n    bind: { $target_tile_id: targetTileId },\n  });\n\n  for (const defender of defenders) {\n    database.exec({\n      sql: `\n        INSERT INTO troops (unit_id, amount, tile_id, source_tile_id)\n        VALUES ((SELECT id FROM unit_ids WHERE unit = $unit_id), $amount, $target_tile_id, $target_tile_id);\n      `,\n      bind: {\n        $unit_id: defender.unitId,\n        $amount: defender.amount,\n        $target_tile_id: targetTileId,\n      },\n    });\n  }\n};\n\nconst getReturnMeta = (database: DbFacade, eventId: number) => {\n  const row = database.selectObject({\n    sql: `\n      SELECT meta\n      FROM events\n      WHERE type = 'troopMovementReturn'\n        AND JSON_EXTRACT(meta, '$.originalMovementEventId') = $event_id\n      LIMIT 1;\n    `,\n    bind: { $event_id: eventId },\n    schema: z.strictObject({ meta: z.string() }),\n  });\n\n  return row ? JSON.parse(row.meta) : null;\n};\n\nconst getReport = (database: DbFacade, reportId: string) =>\n  database.selectObject({\n    sql: 'SELECT title, body FROM lan_arcade_reports WHERE id = $report_id;',\n    bind: { $report_id: reportId },\n    schema: z.strictObject({ title: z.string(), body: z.string() }),\n  })!;\n\nconst sumResources = (resources: number[]) => resources.reduce((sum, amount) => sum + amount, 0);\n\ndescribe('LAN Arcade raid combat', () => {\n  test('raid against an undefended village takes loot with no losses', async () => {\n    const database = await prepareTestDatabase();\n    const originTileId = getVillageTileId(database, sourceVillageId);\n    const target = getTargetVillage(database);\n    resetTarget(database, target.tileId);\n\n    raidMovementResolver(database, createTroopMovementRaidEventMock({\n      id: 101,\n      startsAt: 10_000,\n      duration: 200,\n      villageId: sourceVillageId,\n      originTileId,\n      targetTileId: target.tileId,\n      troops: [{ unitId: 'LEGIONNAIRE', amount: 5, tileId: originTileId, source: originTileId }],\n    }));\n\n    const meta = getReturnMeta(database, 101)!;\n    expect(meta.attackerLosses).toEqual([]);\n    expect(sumResources(meta.carriedResources)).toBe(250);\n    expect(getReport(database, 'raid-101').body).toContain('Defenders present: none');\n  });\n\n  test('raid against light defence loses some attackers, kills defenders, and loots with survivors only', async () => {\n    const database = await prepareTestDatabase();\n    const originTileId = getVillageTileId(database, sourceVillageId);\n    const target = getTargetVillage(database);\n    resetTarget(database, target.tileId, [{ unitId: 'PHALANX', amount: 1 }]);\n\n    raidMovementResolver(database, createTroopMovementRaidEventMock({\n      id: 102,\n      startsAt: 11_000,\n      duration: 200,\n      villageId: sourceVillageId,\n      originTileId,\n      targetTileId: target.tileId,\n      troops: [{ unitId: 'LEGIONNAIRE', amount: 20, tileId: originTileId, source: originTileId }],\n    }));\n\n    const meta = getReturnMeta(database, 102)!;\n    const survivingAttackers = meta.troops.reduce((sum: number, troop: { amount: number }) => sum + troop.amount, 0);\n    const lootTotal = sumResources(meta.carriedResources);\n    expect(survivingAttackers).toBeLessThan(20);\n    expect(survivingAttackers).toBeGreaterThan(0);\n    expect(lootTotal).toBeGreaterThan(0);\n    expect(lootTotal).toBeLessThanOrEqual(survivingAttackers * 50);\n    expect(meta.defenderLosses).toEqual([{ unitId: 'PHALANX', amount: 1, tileId: target.tileId, source: target.tileId }]);\n    expect(getReport(database, 'raid-102').body).toContain('Loot:');\n  });\n\n  test('raid against strong defence kills attackers and takes no loot', async () => {\n    const database = await prepareTestDatabase();\n    const originTileId = getVillageTileId(database, sourceVillageId);\n    const target = getTargetVillage(database);\n    resetTarget(database, target.tileId, [{ unitId: 'PHALANX', amount: 20 }]);\n\n    raidMovementResolver(database, createTroopMovementRaidEventMock({\n      id: 103,\n      startsAt: 12_000,\n      duration: 200,\n      villageId: sourceVillageId,\n      originTileId,\n      targetTileId: target.tileId,\n      troops: [{ unitId: 'LEGIONNAIRE', amount: 1, tileId: originTileId, source: originTileId }],\n    }));\n\n    expect(getReturnMeta(database, 103)).toBeNull();\n    const report = getReport(database, 'raid-103');\n    expect(report.title).toContain('Raid failed');\n    expect(report.body).toContain('Attackers returned: none');\n    expect(report.body).toContain('Loot: 0 wood, 0 clay, 0 iron, 0 wheat');\n  });\n\n  test('normal attack resolves combat and does not carry loot', async () => {\n    const database = await prepareTestDatabase();\n    const originTileId = getVillageTileId(database, sourceVillageId);\n    const target = getTargetVillage(database);\n    resetTarget(database, target.tileId, [{ unitId: 'PHALANX', amount: 1 }]);\n\n    attackMovementResolver(database, createTroopMovementAttackEventMock({\n      id: 104,\n      startsAt: 13_000,\n      duration: 200,\n      villageId: sourceVillageId,\n      originTileId,\n      targetTileId: target.tileId,\n      troops: [{ unitId: 'LEGIONNAIRE', amount: 20, tileId: originTileId, source: originTileId }],\n    }));\n\n    const meta = getReturnMeta(database, 104)!;\n    expect(meta.carriedResources).toBeUndefined();\n    expect(meta.defenderLosses).toEqual([{ unitId: 'PHALANX', amount: 1, tileId: target.tileId, source: target.tileId }]);\n    expect(getReport(database, 'attack-104').body).toContain('Defender losses: 1 PHALANX');\n  });\n});\n";

await fs.mkdir(reportDir, { recursive: true });

let passed = false;
let error = null;
let stdout = '';
let stderr = '';

try {
  const resolverPath = path.join(workdir, 'packages/api/src/http/events/resolvers/troop-movement-resolver.ts');
  const resolverSource = await fs.readFile(resolverPath, 'utf8');
  if (!resolverSource.includes('resolveLanArcadeCombat')) {
    throw new Error(`Pillage First generated checkout is missing raid combat patch: ${resolverPath}`);
  }

  await fs.writeFile(testPath, testSource);

  const uid = typeof process.getuid === 'function' ? process.getuid() : 1000;
  const gid = typeof process.getgid === 'function' ? process.getgid() : 1000;
  const result = spawnSync('docker', [
    'run',
    '--rm',
    '-u', `${uid}:${gid}`,
    '-e', 'HOME=/tmp',
    '-e', 'npm_config_cache=/tmp/npm-cache',
    '-v', `${workdir}:/work`,
    '-w', '/work',
    'node:24-bookworm',
    'bash',
    '-lc',
    `npx -y npm@11.16.0 run -w @pillage-first/api test -- --run ${packageTestPath}`,
  ], { encoding: 'utf8' });

  stdout = result.stdout || '';
  stderr = result.stderr || '';
  passed = result.status === 0;
  if (!passed) {
    error = `vitest exited with status ${result.status}`;
  }
} catch (caught) {
  error = caught?.stack || caught?.message || String(caught);
} finally {
  await fs.rm(testPath, { force: true }).catch(() => {});
}

const report = {
  generatedAt: new Date().toISOString(),
  passed,
  workdir,
  generatedTestPath,
  packageTestPath,
  stdout,
  stderr,
  error,
};

await fs.writeFile(path.join(reportDir, 'result.json'), `${JSON.stringify(report, null, 2)}
`);
await fs.writeFile(path.join(reportDir, 'result.md'), renderMarkdown(report));

if (stdout) process.stdout.write(stdout);
if (stderr) process.stderr.write(stderr);

if (!passed) {
  console.error(`Pillage First raid combat regression failed. Report: ${reportDir}`);
  process.exitCode = 1;
} else {
  console.log(`Pillage First raid combat regression passed. Report: ${reportDir}`);
}

function renderMarkdown(report) {
  return `# Pillage First Raid Combat Regression

Generated: ${report.generatedAt}
Result: ${report.passed ? 'pass' : 'fail'}
Generated checkout: ${report.workdir}
Generated test: ${report.generatedTestPath}\nVitest path: ${report.packageTestPath}

${report.error ? `Error:

\`\`\`
${report.error}
\`\`\`
` : ''}
Stdout:

\`\`\`
${report.stdout || ''}
\`\`\`

Stderr:

\`\`\`
${report.stderr || ''}
\`\`\`
`;
}
