import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import Database from 'better-sqlite3';
import type { LeaderboardEntry, Player, ScoreMode, ScoreSubmission } from '@lan-arcade/shared';

export interface ArcadeDb {
  connection: Database.Database;
  createPlayer(displayName: string, pin?: string): Player;
  listPlayers(): Player[];
  findPlayerById(playerId: string): PlayerRecord | undefined;
  findPlayerByDisplayName(displayName: string): PlayerRecord | undefined;
  createSession(player: PlayerRecord, pin?: string): string;
  getSession(token: string): SessionRecord | undefined;
  insertScore(score: ScoreSubmission): LeaderboardEntry;
  leaderboard(gameId: string, options?: { seed?: string; limit?: number }): LeaderboardEntry[];
  close(): void;
}

export interface PlayerRecord {
  id: string;
  display_name: string;
  pin_hash: string | null;
  created_at: string;
}

interface SessionRecord {
  token: string;
  player_id: string;
  created_at: string;
}

interface ScoreRow {
  id: string;
  game_id: string;
  player_id: string;
  player_name: string;
  score: number;
  mode: ScoreMode;
  difficulty: string;
  seed: string;
  duration_ms: number | null;
  details_json: string;
  created_at: string;
}

export function openArcadeDb(databasePath: string): ArcadeDb {
  fs.mkdirSync(path.dirname(databasePath), { recursive: true });
  const connection = new Database(databasePath);
  connection.pragma('journal_mode = WAL');
  connection.pragma('foreign_keys = ON');
  migrate(connection);

  return {
    connection,
    createPlayer(displayName, pin) {
      const id = crypto.randomUUID();
      const createdAt = new Date().toISOString();
      const pinHash = pin ? hashPin(pin) : null;
      connection.prepare(`
        INSERT INTO players (id, display_name, pin_hash, created_at)
        VALUES (?, ?, ?, ?)
      `).run(id, displayName, pinHash, createdAt);
      return toPlayer({ id, display_name: displayName, pin_hash: pinHash, created_at: createdAt });
    },
    listPlayers() {
      return connection.prepare(`
        SELECT id, display_name, pin_hash, created_at
        FROM players
        ORDER BY lower(display_name)
      `).all().map((row) => toPlayer(row as PlayerRecord));
    },
    findPlayerById(playerId) {
      return connection.prepare(`
        SELECT id, display_name, pin_hash, created_at FROM players WHERE id = ?
      `).get(playerId) as PlayerRecord | undefined;
    },
    findPlayerByDisplayName(displayName) {
      return connection.prepare(`
        SELECT id, display_name, pin_hash, created_at FROM players WHERE lower(display_name) = lower(?)
      `).get(displayName) as PlayerRecord | undefined;
    },
    createSession(player, pin) {
      if (player.pin_hash && (!pin || !verifyPin(pin, player.pin_hash))) {
        throw new Error('Invalid PIN');
      }
      const token = crypto.randomBytes(32).toString('base64url');
      connection.prepare(`
        INSERT INTO sessions (token, player_id, created_at)
        VALUES (?, ?, ?)
      `).run(token, player.id, new Date().toISOString());
      return token;
    },
    getSession(token) {
      return connection.prepare(`
        SELECT token, player_id, created_at FROM sessions WHERE token = ?
      `).get(token) as SessionRecord | undefined;
    },
    insertScore(submission) {
      const id = crypto.randomUUID();
      const createdAt = new Date().toISOString();
      const mode = submission.mode || 'standard';
      const difficulty = submission.difficulty || 'normal';
      const seed = submission.seed || '';
      const durationMs = Number.isFinite(submission.durationMs) ? submission.durationMs ?? null : null;
      const detailsJson = JSON.stringify(submission.details || {});
      connection.prepare(`
        INSERT INTO scores (
          id, game_id, player_id, score, mode, difficulty, seed, duration_ms, details_json, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        id,
        submission.gameId,
        submission.playerId,
        Math.trunc(submission.score),
        mode,
        difficulty,
        seed,
        durationMs,
        detailsJson,
        createdAt
      );
      return this.leaderboard(submission.gameId, { seed, limit: 1 })
        .find((entry) => entry.id === id) || {
        id,
        gameId: submission.gameId,
        playerId: submission.playerId,
        playerName: '',
        score: Math.trunc(submission.score),
        mode,
        difficulty,
        seed,
        durationMs,
        details: submission.details || {},
        createdAt
      };
    },
    leaderboard(gameId, options = {}) {
      const limit = Math.min(Math.max(options.limit || 20, 1), 100);
      const params: unknown[] = [gameId];
      let where = 'scores.game_id = ?';
      if (options.seed !== undefined) {
        where += ' AND scores.seed = ?';
        params.push(options.seed);
      }
      params.push(limit);
      return connection.prepare(`
        SELECT
          scores.id,
          scores.game_id,
          scores.player_id,
          players.display_name AS player_name,
          scores.score,
          scores.mode,
          scores.difficulty,
          scores.seed,
          scores.duration_ms,
          scores.details_json,
          scores.created_at
        FROM scores
        JOIN players ON players.id = scores.player_id
        WHERE ${where}
        ORDER BY scores.score DESC, scores.duration_ms ASC, scores.created_at ASC
        LIMIT ?
      `).all(...params).map(toLeaderboardEntry);
    },
    close() {
      connection.close();
    }
  };
}

function migrate(connection: Database.Database): void {
  connection.exec(`
    CREATE TABLE IF NOT EXISTS players (
      id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL UNIQUE,
      pin_hash TEXT,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS sessions (
      token TEXT PRIMARY KEY,
      player_id TEXT NOT NULL REFERENCES players(id) ON DELETE CASCADE,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS scores (
      id TEXT PRIMARY KEY,
      game_id TEXT NOT NULL,
      player_id TEXT NOT NULL REFERENCES players(id) ON DELETE CASCADE,
      score INTEGER NOT NULL,
      mode TEXT NOT NULL,
      difficulty TEXT NOT NULL,
      seed TEXT NOT NULL,
      duration_ms INTEGER,
      details_json TEXT NOT NULL,
      created_at TEXT NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_scores_game_seed_score
      ON scores(game_id, seed, score DESC);
  `);
}

function toPlayer(row: PlayerRecord): Player {
  return {
    id: row.id,
    displayName: row.display_name,
    pinProtected: Boolean(row.pin_hash),
    createdAt: row.created_at
  };
}

function toLeaderboardEntry(row: unknown): LeaderboardEntry {
  const score = row as ScoreRow;
  return {
    id: score.id,
    gameId: score.game_id,
    playerId: score.player_id,
    playerName: score.player_name,
    score: score.score,
    mode: score.mode,
    difficulty: score.difficulty,
    seed: score.seed,
    durationMs: score.duration_ms,
    details: safeJsonObject(score.details_json),
    createdAt: score.created_at
  };
}

function safeJsonObject(value: string): Record<string, unknown> {
  try {
    const parsed = JSON.parse(value);
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
  } catch {
    return {};
  }
}

function hashPin(pin: string): string {
  const salt = crypto.randomBytes(16).toString('hex');
  const iterations = 120_000;
  const hash = crypto.pbkdf2Sync(pin, salt, iterations, 32, 'sha256').toString('hex');
  return `pbkdf2$${iterations}$${salt}$${hash}`;
}

function verifyPin(pin: string, stored: string): boolean {
  const [scheme, iterationsRaw, salt, hash] = stored.split('$');
  if (scheme !== 'pbkdf2' || !iterationsRaw || !salt || !hash) return false;
  const iterations = Number.parseInt(iterationsRaw, 10);
  const candidate = crypto.pbkdf2Sync(pin, salt, iterations, 32, 'sha256').toString('hex');
  return crypto.timingSafeEqual(Buffer.from(candidate, 'hex'), Buffer.from(hash, 'hex'));
}

export function playerFromRecord(row: PlayerRecord): Player {
  return toPlayer(row);
}
