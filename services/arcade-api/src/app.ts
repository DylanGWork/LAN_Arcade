import fs from 'node:fs';
import { createServer, type IncomingMessage, type Server, type ServerResponse } from 'node:http';
import { z } from 'zod';
import type { AdminFilters, ScoreSubmission } from '@lan-arcade/shared';
import { buildCatalog, currentChallenge, readAdminFilters, writeAdminFilters } from './catalog.js';
import { loadConfig, type ApiConfig } from './config.js';
import { accountFromRecord, openArcadeDb, playerFromRecord, type ArcadeDb } from './db.js';

const createPlayerSchema = z.object({
  displayName: z.string().trim().min(1).max(32),
  pin: z.string().trim().min(1).max(64).optional()
});

const createSessionSchema = z.object({
  playerId: z.string().trim().optional(),
  displayName: z.string().trim().optional(),
  pin: z.string().trim().optional()
});

const accountRoleSchema = z.enum(['admin', 'adult', 'child', 'guest', 'service']);

const createAccountSchema = z.object({
  username: z.string().trim().min(2).max(32).regex(/^[A-Za-z0-9][A-Za-z0-9._-]*$/),
  password: z.string().min(8).max(256),
  displayName: z.string().trim().min(1).max(48).optional(),
  role: accountRoleSchema.default('adult'),
  parentAccountId: z.string().trim().min(1).nullable().optional()
});

const loginSchema = z.object({
  username: z.string().trim().min(1).max(64),
  password: z.string().min(1).max(256)
});

const addFriendSchema = z.object({
  username: z.string().trim().min(1).max(64)
});

const createMessageSchema = z.object({
  toUsername: z.string().trim().min(1).max(64),
  body: z.string().trim().min(1).max(1000),
  gameId: z.string().trim().max(180).default(''),
  gameTitle: z.string().trim().max(180).default(''),
  gamePath: z.string().trim().max(600).default('')
});

const accountActivitySchema = z.object({
  id: z.string().trim().min(1).max(180),
  title: z.string().trim().min(1).max(180),
  path: z.string().trim().min(1).max(600),
  meta: z.string().trim().max(240).default(''),
  description: z.string().trim().max(800).default(''),
  tags: z.array(z.string().trim().max(80)).max(20).default([]),
  categories: z.array(z.string().trim().max(80)).max(20).default([]),
  preview: z.string().trim().max(600).default(''),
  system: z.string().trim().max(120).default(''),
  deepType: z.string().trim().max(60).default('')
});

const saveKeySchema = z.string().trim().min(1).max(180).regex(/^[A-Za-z0-9._:-]+$/);

const accountSaveSchema = z.object({
  adapter: saveKeySchema.max(64),
  gameId: saveKeySchema,
  slot: saveKeySchema.max(80),
  label: z.string().trim().max(180).optional(),
  payloadEncoding: z.enum(['json', 'text', 'base64']).default('json'),
  payload: z.string().max(524288),
  metadata: z.record(z.string(), z.unknown()).default({})
});

const scoreSchema = z.object({
  gameId: z.string().trim().min(1),
  playerId: z.string().trim().min(1),
  score: z.number().finite().nonnegative(),
  mode: z.enum(['standard', 'challenge', 'practice']).optional(),
  difficulty: z.string().trim().default('normal'),
  seed: z.string().trim().default(''),
  durationMs: z.number().int().nonnegative().optional(),
  details: z.record(z.string(), z.unknown()).optional()
});

const filtersSchema = z.object({
  disabled_categories: z.array(z.string()).default([]),
  disabled_games: z.array(z.string()).default([])
});

export interface AppOptions {
  config?: Partial<ApiConfig>;
  db?: ArcadeDb;
}

export interface ApiServer {
  server: Server;
  config: ApiConfig;
  db: ArcadeDb;
}

export function createApiServer(options: AppOptions = {}): ApiServer {
  const config = loadConfig(options.config);
  const db = options.db || openArcadeDb(config.databasePath);
  const server = createServer((request, response) => {
    handleRequest(request, response, config, db).catch((error) => {
      sendJson(response, 500, { error: error instanceof Error ? error.message : 'Internal server error' });
    });
  });

  server.on('close', () => {
    if (!options.db) db.close();
  });

  return { server, config, db };
}

