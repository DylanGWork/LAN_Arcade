export interface Point {
  x: number;
  y: number;
}

export interface TrailguardMap {
  seed: string;
  path: Point[];
  towerSpots: Point[];
}

export interface WaveSpec {
  wave: number;
  enemyCount: number;
  enemyHealth: number;
  enemySpeed: number;
  bounty: number;
}

export interface TrailguardScoreInput {
  kills: number;
  wave: number;
  lives: number;
  money: number;
  leaks: number;
  durationMs: number;
}

export function seededRandom(seed: string): () => number {
  let state = 2166136261;
  for (let i = 0; i < seed.length; i += 1) {
    state ^= seed.charCodeAt(i);
    state = Math.imul(state, 16777619);
  }
  return () => {
    state += 0x6d2b79f5;
    let next = state;
    next = Math.imul(next ^ (next >>> 15), next | 1);
    next ^= next + Math.imul(next ^ (next >>> 7), next | 61);
    return ((next ^ (next >>> 14)) >>> 0) / 4294967296;
  };
}

export function createTrailguardMap(seed: string): TrailguardMap {
  const random = seededRandom(seed);
  const path: Point[] = [
    { x: -30, y: 210 },
    { x: 80, y: 210 },
    { x: 150, y: 110 + Math.floor(random() * 80) },
    { x: 270, y: 110 + Math.floor(random() * 220) },
    { x: 390, y: 120 + Math.floor(random() * 210) },
    { x: 520, y: 130 + Math.floor(random() * 180) },
    { x: 760, y: 240 }
  ];

  const towerSpots: Point[] = [
    { x: 120, y: 330 },
    { x: 210, y: 245 },
    { x: 310, y: 70 },
    { x: 420, y: 365 },
    { x: 515, y: 95 },
    { x: 600, y: 310 }
  ].map((spot) => ({
    x: spot.x + Math.floor((random() - 0.5) * 34),
    y: spot.y + Math.floor((random() - 0.5) * 28)
  }));

  return { seed, path, towerSpots };
}

export function waveSpec(wave: number): WaveSpec {
  return {
    wave,
    enemyCount: 6 + wave * 2,
    enemyHealth: 38 + wave * 18,
    enemySpeed: 36 + wave * 4,
    bounty: 12 + wave * 2
  };
}

export function calculateTrailguardScore(input: TrailguardScoreInput): number {
  const base = input.kills * 110 + input.wave * 350 + input.lives * 180 + input.money * 6;
  const leakPenalty = input.leaks * 150;
  const timeBonus = Math.max(0, 900 - Math.floor(input.durationMs / 1000));
  return Math.max(0, base + timeBonus - leakPenalty);
}
