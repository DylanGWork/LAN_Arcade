(() => {
  'use strict';

  const COLS = 16;
  const ROWS = 10;
  const SAVE_KEY = 'lanArcade.outpostSiege.save.v1';
  const BEST_KEY = 'lanArcade.outpostSiege.bestWave.v1';

  const TOWER_TYPES = {
    cannon: {
      label: 'Cannon',
      cost: 55,
      color: '#f5bd49',
      damageType: 'kinetic',
      damage: 30,
      cooldown: 0.78,
      range: 3.15,
      icon: 'C',
    },
    laser: {
      label: 'Laser',
      cost: 80,
      color: '#5ec8f2',
      damageType: 'energy',
      damage: 13,
      cooldown: 0.22,
      range: 3.75,
      icon: 'L',
    },
    frost: {
      label: 'Frost',
      cost: 70,
      color: '#b892ff',
      damageType: 'frost',
      damage: 10,
      cooldown: 0.95,
      range: 3.05,
      slow: 0.52,
      slowTime: 1.65,
      icon: 'F',
    },
    mine: {
      label: 'Mine',
      cost: 35,
      color: '#ef6b73',
      damageType: 'blast',
      damage: 62,
      cooldown: 2.6,
      range: 1.05,
      trap: true,
      splash: 1.15,
      icon: 'M',
    },
  };

  const ENEMY_TYPES = {
    scout: {
      label: 'Scout',
      color: '#58cf8f',
      hp: 48,
      speed: 1.2,
      armor: 0,
      resist: 0,
      bounty: 7,
      radius: 0.22,
    },
    bruiser: {
      label: 'Bruiser',
      color: '#f5bd49',
      hp: 120,
      speed: 0.72,
      armor: 8,
      resist: 0.08,
      bounty: 13,
      radius: 0.28,
    },
    wraith: {
      label: 'Wraith',
      color: '#5ec8f2',
      hp: 74,
      speed: 1.02,
      armor: 1,
      resist: 0.34,
      bounty: 10,
      radius: 0.24,
    },
    boss: {
      label: 'Siege Engine',
      color: '#ef6b73',
      hp: 430,
      speed: 0.55,
      armor: 13,
      resist: 0.18,
      bounty: 55,
      radius: 0.42,
    },
  };

  const WAYPOINTS = [
    [-0.6, 4.5],
    [3.5, 4.5],
    [3.5, 2.5],
    [6.5, 2.5],
    [6.5, 6.5],
    [10.5, 6.5],
    [10.5, 3.5],
    [13.5, 3.5],
    [13.5, 5.5],
    [16.6, 5.5],
  ];

  const PATH_CELLS = new Set();
  addPathCells(0, 4, 3, 4);
  addPathCells(3, 2, 3, 4);
  addPathCells(3, 2, 6, 2);
  addPathCells(6, 2, 6, 6);
  addPathCells(6, 6, 10, 6);
  addPathCells(10, 3, 10, 6);
  addPathCells(10, 3, 13, 3);
  addPathCells(13, 3, 13, 5);
  addPathCells(13, 5, 15, 5);

  const PATH = buildPathMetrics();
  const canvas = document.getElementById('gameCanvas');
  const ctx = canvas.getContext('2d');
  const toast = document.getElementById('toast');
  const ui = {
    integrity: document.getElementById('integrityValue'),
    scrap: document.getElementById('scrapValue'),
    wave: document.getElementById('waveValue'),
    selectedLabel: document.getElementById('selectedLabel'),
    selectedTowerLabel: document.getElementById('selectedTowerLabel'),
    selectedTowerDetails: document.getElementById('selectedTowerDetails'),
    towerButtons: document.getElementById('towerButtons'),
    upgradeButton: document.getElementById('upgradeButton'),
    waveButton: document.getElementById('waveButton'),
    pauseButton: document.getElementById('pauseButton'),
    speedButton: document.getElementById('speedButton'),
    resetButton: document.getElementById('resetButton'),
    kills: document.getElementById('killsValue'),
    leaks: document.getElementById('leaksValue'),
    bestWave: document.getElementById('bestWaveValue'),
  };

  let layout = {
    width: 1280,
    height: 800,
    tile: 64,
    boardWidth: 1024,
    boardHeight: 640,
    offsetX: 64,
    offsetY: 64,
  };
  let toastTimer = 0;
  let lastFrame = performance.now();
  let state = loadGame();

  createTowerButtons();
  bindEvents();
  resizeCanvas();
  updateUi();
  requestAnimationFrame(frame);

  function defaultState() {
    return {
      resources: 175,
      integrity: 20,
      wave: 0,
      towers: [],
      enemies: [],
      bullets: [],
      effects: [],
      spawnQueue: [],
      spawnTimer: 0,
      spawnInterval: 0.9,
      selectedType: 'cannon',
      selectedTowerId: null,
      inWave: false,
      paused: false,
      speed: 1,
      kills: 0,
      leaks: 0,
      bestWave: Number.parseInt(localStorage.getItem(BEST_KEY) || '0', 10) || 0,
      nextTowerId: 1,
      nextEnemyId: 1,
      nextEffectId: 1,
    };
  }

  function loadGame() {
    const fresh = defaultState();
    try {
      const saved = JSON.parse(localStorage.getItem(SAVE_KEY) || 'null');
      if (!saved || !Array.isArray(saved.towers)) return fresh;
      const restored = {
        ...fresh,
        resources: clampNumber(saved.resources, 0, 99999, fresh.resources),
        integrity: clampNumber(saved.integrity, 0, 99, fresh.integrity),
        wave: clampNumber(saved.wave, 0, 999, fresh.wave),
        kills: clampNumber(saved.kills, 0, 99999, fresh.kills),
        leaks: clampNumber(saved.leaks, 0, 999, fresh.leaks),
        bestWave: Math.max(fresh.bestWave, clampNumber(saved.bestWave, 0, 999, fresh.bestWave)),
        selectedType: TOWER_TYPES[saved.selectedType] ? saved.selectedType : fresh.selectedType,
        towers: saved.towers
          .filter((tower) => TOWER_TYPES[tower.type])
          .map((tower, index) => ({
            id: Number.isFinite(tower.id) ? tower.id : index + 1,
            type: tower.type,
            x: clampNumber(tower.x, 0, COLS - 1, 0),
            y: clampNumber(tower.y, 0, ROWS - 1, 0),
            level: clampNumber(tower.level, 1, 6, 1),
            cooldown: 0,
          })),
      };
      restored.nextTowerId = restored.towers.reduce((max, tower) => Math.max(max, tower.id + 1), 1);
      return restored;
    } catch {
      return fresh;
    }
  }

  function saveGame() {
    const payload = {
      resources: state.resources,
      integrity: state.integrity,
      wave: state.wave,
      kills: state.kills,
      leaks: state.leaks,
      bestWave: state.bestWave,
      selectedType: state.selectedType,
      towers: state.towers.map((tower) => ({
        id: tower.id,
        type: tower.type,
        x: tower.x,
        y: tower.y,
        level: tower.level,
      })),
    };
    localStorage.setItem(SAVE_KEY, JSON.stringify(payload));
    localStorage.setItem(BEST_KEY, String(state.bestWave));
  }

  function createTowerButtons() {
    ui.towerButtons.innerHTML = '';
    Object.entries(TOWER_TYPES).forEach(([id, tower]) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'tower-button';
      button.dataset.tower = id;

      const icon = document.createElement('span');
      icon.className = 'tower-icon';
      icon.textContent = tower.icon;
      icon.style.background = tower.color;
      icon.style.color = '#10131a';

      const name = document.createElement('span');
      name.className = 'tower-name';
      name.textContent = tower.label;

      const cost = document.createElement('span');
      cost.className = 'tower-cost';
      cost.textContent = `${tower.cost} scrap`;

      button.append(icon, name, cost);
      button.addEventListener('click', () => {
        state.selectedType = id;
        state.selectedTowerId = null;
        updateUi();
      });
      ui.towerButtons.append(button);
    });
  }

  function bindEvents() {
    window.addEventListener('resize', resizeCanvas);
    canvas.addEventListener('pointerdown', handleCanvasPointer);

    ui.waveButton.addEventListener('click', () => {
      if (state.integrity <= 0) {
        resetGame();
      } else {
        startWave();
      }
    });
    ui.pauseButton.addEventListener('click', () => {
      state.paused = !state.paused;
      updateUi();
    });
    ui.speedButton.addEventListener('click', () => {
      state.speed = state.speed === 1 ? 2 : state.speed === 2 ? 3 : 1;
      updateUi();
    });
    ui.resetButton.addEventListener('click', resetGame);
    ui.upgradeButton.addEventListener('click', upgradeSelectedTower);

    window.addEventListener('keydown', (event) => {
      if (event.key === ' ') {
        event.preventDefault();
        if (state.inWave) state.paused = !state.paused;
        else startWave();
        updateUi();
      }
      const towerIds = Object.keys(TOWER_TYPES);
      const index = Number.parseInt(event.key, 10) - 1;
      if (towerIds[index]) {
        state.selectedType = towerIds[index];
        state.selectedTowerId = null;
        updateUi();
      }
    });
  }

  function resizeCanvas() {
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.max(1, Math.floor(rect.width * dpr));
    canvas.height = Math.max(1, Math.floor(rect.height * dpr));
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    layout.width = rect.width;
    layout.height = rect.height;
    layout.tile = Math.max(26, Math.min(rect.width / (COLS + 1.2), rect.height / (ROWS + 1.2)));
    layout.boardWidth = layout.tile * COLS;
    layout.boardHeight = layout.tile * ROWS;
    layout.offsetX = (rect.width - layout.boardWidth) / 2;
    layout.offsetY = (rect.height - layout.boardHeight) / 2;
  }

  function handleCanvasPointer(event) {
    event.preventDefault();
    if (state.integrity <= 0) return;
    const cell = cellFromPointer(event);
    if (!cell) return;

    const existing = towerAt(cell.x, cell.y);
    if (existing) {
      state.selectedTowerId = existing.id;
      state.selectedType = existing.type;
      updateUi();
      return;
    }

    placeTower(cell.x, cell.y);
  }

  function placeTower(x, y) {
    const type = TOWER_TYPES[state.selectedType];
    if (!type) return;
    if (state.resources < type.cost) {
      showToast('Scrap reserve too low.');
      return;
    }
    if (type.trap) {
      if (!isPathCell(x, y)) {
        showToast('Mines arm on the road only.');
        return;
      }
    } else if (isPathCell(x, y)) {
      showToast('Open ground required.');
      return;
    }
    if (state.towers.some((tower) => tower.x === x && tower.y === y)) return;

    state.resources -= type.cost;
    const tower = {
      id: state.nextTowerId,
      type: state.selectedType,
      x,
      y,
      level: 1,
      cooldown: 0,
    };
    state.nextTowerId += 1;
    state.towers.push(tower);
    state.selectedTowerId = tower.id;
    showToast(`${type.label} online.`);
    saveGame();
    updateUi();
  }

  function upgradeSelectedTower() {
    const tower = selectedTower();
    if (!tower) {
      showToast('No tower selected.');
      return;
    }
    const cost = towerUpgradeCost(tower);
    if (state.resources < cost) {
      showToast('Scrap reserve too low.');
      return;
    }
    if (tower.level >= 6) {
      showToast('Tower is at peak output.');
      return;
    }
    tower.level += 1;
    state.resources -= cost;
    tower.cooldown = Math.min(tower.cooldown, towerStats(tower).cooldown);
    showToast(`${TOWER_TYPES[tower.type].label} upgraded.`);
    saveGame();
    updateUi();
  }

  function resetGame() {
    const bestWave = Math.max(state.bestWave, state.wave);
    state = defaultState();
    state.bestWave = bestWave;
    localStorage.setItem(BEST_KEY, String(bestWave));
    localStorage.removeItem(SAVE_KEY);
    showToast('Run reset.');
    updateUi();
  }

  function startWave() {
    if (state.inWave || state.integrity <= 0) return;
    state.wave += 1;
    state.bestWave = Math.max(state.bestWave, state.wave);
    state.inWave = true;
    state.paused = false;
    state.spawnQueue = buildWave(state.wave);
    state.spawnTimer = 0;
    state.spawnInterval = Math.max(0.42, 0.92 - state.wave * 0.025);
    showToast(`Wave ${state.wave} inbound.`);
    saveGame();
    updateUi();
  }

  function buildWave(wave) {
    const queue = [];
    const count = 7 + Math.floor(wave * 1.8);
    for (let i = 0; i < count; i += 1) {
      let type = 'scout';
      if (wave >= 3 && i % 6 === 2) type = 'bruiser';
      if (wave >= 4 && i % 5 === 3) type = 'wraith';
      queue.push(type);
    }
    if (wave % 5 === 0) queue.push('boss');
    return queue;
  }

  function frame(now) {
    const dt = Math.min(0.05, (now - lastFrame) / 1000);
    lastFrame = now;

    if (!state.paused && state.integrity > 0) {
      updateGame(dt * state.speed);
    }
    updateToast(dt);
    draw();
    requestAnimationFrame(frame);
  }

  function updateGame(dt) {
    spawnEnemies(dt);
    updateEnemies(dt);
    updateTowers(dt);
    updateBullets(dt);
    updateEffects(dt);
    cleanupEntities();
    checkWaveComplete();
  }

  function spawnEnemies(dt) {
    if (!state.inWave) return;
    state.spawnTimer -= dt;
    while (state.spawnQueue.length > 0 && state.spawnTimer <= 0) {
      spawnEnemy(state.spawnQueue.shift());
      state.spawnTimer += state.spawnInterval;
    }
  }

  function spawnEnemy(type) {
    const template = ENEMY_TYPES[type] || ENEMY_TYPES.scout;
    const hpScale = 1 + state.wave * 0.17 + (type === 'boss' ? state.wave * 0.06 : 0);
    const speedScale = 1 + Math.min(0.32, state.wave * 0.012);
    state.enemies.push({
      id: state.nextEnemyId,
      type,
      distance: 0,
      hp: Math.round(template.hp * hpScale),
      maxHp: Math.round(template.hp * hpScale),
      speed: template.speed * speedScale,
      armor: template.armor + Math.floor(state.wave / 5),
      resist: Math.min(0.58, template.resist + state.wave * 0.008),
      bounty: template.bounty + Math.floor(state.wave * 1.5),
      slowFactor: 1,
      slowTimer: 0,
      dead: false,
    });
    state.nextEnemyId += 1;
  }

  function updateEnemies(dt) {
    state.enemies.forEach((enemy) => {
      if (enemy.dead) return;
      if (enemy.slowTimer > 0) {
        enemy.slowTimer -= dt;
      } else {
        enemy.slowFactor = 1;
      }
      enemy.distance += enemy.speed * enemy.slowFactor * dt;
      if (enemy.distance >= PATH.totalLength) {
        enemy.dead = true;
        state.integrity = Math.max(0, state.integrity - (enemy.type === 'boss' ? 4 : 1));
        state.leaks += 1;
        addEffect(pointAtDistance(PATH.totalLength - 0.01), '#ef6b73', 0.7, 0.5);
        if (state.integrity <= 0) {
          state.inWave = false;
          state.spawnQueue = [];
          showToast('Outpost lost.');
        }
        saveGame();
        updateUi();
      }
    });
  }

  function updateTowers(dt) {
    state.towers.forEach((tower) => {
      const stats = towerStats(tower);
      tower.cooldown = Math.max(0, tower.cooldown - dt);
      if (tower.cooldown > 0) return;

      if (stats.trap) {
        const center = { x: tower.x + 0.5, y: tower.y + 0.5 };
        const target = findTarget(center, stats.range);
        if (!target) return;
        state.enemies.forEach((enemy) => {
          if (enemy.dead) return;
          const pos = pointAtDistance(enemy.distance);
          if (distance(center, pos) <= stats.splash) {
            damageEnemy(enemy, stats.damage, stats.damageType);
          }
        });
        addEffect(center, stats.color, stats.splash, 0.38);
        tower.cooldown = stats.cooldown;
        return;
      }

      const center = { x: tower.x + 0.5, y: tower.y + 0.5 };
      const target = findTarget(center, stats.range);
      if (!target) return;

      if (stats.slow) {
        target.slowFactor = Math.min(target.slowFactor, stats.slow);
        target.slowTimer = Math.max(target.slowTimer, stats.slowTime);
      }
      damageEnemy(target, stats.damage, stats.damageType);
      const targetPos = pointAtDistance(target.distance);
      state.bullets.push({
        x: center.x,
        y: center.y,
        tx: targetPos.x,
        ty: targetPos.y,
        color: stats.color,
        type: tower.type,
        life: tower.type === 'laser' ? 0.1 : 0.22,
        maxLife: tower.type === 'laser' ? 0.1 : 0.22,
      });
      if (tower.type === 'frost') addEffect(targetPos, stats.color, 0.55, 0.22);
      tower.cooldown = stats.cooldown;
    });
  }

  function damageEnemy(enemy, rawDamage, damageType) {
    if (enemy.dead) return;
    let amount = rawDamage;
    if (damageType === 'kinetic') amount = Math.max(2, rawDamage - enemy.armor);
    if (damageType === 'energy') amount = rawDamage * (1 - enemy.resist);
    if (damageType === 'frost') amount = Math.max(1, rawDamage - enemy.armor * 0.35);
    if (damageType === 'blast') amount = Math.max(4, rawDamage - enemy.armor * 0.55);

    enemy.hp -= amount;
    if (enemy.hp <= 0) {
      enemy.dead = true;
      state.kills += 1;
      state.resources += enemy.bounty;
      addEffect(pointAtDistance(enemy.distance), ENEMY_TYPES[enemy.type].color, 0.62, 0.28);
      saveGame();
      updateUi();
    }
  }

  function updateBullets(dt) {
    state.bullets.forEach((bullet) => {
      bullet.life -= dt;
    });
  }

  function updateEffects(dt) {
    state.effects.forEach((effect) => {
      effect.life -= dt;
    });
  }

  function cleanupEntities() {
    state.enemies = state.enemies.filter((enemy) => !enemy.dead);
    state.bullets = state.bullets.filter((bullet) => bullet.life > 0);
    state.effects = state.effects.filter((effect) => effect.life > 0);
  }

  function checkWaveComplete() {
    if (!state.inWave) return;
    if (state.spawnQueue.length > 0 || state.enemies.length > 0) return;
    state.inWave = false;
    const bonus = 24 + state.wave * 8;
    state.resources += bonus;
    showToast(`Wave ${state.wave} secured.`);
    saveGame();
    updateUi();
  }

  function findTarget(origin, range) {
    let best = null;
    state.enemies.forEach((enemy) => {
      if (enemy.dead) return;
      const pos = pointAtDistance(enemy.distance);
      if (distance(origin, pos) > range) return;
      if (!best || enemy.distance > best.distance) best = enemy;
    });
    return best;
  }

  function towerStats(tower) {
    const base = TOWER_TYPES[tower.type];
    const levelBoost = tower.level - 1;
    return {
      ...base,
      damage: base.damage * (1 + levelBoost * 0.42),
      cooldown: base.cooldown * Math.pow(0.88, levelBoost),
      range: base.range + levelBoost * 0.17,
      splash: (base.splash || 0) + levelBoost * 0.08,
      slow: base.slow ? Math.max(0.32, base.slow - levelBoost * 0.025) : null,
      slowTime: base.slowTime ? base.slowTime + levelBoost * 0.18 : 0,
    };
  }

  function towerUpgradeCost(tower) {
    const base = TOWER_TYPES[tower.type];
    return Math.round(base.cost * (0.7 + tower.level * 0.58));
  }

  function draw() {
    ctx.clearRect(0, 0, layout.width, layout.height);
    drawBackdrop();
    drawGrid();
    drawPath();
    drawTowers();
    drawEnemies();
    drawBullets();
    drawEffects();
    drawSelection();
    drawOverlay();
  }

  function drawBackdrop() {
    const gradient = ctx.createLinearGradient(0, 0, layout.width, layout.height);
    gradient.addColorStop(0, '#101722');
    gradient.addColorStop(0.52, '#0d1119');
    gradient.addColorStop(1, '#18131d');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, layout.width, layout.height);

    ctx.fillStyle = 'rgba(94, 200, 242, 0.08)';
    for (let i = 0; i < 24; i += 1) {
      const x = (i * 97) % Math.max(1, layout.width);
      const y = (i * 53) % Math.max(1, layout.height);
      ctx.fillRect(x, y, 2, 2);
    }
  }

  function drawGrid() {
    ctx.save();
    ctx.translate(layout.offsetX, layout.offsetY);
    ctx.fillStyle = 'rgba(13, 18, 26, 0.9)';
    ctx.fillRect(0, 0, layout.boardWidth, layout.boardHeight);

    for (let y = 0; y < ROWS; y += 1) {
      for (let x = 0; x < COLS; x += 1) {
        const pathCell = isPathCell(x, y);
        ctx.fillStyle = pathCell ? 'rgba(245, 189, 73, 0.05)' : ((x + y) % 2 ? 'rgba(255,255,255,0.025)' : 'rgba(255,255,255,0.045)');
        ctx.fillRect(x * layout.tile, y * layout.tile, layout.tile, layout.tile);
      }
    }

    ctx.strokeStyle = 'rgba(174, 184, 200, 0.1)';
    ctx.lineWidth = 1;
    for (let x = 0; x <= COLS; x += 1) {
      ctx.beginPath();
      ctx.moveTo(x * layout.tile, 0);
      ctx.lineTo(x * layout.tile, layout.boardHeight);
      ctx.stroke();
    }
    for (let y = 0; y <= ROWS; y += 1) {
      ctx.beginPath();
      ctx.moveTo(0, y * layout.tile);
      ctx.lineTo(layout.boardWidth, y * layout.tile);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawPath() {
    ctx.save();
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    const points = WAYPOINTS.map(toScreen);

    ctx.strokeStyle = 'rgba(12, 11, 12, 0.88)';
    ctx.lineWidth = layout.tile * 0.78;
    drawPolyline(points);

    ctx.strokeStyle = 'rgba(126, 96, 56, 0.94)';
    ctx.lineWidth = layout.tile * 0.58;
    drawPolyline(points);

    ctx.strokeStyle = 'rgba(245, 189, 73, 0.28)';
    ctx.setLineDash([layout.tile * 0.3, layout.tile * 0.24]);
    ctx.lineWidth = Math.max(2, layout.tile * 0.06);
    drawPolyline(points);
    ctx.setLineDash([]);

    drawEndpoint(-0.2, 4.5, '#5ec8f2', 'G');
    drawEndpoint(15.7, 5.5, '#ef6b73', 'R');
    ctx.restore();
  }

  function drawEndpoint(x, y, color, label) {
    const p = toScreen([x, y]);
    ctx.fillStyle = '#11131a';
    ctx.strokeStyle = color;
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(p.x, p.y, layout.tile * 0.32, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = color;
    ctx.font = `800 ${Math.max(12, layout.tile * 0.22)}px system-ui`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(label, p.x, p.y);
  }

  function drawTowers() {
    state.towers.forEach((tower) => {
      const type = TOWER_TYPES[tower.type];
      const center = toScreen([tower.x + 0.5, tower.y + 0.5]);
      const size = layout.tile * (type.trap ? 0.27 : 0.34);
      ctx.save();
      ctx.fillStyle = type.color;
      ctx.strokeStyle = '#0f131b';
      ctx.lineWidth = 3;
      if (type.trap) {
        ctx.beginPath();
        for (let i = 0; i < 6; i += 1) {
          const a = -Math.PI / 2 + i * Math.PI / 3;
          const px = center.x + Math.cos(a) * size;
          const py = center.y + Math.sin(a) * size;
          if (i === 0) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        ctx.closePath();
      } else {
        ctx.beginPath();
        ctx.arc(center.x, center.y, size, 0, Math.PI * 2);
      }
      ctx.fill();
      ctx.stroke();

      ctx.fillStyle = '#11131a';
      ctx.font = `900 ${Math.max(11, layout.tile * 0.22)}px system-ui`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(type.icon, center.x, center.y);

      ctx.fillStyle = '#f4f7fb';
      for (let i = 0; i < tower.level; i += 1) {
        ctx.beginPath();
        ctx.arc(center.x - (tower.level - 1) * 3 + i * 6, center.y + size + 8, 2.1, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    });
  }

  function drawEnemies() {
    state.enemies.forEach((enemy) => {
      const template = ENEMY_TYPES[enemy.type];
      const p = toScreen(pointAtDistance(enemy.distance));
      const r = layout.tile * template.radius;
      ctx.save();
      ctx.fillStyle = template.color;
      ctx.strokeStyle = enemy.slowTimer > 0 ? '#d9ecff' : '#11131a';
      ctx.lineWidth = enemy.type === 'boss' ? 4 : 2.5;
      ctx.beginPath();
      ctx.arc(p.x, p.y, r, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();

      if (enemy.armor > 0) {
        ctx.strokeStyle = 'rgba(244, 247, 251, 0.52)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(p.x, p.y, r + 4, -Math.PI * 0.9, Math.PI * 0.4);
        ctx.stroke();
      }

      const barWidth = layout.tile * 0.74;
      const barHeight = 5;
      const pct = Math.max(0, enemy.hp / enemy.maxHp);
      ctx.fillStyle = 'rgba(8, 10, 14, 0.8)';
      ctx.fillRect(p.x - barWidth / 2, p.y - r - 12, barWidth, barHeight);
      ctx.fillStyle = pct > 0.45 ? '#58cf8f' : pct > 0.2 ? '#f5bd49' : '#ef6b73';
      ctx.fillRect(p.x - barWidth / 2, p.y - r - 12, barWidth * pct, barHeight);
      ctx.restore();
    });
  }

  function drawBullets() {
    state.bullets.forEach((bullet) => {
      const start = toScreen([bullet.x, bullet.y]);
      const end = toScreen([bullet.tx, bullet.ty]);
      const pct = 1 - bullet.life / bullet.maxLife;
      const x = start.x + (end.x - start.x) * pct;
      const y = start.y + (end.y - start.y) * pct;
      ctx.save();
      ctx.strokeStyle = bullet.color;
      ctx.fillStyle = bullet.color;
      if (bullet.type === 'laser') {
        ctx.globalAlpha = Math.max(0, bullet.life / bullet.maxLife);
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.moveTo(start.x, start.y);
        ctx.lineTo(end.x, end.y);
        ctx.stroke();
      } else {
        ctx.beginPath();
        ctx.arc(x, y, Math.max(3, layout.tile * 0.08), 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    });
  }

  function drawEffects() {
    state.effects.forEach((effect) => {
      const p = toScreen([effect.x, effect.y]);
      const pct = 1 - effect.life / effect.maxLife;
      ctx.save();
      ctx.globalAlpha = Math.max(0, 1 - pct);
      ctx.strokeStyle = effect.color;
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(p.x, p.y, layout.tile * effect.radius * (0.35 + pct), 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    });
  }

  function drawSelection() {
    const tower = selectedTower();
    if (tower) {
      const stats = towerStats(tower);
      const center = toScreen([tower.x + 0.5, tower.y + 0.5]);
      ctx.save();
      ctx.strokeStyle = 'rgba(94, 200, 242, 0.48)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(center.x, center.y, stats.range * layout.tile, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
      return;
    }

    const selected = TOWER_TYPES[state.selectedType];
    if (!selected) return;
    ctx.save();
    ctx.fillStyle = selected.trap ? 'rgba(239, 107, 115, 0.08)' : 'rgba(94, 200, 242, 0.06)';
    for (let y = 0; y < ROWS; y += 1) {
      for (let x = 0; x < COLS; x += 1) {
        if (selected.trap !== isPathCell(x, y)) continue;
        if (towerAt(x, y)) continue;
        ctx.fillRect(layout.offsetX + x * layout.tile + 2, layout.offsetY + y * layout.tile + 2, layout.tile - 4, layout.tile - 4);
      }
    }
    ctx.restore();
  }

  function drawOverlay() {
    if (!state.paused && state.integrity > 0) return;
    ctx.save();
    ctx.fillStyle = 'rgba(9, 11, 16, 0.58)';
    ctx.fillRect(0, 0, layout.width, layout.height);
    ctx.fillStyle = state.integrity <= 0 ? '#ef6b73' : '#f4f7fb';
    ctx.font = `900 ${Math.max(26, layout.tile * 0.58)}px system-ui`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(state.integrity <= 0 ? 'Outpost Lost' : 'Paused', layout.width / 2, layout.height / 2);
    ctx.restore();
  }

  function drawPolyline(points) {
    ctx.beginPath();
    points.forEach((point, index) => {
      if (index === 0) ctx.moveTo(point.x, point.y);
      else ctx.lineTo(point.x, point.y);
    });
    ctx.stroke();
  }

  function updateUi() {
    ui.integrity.textContent = String(state.integrity);
    ui.scrap.textContent = String(Math.floor(state.resources));
    ui.wave.textContent = String(state.wave);
    ui.kills.textContent = String(state.kills);
    ui.leaks.textContent = String(state.leaks);
    ui.bestWave.textContent = String(Math.max(state.bestWave, state.wave));
    ui.selectedLabel.textContent = TOWER_TYPES[state.selectedType]?.label || 'None';
    ui.pauseButton.textContent = state.paused ? 'Resume' : 'Pause';
    ui.speedButton.textContent = `${state.speed}x`;
    ui.waveButton.textContent = state.integrity <= 0 ? 'Restart Outpost' : state.inWave ? `Wave ${state.wave} Active` : state.wave === 0 ? 'Start Mission' : 'Next Wave';
    ui.waveButton.disabled = state.inWave && state.integrity > 0;

    Array.from(ui.towerButtons.querySelectorAll('button')).forEach((button) => {
      const selected = button.dataset.tower === state.selectedType && !state.selectedTowerId;
      button.classList.toggle('is-selected', selected);
    });

    const tower = selectedTower();
    if (!tower) {
      ui.selectedTowerLabel.textContent = 'None';
      ui.selectedTowerDetails.textContent = 'No tower selected.';
      ui.upgradeButton.disabled = true;
      return;
    }

    const type = TOWER_TYPES[tower.type];
    const stats = towerStats(tower);
    const cost = towerUpgradeCost(tower);
    ui.selectedTowerLabel.textContent = `${type.label} L${tower.level}`;
    ui.selectedTowerDetails.textContent = `Damage ${Math.round(stats.damage)} | Range ${stats.range.toFixed(1)} | Upgrade ${cost}`;
    ui.upgradeButton.disabled = tower.level >= 6 || state.resources < cost;
  }

  function updateToast(dt) {
    if (toastTimer <= 0) return;
    toastTimer -= dt;
    if (toastTimer <= 0) {
      toast.classList.remove('is-visible');
    }
  }

  function showToast(message) {
    toast.textContent = message;
    toast.classList.add('is-visible');
    toastTimer = 2.2;
  }

  function addEffect(point, color, radius, life) {
    state.effects.push({
      id: state.nextEffectId,
      x: point.x,
      y: point.y,
      color,
      radius,
      life,
      maxLife: life,
    });
    state.nextEffectId += 1;
  }

  function selectedTower() {
    return state.towers.find((tower) => tower.id === state.selectedTowerId) || null;
  }

  function towerAt(x, y) {
    return state.towers.find((tower) => tower.x === x && tower.y === y) || null;
  }

  function cellFromPointer(event) {
    const rect = canvas.getBoundingClientRect();
    const x = event.clientX - rect.left - layout.offsetX;
    const y = event.clientY - rect.top - layout.offsetY;
    const cellX = Math.floor(x / layout.tile);
    const cellY = Math.floor(y / layout.tile);
    if (cellX < 0 || cellY < 0 || cellX >= COLS || cellY >= ROWS) return null;
    return { x: cellX, y: cellY };
  }

  function toScreen(point) {
    const x = Array.isArray(point) ? point[0] : point.x;
    const y = Array.isArray(point) ? point[1] : point.y;
    return {
      x: layout.offsetX + x * layout.tile,
      y: layout.offsetY + y * layout.tile,
    };
  }

  function pointAtDistance(distanceAlongPath) {
    const d = Math.max(0, Math.min(PATH.totalLength, distanceAlongPath));
    for (const segment of PATH.segments) {
      if (d <= segment.end) {
        const local = (d - segment.start) / segment.length;
        return {
          x: segment.a[0] + (segment.b[0] - segment.a[0]) * local,
          y: segment.a[1] + (segment.b[1] - segment.a[1]) * local,
        };
      }
    }
    const last = WAYPOINTS[WAYPOINTS.length - 1];
    return { x: last[0], y: last[1] };
  }

  function buildPathMetrics() {
    const segments = [];
    let total = 0;
    for (let i = 0; i < WAYPOINTS.length - 1; i += 1) {
      const a = WAYPOINTS[i];
      const b = WAYPOINTS[i + 1];
      const length = Math.hypot(b[0] - a[0], b[1] - a[1]);
      segments.push({ a, b, length, start: total, end: total + length });
      total += length;
    }
    return { segments, totalLength: total };
  }

  function addPathCells(x1, y1, x2, y2) {
    const dx = Math.sign(x2 - x1);
    const dy = Math.sign(y2 - y1);
    let x = x1;
    let y = y1;
    PATH_CELLS.add(`${x},${y}`);
    while (x !== x2 || y !== y2) {
      if (x !== x2) x += dx;
      if (y !== y2) y += dy;
      PATH_CELLS.add(`${x},${y}`);
    }
  }

  function isPathCell(x, y) {
    return PATH_CELLS.has(`${x},${y}`);
  }

  function distance(a, b) {
    return Math.hypot(a.x - b.x, a.y - b.y);
  }

  function clampNumber(value, min, max, fallback) {
    const number = Number(value);
    if (!Number.isFinite(number)) return fallback;
    return Math.max(min, Math.min(max, number));
  }
})();
