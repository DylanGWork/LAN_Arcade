#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';

const workdir = process.env.PILLAGE_FIRST_WORKDIR || '/tmp/lan-arcade-pillage-first-build';
const generatedTestPath = 'packages/api/src/http/events/resolvers/__tests__/lan-arcade-scout.test.ts';
const packageTestPath = 'src/http/events/resolvers/__tests__/lan-arcade-scout.test.ts';
const testPath = path.join(workdir, generatedTestPath);
const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const reportDir = process.env.PILLAGE_FIRST_REPORT_DIR || path.join('qa/reports', `pillage-first-scout-regression-${stamp}`);

const testSource = `import { describe, expect, test } from 'vitest';
import { z } from 'zod';
import { prepareTestDatabase } from '@pillage-first/db';
import { createTroopMovementRaidEventMock } from '@pillage-first/mocks/event';
import type { DbFacade } from '@pillage-first/utils/facades/database';
import { raidMovementResolver } from '../troop-movement-resolver';

const sourceVillageId = 1;

const getVillageTileId = (database: DbFacade, villageId: number) =>
  database.selectValue({
    sql: 'SELECT tile_id FROM villages WHERE id = $village_id;',
    bind: { $village_id: villageId },
    schema: z.number(),
  })!;

const getTargetVillage = (database: DbFacade) =>
  database.selectObject({
    sql: \`
      SELECT v.id AS villageId, v.tile_id AS tileId, v.name AS villageName, t.x, t.y, p.name AS playerName
      FROM villages v
        JOIN tiles t ON t.id = v.tile_id
        JOIN players p ON p.id = v.player_id
      WHERE v.id != $source_village_id
      ORDER BY v.id
      LIMIT 1;
    \`,
    bind: { $source_village_id: sourceVillageId },
    schema: z.strictObject({
      villageId: z.number(),
      tileId: z.number(),
      villageName: z.string(),
      x: z.number(),
      y: z.number(),
      playerName: z.string(),
    }),
  })!;

const resetTarget = (database: DbFacade, targetTileId: number) => {
  database.exec({ sql: 'DELETE FROM troops WHERE tile_id = $target_tile_id;', bind: { $target_tile_id: targetTileId } });
  database.exec({
    sql: \`
      INSERT INTO resource_sites (tile_id, wood, clay, iron, wheat, updated_at)
      VALUES ($target_tile_id, 1234, 2345, 3456, 4567, 0)
      ON CONFLICT(tile_id) DO UPDATE SET wood = 1234, clay = 2345, iron = 3456, wheat = 4567, updated_at = 0;
    \`,
    bind: { $target_tile_id: targetTileId },
  });
  database.exec({
    sql: \`
      INSERT INTO troops (unit_id, amount, tile_id, source_tile_id)
      VALUES ((SELECT id FROM unit_ids WHERE unit = 'PHALANX'), 7, $target_tile_id, $target_tile_id);
    \`,
    bind: { $target_tile_id: targetTileId },
  });
};

const getReturnMeta = (database: DbFacade, eventId: number) => {
  const row = database.selectObject({
    sql: \`
      SELECT meta
      FROM events
      WHERE type = 'troopMovementReturn'
        AND JSON_EXTRACT(meta, '$.originalMovementEventId') = $event_id
      LIMIT 1;
    \`,
    bind: { $event_id: eventId },
    schema: z.strictObject({ meta: z.string() }),
  });
  return row ? JSON.parse(row.meta) : null;
};

const getScoutReport = (database: DbFacade, reportId: string) =>
  database.selectObject({
    sql: 'SELECT type, title, body FROM lan_arcade_reports WHERE id = $report_id;',
    bind: { $report_id: reportId },
    schema: z.strictObject({ type: z.string(), title: z.string(), body: z.string() }),
  })!;

describe('LAN Arcade scout missions', () => {
  test('scout-only raid creates intel report, returns scouts, and takes no loot', async () => {
    const database = await prepareTestDatabase();
    const originTileId = getVillageTileId(database, sourceVillageId);
    const target = getTargetVillage(database);
    resetTarget(database, target.tileId);

    raidMovementResolver(database, createTroopMovementRaidEventMock({
      id: 501,
      startsAt: 20_000,
      duration: 200,
      villageId: sourceVillageId,
      originTileId,
      targetTileId: target.tileId,
      troops: [{ unitId: 'ROMAN_SCOUT', amount: 3, tileId: originTileId, source: originTileId }],
    }));

    const meta = getReturnMeta(database, 501)!;
    expect(meta.troops).toEqual([{ unitId: 'ROMAN_SCOUT', amount: 3, tileId: originTileId, source: originTileId }]);
    expect(meta.carriedResources).toBeUndefined();
    expect(meta.attackerLosses).toBeUndefined();

    const report = getScoutReport(database, 'scout-501');
    expect(report.type).toBe('scout-attack');
    expect(report.title).toContain('Scouted');
    expect(report.body).toContain(target.villageName);
    expect(report.body).toContain('(' + target.x + '|' + target.y + ')');
    expect(report.body).toContain('Scouts sent: 3 ROMAN SCOUT');
    expect(report.body).toContain('Defenders present:');
    expect(report.body).toContain('PHALANX');
    expect(report.body).toContain('Resources visible:');
    expect(report.body).toContain('do not loot resources');
  });
});
`;

await fs.mkdir(reportDir, { recursive: true });
let passed = false;
let error = null;
let stdout = '';
let stderr = '';

try {
  const resolverPath = path.join(workdir, 'packages/api/src/http/events/resolvers/troop-movement-resolver.ts');
  const resolverSource = await fs.readFile(resolverPath, 'utf8');
  if (!resolverSource.includes('isLanArcadeScoutOnlyMovement')) {
    throw new Error(`Pillage First generated checkout is missing scout mission patch: ${resolverPath}`);
  }

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
    { encoding: 'utf8' },
  );

  stdout = result.stdout ?? '';
  stderr = result.stderr ?? '';
  passed = result.status === 0;
  if (!passed) {
    error = `vitest exited with status ${result.status}`;
  }
} catch (err) {
  error = err instanceof Error ? err.message : String(err);
}

await fs.writeFile(path.join(reportDir, 'stdout.log'), stdout);
await fs.writeFile(path.join(reportDir, 'stderr.log'), stderr);
await fs.writeFile(path.join(reportDir, 'summary.json'), JSON.stringify({ passed, error, workdir, testPath }, null, 2));

if (!passed) {
  console.error(stdout);
  console.error(stderr);
  console.error(`Pillage First scout regression failed: ${error}. Report: ${reportDir}`);
  process.exit(1);
}

console.log(stdout);
console.log(`Pillage First scout regression passed. Report: ${reportDir}`);
