#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';

const workdir = process.env.PILLAGE_FIRST_WORKDIR || '/tmp/lan-arcade-pillage-first-build';
const generatedTestPath = 'packages/api/src/http/events/resolvers/__tests__/lan-arcade-npc-treasure.test.ts';
const packageTestPath = 'src/http/events/resolvers/__tests__/lan-arcade-npc-treasure.test.ts';
const testPath = path.join(workdir, generatedTestPath);
const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const reportDir = process.env.PILLAGE_FIRST_REPORT_DIR || path.join('qa/reports', `pillage-first-npc-treasure-regression-${stamp}`);

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
      SELECT v.id AS villageId, v.tile_id AS tileId, v.name AS villageName
      FROM villages v
      WHERE v.id != $source_village_id
      ORDER BY v.id
      LIMIT 1;
    \`,
    bind: { $source_village_id: sourceVillageId },
    schema: z.strictObject({ villageId: z.number(), tileId: z.number(), villageName: z.string() }),
  })!;

const resetTarget = (database: DbFacade, targetTileId: number) => {
  database.exec({ sql: 'DELETE FROM troops WHERE tile_id = $target_tile_id;', bind: { $target_tile_id: targetTileId } });
  database.exec({ sql: 'DELETE FROM world_items WHERE tile_id = $target_tile_id;', bind: { $target_tile_id: targetTileId } });
  database.exec({
    sql: \`
      INSERT INTO resource_sites (tile_id, wood, clay, iron, wheat, updated_at)
      VALUES ($target_tile_id, 10000, 10000, 10000, 10000, 0)
      ON CONFLICT(tile_id) DO UPDATE SET wood = 10000, clay = 10000, iron = 10000, wheat = 10000, updated_at = 0;
    \`,
    bind: { $target_tile_id: targetTileId },
  });
};

const ensureNoNpcRefresh = (database: DbFacade, tileId: number, timestamp: number) => {
  database.exec({
    sql: \`
      CREATE TABLE IF NOT EXISTS lan_arcade_npc_growth
      (
        tile_id INTEGER PRIMARY KEY,
        last_reinforced_at INTEGER NOT NULL
      ) STRICT;
    \`,
  });
  database.exec({
    sql: \`
      INSERT INTO lan_arcade_npc_growth (tile_id, last_reinforced_at)
      VALUES ($tile_id, $timestamp)
      ON CONFLICT(tile_id) DO UPDATE SET last_reinforced_at = $timestamp;
    \`,
    bind: { $tile_id: tileId, $timestamp: timestamp },
  });
};

const countTargetDefenders = (database: DbFacade, tileId: number) =>
  database.selectValue({
    sql: 'SELECT CAST(COALESCE(SUM(amount), 0) AS INTEGER) FROM troops WHERE tile_id = $tile_id;',
    bind: { $tile_id: tileId },
    schema: z.number(),
  })!;

const getResourceFieldLevelSum = (database: DbFacade, villageId: number) =>
  database.selectValue({
    sql: 'SELECT CAST(COALESCE(SUM(level), 0) AS INTEGER) FROM building_fields WHERE village_id = $village_id AND field_id BETWEEN 1 AND 18;',
    bind: { $village_id: villageId },
    schema: z.number(),
  })!;

const getStorageLevelSum = (database: DbFacade, villageId: number) =>
  database.selectValue({
    sql: "SELECT CAST(COALESCE(SUM(bf.level), 0) AS INTEGER) FROM building_fields bf JOIN building_ids bi ON bi.id = bf.building_id WHERE bf.village_id = $village_id AND bi.building IN ('WAREHOUSE', 'GRANARY');",
    bind: { $village_id: villageId },
    schema: z.number(),
  })!;

const getReport = (database: DbFacade, reportId: string) =>
  database.selectObject({
    sql: 'SELECT title, body FROM lan_arcade_reports WHERE id = $report_id;',
    bind: { $report_id: reportId },
    schema: z.strictObject({ title: z.string(), body: z.string() }),
  })!;

const getHeroInventoryAmount = (database: DbFacade, itemId: number) =>
  database.selectValue({
    sql: \`
      SELECT COALESCE(SUM(i.amount), 0)
      FROM hero_inventory i
        JOIN heroes h ON h.id = i.hero_id
      WHERE h.player_id = 1
        AND i.item_id = $item_id;
    \`,
    bind: { $item_id: itemId },
    schema: z.number(),
  })!;

describe('LAN Arcade NPC recovery and treasure', () => {
  test('untouched NPC villages lazily grow resources and storage on a 3-to-1 cadence', async () => {
    const database = await prepareTestDatabase();
    const originTileId = getVillageTileId(database, sourceVillageId);
    const target = getTargetVillage(database);
    resetTarget(database, target.tileId);
    database.exec({
      sql: 'UPDATE building_fields SET level = 1 WHERE village_id = $village_id AND field_id BETWEEN 1 AND 18;',
      bind: { $village_id: target.villageId },
    });
    database.exec({
      sql: "UPDATE building_fields SET level = 1 WHERE village_id = $village_id AND building_id IN (SELECT id FROM building_ids WHERE building IN ('WAREHOUSE', 'GRANARY'));",
      bind: { $village_id: target.villageId },
    });
    const beforeLevelSum = getResourceFieldLevelSum(database, target.villageId);
    const beforeStorageLevelSum = getStorageLevelSum(database, target.villageId);

    raidMovementResolver(database, createTroopMovementRaidEventMock({
      id: 600,
      startsAt: 8 * 60 * 60 * 1000,
      duration: 200,
      villageId: sourceVillageId,
      originTileId,
      targetTileId: target.tileId,
      troops: [{ unitId: 'ROMAN_SCOUT', amount: 1, tileId: originTileId, source: originTileId }],
    }));

    expect(getResourceFieldLevelSum(database, target.villageId)).toBeGreaterThan(beforeLevelSum);
    expect(getStorageLevelSum(database, target.villageId)).toBeGreaterThan(beforeStorageLevelSum);
  });

  test('migrated NPC growth rows use reinforcement timestamp for development and skirmish clocks', async () => {
    const database = await prepareTestDatabase();
    const originTileId = getVillageTileId(database, sourceVillageId);
    const target = getTargetVillage(database);
    const timestamp = 8 * 60 * 60 * 1000;
    resetTarget(database, target.tileId);
    ensureNoNpcRefresh(database, target.tileId, 9999999999);
    const beforeLevelSum = getResourceFieldLevelSum(database, target.villageId);

    raidMovementResolver(database, createTroopMovementRaidEventMock({
      id: 603,
      startsAt: timestamp,
      duration: 200,
      villageId: sourceVillageId,
      originTileId,
      targetTileId: target.tileId,
      troops: [{ unitId: 'ROMAN_SCOUT', amount: 1, tileId: originTileId, source: originTileId }],
    }));

    expect(getResourceFieldLevelSum(database, target.villageId)).toBe(beforeLevelSum);
    expect(countTargetDefenders(database, target.tileId)).toBe(0);
  });
  test('NPC villages lazily rebuild defenders when visited', async () => {
    const database = await prepareTestDatabase();
    const originTileId = getVillageTileId(database, sourceVillageId);
    const target = getTargetVillage(database);
    resetTarget(database, target.tileId);
    expect(countTargetDefenders(database, target.tileId)).toBe(0);

    raidMovementResolver(database, createTroopMovementRaidEventMock({
      id: 601,
      startsAt: 8 * 60 * 60 * 1000,
      duration: 200,
      villageId: sourceVillageId,
      originTileId,
      targetTileId: target.tileId,
      troops: [{ unitId: 'ROMAN_SCOUT', amount: 1, tileId: originTileId, source: originTileId }],
    }));

    expect(countTargetDefenders(database, target.tileId)).toBeGreaterThan(0);
    const report = getReport(database, 'scout-601');
    expect(report.body).toContain('Defenders present:');
    expect(report.body).not.toContain('Defenders present: none');
  });


  test('farmed NPC villages rebuild only a light daily guard after being cleared', async () => {
    const database = await prepareTestDatabase();
    const originTileId = getVillageTileId(database, sourceVillageId);
    const target = getTargetVillage(database);
    const timestamp = 24 * 60 * 60 * 1000;
    resetTarget(database, target.tileId);
    ensureNoNpcRefresh(database, target.tileId, timestamp - 24 * 60 * 60 * 1000);

    raidMovementResolver(database, createTroopMovementRaidEventMock({
      id: 604,
      startsAt: timestamp,
      duration: 200,
      villageId: sourceVillageId,
      originTileId,
      targetTileId: target.tileId,
      troops: [{ unitId: 'ROMAN_SCOUT', amount: 1, tileId: originTileId, source: originTileId }],
    }));

    const rebuiltDefenders = countTargetDefenders(database, target.tileId);
    expect(rebuiltDefenders).toBeGreaterThan(0);
    expect(rebuiltDefenders).toBeLessThanOrEqual(18);
  });

  test('surviving hero raid collects world item into inventory and report', async () => {
    const database = await prepareTestDatabase();
    const originTileId = getVillageTileId(database, sourceVillageId);
    const target = getTargetVillage(database);
    const timestamp = 7 * 60 * 60 * 1000;
    resetTarget(database, target.tileId);
    ensureNoNpcRefresh(database, target.tileId, timestamp);

    database.exec({
      sql: 'INSERT INTO world_items (tile_id, item_id, amount) VALUES ($tile_id, 1001, 2);',
      bind: { $tile_id: target.tileId },
    });

    raidMovementResolver(database, createTroopMovementRaidEventMock({
      id: 602,
      startsAt: timestamp,
      duration: 200,
      villageId: sourceVillageId,
      originTileId,
      targetTileId: target.tileId,
      troops: [{ unitId: 'HERO', amount: 1, tileId: originTileId, source: originTileId }],
    }));

    expect(getHeroInventoryAmount(database, 1001)).toBeGreaterThanOrEqual(2);
    expect(database.selectValue({ sql: 'SELECT COUNT(*) FROM world_items WHERE tile_id = $tile_id;', bind: { $tile_id: target.tileId }, schema: z.number() })).toBe(0);
    const report = getReport(database, 'raid-602');
    expect(report.body).toContain('Treasure:');
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
  if (!resolverSource.includes('refreshLanArcadeNpcVillage') || !resolverSource.includes('collectLanArcadeWorldItemsWithHero')) {
    throw new Error(`Pillage First generated checkout is missing NPC/treasure patch: ${resolverPath}`);
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
  console.error(`Pillage First NPC/treasure regression failed: ${error}. Report: ${reportDir}`);
  process.exit(1);
}

console.log(stdout);
console.log(`Pillage First NPC/treasure regression passed. Report: ${reportDir}`);