async function handleRequest(
  request: IncomingMessage,
  response: ServerResponse,
  config: ApiConfig,
  db: ArcadeDb
): Promise<void> {
  setCommonHeaders(response);
  if (request.method === 'OPTIONS') {
    response.writeHead(204);
    response.end();
    return;
  }

  const url = new URL(request.url || '/', 'http://lan-arcade.local');
  const pathname = trimTrailingSlash(url.pathname);
  const method = request.method || 'GET';

  if (method === 'GET' && pathname === '/health') {
    sendJson(response, 200, { ok: true, generatedAt: new Date().toISOString() });
    return;
  }

  if (method === 'GET' && pathname === '/server-info') {
    sendJson(response, 200, {
      name: config.arcadeName,
      apiVersion: '0.2.0',
      generatedAt: new Date().toISOString(),
      capabilities: ['catalog', 'profiles', 'accounts', 'account-sessions', 'account-activity', 'account-favorites', 'account-friends', 'account-messages', 'account-save-vault', 'local-email-addresses', 'account-email-state', 'launcher-adapters', 'launcher-status', 'scores', 'leaderboards', 'daily-challenges']
    });
    return;
  }

  if (method === 'GET' && pathname === '/catalog') {
    sendJson(response, 200, await buildCatalog(config));
    return;
  }

  if (method === 'GET' && pathname === '/accounts') {
    const session = readAccountSession(request, db);
    if (!session) return sendJson(response, 401, { error: 'Missing or invalid account session' });
    const actorRecord = db.findAccountById(session.account_id);
    if (!actorRecord) return sendJson(response, 401, { error: 'Account not found' });
    const actor = accountFromRecord(actorRecord);
    const accounts = db.listAccounts();
    const visibleAccounts = actor.role === 'admin'
      ? accounts
      : actor.role === 'adult'
        ? accounts.filter((account) => account.id === actor.id || account.parentAccountId === actor.id)
        : accounts.filter((account) => account.id === actor.id);
    sendJson(response, 200, { accounts: visibleAccounts });
    return;
  }

  if (method === 'POST' && pathname === '/accounts') {
    const parsed = createAccountSchema.safeParse(await readJson(request));
    if (!parsed.success) return sendJson(response, 400, { error: 'Invalid account payload', details: parsed.error.flatten() });

    const existingAccounts = db.listAccounts();
    const session = readAccountSession(request, db);
    const actorRecord = session ? db.findAccountById(session.account_id) : undefined;
    let accountInput = { ...parsed.data };

    if (existingAccounts.length === 0) {
      accountInput = { ...accountInput, role: 'admin', parentAccountId: null };
    } else if (!actorRecord) {
      if (accountInput.role !== 'adult' || accountInput.parentAccountId) {
        return sendJson(response, 403, { error: 'Sign in as a family organizer to create child or privileged accounts' });
      }
      accountInput = { ...accountInput, role: 'adult', parentAccountId: null };
    } else {
      const actor = accountFromRecord(actorRecord);
      if (!['admin', 'adult'].includes(actor.role)) {
        return sendJson(response, 403, { error: 'This account cannot create family accounts' });
      }
      if (accountInput.role === 'child') {
        if (accountInput.parentAccountId && accountInput.parentAccountId !== actor.id) {
          return sendJson(response, 403, { error: 'Child accounts must belong to the signed-in family organizer' });
        }
        accountInput = { ...accountInput, parentAccountId: actor.id };
      } else if (accountInput.role === 'adult') {
        if (accountInput.parentAccountId) {
          return sendJson(response, 400, { error: 'Adult accounts cannot have a parent account' });
        }
        accountInput = { ...accountInput, parentAccountId: null };
      } else if (['admin', 'service'].includes(accountInput.role)) {
        if (actor.role !== 'admin') {
          return sendJson(response, 403, { error: 'Only an admin account can create privileged accounts' });
        }
        accountInput = { ...accountInput, parentAccountId: null };
      } else {
        return sendJson(response, 403, { error: 'Guest mode does not create a persistent account' });
      }
    }

    try {
      const created = db.createAccount(accountInput);
      const accountRecord = db.findAccountById(created.account.id);
      if (!accountRecord) return sendJson(response, 500, { error: 'Account was created but could not be loaded' });
      const token = db.createAccountSession(accountRecord, accountInput.password);
      return sendJson(response, 201, {
        token,
        account: created.account,
        player: created.player,
        email: {
          localAddress: created.account.localEmail,
          mailboxStatus: created.account.mailboxStatus,
          emailVerifiedAt: created.account.emailVerifiedAt,
        }
      });
    } catch (error) {
      return sendJson(response, 409, { error: error instanceof Error ? error.message : 'Could not create account' });
    }
  }

  if (method === 'POST' && pathname === '/auth/login') {
    const parsed = loginSchema.safeParse(await readJson(request));
    if (!parsed.success) return sendJson(response, 400, { error: 'Invalid login payload', details: parsed.error.flatten() });
    const account = db.findAccountByUsername(parsed.data.username);
    if (!account) return sendJson(response, 401, { error: 'Invalid username or password' });
    try {
      const token = db.createAccountSession(account, parsed.data.password);
      const refreshed = db.findAccountById(account.id) || account;
      const player = db.findPlayerByAccountId(account.id);
      return sendJson(response, 200, {
        token,
        account: accountFromRecord(refreshed),
        player: player ? playerFromRecord(player) : null
      });
    } catch {
      return sendJson(response, 401, { error: 'Invalid username or password' });
    }
  }

  if (method === 'GET' && pathname === '/auth/me') {
    const session = readAccountSession(request, db);
    if (!session) return sendJson(response, 401, { error: 'Missing or invalid account session' });
    const account = db.findAccountById(session.account_id);
    if (!account) return sendJson(response, 401, { error: 'Account not found' });
    const player = db.findPlayerByAccountId(account.id);
    sendJson(response, 200, {
      account: accountFromRecord(account),
      player: player ? playerFromRecord(player) : null
    });
    return;
  }

  if (method === 'GET' && pathname === '/account/activity/recent') {
    const session = readAccountSession(request, db);
    if (!session) return sendJson(response, 401, { error: 'Missing or invalid account session' });
    const limit = url.searchParams.get('limit') ? Number.parseInt(url.searchParams.get('limit') || '12', 10) : 12;
    sendJson(response, 200, { activity: db.listAccountActivity(session.account_id, { limit }) });
    return;
  }

  if (method === 'POST' && pathname === '/account/activity') {
    const session = readAccountSession(request, db);
    if (!session) return sendJson(response, 401, { error: 'Missing or invalid account session' });
    const parsed = accountActivitySchema.safeParse(await readJson(request));
    if (!parsed.success) return sendJson(response, 400, { error: 'Invalid activity payload', details: parsed.error.flatten() });
    sendJson(response, 201, { activity: db.recordAccountActivity(session.account_id, parsed.data) });
    return;
  }

  if (method === 'GET' && pathname === '/account/favorites') {
    const session = readAccountSession(request, db);
    if (!session) return sendJson(response, 401, { error: 'Missing or invalid account session' });
    const limit = url.searchParams.get('limit') ? Number.parseInt(url.searchParams.get('limit') || '100', 10) : 100;
    sendJson(response, 200, { favorites: db.listAccountFavorites(session.account_id, { limit }) });
    return;
  }

  if (method === 'PUT' && pathname === '/account/favorites') {
    const session = readAccountSession(request, db);
    if (!session) return sendJson(response, 401, { error: 'Missing or invalid account session' });
    const parsed = accountActivitySchema.safeParse(await readJson(request));
    if (!parsed.success) return sendJson(response, 400, { error: 'Invalid favorite payload', details: parsed.error.flatten() });
    sendJson(response, 200, { favorite: db.upsertAccountFavorite(session.account_id, parsed.data) });
    return;
  }

  const favoriteMatch = pathname.match(/^\/account\/favorites\/([^/]+)$/);
  if (method === 'DELETE' && favoriteMatch) {
    const session = readAccountSession(request, db);
    if (!session) return sendJson(response, 401, { error: 'Missing or invalid account session' });
    sendJson(response, 200, { removed: db.deleteAccountFavorite(session.account_id, decodeURIComponent(favoriteMatch[1])) });
    return;
  }


  if (method === 'GET' && pathname === '/account/friends') {
    const session = readAccountSession(request, db);
    if (!session) return sendJson(response, 401, { error: 'Missing or invalid account session' });
    const limit = url.searchParams.get('limit') ? Number.parseInt(url.searchParams.get('limit') || '100', 10) : 100;
    sendJson(response, 200, { friends: db.listAccountFriends(session.account_id, { limit }) });
    return;
  }

  if (method === 'POST' && pathname === '/account/friends') {
    const session = readAccountSession(request, db);
    if (!session) return sendJson(response, 401, { error: 'Missing or invalid account session' });
    const parsed = addFriendSchema.safeParse(await readJson(request));
    if (!parsed.success) return sendJson(response, 400, { error: 'Invalid friend payload', details: parsed.error.flatten() });
    try {
      sendJson(response, 201, { friend: db.addAccountFriend(session.account_id, parsed.data.username) });
    } catch (error) {
      sendJson(response, 404, { error: error instanceof Error ? error.message : 'Could not add friend' });
    }
    return;
  }

  const friendMatch = pathname.match(/^\/account\/friends\/([^/]+)$/);
  if (method === 'DELETE' && friendMatch) {
    const session = readAccountSession(request, db);
    if (!session) return sendJson(response, 401, { error: 'Missing or invalid account session' });
    sendJson(response, 200, { removed: db.deleteAccountFriend(session.account_id, decodeURIComponent(friendMatch[1])) });
    return;
  }

  if (method === 'GET' && pathname === '/account/messages') {
    const session = readAccountSession(request, db);
    if (!session) return sendJson(response, 401, { error: 'Missing or invalid account session' });
    const limit = url.searchParams.get('limit') ? Number.parseInt(url.searchParams.get('limit') || '50', 10) : 50;
    sendJson(response, 200, { messages: db.listAccountMessages(session.account_id, { limit }) });
    return;
  }

  if (method === 'POST' && pathname === '/account/messages') {
    const session = readAccountSession(request, db);
    if (!session) return sendJson(response, 401, { error: 'Missing or invalid account session' });
    const parsed = createMessageSchema.safeParse(await readJson(request));
    if (!parsed.success) return sendJson(response, 400, { error: 'Invalid message payload', details: parsed.error.flatten() });
    try {
      sendJson(response, 201, { message: db.createAccountMessage(session.account_id, parsed.data) });
    } catch (error) {
      sendJson(response, 404, { error: error instanceof Error ? error.message : 'Could not send message' });
    }
    return;
  }

  const messageReadMatch = pathname.match(/^\/account\/messages\/([^/]+)\/read$/);
  if (method === 'PUT' && messageReadMatch) {
    const session = readAccountSession(request, db);
    if (!session) return sendJson(response, 401, { error: 'Missing or invalid account session' });
    const message = db.markAccountMessageRead(session.account_id, decodeURIComponent(messageReadMatch[1]));
    if (!message) return sendJson(response, 404, { error: 'Message not found' });
    sendJson(response, 200, { message });
    return;
  }

  if (method === 'GET' && pathname === '/account/saves') {
    const session = readAccountSession(request, db);
    if (!session) return sendJson(response, 401, { error: 'Missing or invalid account session' });
    const limit = url.searchParams.get('limit') ? Number.parseInt(url.searchParams.get('limit') || '50', 10) : 50;
    sendJson(response, 200, {
      saves: db.listAccountSaves(session.account_id, {
        adapter: url.searchParams.get('adapter') || undefined,
        gameId: url.searchParams.get('gameId') || undefined,
        includePayload: url.searchParams.get('includePayload') === '1',
        limit
      })
    });
    return;
  }

  if (method === 'PUT' && pathname === '/account/saves') {
    const session = readAccountSession(request, db);
    if (!session) return sendJson(response, 401, { error: 'Missing or invalid account session' });
    const parsed = accountSaveSchema.safeParse(await readJson(request));
    if (!parsed.success) return sendJson(response, 400, { error: 'Invalid save payload', details: parsed.error.flatten() });
    sendJson(response, 200, { save: db.upsertAccountSave(session.account_id, parsed.data) });
    return;
  }

  const saveMatch = pathname.match(/^\/account\/saves\/([^/]+)\/([^/]+)\/([^/]+)$/);
  if (method === 'GET' && saveMatch) {
    const session = readAccountSession(request, db);
    if (!session) return sendJson(response, 401, { error: 'Missing or invalid account session' });
    const save = db.getAccountSave(
      session.account_id,
      decodeURIComponent(saveMatch[1]),
      decodeURIComponent(saveMatch[2]),
      decodeURIComponent(saveMatch[3])
    );
    if (!save) return sendJson(response, 404, { error: 'Save not found' });
    sendJson(response, 200, { save });
    return;
  }

  if (method === 'GET' && pathname === '/launchers') {
    sendJson(response, 200, readLauncherAdapters(config));
    return;
  }

  const launcherMatch = pathname.match(/^\/launchers\/([^/]+)$/);
  if (method === 'GET' && launcherMatch) {
    const gameId = decodeURIComponent(launcherMatch[1]);
    const launcher = launcherStatus(config, gameId);
    if (!launcher) return sendJson(response, 404, { error: 'Launcher not found' });
    sendJson(response, 200, launcher);
    return;
  }

  const launcherControlMatch = pathname.match(/^\/launchers\/([^/]+)\/(start|stop)$/);
  if (method === 'POST' && launcherControlMatch) {
    const gameId = decodeURIComponent(launcherControlMatch[1]);
    const action = launcherControlMatch[2];
    const launcher = launcherStatus(config, gameId);
    if (!launcher) return sendJson(response, 404, { error: 'Launcher not found' });
    if (!['hosted-lan', 'browser-stream'].includes(String(launcher.adapter || ''))) {
      return sendJson(response, 400, { error: 'This launcher does not use start/stop control', launcher });
    }
    sendJson(response, 501, {
      error: 'Launcher service control is not enabled in the API container yet',
      action,
      launcher,
      safePath: 'Use the allowlisted VM helper until a host-control service is installed.',
      helper: 'python3 scripts/native_service_admin.py start|stop <serviceId>'
    });
    return;
  }

  if (method === 'GET' && pathname === '/players') {
    sendJson(response, 200, { players: db.listPlayers() });
    return;
  }

  if (method === 'POST' && pathname === '/players') {
    const parsed = createPlayerSchema.safeParse(await readJson(request));
    if (!parsed.success) return sendJson(response, 400, { error: 'Invalid player payload', details: parsed.error.flatten() });
    try {
      return sendJson(response, 201, { player: db.createPlayer(parsed.data.displayName, parsed.data.pin) });
    } catch (error) {
      return sendJson(response, 409, { error: error instanceof Error ? error.message : 'Could not create player' });
    }
  }

  if (method === 'POST' && pathname === '/sessions') {
    const parsed = createSessionSchema.safeParse(await readJson(request));
    if (!parsed.success) return sendJson(response, 400, { error: 'Invalid session payload', details: parsed.error.flatten() });
    const player = parsed.data.playerId
      ? db.findPlayerById(parsed.data.playerId)
      : parsed.data.displayName
        ? db.findPlayerByDisplayName(parsed.data.displayName)
        : undefined;
    if (!player) return sendJson(response, 404, { error: 'Player not found' });
    try {
      const token = db.createSession(player, parsed.data.pin);
      return sendJson(response, 200, { token, player: playerFromRecord(player) });
    } catch {
      return sendJson(response, 401, { error: 'Invalid PIN' });
    }
  }

  const leaderboardMatch = pathname.match(/^\/leaderboards\/([^/]+)$/);
  if (method === 'GET' && leaderboardMatch) {
    const gameId = decodeURIComponent(leaderboardMatch[1]);
    const limit = url.searchParams.get('limit') ? Number.parseInt(url.searchParams.get('limit') || '20', 10) : 20;
    const seed = url.searchParams.get('seed') || undefined;
    sendJson(response, 200, { entries: db.leaderboard(gameId, { seed, limit }) });
    return;
  }

  if (method === 'POST' && pathname === '/scores') {
    const parsed = scoreSchema.safeParse(await readJson(request));
    if (!parsed.success) return sendJson(response, 400, { error: 'Invalid score payload', details: parsed.error.flatten() });
    const sessionToken = request.headers['x-arcade-session'];
    if (typeof sessionToken !== 'string') return sendJson(response, 401, { error: 'Missing session token' });
    const session = db.getSession(sessionToken);
    if (!session || session.player_id !== parsed.data.playerId) return sendJson(response, 403, { error: 'Session does not match player' });
    if (!db.findPlayerById(parsed.data.playerId)) return sendJson(response, 404, { error: 'Player not found' });
    return sendJson(response, 201, { entry: db.insertScore(parsed.data as ScoreSubmission) });
  }

  if (method === 'GET' && pathname === '/challenges/current') {
    const date = url.searchParams.get('date');
    const at = date ? new Date(`${date}T00:00:00.000Z`) : new Date();
    sendJson(response, 200, {
      challenge: currentChallenge(
        url.searchParams.get('gameId') || 'trailguard-td',
        url.searchParams.get('difficulty') || 'normal',
        at
      )
    });
    return;
  }

  if (method === 'GET' && pathname === '/admin/filters') {
    sendJson(response, 200, { filters: await readAdminFilters(config.filtersPath) });
    return;
  }

  if (method === 'PUT' && pathname === '/admin/filters') {
    const parsed = filtersSchema.safeParse(await readJson(request));
    if (!parsed.success) return sendJson(response, 400, { error: 'Invalid filters payload', details: parsed.error.flatten() });
    const filters = await writeAdminFilters(config.filtersPath, parsed.data as AdminFilters);
    sendJson(response, 200, { filters });
    return;
  }

  sendJson(response, 404, { error: 'Not found' });
}

