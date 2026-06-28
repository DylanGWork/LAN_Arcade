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
  const launcherAdaptersPath = path.join(dir, 'launcher-adapters.json');
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
  fs.writeFileSync(launcherAdaptersPath, JSON.stringify({
    generatedAt: '2026-06-28T00:00:00Z',
    total: 1,
    counts: { browser: 1 },
    contract: { rule: 'Ready now requires a real player launch adapter.' },
    games: {
      '2048': {
        adapter: 'browser',
        preferredAdapter: 'browser',
        primaryAction: 'Play',
        readiness: 'Ready offline',
        readyNow: true,
        guestReady: true,
        launchHint: 'browser play',
        qaStatus: 'inferred-ready',
        promotionState: 'ready'
      },
      'mindustry-lan': {
        adapter: 'hosted-lan',
        preferredAdapter: 'hosted-lan',
        serviceId: 'mindustry-lan',
        primaryAction: 'Start / join',
        readiness: 'Start on demand',
        readyNow: true,
        guestReady: true,
        launchHint: 'local server',
        qaStatus: 'service-smoke-passed',
        promotionState: 'ready'
      }
    }
  }, null, 2));
  return { dir, catalogPath, filtersPath, launcherAdaptersPath, databasePath };
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
      account: { id: string; username: string; localEmail: string; mailboxStatus: string; emailVerifiedAt: string | null; role: string; status: string };
      player: { id: string; accountId: string | null };
      email: { mailboxStatus: string; emailVerifiedAt: string | null };
    }>(baseUrl, '/accounts', {
      method: 'POST',
      body: JSON.stringify({ username: 'Dylan', displayName: 'Dylan', password: 'correct-horse-battery', role: 'admin' })
    });

    assert.equal(created.account.username, 'dylan');
    assert.equal(created.account.localEmail, 'dylan@gannan.home.arpa');
    assert.equal(created.account.mailboxStatus, 'pending');
    assert.equal(created.account.emailVerifiedAt, null);
    assert.equal(created.account.role, 'admin');
    assert.equal(created.account.status, 'active');
    assert.equal(created.player.accountId, created.account.id);
    assert.equal(created.email.mailboxStatus, 'pending');
    assert.equal(created.email.emailVerifiedAt, null);
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

