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
      capabilities: ['catalog', 'profiles', 'accounts', 'account-sessions', 'account-activity', 'account-favorites', 'account-save-vault', 'local-email-addresses', 'account-email-state', 'scores', 'leaderboards', 'daily-challenges']
    });
    return;
  }

  if (method === 'GET' && pathname === '/catalog') {
    sendJson(response, 200, await buildCatalog(config));
    return;
  }

  if (method === 'GET' && pathname === '/accounts') {
    sendJson(response, 200, { accounts: db.listAccounts() });
    return;
  }

  if (method === 'POST' && pathname === '/accounts') {
    const parsed = createAccountSchema.safeParse(await readJson(request));
    if (!parsed.success) return sendJson(response, 400, { error: 'Invalid account payload', details: parsed.error.flatten() });
    try {
      const created = db.createAccount(parsed.data);
      const accountRecord = db.findAccountById(created.account.id);
      if (!accountRecord) return sendJson(response, 500, { error: 'Account was created but could not be loaded' });
      const token = db.createAccountSession(accountRecord, parsed.data.password);
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

function readAccountSession(request: IncomingMessage, db: ArcadeDb) {
  const sessionToken = request.headers['x-arcade-account-session'];
  if (typeof sessionToken !== 'string') return undefined;
  return db.getAccountSession(sessionToken);
}

function setCommonHeaders(response: ServerResponse): void {
  response.setHeader('access-control-allow-origin', '*');
  response.setHeader('access-control-allow-methods', 'GET,POST,PUT,OPTIONS');
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
