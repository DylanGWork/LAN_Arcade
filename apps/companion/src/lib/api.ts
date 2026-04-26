import { Capacitor } from '@capacitor/core';
import type {
  ArcadeCatalog,
  Challenge,
  CreatePlayerRequest,
  LeaderboardEntry,
  Player,
  ScoreSubmission,
  ServerInfo,
  Session
} from '@lan-arcade/shared';

export interface ApiState {
  apiUrl: string;
  sessionToken: string;
  player: Player | null;
}

export interface ApiClient {
  baseUrl: string;
  health(): Promise<{ ok: boolean }>;
  serverInfo(): Promise<ServerInfo>;
  catalog(): Promise<ArcadeCatalog>;
  players(): Promise<Player[]>;
  createPlayer(payload: CreatePlayerRequest): Promise<Player>;
  createSession(payload: { playerId?: string; displayName?: string; pin?: string }): Promise<Session>;
  leaderboard(gameId: string, seed?: string): Promise<LeaderboardEntry[]>;
  currentChallenge(gameId: string, difficulty?: string): Promise<Challenge>;
  submitScore(score: ScoreSubmission, token: string): Promise<LeaderboardEntry>;
}

export const storageKeys = {
  apiUrl: 'lanArcade.apiUrl',
  sessionToken: 'lanArcade.sessionToken',
  player: 'lanArcade.player'
};

export function defaultApiUrl(): string {
  if (Capacitor.isNativePlatform()) return 'http://10.0.2.2/arcade-api/';
  return `${window.location.origin}/arcade-api/`;
}

export function normalizeApiUrl(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) return defaultApiUrl();
  return trimmed.endsWith('/') ? trimmed : `${trimmed}/`;
}

export function loadApiState(): ApiState {
  const playerRaw = window.localStorage.getItem(storageKeys.player);
  return {
    apiUrl: window.localStorage.getItem(storageKeys.apiUrl) || defaultApiUrl(),
    sessionToken: window.localStorage.getItem(storageKeys.sessionToken) || '',
    player: playerRaw ? JSON.parse(playerRaw) as Player : null
  };
}

export function saveApiState(state: Partial<ApiState>): void {
  if (state.apiUrl !== undefined) window.localStorage.setItem(storageKeys.apiUrl, state.apiUrl);
  if (state.sessionToken !== undefined) window.localStorage.setItem(storageKeys.sessionToken, state.sessionToken);
  if (state.player !== undefined) {
    if (state.player) window.localStorage.setItem(storageKeys.player, JSON.stringify(state.player));
    else window.localStorage.removeItem(storageKeys.player);
  }
}

export function createApiClient(baseUrlRaw: string): ApiClient {
  const baseUrl = normalizeApiUrl(baseUrlRaw);

  async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
    const response = await fetch(new URL(path.replace(/^\//, ''), baseUrl), {
      ...options,
      headers: {
        'content-type': 'application/json',
        ...(options.headers || {})
      }
    });
    if (!response.ok) {
      const body = await response.text();
      throw new Error(`${response.status} ${response.statusText}: ${body.slice(0, 160)}`);
    }
    return response.json() as Promise<T>;
  }

  return {
    baseUrl,
    health: () => request('/health'),
    serverInfo: () => request('/server-info'),
    catalog: () => request('/catalog'),
    players: async () => (await request<{ players: Player[] }>('/players')).players,
    createPlayer: async (payload) => (await request<{ player: Player }>('/players', {
      method: 'POST',
      body: JSON.stringify(payload)
    })).player,
    createSession: (payload) => request('/sessions', { method: 'POST', body: JSON.stringify(payload) }),
    leaderboard: async (gameId, seed) => {
      const query = seed ? `?seed=${encodeURIComponent(seed)}` : '';
      return (await request<{ entries: LeaderboardEntry[] }>(`/leaderboards/${encodeURIComponent(gameId)}${query}`)).entries;
    },
    currentChallenge: async (gameId, difficulty = 'normal') => (
      await request<{ challenge: Challenge }>(
        `/challenges/current?gameId=${encodeURIComponent(gameId)}&difficulty=${encodeURIComponent(difficulty)}`
      )
    ).challenge,
    submitScore: async (score, token) => (await request<{ entry: LeaderboardEntry }>('/scores', {
      method: 'POST',
      headers: { 'x-arcade-session': token },
      body: JSON.stringify(score)
    })).entry
  };
}

export function launchUrlForGame(apiBaseUrl: string, launchPath: string): string {
  const apiUrl = new URL(normalizeApiUrl(apiBaseUrl));
  return new URL(launchPath, apiUrl.origin).href;
}
