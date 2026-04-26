import test from 'node:test';
import assert from 'node:assert/strict';
import { calculateTrailguardScore, createTrailguardMap, waveSpec } from './engine';

test('trailguard maps are deterministic for a seed', () => {
  assert.deepEqual(createTrailguardMap('camp-seed'), createTrailguardMap('camp-seed'));
  assert.notDeepEqual(createTrailguardMap('camp-seed'), createTrailguardMap('other-seed'));
});

test('waves scale enemy pressure', () => {
  const first = waveSpec(1);
  const third = waveSpec(3);
  assert.ok(third.enemyCount > first.enemyCount);
  assert.ok(third.enemyHealth > first.enemyHealth);
  assert.ok(third.bounty > first.bounty);
});

test('score rewards progress and penalizes leaks', () => {
  const clean = calculateTrailguardScore({
    kills: 30,
    wave: 5,
    lives: 10,
    money: 80,
    leaks: 0,
    durationMs: 180000
  });
  const leaky = calculateTrailguardScore({
    kills: 30,
    wave: 5,
    lives: 2,
    money: 80,
    leaks: 8,
    durationMs: 180000
  });
  assert.ok(clean > leaky);
});
