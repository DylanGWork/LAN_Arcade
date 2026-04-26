import { createServer, type IncomingMessage, type Server, type ServerResponse } from 'node:http';
import { z } from 'zod';
import type { AdminFilters, ScoreSubmission } from '@lan-arcade/shared';
import { buildCatalog, currentChallenge, readAdminFilters, writeAdminFilters } from './catalog.js';
import { loadConfig, type ApiConfig } from './config.js';
import { openArcadeDb, playerFromRecord, type ArcadeDb } from './db.js';

const createPlayerSchema = z.object({
  displayName: z.string().trim().min(1).max(32),
  pin: z.string().trim().min(1).max(64).optional()
});

const createSessionSchema = z.object({
  playerId: z.string().trim().optional(),
  displayName: z.string().trim().optional(),
  pin: z.string().trim().optional()
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
      apiVersion: '0.1.0',
      generatedAt: new Date().toISOString(),
      capabilities: ['catalog', 'profiles', 'scores', 'leaderboards', 'daily-challenges']
    });
    return;
  }

  if (method === 'GET' && pathname === '/catalog') {
    sendJson(response, 200, await buildCatalog(config));
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

function setCommonHeaders(response: ServerResponse): void {
  response.setHeader('access-control-allow-origin', '*');
  response.setHeader('access-control-allow-methods', 'GET,POST,PUT,OPTIONS');
  response.setHeader('access-control-allow-headers', 'content-type,x-arcade-session');
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
