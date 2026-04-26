import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import {
  bundledCompanionGames,
  type AdminFilters,
  type ArcadeCatalog,
  type ArcadeCategory,
  type ArcadeGame,
  isScoreEnabledGame
} from '@lan-arcade/shared';
import type { ApiConfig } from './config.js';

interface RawCatalog {
  generated_at?: string;
  arcade_name?: string;
  categories?: ArcadeCategory[];
  games?: Array<{
    id?: string;
    title?: string;
    icon?: string;
    meta?: string;
    description?: string;
    tags?: string[];
    categories?: string[];
    path?: string;
  }>;
}

export async function readAdminFilters(filtersPath: string): Promise<AdminFilters> {
  try {
    const raw = JSON.parse(await fs.readFile(filtersPath, 'utf8')) as Partial<AdminFilters>;
    return normalizeFilters(raw);
  } catch {
    return { disabled_categories: [], disabled_games: [] };
  }
}

export async function writeAdminFilters(filtersPath: string, filters: AdminFilters): Promise<AdminFilters> {
  const normalized = normalizeFilters(filters);
  await fs.mkdir(path.dirname(filtersPath), { recursive: true });
  await fs.writeFile(filtersPath, `${JSON.stringify(normalized, null, 2)}\n`, { mode: 0o644 });
  await fs.chmod(filtersPath, 0o644);
  return normalized;
}

export async function buildCatalog(config: ApiConfig): Promise<ArcadeCatalog> {
  const [rawCatalog, filters] = await Promise.all([
    readRawCatalog(config.catalogPath),
    readAdminFilters(config.filtersPath)
  ]);

  const categories = mergeCategories(rawCatalog.categories || [], bundledCompanionGames);
  const lanGames = (rawCatalog.games || []).map(toLanGame).filter(Boolean) as ArcadeGame[];
  const games = [...lanGames, ...bundledCompanionGames]
    .filter((game) => gameEnabled(game, filters))
    .sort((a, b) => a.title.localeCompare(b.title));

  return {
    generatedAt: new Date().toISOString(),
    arcadeName: rawCatalog.arcade_name || config.arcadeName,
    categories,
    games,
    filters
  };
}

export function currentChallenge(gameId: string, difficulty = 'normal', at = new Date()) {
  const day = at.toISOString().slice(0, 10);
  const seed = crypto.createHash('sha256')
    .update(`${day}:${gameId}:${difficulty}`)
    .digest('hex')
    .slice(0, 12);
  const startsAt = `${day}T00:00:00.000Z`;
  const endsAtDate = new Date(startsAt);
  endsAtDate.setUTCDate(endsAtDate.getUTCDate() + 1);
  return {
    gameId,
    mode: 'challenge' as const,
    difficulty,
    seed,
    label: `${gameId} ${difficulty} ${day}`,
    startsAt,
    endsAt: endsAtDate.toISOString()
  };
}

async function readRawCatalog(catalogPath: string): Promise<RawCatalog> {
  try {
    return JSON.parse(await fs.readFile(catalogPath, 'utf8')) as RawCatalog;
  } catch {
    return { generated_at: new Date().toISOString(), arcade_name: 'LAN Arcade', categories: [], games: [] };
  }
}

function toLanGame(raw: NonNullable<RawCatalog['games']>[number]): ArcadeGame | null {
  if (!raw.id) return null;
  return {
    id: raw.id,
    title: raw.title || raw.id,
    icon: raw.icon || 'Play',
    meta: raw.meta || 'HTML5 / Offline',
    description: raw.description || 'LAN-hosted browser game.',
    tags: Array.isArray(raw.tags) ? raw.tags.map(String) : [],
    categories: Array.isArray(raw.categories) ? raw.categories.map(String) : [],
    source: 'lan-web',
    scoreEnabled: isScoreEnabledGame(raw.id),
    launchPath: catalogPathToLaunchPath(raw.path, raw.id)
  };
}

function catalogPathToLaunchPath(catalogPath: string | undefined, gameId: string): string {
  if (!catalogPath) return `/mirrors/${encodeURIComponent(gameId)}/`;
  if (catalogPath.startsWith('../')) {
    return `/mirrors/${catalogPath.slice(3).replace(/^\/+/, '')}`;
  }
  if (catalogPath.startsWith('/')) return catalogPath;
  return `/mirrors/games/${catalogPath}`;
}

function mergeCategories(existing: ArcadeCategory[], games: ArcadeGame[]): ArcadeCategory[] {
  const map = new Map<string, ArcadeCategory>();
  existing.forEach((category) => {
    if (category?.id) map.set(category.id, { id: category.id, label: category.label || labelFromSlug(category.id) });
  });
  games.flatMap((game) => game.categories).forEach((categoryId) => {
    if (!map.has(categoryId)) map.set(categoryId, { id: categoryId, label: labelFromSlug(categoryId) });
  });
  return [...map.values()];
}

function gameEnabled(game: ArcadeGame, filters: AdminFilters): boolean {
  if (filters.disabled_games.includes(game.id)) return false;
  return !game.categories.some((category) => filters.disabled_categories.includes(category));
}

function normalizeFilters(raw: Partial<AdminFilters>): AdminFilters {
  return {
    disabled_categories: uniqueStrings(raw.disabled_categories),
    disabled_games: uniqueStrings(raw.disabled_games)
  };
}

function uniqueStrings(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.map((item) => String(item).trim()).filter(Boolean))].sort();
}

function labelFromSlug(slug: string): string {
  return slug.split('-').map((part) => `${part.slice(0, 1).toUpperCase()}${part.slice(1)}`).join(' ');
}
