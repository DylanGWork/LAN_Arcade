import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import Database from 'better-sqlite3';
import type {
  AccountRole,
  AccountStatus,
  MailboxStatus,
  ArcadeAccount,
  LeaderboardEntry,
  Player,
  AccountSaveSlot,
  RecentGameActivity,
  RecordGameActivityRequest,
  UpsertAccountSaveRequest,
  ScoreMode,
  ScoreSubmission
} from '@lan-arcade/shared';

export interface ArcadeDb {
  connection: Database.Database;
  createAccount(input: CreateAccountInput): { account: ArcadeAccount; player: Player };
  listAccounts(): ArcadeAccount[];
  findAccountById(accountId: string): AccountRecord | undefined;
  findAccountByUsername(username: string): AccountRecord | undefined;
  createAccountSession(account: AccountRecord, password: string): string;
  getAccountSession(token: string): AccountSessionRecord | undefined;
  recordAccountActivity(accountId: string, input: RecordGameActivityRequest): RecentGameActivity;
  listAccountActivity(accountId: string, options?: { limit?: number }): RecentGameActivity[];
  upsertAccountSave(accountId: string, input: UpsertAccountSaveRequest): AccountSaveSlot;
  getAccountSave(accountId: string, adapter: string, gameId: string, slot: string): AccountSaveSlot | undefined;
  listAccountSaves(accountId: string, options?: { adapter?: string; gameId?: string; limit?: number; includePayload?: boolean }): AccountSaveSlot[];
  createPlayer(displayName: string, pin?: string): Player;
  listPlayers(): Player[];
  findPlayerById(playerId: string): PlayerRecord | undefined;
  findPlayerByDisplayName(displayName: string): PlayerRecord | undefined;
  findPlayerByAccountId(accountId: string): PlayerRecord | undefined;
  createSession(player: PlayerRecord, pin?: string): string;
  getSession(token: string): SessionRecord | undefined;
  insertScore(score: ScoreSubmission): LeaderboardEntry;
  leaderboard(gameId: string, options?: { seed?: string; limit?: number }): LeaderboardEntry[];
  close(): void;
}

export interface CreateAccountInput {
  username: string;
  password: string;
  displayName?: string;
  role?: AccountRole;
  parentAccountId?: string | null;
}

export interface AccountRecord {
  id: string;
  username: string;
  display_name: string;
  local_email: string;
  mailbox_status: MailboxStatus;
  email_verified_at: string | null;
  password_hash: string;
  role: AccountRole;
  status: AccountStatus;
  parent_account_id: string | null;
  created_at: string;
  updated_at: string;
  last_login_at: string | null;
}

export interface PlayerRecord {
  id: string;
  display_name: string;
  pin_hash: string | null;
  created_at: string;
  account_id: string | null;
}

interface SessionRecord {
  token: string;
  player_id: string;
  created_at: string;
}

