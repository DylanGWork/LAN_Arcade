export type GameSource = 'lan-web' | 'app-web' | 'lan-service';

export type ScoreMode = 'standard' | 'challenge' | 'practice';

export interface ArcadeCategory {
  id: string;
  label: string;
}

export interface ArcadeGame {
  id: string;
  title: string;
  icon: string;
  meta: string;
  description: string;
  tags: string[];
  categories: string[];
  source: GameSource;
  scoreEnabled: boolean;
  launchPath?: string;
  appRoute?: string;
  connectionHint?: string;
  serverPort?: number;
  systemHint?: string;
}

export interface ArcadeCatalog {
  generatedAt: string;
  arcadeName: string;
  categories: ArcadeCategory[];
  games: ArcadeGame[];
  filters: AdminFilters;
}

export interface AdminFilters {
  disabled_categories: string[];
  disabled_games: string[];
}

export interface Player {
  id: string;
  displayName: string;
  pinProtected: boolean;
  createdAt: string;
}

export interface Session {
  token: string;
  player: Player;
}

export interface CreatePlayerRequest {
  displayName: string;
  pin?: string;
}

export interface CreateSessionRequest {
  playerId?: string;
  displayName?: string;
  pin?: string;
}

export interface ScoreSubmission {
  gameId: string;
  playerId: string;
  score: number;
  mode?: ScoreMode;
  difficulty?: string;
  seed?: string;
  durationMs?: number;
  details?: Record<string, unknown>;
}

export interface LeaderboardEntry {
  id: string;
  gameId: string;
  playerId: string;
  playerName: string;
  score: number;
  mode: ScoreMode;
  difficulty: string;
  seed: string;
  durationMs: number | null;
  details: Record<string, unknown>;
  createdAt: string;
}

export interface Challenge {
  gameId: string;
  mode: 'challenge';
  difficulty: string;
  seed: string;
  label: string;
  startsAt: string;
  endsAt: string;
}

export interface ServerInfo {
  name: string;
  apiVersion: string;
  generatedAt: string;
  capabilities: string[];
}

export const scoreEnabledGameIds = ['trailguard-td', 'camp-colony', '2048', 'snake', 'number-splash'] as const;

export const bundledCompanionGames: ArcadeGame[] = [
  {
    id: 'camp-colony',
    title: 'Camp Colony',
    icon: 'CC',
    meta: 'Turn Strategy - App Only',
    description: 'Build a tiny off-grid base over seeded turns, then compare survival scores on the LAN leaderboard.',
    tags: ['Strategy', 'Base builder', 'Challenge', 'App only'],
    categories: ['strategy', 'puzzle', 'age-10-plus', 'family'],
    source: 'app-web',
    scoreEnabled: true,
    appRoute: 'camp-colony'
  },
  {
    id: 'trailguard-td',
    title: 'Trailguard TD',
    icon: 'TD',
    meta: 'Tower Defense - App Only',
    description: 'Defend a winding trail with touch-built towers, seeded waves, and camp leaderboards.',
    tags: ['Tower defense', 'Challenge', 'App only'],
    categories: ['strategy', 'arcade', 'age-10-plus'],
    source: 'app-web',
    scoreEnabled: true,
    appRoute: 'trailguard-td'
  },
  {
    id: 'number-splash',
    title: 'Number Splash',
    icon: '123',
    meta: 'Kids - Counting',
    description: 'Tap the matching number bubbles before time runs out.',
    tags: ['Counting', 'Kids', 'Quick play'],
    categories: ['educational', 'maths', 'age-5-plus', 'family'],
    source: 'app-web',
    scoreEnabled: true,
    appRoute: 'number-splash'
  },
  {
    id: 'mindustry-lan',
    title: 'Mindustry LAN Server',
    icon: 'MD',
    meta: 'Native Multiplayer - Pi Hosted',
    description: 'A Raspberry Pi hosts the dedicated server while Android and desktop Mindustry clients do the rendering and gameplay.',
    tags: ['Strategy', 'Multiplayer', 'Pi server', 'External client'],
    categories: ['strategy', 'multiplayer', 'age-10-plus'],
    source: 'lan-service',
    scoreEnabled: false,
    connectionHint: 'Install Mindustry on each phone/desktop, then join the LAN server address shown by your Pi on port 6567.',
    serverPort: 6567,
    systemHint: 'Best on a Pi 4 with 4 GB or more. Start with MINDUSTRY_XMX=512m and a small map.'
  },
  {
    id: 'unciv-lan',
    title: 'Unciv LAN Server',
    icon: 'UC',
    meta: 'Turn Strategy - Native Clients',
    description: 'A lightweight Civilization-style turn server for Android and desktop Unciv clients on the local network.',
    tags: ['Strategy', 'Turns', 'Pi server', 'External client'],
    categories: ['strategy', 'multiplayer', 'age-10-plus'],
    source: 'lan-service',
    scoreEnabled: false,
    connectionHint: 'Install Unciv on each phone/desktop, then set the multiplayer server to http://<pi-ip>:8090.',
    serverPort: 8090,
    systemHint: 'Lightest bigger-game trial. Start with UNCIV_JAVA_OPTS="-Xms64m -Xmx256m".'
  }
];

export function isScoreEnabledGame(gameId: string): boolean {
  return (scoreEnabledGameIds as readonly string[]).includes(gameId);
}