interface LauncherAuditFile {
  generatedAt?: string;
  total?: number;
  counts?: Record<string, number>;
  contract?: unknown;
  games?: Record<string, Record<string, unknown>>;
}

function readLauncherAdapters(config: ApiConfig): LauncherAuditFile {
  try {
    const raw = fs.readFileSync(config.launcherAdaptersPath, 'utf8');
    const parsed = JSON.parse(raw) as LauncherAuditFile;
    return {
      generatedAt: parsed.generatedAt,
      total: parsed.total,
      counts: parsed.counts || {},
      contract: parsed.contract || {},
      games: parsed.games || {}
    };
  } catch {
    return { counts: {}, games: {} };
  }
}

function launcherStatus(config: ApiConfig, gameId: string): Record<string, unknown> | undefined {
  const audit = readLauncherAdapters(config);
  const info = audit.games?.[gameId];
  if (!info) return undefined;
  const adapter = String(info.adapter || info.preferredAdapter || 'setup-needed');
  const serviceId = String(info.serviceId || gameId);
  return {
    gameId,
    adapter,
    serviceId,
    primaryAction: info.primaryAction || info.playerAction || 'Open',
    readiness: info.readiness || 'Unknown',
    readyNow: info.readyNow === true,
    guestReady: info.guestReady === true,
    launchHint: info.launchHint || '',
    qaStatus: info.qaStatus || 'unknown',
    promotionState: info.promotionState || 'unknown',
    control: adapter === 'hosted-lan' || adapter === 'browser-stream'
      ? { supported: false, mode: 'vm-helper-pending' }
      : { supported: false, mode: 'not-required' }
  };
}

function readAccountSession(request: IncomingMessage, db: ArcadeDb) {
  const sessionToken = request.headers['x-arcade-account-session'];
  if (typeof sessionToken !== 'string') return undefined;
  return db.getAccountSession(sessionToken);
}

function setCommonHeaders(response: ServerResponse): void {
  response.setHeader('access-control-allow-origin', '*');
  response.setHeader('access-control-allow-methods', 'GET,POST,PUT,DELETE,OPTIONS');
  response.setHeader('access-control-allow-headers', 'content-type,x-arcade-session,x-arcade-account-session');
  response.setHeader('cache-control', 'no-store');
}

function sendJson(response: ServerResponse, statusCode: number, payload: unknown): void {
  response.statusCode = statusCode;
  response.setHeader('content-type', 'application/json; charset=utf-8');
  response.end(`${JSON.stringify(payload)}\n`);
}

async function readJson(request: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  for await (const chunk of request) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  if (chunks.length === 0) return {};
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

function trimTrailingSlash(value: string): string {
  if (value.length > 1 && value.endsWith('/')) return value.slice(0, -1);
  return value;
}
