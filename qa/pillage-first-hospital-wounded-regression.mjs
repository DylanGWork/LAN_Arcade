#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';

const workdir = process.env.PILLAGE_FIRST_WORKDIR || '/tmp/lan-arcade-pillage-first-build';
const generatedTestPath = 'packages/api/src/http/events/resolvers/__tests__/lan-arcade-hospital-wounded.test.ts';
const packageTestPath = 'src/http/events/resolvers/__tests__/lan-arcade-hospital-wounded.test.ts';
const testPath = path.join(workdir, generatedTestPath);
const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const reportDir = process.env.PILLAGE_FIRST_REPORT_DIR || path.join('qa/reports', `pillage-first-hospital-wounded-regression-${stamp}`);

const testSource = `import { describe, expect, test } from 'vitest';
import { z } from 'zod';
import { prepareTestDatabase } from '@pillage-first/db';
import { createTroopMovementRaidEventMock } from '@pillage-first/mocks/event';
import type { DbFacade } from '@pillage-first/utils/facades/database';
import { raidMovementResolver } from '../troop-movement-resolver';
import { getHospitalWoundedTroops, healHospitalWoundedTroops } from '../../../controllers/hospital-controllers';
import { createControllerArgs } from '../../../controllers/__tests__/utils/controller-args';

const sourceVillageId = 1;
const testTime = 24_000_000;

const getVillageTileId = (database: DbFacade, villageId: number) =>
  database.selectValue({
    sql: 'SELECT tile_id FROM villages WHERE id = $village_id;',
    bind: { $village_id: villageId },
    schema: z.number(),
  })!;

const getTroopCount = (database: DbFacade, tileId: number, unitId: string) =>
  database.selectValue({
    sql:
      'SELECT CAST(COALESCE(SUM(t.amount), 0) AS INTEGER) FROM troops t JOIN unit_ids ui ON ui.id = t.unit_id WHERE ui.unit = $unit_id AND t.tile_id = $tile_id AND t.source_tile_id = $tile_id;',
    bind: { $unit_id: unitId, $tile_id: tileId },
    schema: z.number(),
  }) ?? 0;

const getReportBody = (database: DbFacade, reportId: string) =>
  database.selectValue({
    sql: 'SELECT body FROM lan_arcade_reports WHERE id = $report_id;',
    bind: { $report_id: reportId },
    schema: z.string(),
  })!;

const getTargetVillage = (database: DbFacade) =>
  database.selectObject({
    sql:
      'SELECT v.id AS villageId, v.tile_id AS tileId FROM villages v WHERE v.id != $source_village_id ORDER BY v.id LIMIT 1;',
    bind: { $source_village_id: sourceVillageId },
    schema: z.strictObject({ villageId: z.number(), tileId: z.number() }),
  })!;

const installHospital = (database: DbFacade, villageId: number) => {
  database.exec({
    sql:
      "INSERT INTO building_fields (village_id, field_id, building_id, level) VALUES ($village_id, 19, (SELECT id FROM building_ids WHERE building = 'HOSPITAL'), 1) ON CONFLICT(village_id, field_id) DO UPDATE SET building_id = excluded.building_id, level = excluded.level;",
    bind: { $village_id: villageId },
  });
};

const fundVillage = (database: DbFacade, villageId: number) => {
  const tileId = getVillageTileId(database, villageId);
  database.exec({
    sql:
      'UPDATE resource_sites SET wood = 100000, clay = 100000, iron = 100000, wheat = 100000, updated_at = $now WHERE tile_id = $tile_id;',
    bind: { $tile_id: tileId, $now: testTime },
  });
};

const resetTarget = (database: DbFacade, targetTileId: number) => {
  database.exec({
    sql: 'DELETE FROM troops WHERE tile_id = $target_tile_id;',
    bind: { $target_tile_id: targetTileId },
  });
  database.exec({
    sql:
      'INSERT INTO resource_sites (tile_id, wood, clay, iron, wheat, updated_at) VALUES ($target_tile_id, 10000, 10000, 10000, 10000, 0) ON CONFLICT(tile_id) DO UPDATE SET wood = 10000, clay = 10000, iron = 10000, wheat = 10000, updated_at = 0;',
    bind: { $target_tile_id: targetTileId },
  });
  database.exec({
    sql:
      "INSERT INTO troops (unit_id, amount, tile_id, source_tile_id) VALUES ((SELECT id FROM unit_ids WHERE unit = 'PHALANX'), 4, $target_tile_id, $target_tile_id);",
    bind: { $target_tile_id: targetTileId },
  });
  database.exec({
    sql:
      'CREATE TABLE IF NOT EXISTS lan_arcade_npc_growth (tile_id INTEGER PRIMARY KEY, last_reinforced_at INTEGER NOT NULL, last_developed_at INTEGER, last_conflict_at INTEGER, resource_upgrade_streak INTEGER NOT NULL DEFAULT 0) STRICT;',
  });
  database.exec({
    sql:
      'INSERT INTO lan_arcade_npc_growth (tile_id, last_reinforced_at, last_developed_at, last_conflict_at, resource_upgrade_streak) VALUES ($target_tile_id, 9999999999, 9999999999, 9999999999, 0) ON CONFLICT(tile_id) DO UPDATE SET last_reinforced_at = 9999999999, last_developed_at = 9999999999, last_conflict_at = 9999999999, resource_upgrade_streak = 0;',
    bind: { $target_tile_id: targetTileId },
  });
};

describe('LAN Arcade hospital wounded troops', () => {
  test('combat losses become hospital wounded troops and can be healed', async () => {
    const database = await prepareTestDatabase();
    const originTileId = getVillageTileId(database, sourceVillageId);
    const target = getTargetVillage(database);

    installHospital(database, sourceVillageId);
    fundVillage(database, sourceVillageId);
    resetTarget(database, target.tileId);

    const beforeActiveLegionnaires = getTroopCount(database, originTileId, 'LEGIONNAIRE');

    raidMovementResolver(database, createTroopMovementRaidEventMock({
      id: 9901,
      startsAt: testTime,
      duration: 200,
      villageId: sourceVillageId,
      originTileId,
      targetTileId: target.tileId,
      troops: [{ unitId: 'LEGIONNAIRE', amount: 20, tileId: originTileId, source: originTileId }],
    }));

    const wounded = getHospitalWoundedTroops(database, createControllerArgs<'/villages/:villageId/hospital/wounded-troops'>({
      path: { villageId: sourceVillageId },
    }));
    const legionnaireWounded = wounded.find((row) => row.unitId === 'LEGIONNAIRE');

    expect(legionnaireWounded?.amount).toBeGreaterThan(0);
    expect(getReportBody(database, 'raid-9901')).toContain('Attackers wounded in hospital:');

    healHospitalWoundedTroops(database, createControllerArgs<'/villages/:villageId/hospital/heal', 'post'>({
      path: { villageId: sourceVillageId },
      body: { unitId: 'LEGIONNAIRE', amount: 1 },
    }));

    const afterActiveLegionnaires = getTroopCount(database, originTileId, 'LEGIONNAIRE');
    const afterWounded = getHospitalWoundedTroops(database, createControllerArgs<'/villages/:villageId/hospital/wounded-troops'>({
      path: { villageId: sourceVillageId },
    }));
    const afterLegionnaireWounded = afterWounded.find((row) => row.unitId === 'LEGIONNAIRE');

    expect(afterActiveLegionnaires).toBe(beforeActiveLegionnaires + 1);
    expect(afterLegionnaireWounded?.amount ?? 0).toBe((legionnaireWounded?.amount ?? 0) - 1);
  });
});
`;

