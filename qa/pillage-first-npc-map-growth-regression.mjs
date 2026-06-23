#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';

const workdir = process.env.PILLAGE_FIRST_WORKDIR || '/tmp/lan-arcade-pillage-first-build';
const generatedTestPath = 'packages/api/src/http/controllers/__tests__/lan-arcade-map-npc-growth.test.ts';
const packageTestPath = 'src/http/controllers/__tests__/lan-arcade-map-npc-growth.test.ts';
const testPath = path.join(workdir, generatedTestPath);
const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const reportDir = process.env.PILLAGE_FIRST_REPORT_DIR || path.join('qa/reports', `pillage-first-npc-map-growth-regression-${stamp}`);

const testSource = `import { describe, expect, test, vi } from 'vitest';
import { z } from 'zod';
import { prepareTestDatabase } from '@pillage-first/db';
import type { DbFacade } from '@pillage-first/utils/facades/database';
import { getTiles } from '../map-controllers';
import { createControllerArgs } from './utils/controller-args';

const getTargetVillage = (database: DbFacade) =>
  database.selectObject({
    sql: \`
      SELECT v.id AS villageId, v.tile_id AS tileId
      FROM villages v
        JOIN players p ON p.id = v.player_id
        JOIN tiles target_tile ON target_tile.id = v.tile_id
        JOIN villages player_village ON player_village.player_id = 1
        JOIN tiles player_tile ON player_tile.id = player_village.tile_id
      WHERE p.id != 1
        AND ABS(target_tile.x - player_tile.x) <= 12
        AND ABS(target_tile.y - player_tile.y) <= 12
      ORDER BY ABS(target_tile.x - player_tile.x) + ABS(target_tile.y - player_tile.y), v.id
      LIMIT 1;
    \`,
    schema: z.strictObject({ villageId: z.number(), tileId: z.number() }),
  })!;

const getMapPopulation = (database: DbFacade, tileId: number) => {
  const tiles = getTiles(database, createControllerArgs<'/tiles'>({}));
  return tiles.find((tile) => tile?.id === tileId)?.ownerVillage?.population ?? 0;
};

const getPopulation = (database: DbFacade, villageId: number) =>
  database.selectValue({
    sql: \`
      SELECT CAST(COALESCE(ROUND(SUM(CASE WHEN ei.effect = 'wheatProduction' AND e.source = 'building' THEN -e.value ELSE 0 END)), 0) AS INTEGER)
      FROM effects e
        JOIN effect_ids ei ON ei.id = e.effect_id
      WHERE e.village_id = $village_id;
    \`,
    bind: { $village_id: villageId },
    schema: z.number(),
  }) ?? 0;

const getResourceFieldLevelSum = (database: DbFacade, villageId: number) =>
  database.selectValue({
    sql: 'SELECT CAST(COALESCE(SUM(level), 0) AS INTEGER) FROM building_fields WHERE village_id = $village_id AND field_id BETWEEN 1 AND 18;',
    bind: { $village_id: villageId },
    schema: z.number(),
  })!;

describe('LAN Arcade map NPC growth catch-up', () => {
  test('opening the map refreshes stale NPC farm growth and visible population', async () => {
    vi.setSystemTime(24 * 60 * 60 * 1000);
    const database = await prepareTestDatabase();
    const target = getTargetVillage(database);

    database.exec({
      sql: 'UPDATE building_fields SET level = 1 WHERE village_id = $village_id AND field_id BETWEEN 1 AND 18;',
      bind: { $village_id: target.villageId },
    });
    const beforePopulation = getPopulation(database, target.villageId);
    const beforeLevelSum = getResourceFieldLevelSum(database, target.villageId);
    const afterMapPopulation = getMapPopulation(database, target.tileId);

    expect(getResourceFieldLevelSum(database, target.villageId)).toBeGreaterThan(beforeLevelSum);
    expect(afterMapPopulation).toBeGreaterThan(beforePopulation);
  }, 30000);
});
`;

await fs.mkdir(path.dirname(testPath), { recursive: true });
await fs.writeFile(testPath, testSource);

const uid = typeof process.getuid === 'function' ? process.getuid() : 1000;
const gid = typeof process.getgid === 'function' ? process.getgid() : 1000;
const result = spawnSync(
  'docker',
  [
    'run', '--rm',
    '-u', `${uid}:${gid}`,
    '-v', `${workdir}:/work`,
    '-w', '/work/packages/api',
    'node:24-bookworm-slim',
    'npm', 'test', '--', '--run', packageTestPath,
  ],
  { stdio: 'inherit', env: process.env },
);

await fs.mkdir(reportDir, { recursive: true });
await fs.writeFile(path.join(reportDir, 'result.json'), `${JSON.stringify({
  generatedAt: new Date().toISOString(),
  passed: result.status === 0,
  testPath,
  packageTestPath,
}, null, 2)}\n`);
await fs.writeFile(path.join(reportDir, 'result.md'), `# Pillage First NPC Map Growth Regression\n\nGenerated: ${new Date().toISOString()}\nResult: ${result.status === 0 ? 'pass' : 'fail'}\nTest: ${testPath}\n`);

if (result.status !== 0) {
  console.error(`Pillage First NPC map growth regression failed. Report: ${reportDir}`);
  process.exit(result.status ?? 1);
}

console.log(`Pillage First NPC map growth regression passed. Report: ${reportDir}`);
