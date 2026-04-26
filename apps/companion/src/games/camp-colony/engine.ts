export type Terrain = 'meadow' | 'woods' | 'ridge' | 'ruins' | 'creek';

export interface CampTile {
  id: string;
  x: number;
  y: number;
  terrain: Terrain;
  value: number;
}

export interface CampColonyMap {
  seed: string;
  width: number;
  height: number;
  tiles: CampTile[];
}

export interface CampColonyBuildings {
  gardens: number;
  solar: number;
  watchtowers: number;
  workshops: number;
}

export type CampActionId =
  | 'forage'
  | 'build-garden'
  | 'build-solar'
  | 'build-watchtower'
  | 'build-workshop'
  | 'send-scouts'
  | 'research';

export interface CampAction {
  id: CampActionId;
  label: string;
  description: string;
  cost: Partial<Pick<CampColonyState, 'food' | 'parts' | 'power'>>;
}

export interface CampColonyState {
  seed: string;
  turn: number;
  maxTurns: number;
  food: number;
  parts: number;
  power: number;
  population: number;
  defense: number;
  scouts: number;
  tech: number;
  morale: number;
  threat: number;
  explored: number;
  buildings: CampColonyBuildings;
  log: string[];
  complete: boolean;
  failed: boolean;
  score: number;
}

export interface CampColonyOptions {
  maxTurns?: number;
}

export const campActions: CampAction[] = [
  {
    id: 'forage',
    label: 'Forage',
    description: 'Gather food and parts, but make a little noise.',
    cost: {}
  },
  {
    id: 'build-garden',
    label: 'Garden',
    description: 'Adds food production each turn.',
    cost: { parts: 12, power: 1 }
  },
  {
    id: 'build-solar',
    label: 'Solar',
    description: 'Adds stored power each turn.',
    cost: { parts: 14 }
  },
  {
    id: 'build-watchtower',
    label: 'Watchtower',
    description: 'Improves raid defense.',
    cost: { parts: 16, power: 2 }
  },
  {
    id: 'build-workshop',
    label: 'Workshop',
    description: 'Adds parts production and unlocks better scoring.',
    cost: { parts: 20, power: 2 }
  },
  {
    id: 'send-scouts',
    label: 'Scout',
    description: 'Explores the map and reduces threat.',
    cost: { food: 5 }
  },
  {
    id: 'research',
    label: 'Research',
    description: 'Turns parts and power into better colony tech.',
    cost: { parts: 6, power: 2 }
  }
];

export function createCampColony(seed: string, options: CampColonyOptions = {}): CampColonyState {
  const random = seededRandom(seed);
  const state: CampColonyState = {
    seed,
    turn: 1,
    maxTurns: options.maxTurns || 10,
    food: 20 + Math.floor(random() * 5),
    parts: 26 + Math.floor(random() * 7),
    power: 4,
    population: 6,
    defense: 4 + Math.floor(random() * 3),
    scouts: 0,
    tech: 0,
    morale: 70,
    threat: 10 + Math.floor(random() * 7),
    explored: 2,
    buildings: { gardens: 0, solar: 0, watchtowers: 0, workshops: 0 },
    log: ['Camp founded. Keep everyone fed and the perimeter quiet.'],
    complete: false,
    failed: false,
    score: 0
  };
  return { ...state, score: calculateCampScore(state) };
}

export function createCampMap(seed: string, width = 5, height = 4): CampColonyMap {
  const random = seededRandom(`map:${seed}`);
  const terrains: Terrain[] = ['meadow', 'woods', 'ridge', 'ruins', 'creek'];
  const tiles: CampTile[] = [];
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const center = x === Math.floor(width / 2) && y === Math.floor(height / 2);
      tiles.push({
        id: `${x}:${y}`,
        x,
        y,
        terrain: center ? 'meadow' : terrains[Math.floor(random() * terrains.length)],
        value: center ? 9 : 1 + Math.floor(random() * 9)
      });
    }
  }
  return { seed, width, height, tiles };
}

export function canUseCampAction(state: CampColonyState, actionId: CampActionId): boolean {
  const action = campActions.find((candidate) => candidate.id === actionId);
  if (!action || state.complete || state.failed) return false;
  return resourceKeys.every((key) => state[key] >= (action.cost[key] || 0));
}

