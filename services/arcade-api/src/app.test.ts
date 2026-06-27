import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import assert from 'node:assert/strict';
import { createApiServer } from './app.js';

function tempFixture() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'lan-arcade-api-'));
  const catalogPath = path.join(dir, 'catalog.json');
  const filtersPath = path.join(dir, 'admin.filters.json');
  const databasePath = path.join(dir, 'arcade.sqlite');
  fs.writeFileSync(catalogPath, JSON.stringify({
    generated_at: '2026-04-25T00:00:00Z',
    arcade_name: 'Test Arcade',
    categories: [{ id: 'puzzle', label: 'Puzzle' }],
    games: [{
      id: '2048',
      title: '2048',
      icon: '123',
      meta: 'Puzzle',
      description: 'Merge tiles',
      tags: ['Puzzle'],
      categories: ['puzzle'],
      path: '../2048/'
    }]
  }, null, 2));
  fs.writeFileSync(filtersPath, JSON.stringify({ disabled_categories: [], disabled_games: [] }, null, 2));
  return { dir, catalogPath, filtersPath, databasePath };
}

async function withServer<T>(fixture: ReturnType<typeof tempFixture>, run: (baseUrl: string) => Promise<T>): Promise<T> {
  const { server } = createApiServer({ config: { ...fixture, host: '127.0.0.1', port: 0 } });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  assert.ok(address && typeof address === 'object');
  try {
    return await run(`http://127.0.0.1:${address.port}/`);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
}

async function request<T>(baseUrl: string, pathName: string, options: RequestInit = {}): Promise<T> {
  const response = await fetch(new URL(pathName, baseUrl), {
    ...options,
    headers: {
      'content-type': 'application/json',
      ...(options.headers || {})
    }
  });
  if (!response.ok) {
    assert.fail(`${response.status} ${await response.text()}`);
  }
  return response.json() as Promise<T>;
}

test('catalog merges mirrored and app-only games', async () => {
  const fixture = tempFixture();
  await withServer(fixture, async (baseUrl) => {
    const body = await request<{ games: Array<{ id: string; source: string }> }>(baseUrl, '/catalog');
    assert.ok(body.games.some((game) => game.id === '2048' && game.source === 'lan-web'));
    assert.ok(body.games.some((game) => game.id === 'trailguard-td' && game.source === 'app-web'));
  });
});

test('accounts create local email, linked player, and login session', async () => {
  const fixture = tempFixture();
  await withServer(fixture, async (baseUrl) => {
    const created = await request<{
      token: string;
      account: { id: string; username: string; localEmail: string; role: string; status: string };
      player: { id: string; accountId: string | null };
      email: { mailboxProvisioning: string };
    }>(baseUrl, '/accounts', {
      method: 'POST',
      body: JSON.stringify({ username: 'Dylan', displayName: 'Dylan', password: 'correct-horse-battery', role: 'admin' })
    });

    assert.equal(created.account.username, 'dylan');
    assert.equal(created.account.localEmail, 'dylan@gannan.home.arpa');
    assert.equal(created.account.role, 'admin');
    assert.equal(created.account.status, 'active');
    assert.equal(created.player.accountId, created.account.id);
    assert.equal(created.email.mailboxProvisioning, 'pending-mailu-automation');
    assert.ok(created.token.length > 20);

    const current = await request<{ account: { id: string }; player: { id: string } }>(baseUrl, '/auth/me', {
      headers: { 'x-arcade-account-session': created.token }
    });
    assert.equal(current.account.id, created.account.id);
    assert.equal(current.player.id, created.player.id);

    const login = await request<{ token: string; account: { id: string }; player: { id: string } }>(baseUrl, '/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username: 'DYLAN', password: 'correct-horse-battery' })
    });
    assert.equal(login.account.id, created.account.id);
    assert.equal(login.player.id, created.player.id);
    assert.ok(login.token.length > 20);
  });
});

test('signed-in accounts can record and list recent game activity', async () => {
  const fixture = tempFixture();
  await withServer(fixture, async (baseUrl) => {
    const created = await request<{ token: string; account: { id: string } }>(baseUrl, '/accounts', {
      method: 'POST',
      body: JSON.stringify({ username: 'Casey', displayName: 'Casey', password: 'correct-horse-battery' })
    });

    await request(baseUrl, '/account/activity', {
      method: 'POST',
      headers: { 'x-arcade-account-session': created.token },
      body: JSON.stringify({
        id: 'simant-ma',
        title: 'SimAnt',
        path: '../private-dos-vault/play.html?id=simant-ma',
        meta: 'Classic PC',
        tags: ['DOS', 'Simulation'],
        categories: ['retro', 'dos']
      })
    });

    const second = await request<{ activity: { gameId: string; playCount: number; tags: string[] } }>(baseUrl, '/account/activity', {
      method: 'POST',
      headers: { 'x-arcade-account-session': created.token },
      body: JSON.stringify({
        id: 'simant-ma',
        title: 'SimAnt',
        path: '../private-dos-vault/play.html?id=simant-ma',
        meta: 'Classic PC',
        tags: ['DOS', 'Sim'],
        categories: ['retro', 'dos']
      })
    });
    assert.equal(second.activity.gameId, 'simant-ma');
    assert.equal(second.activity.playCount, 2);
    assert.deepEqual(second.activity.tags, ['DOS', 'Sim']);

    const recent = await request<{ activity: Array<{ gameId: string; playCount: number }> }>(baseUrl, '/account/activity/recent', {
      headers: { 'x-arcade-account-session': created.token }
    });
    assert.equal(recent.activity.length, 1);
    assert.equal(recent.activity[0].gameId, 'simant-ma');
    assert.equal(recent.activity[0].playCount, 2);
  });
});

test('players, sessions, scores, and leaderboards work', async () => {
  const fixture = tempFixture();
  await withServer(fixture, async (baseUrl) => {
    const created = await request<{ player: { id: string } }>(baseUrl, '/players', {
      method: 'POST',
      body: JSON.stringify({ displayName: 'Dylan', pin: '1234' })
    });

    const session = await request<{ token: string }>(baseUrl, '/sessions', {
      method: 'POST',
      body: JSON.stringify({ playerId: created.player.id, pin: '1234' })
    });

    await request(baseUrl, '/scores', {
      method: 'POST',
      headers: { 'x-arcade-session': session.token },
      body: JSON.stringify({
        gameId: 'trailguard-td',
        playerId: created.player.id,
        score: 4200,
        mode: 'challenge',
        difficulty: 'normal',
        seed: 'abc123',
        durationMs: 180000,
        details: { wave: 4 }
      })
    });

    const leaderboard = await request<{ entries: Array<{ score: number; playerName: string }> }>(
      baseUrl,
      '/leaderboards/trailguard-td?seed=abc123'
    );
    assert.equal(leaderboard.entries[0].score, 4200);
    assert.equal(leaderboard.entries[0].playerName, 'Dylan');
  });
});

test('challenge seeds are deterministic per day', async () => {
  const fixture = tempFixture();
  await withServer(fixture, async (baseUrl) => {
    const first = await request<{ challenge: { seed: string } }>(
      baseUrl,
      '/challenges/current?gameId=trailguard-td&difficulty=normal&date=2026-04-25'
    );
    const second = await request<{ challenge: { seed: string } }>(
      baseUrl,
      '/challenges/current?gameId=trailguard-td&difficulty=normal&date=2026-04-25'
    );
    assert.equal(first.challenge.seed, second.challenge.seed);
  });
});
