(() => {
  'use strict';

  const canvas = document.getElementById('world');
  const ctx = canvas.getContext('2d');

  const el = {
    toggleRun: document.getElementById('toggleRun'),
    runLine: document.getElementById('runLine'),
    population: document.getElementById('population'),
    generation: document.getElementById('generation'),
    families: document.getElementById('families'),
    grass: document.getElementById('grass'),
    speed: document.getElementById('speed'),
    mutation: document.getElementById('mutation'),
    pressure: document.getElementById('pressure'),
    startSize: document.getElementById('startSize'),
    dominantLine: document.getElementById('dominantLine'),
    birthDeath: document.getElementById('birthDeath'),
    geneBars: document.getElementById('geneBars'),
    familyList: document.getElementById('familyList'),
    toolReadout: document.getElementById('toolReadout'),
    eventLog: document.getElementById('eventLog'),
  };

  const geneDefs = [
    { key: 'sense', label: 'Sense' },
    { key: 'appetite', label: 'Appetite' },
    { key: 'thrift', label: 'Thrift' },
    { key: 'fertility', label: 'Fertility' },
    { key: 'speed', label: 'Speed' },
    { key: 'wander', label: 'Wander' },
    { key: 'longevity', label: 'Longevity' },
    { key: 'boldness', label: 'Boldness' },
  ];

  const familyNames = [
    'Aster', 'Beryl', 'Cinder', 'Dune', 'Ember', 'Fennel', 'Grove', 'Harbor',
    'Iris', 'Juniper', 'Kite', 'Lumen', 'Mica', 'Nettle', 'Ochre', 'Pollen',
  ];

  let seed = 0x6d2b79f5;
  const rand = () => {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };

  const clamp = (value, min = 0, max = 1) => Math.max(min, Math.min(max, value));
  const mix = (a, b, amount) => a + (b - a) * amount;
  const indexOf = (x, y) => y * state.cols + x;
  const seasonName = () => (state.forcedWinter > 0 ? 'Winter' : state.season);

  const state = {
    cols: 72,
    rows: 44,
    grass: new Float32Array(72 * 44),
    walls: new Uint8Array(72 * 44),
    occ: new Int32Array(72 * 44),
    critters: [],
    families: new Map(),
    tick: 0,
    births: 0,
    deaths: 0,
    nextId: 1,
    nextFamily: 0,
    running: true,
    speed: 4,
    mutation: 0.18,
    pressure: 0.42,
    startSize: 72,
    tool: 'grass',
    layout: 'meadow',
    season: 'Spring',
    seasonClock: 0,
    seasonLength: 540,
    forcedWinter: 0,
    frameCarry: 0,
    lastUi: 0,
    stats: null,
  };

  function resizeCanvas() {
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.max(1, Math.min(2, window.devicePixelRatio || 1));
    const width = Math.max(320, Math.floor(rect.width * dpr));
    const height = Math.max(320, Math.floor(rect.height * dpr));
    if (canvas.width !== width || canvas.height !== height) {
      canvas.width = width;
      canvas.height = height;
    }
  }

  function newFamily() {
    const number = state.nextFamily++;
    const name = familyNames[number % familyNames.length] + (number >= familyNames.length ? ` ${Math.floor(number / familyNames.length) + 1}` : '');
    const family = {
      id: number,
      name,
      hue: (number * 47 + 95) % 360,
      founded: state.tick,
      peak: 0,
    };
    state.families.set(number, family);
    return family;
  }

  function freshGenes() {
    const genes = {};
    for (const def of geneDefs) {
      genes[def.key] = clamp(0.28 + rand() * 0.56 + (rand() - rand()) * 0.12);
    }
    return genes;
  }

  function mutate(value) {
    const chance = 0.22 + state.mutation * 0.62;
    if (rand() > chance) return clamp(value + (rand() - rand()) * state.mutation * 0.08);
    const drift = (rand() + rand() - 1) * (0.07 + state.mutation * 0.24);
    return clamp(value + drift);
  }

  function mixGenes(a, b) {
    const genes = {};
    for (const def of geneDefs) {
      const fromParents = rand() < 0.5 ? a[def.key] : b[def.key];
      const blended = mix(fromParents, (a[def.key] + b[def.key]) / 2, 0.35);
      genes[def.key] = mutate(blended);
    }
    return genes;
  }

  function randomOpenCell() {
    for (let tries = 0; tries < 800; tries += 1) {
      const x = Math.floor(rand() * state.cols);
      const y = Math.floor(rand() * state.rows);
      const i = indexOf(x, y);
      if (!state.walls[i]) return { x, y };
    }
    return null;
  }

  function makeCritter(x, y, genes = freshGenes(), family = newFamily(), generation = 1) {
    return {
      id: state.nextId++,
      x,
      y,
      genes,
      family: family.id,
      generation,
      age: Math.floor(rand() * 25),
      energy: 0.45 + rand() * 0.42,
      maxAge: Math.floor(360 + genes.longevity * 860 + rand() * 160),
      alive: true,
    };
  }

  function addCritters(count, genes, family) {
    let added = 0;
    for (let i = 0; i < count; i += 1) {
      const cell = randomOpenCell();
      if (!cell) break;
      const critter = makeCritter(cell.x, cell.y, genes ? { ...genes } : freshGenes(), family || newFamily(), 1);
      state.critters.push(critter);
      added += 1;
    }
    if (added) logEvent(`Seeded ${added} new critters.`);
    return added;
  }

  function seedGrass() {
    for (let y = 0; y < state.rows; y += 1) {
      for (let x = 0; x < state.cols; x += 1) {
        const i = indexOf(x, y);
        const moisture = 0.36 + rand() * 0.42 + Math.sin(x * 0.21) * 0.08 + Math.cos(y * 0.17) * 0.08;
        state.grass[i] = clamp(moisture);
      }
    }
  }

  function clearWalls() {
    state.walls.fill(0);
  }

  function applyLayout(layout) {
    state.layout = layout;
    clearWalls();
    if (layout === 'paddocks') {
      for (let y = 0; y < state.rows; y += 1) {
        for (let x = 0; x < state.cols; x += 1) {
          const wall = (x % 12 === 0 || y % 10 === 0) && !(x % 12 === 6 && y % 10 === 0) && !(y % 10 === 5 && x % 12 === 0);
          if (wall) state.walls[indexOf(x, y)] = 1;
        }
      }
      logEvent('Paddocks divided the meadow into separate trials.');
    } else if (layout === 'corridor') {
      state.walls.fill(1);
      for (let y = 2; y < state.rows - 2; y += 1) {
        const leftToRight = Math.floor((y - 2) / 4) % 2 === 0;
        const start = leftToRight ? 2 : state.cols - 4;
        const end = leftToRight ? state.cols - 3 : 1;
        const step = leftToRight ? 1 : -1;
        for (let x = start; x !== end; x += step) {
          state.walls[indexOf(x, y)] = 0;
          if (y + 1 < state.rows - 2) state.walls[indexOf(x, y + 1)] = 0;
        }
        if (y % 4 === 1 && y + 2 < state.rows - 2) {
          const gateX = leftToRight ? state.cols - 4 : 3;
          state.walls[indexOf(gateX, y + 2)] = 0;
        }
      }
      logEvent('A long corridor forced lineages into traffic.');
    } else {
      logEvent('Open meadow restored.');
    }
  }

  function reset(layout = state.layout) {
    seed = (Date.now() ^ 0x9e3779b9) >>> 0;
    state.tick = 0;
    state.births = 0;
    state.deaths = 0;
    state.nextId = 1;
    state.nextFamily = 0;
    state.families.clear();
    state.critters = [];
    state.season = 'Spring';
    state.seasonClock = 0;
    state.forcedWinter = 0;
    state.startSize = Number(el.startSize.value);
    state.speed = Number(el.speed.value);
    state.mutation = Number(el.mutation.value) / 100;
    state.pressure = Number(el.pressure.value) / 100;
    state.grass = new Float32Array(state.cols * state.rows);
    state.walls = new Uint8Array(state.cols * state.rows);
    state.occ = new Int32Array(state.cols * state.rows);
    seedGrass();
    applyLayout(layout);
    addCritters(state.startSize);
    logEvent('Fresh gene pool started.');
    updateUi(true);
  }

  function logEvent(message) {
    el.eventLog.textContent = message;
  }

  function rebuildOccupancy() {
    state.occ.fill(-1);
    state.critters.forEach((critter, idx) => {
      if (critter.alive) state.occ[indexOf(critter.x, critter.y)] = idx;
    });
  }

  function updateSeason() {
    if (state.forcedWinter > 0) {
      state.forcedWinter -= 1;
      return;
    }
    state.seasonClock += 1;
    if (state.seasonClock >= state.seasonLength) {
      state.seasonClock = 0;
      state.season = state.season === 'Spring' ? 'Winter' : 'Spring';
      logEvent(state.season === 'Winter' ? 'Winter slowed the grass.' : 'Spring growth returned.');
    }
  }

  function growGrass() {
    const winter = seasonName() === 'Winter';
    const base = winter ? 0.0008 + (1 - state.pressure) * 0.002 : 0.010 + (1 - state.pressure) * 0.004;
    for (let i = 0; i < state.grass.length; i += 1) {
      if (state.walls[i]) continue;
      const current = state.grass[i];
      state.grass[i] = clamp(current + base * (1 - current) + rand() * 0.002);
    }
  }

  function death(critter, reason) {
    if (!critter.alive) return;
    critter.alive = false;
    state.deaths += 1;
    const i = indexOf(critter.x, critter.y);
    state.grass[i] = clamp(state.grass[i] + 0.22);
    if (reason === 'storm') return;
    if (state.deaths % 25 === 0) logEvent(`${state.deaths} critters lost; selection is tightening.`);
  }

  function candidateScore(critter, x, y) {
    if (x < 0 || y < 0 || x >= state.cols || y >= state.rows) return -999;
    const i = indexOf(x, y);
    if (state.walls[i]) return -999;
    const occupied = state.occ[i] >= 0 ? 1 : 0;
    const distance = Math.max(Math.abs(x - critter.x), Math.abs(y - critter.y));
    const genes = critter.genes;
    const grassScore = state.grass[i] * (1.1 + genes.appetite * 2.2);
    const crowdPenalty = occupied * (1.25 - genes.boldness * 0.85);
    const travelPenalty = distance * (0.035 + genes.thrift * 0.018);
    const noise = (rand() - 0.5) * genes.wander * 0.42;
    return grassScore - crowdPenalty - travelPenalty + noise;
  }

  function moveCritter(critter) {
    const genes = critter.genes;
    const sense = 1 + Math.floor(genes.sense * 4);
    let best = { x: critter.x, y: critter.y, score: candidateScore(critter, critter.x, critter.y) };
    for (let yy = critter.y - sense; yy <= critter.y + sense; yy += 1) {
      for (let xx = critter.x - sense; xx <= critter.x + sense; xx += 1) {
        const score = candidateScore(critter, xx, yy);
        if (score > best.score) best = { x: xx, y: yy, score };
      }
    }

    const steps = genes.speed > 0.68 && rand() < genes.speed ? 2 : 1;
    for (let s = 0; s < steps; s += 1) {
      const dx = Math.sign(best.x - critter.x);
      const dy = Math.sign(best.y - critter.y);
      const options = [
        { x: critter.x + dx, y: critter.y + dy },
        { x: critter.x + dx, y: critter.y },
        { x: critter.x, y: critter.y + dy },
        { x: critter.x + Math.sign(rand() - 0.5), y: critter.y + Math.sign(rand() - 0.5) },
      ];
      const next = options.find((cell) => {
        if (cell.x < 0 || cell.y < 0 || cell.x >= state.cols || cell.y >= state.rows) return false;
        const i = indexOf(cell.x, cell.y);
        return !state.walls[i] && state.occ[i] < 0;
      });
      if (!next) break;
      state.occ[indexOf(critter.x, critter.y)] = -1;
      critter.x = next.x;
      critter.y = next.y;
      state.occ[indexOf(critter.x, critter.y)] = state.critters.indexOf(critter);
    }
  }

  function feed(critter) {
    const i = indexOf(critter.x, critter.y);
    const bite = 0.045 + critter.genes.appetite * 0.15;
    const eaten = Math.min(state.grass[i], bite);
    state.grass[i] -= eaten;
    critter.energy = clamp(critter.energy + eaten * (0.86 + critter.genes.thrift * 0.55), 0, 1.6);
  }

  function nearbyPartner(critter) {
    const radius = 1 + Math.floor(critter.genes.sense * 2);
    let best = null;
    let bestScore = -1;
    for (let y = critter.y - radius; y <= critter.y + radius; y += 1) {
      for (let x = critter.x - radius; x <= critter.x + radius; x += 1) {
        if (x < 0 || y < 0 || x >= state.cols || y >= state.rows) continue;
        const otherIndex = state.occ[indexOf(x, y)];
        if (otherIndex < 0) continue;
        const other = state.critters[otherIndex];
        if (!other || other.id === critter.id || !other.alive || other.age < 18 || other.energy < 0.58) continue;
        const score = other.energy + other.genes.fertility * 0.3 - Math.abs(other.generation - critter.generation) * 0.01;
        if (score > bestScore) {
          best = other;
          bestScore = score;
        }
      }
    }
    return best;
  }

  function emptyNeighbor(critter) {
    const cells = [];
    for (let y = critter.y - 1; y <= critter.y + 1; y += 1) {
      for (let x = critter.x - 1; x <= critter.x + 1; x += 1) {
        if (x < 0 || y < 0 || x >= state.cols || y >= state.rows || (x === critter.x && y === critter.y)) continue;
        const i = indexOf(x, y);
        if (!state.walls[i] && state.occ[i] < 0) cells.push({ x, y, grass: state.grass[i] });
      }
    }
    cells.sort((a, b) => b.grass - a.grass);
    return cells[0] || null;
  }

  function reproduce(critter) {
    if (state.critters.length > 420 || critter.age < 22) return;
    const threshold = 0.88 - critter.genes.fertility * 0.28 + critter.genes.speed * 0.07;
    if (critter.energy < threshold) return;

    const mate = nearbyPartner(critter);
    const asexual = !mate && critter.energy > 1.18 && rand() < critter.genes.fertility * 0.035;
    if (!mate && !asexual) return;
    if (mate && rand() > 0.035 + critter.genes.fertility * 0.13 + mate.genes.fertility * 0.08) return;

    const cell = emptyNeighbor(critter);
    if (!cell) return;

    const family = state.families.get(critter.family) || newFamily();
    const genes = mate ? mixGenes(critter.genes, mate.genes) : mixGenes(critter.genes, critter.genes);
    const generation = Math.max(critter.generation, mate ? mate.generation : critter.generation) + 1;
    const baby = makeCritter(cell.x, cell.y, genes, family, generation);
    baby.energy = 0.32 + rand() * 0.18;
    state.critters.push(baby);
    state.occ[indexOf(cell.x, cell.y)] = state.critters.length - 1;
    state.births += 1;
    critter.energy *= 0.58;
    if (mate) mate.energy *= 0.72;
    if (generation % 6 === 0 && rand() < 0.2) logEvent(`${family.name} reached generation ${generation}.`);
  }

  function step() {
    state.tick += 1;
    updateSeason();
    growGrass();
    rebuildOccupancy();

    const order = Array.from({ length: state.critters.length }, (_, i) => i);
    for (let i = order.length - 1; i > 0; i -= 1) {
      const j = Math.floor(rand() * (i + 1));
      [order[i], order[j]] = [order[j], order[i]];
    }

    for (const idx of order) {
      const critter = state.critters[idx];
      if (!critter || !critter.alive) continue;
      state.occ[indexOf(critter.x, critter.y)] = -1;
      critter.age += 1;
      const winterCost = seasonName() === 'Winter' ? state.pressure * 0.0038 : 0;
      const cost = 0.0042 + critter.genes.speed * 0.0024 + critter.genes.appetite * 0.0018 + winterCost - critter.genes.thrift * 0.0027;
      critter.energy -= Math.max(0.0018, cost);
      if (critter.energy <= 0 || critter.age > critter.maxAge) {
        death(critter, 'attrition');
        continue;
      }
      state.occ[indexOf(critter.x, critter.y)] = idx;
      moveCritter(critter);
      feed(critter);
      reproduce(critter);
    }

    state.critters = state.critters.filter((critter) => critter.alive);
    if (state.critters.length < 8) {
      addCritters(18);
      logEvent('Population rescue seeded a new line.');
    }
  }

  function storm() {
    for (let i = 0; i < state.grass.length; i += 1) {
      state.grass[i] *= 0.28 + rand() * 0.18;
    }
    for (const critter of state.critters) {
      critter.energy -= 0.08 + state.pressure * 0.12 * rand();
      if (critter.energy <= 0 && rand() < 0.6) death(critter, 'storm');
    }
    state.critters = state.critters.filter((critter) => critter.alive);
    state.forcedWinter = Math.max(state.forcedWinter, 220);
    logEvent('Storm cut grass and exposed fragile lineages.');
  }

  function forceWinter() {
    state.forcedWinter = 420;
    logEvent('Winter pressure forced a survival test.');
  }

  function paintCell(x, y, tool = state.tool) {
    const radius = tool === 'grass' ? 2 : tool === 'erase' ? 1 : 0;
    for (let yy = y - radius; yy <= y + radius; yy += 1) {
      for (let xx = x - radius; xx <= x + radius; xx += 1) {
        if (xx < 0 || yy < 0 || xx >= state.cols || yy >= state.rows) continue;
        const i = indexOf(xx, yy);
        if (tool === 'grass') {
          if (!state.walls[i]) state.grass[i] = clamp(state.grass[i] + 0.42);
        } else if (tool === 'wall') {
          state.walls[i] = 1;
          state.grass[i] = 0;
        } else if (tool === 'erase') {
          state.walls[i] = 0;
          state.grass[i] = clamp(state.grass[i] + 0.12);
        }
      }
    }
    if (tool === 'add') {
      const i = indexOf(x, y);
      if (!state.walls[i]) {
        const family = newFamily();
        state.critters.push(makeCritter(x, y, freshGenes(), family, 1));
        logEvent(`${family.name} joined the garden.`);
      }
    }
  }

  function pointerToCell(event) {
    const rect = canvas.getBoundingClientRect();
    const x = clamp((event.clientX - rect.left) / rect.width);
    const y = clamp((event.clientY - rect.top) / rect.height);
    return {
      x: Math.floor(x * state.cols),
      y: Math.floor(y * state.rows),
    };
  }

  function computeStats() {
    const familyCounts = new Map();
    const avg = Object.fromEntries(geneDefs.map((def) => [def.key, 0]));
    let maxGeneration = 0;
    let grassTotal = 0;
    let dominant = null;

    for (const value of state.grass) grassTotal += value;
    for (const critter of state.critters) {
      maxGeneration = Math.max(maxGeneration, critter.generation);
      familyCounts.set(critter.family, (familyCounts.get(critter.family) || 0) + 1);
      for (const def of geneDefs) avg[def.key] += critter.genes[def.key];
    }

    const population = state.critters.length;
    if (population) {
      for (const def of geneDefs) avg[def.key] /= population;
    }

    for (const [id, count] of familyCounts) {
      const family = state.families.get(id);
      if (family) family.peak = Math.max(family.peak, count);
      if (!dominant || count > dominant.count) dominant = { family, count };
    }

    return {
      population,
      maxGeneration,
      families: familyCounts.size,
      grassAvg: grassTotal / state.grass.length,
      avg,
      familyCounts,
      dominant,
    };
  }

  function updateUi(force = false) {
    const now = performance.now();
    if (!force && now - state.lastUi < 180) return;
    state.lastUi = now;
    const stats = computeStats();
    state.stats = stats;

    el.runLine.textContent = `${seasonName()}, tick ${state.tick}`;
    el.population.textContent = String(stats.population);
    el.generation.textContent = String(stats.maxGeneration);
    el.families.textContent = String(stats.families);
    el.grass.textContent = `${Math.round(stats.grassAvg * 100)}%`;
    el.dominantLine.textContent = stats.dominant?.family ? `${stats.dominant.family.name} leads` : 'No line';
    el.birthDeath.textContent = `${state.births} born / ${state.deaths} lost`;
    el.toggleRun.textContent = state.running ? 'Pause' : 'Run';
    el.toggleRun.classList.toggle('active', state.running);
    el.toolReadout.textContent = `${state.tool[0].toUpperCase()}${state.tool.slice(1)} tool`;

    el.geneBars.innerHTML = geneDefs.map((def) => {
      const value = Math.round((stats.avg[def.key] || 0) * 100);
      return `<div class="gene-row"><span>${def.label}</span><div class="bar-track"><div class="bar-fill" style="width:${value}%"></div></div><span>${value}</span></div>`;
    }).join('');

    const rows = Array.from(stats.familyCounts.entries())
      .map(([id, count]) => ({ family: state.families.get(id), count }))
      .filter((row) => row.family)
      .sort((a, b) => b.count - a.count)
      .slice(0, 6);
    el.familyList.innerHTML = rows.length ? rows.map((row) => {
      const pct = stats.population ? Math.round((row.count / stats.population) * 100) : 0;
      return `<div class="family-item"><span class="family-swatch" style="background:hsl(${row.family.hue} 70% 58%)"></span><span>${row.family.name}</span><span>${row.count} / ${pct}%</span></div>`;
    }).join('') : '<div class="family-item"><span></span><span>No surviving line</span><span>0</span></div>';

    for (const button of document.querySelectorAll('[data-tool]')) {
      button.classList.toggle('active', button.dataset.tool === state.tool);
    }
  }

  function draw() {
    resizeCanvas();
    const w = canvas.width;
    const h = canvas.height;
    const cellW = w / state.cols;
    const cellH = h / state.rows;
    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = '#090b0c';
    ctx.fillRect(0, 0, w, h);

    const winter = seasonName() === 'Winter';
    for (let y = 0; y < state.rows; y += 1) {
      for (let x = 0; x < state.cols; x += 1) {
        const i = indexOf(x, y);
        if (state.walls[i]) {
          ctx.fillStyle = '#2b3034';
        } else {
          const g = state.grass[i];
          const r = Math.floor(mix(24, winter ? 88 : 58, g));
          const gg = Math.floor(mix(42, winter ? 104 : 176, g));
          const b = Math.floor(mix(33, winter ? 86 : 72, g));
          ctx.fillStyle = `rgb(${r},${gg},${b})`;
        }
        ctx.fillRect(Math.floor(x * cellW), Math.floor(y * cellH), Math.ceil(cellW + 0.5), Math.ceil(cellH + 0.5));
      }
    }

    ctx.strokeStyle = 'rgba(0,0,0,0.16)';
    ctx.lineWidth = 1;
    for (let x = 0; x <= state.cols; x += 6) {
      const px = Math.floor(x * cellW);
      ctx.beginPath();
      ctx.moveTo(px, 0);
      ctx.lineTo(px, h);
      ctx.stroke();
    }
    for (let y = 0; y <= state.rows; y += 6) {
      const py = Math.floor(y * cellH);
      ctx.beginPath();
      ctx.moveTo(0, py);
      ctx.lineTo(w, py);
      ctx.stroke();
    }

    const topFamily = state.stats?.dominant?.family?.id;
    for (const critter of state.critters) {
      const family = state.families.get(critter.family);
      const cx = (critter.x + 0.5) * cellW;
      const cy = (critter.y + 0.5) * cellH;
      const ageScale = clamp(critter.age / 90, 0.42, 1);
      const radius = Math.max(2.2, Math.min(cellW, cellH) * (0.2 + ageScale * 0.22 + critter.energy * 0.07));
      ctx.beginPath();
      ctx.arc(cx, cy, radius, 0, Math.PI * 2);
      ctx.fillStyle = `hsl(${family ? family.hue : 180} 72% ${critter.family === topFamily ? 62 : 54}%)`;
      ctx.fill();
      ctx.lineWidth = critter.family === topFamily ? 2 : 1;
      ctx.strokeStyle = 'rgba(255,255,255,0.7)';
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(cx, cy, radius + 2, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * clamp(critter.energy / 1.4));
      ctx.strokeStyle = 'rgba(255,241,174,0.85)';
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }
  }

  function frame(time) {
    if (state.running) {
      state.frameCarry += state.speed;
      const steps = Math.min(24, Math.floor(state.frameCarry));
      state.frameCarry -= steps;
      for (let i = 0; i < steps; i += 1) step();
    }
    updateUi(false);
    draw();
    requestAnimationFrame(frame);
  }

  function setTool(tool) {
    state.tool = tool;
    updateUi(true);
  }

  function initEvents() {
    el.toggleRun.addEventListener('click', () => {
      state.running = !state.running;
      updateUi(true);
    });

    for (const button of document.querySelectorAll('[data-tool]')) {
      button.addEventListener('click', () => setTool(button.dataset.tool));
    }

    for (const button of document.querySelectorAll('[data-action]')) {
      button.addEventListener('click', () => {
        const action = button.dataset.action;
        if (action === 'reset') reset(state.layout);
        if (action === 'storm') storm();
        if (action === 'meadow') reset('meadow');
        if (action === 'paddocks') reset('paddocks');
        if (action === 'corridor') reset('corridor');
        if (action === 'winter') forceWinter();
      });
    }

    el.speed.addEventListener('input', () => { state.speed = Number(el.speed.value); });
    el.mutation.addEventListener('input', () => { state.mutation = Number(el.mutation.value) / 100; });
    el.pressure.addEventListener('input', () => { state.pressure = Number(el.pressure.value) / 100; });
    el.startSize.addEventListener('input', () => { state.startSize = Number(el.startSize.value); });

    let dragging = false;
    const paint = (event) => {
      const cell = pointerToCell(event);
      paintCell(cell.x, cell.y);
      updateUi(true);
    };
    canvas.addEventListener('pointerdown', (event) => {
      canvas.setPointerCapture(event.pointerId);
      dragging = true;
      paint(event);
    });
    canvas.addEventListener('pointermove', (event) => {
      if (dragging) paint(event);
    });
    canvas.addEventListener('pointerup', () => { dragging = false; });
    canvas.addEventListener('pointercancel', () => { dragging = false; });

    window.addEventListener('keydown', (event) => {
      if (event.target && ['INPUT', 'SELECT', 'TEXTAREA'].includes(event.target.tagName)) return;
      if (event.code === 'Space') {
        event.preventDefault();
        state.running = !state.running;
      } else if (event.key === '1') setTool('grass');
      else if (event.key === '2') setTool('wall');
      else if (event.key === '3') setTool('erase');
      else if (event.key === '4') setTool('add');
      else if (event.key.toLowerCase() === 'r') reset(state.layout);
      else if (event.key.toLowerCase() === 's') storm();
      updateUi(true);
    });

    window.addEventListener('resize', resizeCanvas);
  }

  function fastForward(ticks = 600) {
    const count = Math.max(1, Math.min(5000, Number(ticks) || 600));
    for (let i = 0; i < count; i += 1) step();
    updateUi(true);
    draw();
  }

  window.__lanArcadeGame = {
    setTool,
    clickCell(x, y) {
      paintCell(Math.floor(clamp(Number(x) || 0, 0, state.cols - 1)), Math.floor(clamp(Number(y) || 0, 0, state.rows - 1)));
      updateUi(true);
    },
    run() {
      state.running = true;
      updateUi(true);
    },
    pause() {
      state.running = false;
      updateUi(true);
    },
    reset(layout = state.layout) {
      reset(layout);
    },
    storm,
    winter: forceWinter,
    addCritters(count = 12) {
      addCritters(Number(count) || 12);
      updateUi(true);
    },
    fastForward,
    getStats() {
      return computeStats();
    },
  };

  initEvents();
  reset('meadow');
  requestAnimationFrame(frame);
})();