export function applyCampAction(state: CampColonyState, actionId: CampActionId): CampColonyState {
  const action = campActions.find((candidate) => candidate.id === actionId);
  if (!action || state.complete || state.failed) return state;
  if (!canUseCampAction(state, actionId)) {
    return {
      ...state,
      log: [`Need more supplies for ${action.label}.`, ...state.log].slice(0, 6)
    };
  }

  const next = cloneState(state);
  const random = seededRandom(`${state.seed}:turn:${state.turn}:${actionId}`);
  const events: string[] = [];

  resourceKeys.forEach((key) => {
    next[key] -= action.cost[key] || 0;
  });

  switch (actionId) {
    case 'forage':
      next.food += 8 + Math.floor(random() * 7);
      next.parts += 6 + Math.floor(random() * 6);
      next.threat += 3;
      events.push('Foragers returned with supplies, and a few snapped branches.');
      break;
    case 'build-garden':
      next.buildings.gardens += 1;
      next.morale += 1;
      events.push('A food garden is growing beside the camp kitchen.');
      break;
    case 'build-solar':
      next.buildings.solar += 1;
      next.power += 3;
      events.push('Solar panels are charging the battery bank.');
      break;
    case 'build-watchtower':
      next.buildings.watchtowers += 1;
      next.defense += 5;
      events.push('A new watchtower covers the trail approach.');
      break;
    case 'build-workshop':
      next.buildings.workshops += 1;
      next.tech += 1;
      events.push('The workshop can turn scavenged bits into better gear.');
      break;
    case 'send-scouts':
      next.scouts += 1;
      next.explored += 2 + Math.floor(random() * 3);
      next.threat = clamp(next.threat - 4, 0, 99);
      events.push('Scouts mapped nearby trails and steered trouble away.');
      break;
    case 'research':
      next.tech += 2;
      next.morale += 2;
      events.push('The camp learned a cleaner, quicker way to build.');
      break;
  }

  return resolveCampTurn(next, actionId, events);
}

export function calculateCampScore(state: CampColonyState): number {
  const buildingScore = (
    state.buildings.gardens * 120
    + state.buildings.solar * 100
    + state.buildings.watchtowers * 140
    + state.buildings.workshops * 180
  );
  const survivalBonus = state.complete && !state.failed ? 1000 : 0;
  const failurePenalty = state.failed ? 600 : 0;
  const score = (
    state.population * 340
    + state.morale * 16
    + state.defense * 28
    + state.tech * 95
    + state.scouts * 80
    + state.explored * 42
    + state.food * 5
    + state.parts * 6
    + state.power * 4
    + buildingScore
    + survivalBonus
    - state.threat * 8
    - failurePenalty
  );
  return Math.max(0, Math.floor(score));
}

function resolveCampTurn(state: CampColonyState, actionId: CampActionId, events: string[]): CampColonyState {
  const next = cloneState(state);
  const random = seededRandom(`${state.seed}:resolve:${state.turn}:${actionId}`);

  next.food += next.buildings.gardens * 5;
  next.parts += next.buildings.workshops * 4;
  next.power = Math.min(30 + next.buildings.solar * 8, next.power + next.buildings.solar * 2);

  const consumption = next.population * 2;
  if (next.food >= consumption) {
    next.food -= consumption;
    next.morale = clamp(next.morale + 1, 0, 100);
  } else {
    const shortage = consumption - next.food;
    next.food = 0;
    next.morale = clamp(next.morale - shortage * 3, 0, 100);
    if (shortage >= 5) {
      next.population = Math.max(0, next.population - Math.ceil(shortage / 5));
    }
    events.push('Food ran short and the camp lost morale.');
  }

  const threatGrowth = Math.max(1, 5 + Math.floor(random() * 6) - next.scouts - Math.floor(next.tech / 2));
  next.threat = clamp(next.threat + threatGrowth, 0, 99);

  const raidDue = state.turn % 3 === 0 || next.threat >= 32;
  if (raidDue) {
    const raidPower = next.threat + Math.floor(random() * 12);
    const guard = next.defense + next.buildings.watchtowers * 3 + next.scouts * 2 + next.tech * 2;
    const damage = Math.max(0, raidPower - guard);
    if (damage > 0) {
      next.parts = Math.max(0, next.parts - Math.floor(damage / 2));
      next.food = Math.max(0, next.food - Math.floor(damage / 3));
      next.morale = clamp(next.morale - Math.min(22, 4 + Math.floor(damage / 3)), 0, 100);
      next.threat = clamp(next.threat - 9 - next.tech, 0, 99);
      events.push(`A raid broke through for ${damage} damage.`);
    } else {
      next.morale = clamp(next.morale + 3, 0, 100);
      next.threat = clamp(next.threat - 13, 0, 99);
      events.push('The perimeter held and the camp cheered.');
    }
  }

  next.turn += 1;
  next.failed = next.population <= 0 || next.morale <= 0;
  next.complete = next.failed || next.turn > next.maxTurns;
  if (next.complete && !next.failed) events.push('The colony survived the full challenge.');
  if (next.failed) events.push('The colony could not hold together.');
  next.score = calculateCampScore(next);
  next.log = [...events.reverse(), ...state.log].slice(0, 6);
  return next;
}

function cloneState(state: CampColonyState): CampColonyState {
  return {
    ...state,
    buildings: { ...state.buildings },
    log: [...state.log]
  };
}

const resourceKeys = ['food', 'parts', 'power'] as const;

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function seededRandom(seed: string): () => number {
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
