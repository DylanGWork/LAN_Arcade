#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { spawnSync } from 'node:child_process';

const workdir = process.env.PILLAGE_FIRST_WORKDIR || '/tmp/lan-arcade-pillage-first-build';
const generatedTestPath = 'packages/api/src/http/controllers/__tests__/lan-arcade-movement-dto.test.ts';
const packageTestPath = 'src/http/controllers/__tests__/lan-arcade-movement-dto.test.ts';
const testPath = path.join(workdir, generatedTestPath);
const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, 'Z');
const reportDir = process.env.PILLAGE_FIRST_REPORT_DIR || path.join('qa/reports', `pillage-first-movement-dto-${stamp}`);
const testSource = `import { describe, expect, test } from 'vitest';
import { troopMovementItemDtoSchema } from '@pillage-first/types/dtos/troop-movement';

describe('LAN Arcade troop movement DTO', () => {
  test('accepts raid/attack movement rows with origin and target coordinates', () => {
    const parsed = troopMovementItemDtoSchema.parse({
      id: 1,
      type: 'troopMovementRaid',
      originatingVillageId: 1,
      originatingVillageName: 'New village',
      originatingTileId: 100,
      originatingX: 0,
      originatingY: 0,
      playerName: 'LAN QA',
      playerId: 1,
      playerTribe: 'romans',
      resolvesAt: 12345,
      targetVillageId: 2,
      targetVillageName: 'Target village',
      targetTileId: 200,
      targetX: 3,
      targetY: -4,
    });

    expect(parsed.type).toBe('troopMovementRaid');
    expect(parsed.originatingX).toBe(0);
    expect(parsed.originatingY).toBe(0);
    expect(parsed.targetX).toBe(3);
    expect(parsed.targetY).toBe(-4);
  });
});
`;

await fs.mkdir(reportDir, { recursive: true });

let passed = false;
let error = null;
let stdout = '';
let stderr = '';

try {
  await fs.mkdir(path.dirname(testPath), { recursive: true });
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
  if (!passed) error = `vitest exited with status ${result.status}`;
} catch (caught) {
  error = caught?.stack || caught?.message || String(caught);
} finally {
  await fs.rm(testPath, { force: true }).catch(() => {});
}

const report = { generatedAt: new Date().toISOString(), passed, workdir, generatedTestPath, packageTestPath, stdout, stderr, error };
await fs.writeFile(path.join(reportDir, 'summary.json'), `${JSON.stringify(report, null, 2)}\n`);
await fs.writeFile(path.join(reportDir, 'stdout.log'), stdout);
await fs.writeFile(path.join(reportDir, 'stderr.log'), stderr);

if (stdout) process.stdout.write(stdout);
if (stderr) process.stderr.write(stderr);

if (!passed) {
  console.error(`Pillage First movement DTO regression failed. Report: ${reportDir}`);
  process.exitCode = 1;
} else {
  console.log(`Pillage First movement DTO regression passed. Report: ${reportDir}`);
}