await fs.mkdir(reportDir, { recursive: true });

let passed = false;
let error = null;
let stdout = '';
let stderr = '';

try {
  const controllerPath = path.join(workdir, 'packages/api/src/http/controllers/hospital-controllers.ts');
  const controllerSource = await fs.readFile(controllerPath, 'utf8');
  if (!controllerSource.includes('healHospitalWoundedTroops')) {
    throw new Error(`Pillage First generated checkout is missing hospital controller patch: ${controllerPath}`);
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

await fs.writeFile(path.join(reportDir, 'result.json'), `${JSON.stringify(report, null, 2)}\n`);
await fs.writeFile(path.join(reportDir, 'result.md'), renderMarkdown(report));

if (stdout) process.stdout.write(stdout);
if (stderr) process.stderr.write(stderr);

if (!passed) {
  console.error(`Pillage First hospital wounded regression failed. Report: ${reportDir}`);
  process.exitCode = 1;
} else {
  console.log(`Pillage First hospital wounded regression passed. Report: ${reportDir}`);
}

function renderMarkdown(report) {
  return `# Pillage First Hospital Wounded Regression\n\nGenerated: ${report.generatedAt}\nResult: ${report.passed ? 'pass' : 'fail'}\nGenerated checkout: ${report.workdir}\nGenerated test: ${report.generatedTestPath}\nVitest path: ${report.packageTestPath}\n\n${report.error ? `Error:\n\n\`\`\`\n${report.error}\n\`\`\`\n` : ''}Stdout:\n\n\`\`\`\n${report.stdout || ''}\n\`\`\`\n\nStderr:\n\n\`\`\`\n${report.stderr || ''}\n\`\`\`\n`;
}