test('signed-in accounts can save, list, and remove favorite games', async () => {
  const fixture = tempFixture();
  await withServer(fixture, async (baseUrl) => {
    const created = await request<{ token: string }>(baseUrl, '/accounts', {
      method: 'POST',
      body: JSON.stringify({ username: 'Riley', displayName: 'Riley', password: 'correct-horse-battery' })
    });

    const saved = await request<{ favorite: { gameId: string; title: string; path: string; tags: string[] } }>(baseUrl, '/account/favorites', {
      method: 'PUT',
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
    assert.equal(saved.favorite.gameId, 'simant-ma');
    assert.equal(saved.favorite.title, 'SimAnt');
    assert.deepEqual(saved.favorite.tags, ['DOS', 'Simulation']);

    const listed = await request<{ favorites: Array<{ gameId: string; path: string }> }>(baseUrl, '/account/favorites', {
      headers: { 'x-arcade-account-session': created.token }
    });
    assert.equal(listed.favorites.length, 1);
    assert.equal(listed.favorites[0].gameId, 'simant-ma');

    const removed = await request<{ removed: boolean }>(baseUrl, '/account/favorites/simant-ma', {
      method: 'DELETE',
      headers: { 'x-arcade-account-session': created.token }
    });
    assert.equal(removed.removed, true);

    const empty = await request<{ favorites: Array<{ gameId: string }> }>(baseUrl, '/account/favorites', {
      headers: { 'x-arcade-account-session': created.token }
    });
    assert.equal(empty.favorites.length, 0);
  });
});

test('signed-in accounts can add friends and exchange local messages', async () => {
  const fixture = tempFixture();
  await withServer(fixture, async (baseUrl) => {
    const dylan = await request<{ token: string; account: { id: string; username: string } }>(baseUrl, '/accounts', {
      method: 'POST',
      body: JSON.stringify({ username: 'Dylan', displayName: 'Dylan', password: 'correct-horse-battery' })
    });
    const riley = await request<{ token: string; account: { id: string; username: string } }>(baseUrl, '/accounts', {
      method: 'POST',
      body: JSON.stringify({ username: 'Riley', displayName: 'Riley', password: 'correct-horse-battery' })
    });

    const added = await request<{ friend: { friendAccountId: string; username: string; displayName: string } }>(baseUrl, '/account/friends', {
      method: 'POST',
      headers: { 'x-arcade-account-session': dylan.token },
      body: JSON.stringify({ username: 'RILEY' })
    });
    assert.equal(added.friend.friendAccountId, riley.account.id);
    assert.equal(added.friend.username, 'riley');

    const dylanFriends = await request<{ friends: Array<{ friendAccountId: string; username: string }> }>(baseUrl, '/account/friends', {
      headers: { 'x-arcade-account-session': dylan.token }
    });
    const rileyFriends = await request<{ friends: Array<{ friendAccountId: string; username: string }> }>(baseUrl, '/account/friends', {
      headers: { 'x-arcade-account-session': riley.token }
    });
    assert.equal(dylanFriends.friends[0].friendAccountId, riley.account.id);
    assert.equal(rileyFriends.friends[0].friendAccountId, dylan.account.id);

    const sent = await request<{ message: { id: string; fromUsername: string; toUsername: string; body: string; gameTitle: string } }>(baseUrl, '/account/messages', {
      method: 'POST',
      headers: { 'x-arcade-account-session': dylan.token },
      body: JSON.stringify({
        toUsername: 'riley',
        body: 'Come play SimAnt',
        gameId: 'simant-ma',
        gameTitle: 'SimAnt',
        gamePath: '../private-dos-vault/play.html?id=simant-ma'
      })
    });
    assert.equal(sent.message.fromUsername, 'dylan');
    assert.equal(sent.message.toUsername, 'riley');
    assert.equal(sent.message.gameTitle, 'SimAnt');

    const messages = await request<{ messages: Array<{ id: string; body: string; gameId: string; readAt: string | null }> }>(baseUrl, '/account/messages', {
      headers: { 'x-arcade-account-session': riley.token }
    });
    assert.equal(messages.messages.length, 1);
    assert.equal(messages.messages[0].body, 'Come play SimAnt');
    assert.equal(messages.messages[0].gameId, 'simant-ma');
    assert.equal(messages.messages[0].readAt, null);

    const read = await request<{ message: { readAt: string | null } }>(baseUrl, `/account/messages/${encodeURIComponent(sent.message.id)}/read`, {
      method: 'PUT',
      headers: { 'x-arcade-account-session': riley.token }
    });
    assert.ok(read.message.readAt);
  });
});

test('signed-in accounts can store and retrieve isolated save slots', async () => {
  const fixture = tempFixture();
  await withServer(fixture, async (baseUrl) => {
    const created = await request<{ token: string }>(baseUrl, '/accounts', {
      method: 'POST',
      body: JSON.stringify({ username: 'Morgan', displayName: 'Morgan', password: 'correct-horse-battery' })
    });

    const first = await request<{ save: { adapter: string; gameId: string; slot: string; payload: string; checksum: string; sizeBytes: number } }>(baseUrl, '/account/saves', {
      method: 'PUT',
      headers: { 'x-arcade-account-session': created.token },
      body: JSON.stringify({
        adapter: 'browser-localstorage',
        gameId: '2048',
        slot: 'autosave',
        label: 'Auto save',
        payloadEncoding: 'json',
        payload: JSON.stringify({ board: [2, 4, 8], score: 14 }),
        metadata: { source: 'test' }
      })
    });
    assert.equal(first.save.adapter, 'browser-localstorage');
    assert.equal(first.save.gameId, '2048');
    assert.equal(first.save.slot, 'autosave');
    assert.ok(first.save.payload.includes('board'));
    assert.equal(first.save.sizeBytes, Buffer.byteLength(first.save.payload, 'utf8'));
    assert.equal(first.save.checksum.length, 64);

    const list = await request<{ saves: Array<{ gameId: string; payload?: string; metadata: { source?: string } }> }>(baseUrl, '/account/saves?adapter=browser-localstorage', {
      headers: { 'x-arcade-account-session': created.token }
    });
    assert.equal(list.saves.length, 1);
    assert.equal(list.saves[0].gameId, '2048');
    assert.equal(list.saves[0].payload, undefined);
    assert.equal(list.saves[0].metadata.source, 'test');

    const fetched = await request<{ save: { payload: string; metadata: { source?: string } } }>(baseUrl, '/account/saves/browser-localstorage/2048/autosave', {
      headers: { 'x-arcade-account-session': created.token }
    });
    assert.deepEqual(JSON.parse(fetched.save.payload), { board: [2, 4, 8], score: 14 });

    const updated = await request<{ save: { payload: string; checksum: string } }>(baseUrl, '/account/saves', {
      method: 'PUT',
      headers: { 'x-arcade-account-session': created.token },
      body: JSON.stringify({
        adapter: 'browser-localstorage',
        gameId: '2048',
        slot: 'autosave',
        payload: JSON.stringify({ board: [16], score: 16 })
      })
    });
    assert.notEqual(updated.save.checksum, first.save.checksum);
    assert.deepEqual(JSON.parse(updated.save.payload), { board: [16], score: 16 });
  });
});

test('launcher adapter status is exposed without enabling host control', async () => {
  const fixture = tempFixture();
  await withServer(fixture, async (baseUrl) => {
    const all = await request<{ games: Record<string, { adapter: string; primaryAction: string }> }>(baseUrl, '/launchers');
    assert.equal(all.games['2048'].adapter, 'browser');

    const launcher = await request<{ gameId: string; adapter: string; serviceId: string; primaryAction: string; readyNow: boolean; control: { supported: boolean; mode: string } }>(baseUrl, '/launchers/mindustry-lan');
    assert.equal(launcher.gameId, 'mindustry-lan');
    assert.equal(launcher.adapter, 'hosted-lan');
    assert.equal(launcher.serviceId, 'mindustry-lan');
    assert.equal(launcher.primaryAction, 'Start / join');
    assert.equal(launcher.readyNow, true);
    assert.equal(launcher.control.supported, false);
    assert.equal(launcher.control.mode, 'vm-helper-pending');

    const response = await fetch(new URL('/launchers/mindustry-lan/start', baseUrl), { method: 'POST' });
    assert.equal(response.status, 501);
    const body = await response.json() as { safePath: string };
    assert.match(body.safePath, /allowlisted VM helper/);
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