export interface AccountSessionRecord {
  token: string;
  account_id: string;
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

interface AccountActivityRow {
  id: string;
  account_id: string;
  game_id: string;
  title: string;
  path: string;
  meta: string;
  description: string;
  tags_json: string;
  categories_json: string;
  preview: string;
  system: string;
  deep_type: string;
  play_count: number;
  first_played_at: string;
  last_played_at: string;
}

interface AccountSaveRow {
  id: string;
  account_id: string;
  adapter: string;
  game_id: string;
  slot: string;
  label: string;
  payload_encoding: 'json' | 'text' | 'base64';
  payload: string;
  metadata_json: string;
  size_bytes: number;
  checksum: string;
  created_at: string;
  updated_at: string;
}

export function openArcadeDb(databasePath: string): ArcadeDb {
  fs.mkdirSync(path.dirname(databasePath), { recursive: true });
  const connection = new Database(databasePath);
  connection.pragma('journal_mode = WAL');
  connection.pragma('foreign_keys = ON');
  migrate(connection);

  return {
    connection,
    createAccount(input) {
      const create = connection.transaction((payload: CreateAccountInput) => {
        const username = normalizeUsername(payload.username);
        if (!username) throw new Error('Invalid username');
        const displayName = (payload.displayName || username).trim();
        if (!displayName) throw new Error('Invalid display name');
        const now = new Date().toISOString();
        const id = crypto.randomUUID();
        const role = payload.role || 'adult';
        const localEmail = `${username}@gannan.home.arpa`;
        const passwordHash = hashSecret(payload.password);
        connection.prepare(`
          INSERT INTO accounts (
            id, username, display_name, local_email, mailbox_status, email_verified_at, password_hash, role, status,
            parent_account_id, created_at, updated_at, last_login_at
          ) VALUES (?, ?, ?, ?, 'pending', NULL, ?, ?, 'active', ?, ?, ?, NULL)
        `).run(id, username, displayName, localEmail, passwordHash, role, payload.parentAccountId || null, now, now);

        let player = connection.prepare(`
          SELECT id, display_name, pin_hash, created_at, account_id
          FROM players
          WHERE lower(display_name) = lower(?)
        `).get(displayName) as PlayerRecord | undefined;

        if (player) {
          if (player.account_id && player.account_id !== id) throw new Error('Display name is already linked to another account');
          connection.prepare(`UPDATE players SET account_id = ? WHERE id = ?`).run(id, player.id);
          player = { ...player, account_id: id };
        } else {
          const playerId = crypto.randomUUID();
          connection.prepare(`
            INSERT INTO players (id, display_name, pin_hash, created_at, account_id)
            VALUES (?, ?, NULL, ?, ?)
          `).run(playerId, displayName, now, id);
          player = { id: playerId, display_name: displayName, pin_hash: null, created_at: now, account_id: id };
        }

        const account = connection.prepare(`
          SELECT id, username, display_name, local_email, mailbox_status, email_verified_at, password_hash, role, status,
                 parent_account_id, created_at, updated_at, last_login_at
          FROM accounts
          WHERE id = ?
        `).get(id) as AccountRecord;
        return { account: toAccount(account), player: toPlayer(player) };
      });
      try {
        return create(input);
      } catch (error) {
        if (isSqliteUnique(error)) throw new Error('Account or display name already exists');
        throw error;
      }
    },
    listAccounts() {
      return connection.prepare(`
        SELECT id, username, display_name, local_email, mailbox_status, email_verified_at, password_hash, role, status,
               parent_account_id, created_at, updated_at, last_login_at
        FROM accounts
        ORDER BY lower(username)
      `).all().map((row) => toAccount(row as AccountRecord));
    },
    findAccountById(accountId) {
      return connection.prepare(`
        SELECT id, username, display_name, local_email, mailbox_status, email_verified_at, password_hash, role, status,
               parent_account_id, created_at, updated_at, last_login_at
        FROM accounts
        WHERE id = ?
      `).get(accountId) as AccountRecord | undefined;
    },
    findAccountByUsername(username) {
      return connection.prepare(`
        SELECT id, username, display_name, local_email, mailbox_status, email_verified_at, password_hash, role, status,
               parent_account_id, created_at, updated_at, last_login_at
        FROM accounts
        WHERE username = ?
      `).get(normalizeUsername(username)) as AccountRecord | undefined;
    },
    createAccountSession(account, password) {
      if (account.status !== 'active') throw new Error('Account is not active');
      if (!verifySecret(password, account.password_hash)) throw new Error('Invalid password');
      const token = crypto.randomBytes(32).toString('base64url');
      const now = new Date().toISOString();
      connection.prepare(`
        INSERT INTO account_sessions (token, account_id, created_at)
        VALUES (?, ?, ?)
      `).run(token, account.id, now);
      connection.prepare(`
        UPDATE accounts SET last_login_at = ?, updated_at = ? WHERE id = ?
      `).run(now, now, account.id);
      return token;
    },
    getAccountSession(token) {
      return connection.prepare(`
        SELECT token, account_id, created_at FROM account_sessions WHERE token = ?
      `).get(token) as AccountSessionRecord | undefined;
    },
    recordAccountActivity(accountId, input) {
      const now = new Date().toISOString();
      const id = crypto.randomUUID();
      const gameId = input.id.trim();
      const title = input.title.trim() || gameId;
      const gamePath = input.path.trim();
      const meta = (input.meta || '').trim();
      const description = (input.description || '').trim();
      const tagsJson = JSON.stringify(safeStringArray(input.tags));
      const categoriesJson = JSON.stringify(safeStringArray(input.categories));
      const preview = (input.preview || '').trim();
      const system = (input.system || '').trim();
      const deepType = (input.deepType || '').trim();
      connection.prepare(`
        INSERT INTO account_activity (
          id, account_id, game_id, title, path, meta, description, tags_json, categories_json,
          preview, system, deep_type, play_count, first_played_at, last_played_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
        ON CONFLICT(account_id, game_id, path) DO UPDATE SET
          title = excluded.title,
          meta = excluded.meta,
          description = excluded.description,
          tags_json = excluded.tags_json,
          categories_json = excluded.categories_json,
          preview = excluded.preview,
          system = excluded.system,
          deep_type = excluded.deep_type,
          play_count = account_activity.play_count + 1,
          last_played_at = excluded.last_played_at
      `).run(
        id,
        accountId,
        gameId,
        title,
        gamePath,
        meta,
        description,
        tagsJson,
        categoriesJson,
        preview,
        system,
        deepType,
        now,
        now
      );
      const row = connection.prepare(`
        SELECT id, account_id, game_id, title, path, meta, description, tags_json, categories_json,
               preview, system, deep_type, play_count, first_played_at, last_played_at
        FROM account_activity
        WHERE account_id = ? AND game_id = ? AND path = ?
      `).get(accountId, gameId, gamePath) as AccountActivityRow | undefined;
      if (!row) throw new Error('Activity was recorded but could not be loaded');
      return toRecentGameActivity(row);
    },
    listAccountActivity(accountId, options = {}) {
      const limit = Math.min(Math.max(options.limit || 12, 1), 100);
      return connection.prepare(`
        SELECT id, account_id, game_id, title, path, meta, description, tags_json, categories_json,
               preview, system, deep_type, play_count, first_played_at, last_played_at
        FROM account_activity
        WHERE account_id = ?
        ORDER BY last_played_at DESC
        LIMIT ?
      `).all(accountId, limit).map((row) => toRecentGameActivity(row as AccountActivityRow));
    },
    upsertAccountSave(accountId, input) {
      const now = new Date().toISOString();
      const id = crypto.randomUUID();
      const payload = String(input.payload);
      const sizeBytes = Buffer.byteLength(payload, 'utf8');
      const checksum = crypto.createHash('sha256').update(payload).digest('hex');
      const metadataJson = JSON.stringify(input.metadata || {});
      connection.prepare(`
        INSERT INTO account_save_slots (
          id, account_id, adapter, game_id, slot, label, payload_encoding, payload,
          metadata_json, size_bytes, checksum, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(account_id, adapter, game_id, slot) DO UPDATE SET
          label = excluded.label,
          payload_encoding = excluded.payload_encoding,
          payload = excluded.payload,
          metadata_json = excluded.metadata_json,
          size_bytes = excluded.size_bytes,
          checksum = excluded.checksum,
          updated_at = excluded.updated_at
      `).run(
        id,
        accountId,
        input.adapter,
        input.gameId,
        input.slot,
        input.label || input.slot,
        input.payloadEncoding || 'json',
        payload,
        metadataJson,
        sizeBytes,
        checksum,
        now,
        now
      );
      const saved = this.getAccountSave(accountId, input.adapter, input.gameId, input.slot);
      if (!saved) throw new Error('Save was written but could not be loaded');
      return saved;
    },
    getAccountSave(accountId, adapter, gameId, slot) {
      const row = connection.prepare(`
        SELECT id, account_id, adapter, game_id, slot, label, payload_encoding, payload,
               metadata_json, size_bytes, checksum, created_at, updated_at
        FROM account_save_slots
        WHERE account_id = ? AND adapter = ? AND game_id = ? AND slot = ?
      `).get(accountId, adapter, gameId, slot) as AccountSaveRow | undefined;
      return row ? toAccountSaveSlot(row, true) : undefined;
    },
    listAccountSaves(accountId, options = {}) {
      const params: unknown[] = [accountId];
      const where = ['account_id = ?'];
      if (options.adapter) { where.push('adapter = ?'); params.push(options.adapter); }
      if (options.gameId) { where.push('game_id = ?'); params.push(options.gameId); }
      const limit = Math.min(Math.max(options.limit || 50, 1), 200);
      params.push(limit);
      return connection.prepare(`
        SELECT id, account_id, adapter, game_id, slot, label, payload_encoding, payload,
               metadata_json, size_bytes, checksum, created_at, updated_at
        FROM account_save_slots
        WHERE ${where.join(' AND ')}
        ORDER BY updated_at DESC
        LIMIT ?
      `).all(...params).map((row) => toAccountSaveSlot(row as AccountSaveRow, Boolean(options.includePayload)));
    },
    createPlayer(displayName, pin) {
      const id = crypto.randomUUID();
      const createdAt = new Date().toISOString();
      const pinHash = pin ? hashPin(pin) : null;
      connection.prepare(`
        INSERT INTO players (id, display_name, pin_hash, created_at, account_id)
        VALUES (?, ?, ?, ?, NULL)
      `).run(id, displayName, pinHash, createdAt);
      return toPlayer({ id, display_name: displayName, pin_hash: pinHash, created_at: createdAt, account_id: null });
    },
    listPlayers() {
      return connection.prepare(`
        SELECT id, display_name, pin_hash, created_at, account_id
        FROM players
        ORDER BY lower(display_name)
      `).all().map((row) => toPlayer(row as PlayerRecord));
    },
    findPlayerById(playerId) {
      return connection.prepare(`
        SELECT id, display_name, pin_hash, created_at, account_id FROM players WHERE id = ?
      `).get(playerId) as PlayerRecord | undefined;
    },
    findPlayerByDisplayName(displayName) {
      return connection.prepare(`
        SELECT id, display_name, pin_hash, created_at, account_id FROM players WHERE lower(display_name) = lower(?)
      `).get(displayName) as PlayerRecord | undefined;
    },
    findPlayerByAccountId(accountId) {
      return connection.prepare(`
        SELECT id, display_name, pin_hash, created_at, account_id FROM players WHERE account_id = ?
      `).get(accountId) as PlayerRecord | undefined;
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
    CREATE TABLE IF NOT EXISTS accounts (
      id TEXT PRIMARY KEY,
      username TEXT NOT NULL UNIQUE,
      display_name TEXT NOT NULL,
      local_email TEXT NOT NULL UNIQUE,
      mailbox_status TEXT NOT NULL DEFAULT 'pending',
      email_verified_at TEXT,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL,
      status TEXT NOT NULL,
      parent_account_id TEXT REFERENCES accounts(id) ON DELETE SET NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_login_at TEXT
    );

    CREATE TABLE IF NOT EXISTS players (
      id TEXT PRIMARY KEY,
      display_name TEXT NOT NULL UNIQUE,
      pin_hash TEXT,
      created_at TEXT NOT NULL,
      account_id TEXT REFERENCES accounts(id) ON DELETE SET NULL
    );

    CREATE TABLE IF NOT EXISTS sessions (
      token TEXT PRIMARY KEY,
      player_id TEXT NOT NULL REFERENCES players(id) ON DELETE CASCADE,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS account_sessions (
      token TEXT PRIMARY KEY,
      account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
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

    CREATE TABLE IF NOT EXISTS account_activity (
      id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
      game_id TEXT NOT NULL,
      title TEXT NOT NULL,
      path TEXT NOT NULL,
      meta TEXT NOT NULL,
      description TEXT NOT NULL,
      tags_json TEXT NOT NULL,
      categories_json TEXT NOT NULL,
      preview TEXT NOT NULL,
      system TEXT NOT NULL,
      deep_type TEXT NOT NULL,
      play_count INTEGER NOT NULL,
      first_played_at TEXT NOT NULL,
      last_played_at TEXT NOT NULL,
      UNIQUE(account_id, game_id, path)
    );

    CREATE TABLE IF NOT EXISTS account_save_slots (
      id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
      adapter TEXT NOT NULL,
      game_id TEXT NOT NULL,
      slot TEXT NOT NULL,
      label TEXT NOT NULL,
      payload_encoding TEXT NOT NULL,
      payload TEXT NOT NULL,
      metadata_json TEXT NOT NULL,
      size_bytes INTEGER NOT NULL,
      checksum TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      UNIQUE(account_id, adapter, game_id, slot)
    );

    CREATE INDEX IF NOT EXISTS idx_scores_game_seed_score
      ON scores(game_id, seed, score DESC);
    CREATE INDEX IF NOT EXISTS idx_players_account_id
      ON players(account_id);
    CREATE INDEX IF NOT EXISTS idx_account_sessions_account_id
      ON account_sessions(account_id);
    CREATE INDEX IF NOT EXISTS idx_account_activity_account_recent
      ON account_activity(account_id, last_played_at DESC);
    CREATE INDEX IF NOT EXISTS idx_account_save_slots_account_game
      ON account_save_slots(account_id, adapter, game_id, updated_at DESC);
  `);
  safeAlter(connection, 'ALTER TABLE players ADD COLUMN account_id TEXT REFERENCES accounts(id) ON DELETE SET NULL');
  safeAlter(connection, "ALTER TABLE accounts ADD COLUMN mailbox_status TEXT NOT NULL DEFAULT 'pending'");
  safeAlter(connection, 'ALTER TABLE accounts ADD COLUMN email_verified_at TEXT');
}

function safeAlter(connection: Database.Database, sql: string): void {
  try {
    connection.exec(sql);
  } catch (error) {
    if (error instanceof Error && /duplicate column name/i.test(error.message)) return;
    throw error;
  }
}

function normalizeUsername(value: string): string {
  return value.trim().toLowerCase();
}

function toAccount(row: AccountRecord): ArcadeAccount {
  return {
    id: row.id,
    username: row.username,
    displayName: row.display_name,
    localEmail: row.local_email,
    mailboxStatus: row.mailbox_status || 'pending',
    emailVerifiedAt: row.email_verified_at,
    role: row.role,
    status: row.status,
    parentAccountId: row.parent_account_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    lastLoginAt: row.last_login_at
  };
}

function toPlayer(row: PlayerRecord): Player {
  return {
    id: row.id,
    displayName: row.display_name,
    pinProtected: Boolean(row.pin_hash),
    createdAt: row.created_at,
    accountId: row.account_id
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

function toRecentGameActivity(row: AccountActivityRow): RecentGameActivity {
  return {
    id: row.id,
    accountId: row.account_id,
    gameId: row.game_id,
    title: row.title,
    path: row.path,
    meta: row.meta,
    description: row.description,
    tags: safeJsonArray(row.tags_json),
    categories: safeJsonArray(row.categories_json),
    preview: row.preview,
    system: row.system,
    deepType: row.deep_type,
    playCount: row.play_count,
    firstPlayedAt: row.first_played_at,
    lastPlayedAt: row.last_played_at
  };
}

function toAccountSaveSlot(row: AccountSaveRow, includePayload: boolean): AccountSaveSlot {
  return {
    id: row.id,
    accountId: row.account_id,
    adapter: row.adapter,
    gameId: row.game_id,
    slot: row.slot,
    label: row.label,
    payloadEncoding: row.payload_encoding,
    payload: includePayload ? row.payload : undefined,
    metadata: safeJsonObject(row.metadata_json),
    sizeBytes: row.size_bytes,
    checksum: row.checksum,
    createdAt: row.created_at,
    updatedAt: row.updated_at
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

function safeJsonArray(value: string): string[] {
  try {
    const parsed = JSON.parse(value);
    return safeStringArray(parsed);
  } catch {
    return [];
  }
}

function safeStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.map((item) => String(item).trim()).filter(Boolean).slice(0, 20);
}

function hashPin(pin: string): string {
  return hashSecret(pin);
}

function hashSecret(secret: string): string {
  const salt = crypto.randomBytes(16).toString('hex');
  const iterations = 120_000;
  const hash = crypto.pbkdf2Sync(secret, salt, iterations, 32, 'sha256').toString('hex');
  return `pbkdf2$${iterations}$${salt}$${hash}`;
}

function verifyPin(pin: string, stored: string): boolean {
  return verifySecret(pin, stored);
}

function verifySecret(secret: string, stored: string): boolean {
  const [scheme, iterationsRaw, salt, hash] = stored.split('$');
  if (scheme !== 'pbkdf2' || !iterationsRaw || !salt || !hash) return false;
  const iterations = Number.parseInt(iterationsRaw, 10);
  const candidate = crypto.pbkdf2Sync(secret, salt, iterations, 32, 'sha256').toString('hex');
  return crypto.timingSafeEqual(Buffer.from(candidate, 'hex'), Buffer.from(hash, 'hex'));
}

function isSqliteUnique(error: unknown): boolean {
  return error instanceof Error && /UNIQUE constraint failed/i.test(error.message);
}

export function playerFromRecord(row: PlayerRecord): Player {
  return toPlayer(row);
}

export function accountFromRecord(row: AccountRecord): ArcadeAccount {
  return toAccount(row);
}
