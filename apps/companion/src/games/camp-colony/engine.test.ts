import assert from 'node:assert/strict';
import test from 'node:test';
import {
  applyCampAction,
  calculateCampScore,
  canUseCampAction,
  createCampColony,
  createCampMap
} from './engine';

test('camp map generation is deterministic by seed', () => {
  assert.deepEqual(createCampMap('same-camp'), createCampMap('same-camp'));
  assert.notDeepEqual(createCampMap('same-camp'), createCampMap('other-camp'));
});

test('camp actions advance turns and update colony state', () => {
  const start = createCampColony('action-seed');
  const next = applyCampAction(start, 'build-garden');

  assert.equal(next.turn, start.turn + 1);
  assert.equal(next.buildings.gardens, 1);
  assert.ok(next.score > 0);
  assert.equal(calculateCampScore(next), next.score);
});

test('unaffordable actions are blocked without advancing the turn', () => {
  const start = { ...createCampColony('poor-camp'), parts: 0, power: 0 };

  assert.equal(canUseCampAction(start, 'build-workshop'), false);
  const next = applyCampAction(start, 'build-workshop');
  assert.equal(next.turn, start.turn);
  assert.match(next.log[0], /Need more supplies/);
});

test('a short scripted camp can complete and score a challenge', () => {
  let state = createCampColony('smoke-colony', { maxTurns: 4 });
  for (const action of ['forage', 'build-garden', 'send-scouts', 'build-watchtower'] as const) {
    state = canUseCampAction(state, action) ? applyCampAction(state, action) : applyCampAction(state, 'forage');
  }

  assert.equal(state.complete, true);
  assert.ok(state.score > 1000);
  assert.ok(state.log.length > 0);
});
