#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';

const workdir = process.env.PILLAGE_FIRST_WORKDIR || '/tmp/lan-arcade-pillage-first-build';
const generatedTestPath = 'packages/api/src/http/controllers/__tests__/lan-arcade-troop-movement-visibility.test.ts';
const packageTestPath = 'src/http/controllers/__tests__/lan-arcade-troop-movement-visibility.test.ts';
const testPath = path.join(workdir, generatedTestPath);
const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const reportDir = process.env.PILLAGE_FIRST_REPORT_DIR || path.join('qa/reports', `pillage-first-troop-movement-visibility-${stamp}`);

const testSource = `import { describe, expect, test } from 'vitest';
import { z } from 'zod';
import { prepareTestDatabase } from '@pillage-first/db';
import { PLAYER_ID } from '@pillage-first/game-assets/player';
import type { DbFacade } from '@pillage-first/utils/facades/database';
import { getVillageTroopMovements, validateTroopMovement } from '../troop-movement-controllers';
import { createControllerArgs } from './utils/controller-args';

const getPlayerVillage = (database: DbFacade) =>
  database.selectObject({
    sql: 'SELECT id, tile_id FROM villages WHERE player_id = $player_id ORDER BY id LIMIT 1;',
    bind: { $player_id: PLAYER_ID },
    schema: z.strictObject({ id: z.number(), tile_id: z.number() }),
  })!;

const getOtherVillage = (database: DbFacade) =>
  database.selectObject({
    sql: 'SELECT id, tile_id FROM villages WHERE player_id != $player_id ORDER BY id LIMIT 1;',
    bind: { $player_id: PLAYER_ID },
    schema: z.strictObject({ id: z.number(), tile_id: z.number() }),
  })!;

describe('LAN Arcade troop movement visibility', () => {
  test('active movement DTO includes total troops and unit manifest', async () => {
    const database = await prepareTestDatabase();
    database.exec({ sql: 'DELETE FROM events;' });
    const origin = getPlayerVillage(database);
    const target = getOtherVillage(database);

    database.exec({
      sql: \`
        INSERT INTO events (type, starts_at, duration, village_id, meta)
        VALUES ('troopMovementRaid', 1000, 5000, $village_id, $meta);
      \`,
      bind: {
        $village_id: origin.id,
        $meta: JSON.stringify({
          originTileId: origin.tile_id,
          targetTileId: target.tile_id,
          troops: [
            { unitId: 'PHALANX', amount: 19, tileId: origin.tile_id, source: origin.tile_id },
            { unitId: 'THEUTATES_THUNDER', amount: 268, tileId: origin.tile_id, source: origin.tile_id },
          ],
        }),
      },
    });

    const movements = getVillageTroopMovements(
      database,
      createControllerArgs<'/villages/:villageId/troop-movements'>({ path: { villageId: origin.id } }),
    );

    expect(movements).toHaveLength(1);
    expect(movements[0]).toMatchObject({
      type: 'troopMovementRaid',
      totalTroops: 287,
      troops: [
        { unitId: 'PHALANX', amount: 19 },
        { unitId: 'THEUTATES_THUNDER', amount: 268 },
      ],
    });
  });

  test('troop movement validation rejects empty and unavailable sends', async () => {
    const database = await prepareTestDatabase();
    const origin = getPlayerVillage(database);
    const target = getOtherVillage(database);

    const empty = validateTroopMovement(
      database,
      createControllerArgs<'/troop-movements/validate', 'post'>({
        body: {
          type: 'troopMovementRaid',
          villageId: origin.id,
          targetTileId: target.tile_id,
          troops: [],
        },
      }),
    );
    expect(empty.errors).toContain('At least one troop must be selected');

    const unavailable = validateTroopMovement(
      database,
      createControllerArgs<'/troop-movements/validate', 'post'>({
        body: {
          type: 'troopMovementRaid',
          villageId: origin.id,
          targetTileId: target.tile_id,
          troops: [{ unitId: 'THEUTATES_THUNDER', amount: 999999 }],
        },
      }),
    );
    expect(unavailable.errors).toContain('Not enough THEUTATES_THUNDER available');
  });
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
await fs.writeFile(path.join(reportDir, 'result.md'), `# Pillage First Troop Movement Visibility Regression\n\nGenerated: ${new Date().toISOString()}\nResult: ${result.status === 0 ? 'pass' : 'fail'}\nTest: ${testPath}\n`);

if (result.status !== 0) {
  console.error(`Pillage First troop movement visibility regression failed. Report: ${reportDir}`);
  process.exit(result.status ?? 1);
}

console.log(`Pillage First troop movement visibility regression passed. Report: ${reportDir}`);
