(() => {
  'use strict';

  const COLS = 10;
  const ROWS = 8;
  const SAVE_KEY = 'lanArcade.breachlineTactics.save.v1';
  const BEST_KEY = 'lanArcade.breachlineTactics.bestDepth.v1';

  const OPERATORS = [
    { id: 'vanguard', name: 'Vanguard', color: '#f3bf58', hp: 7, range: 1, damage: 3, move: 3, role: 'Frontline' },
    { id: 'ranger', name: 'Ranger', color: '#5ec8f2', hp: 5, range: 4, damage: 2, move: 3, role: 'Marksman' },
    { id: 'tech', name: 'Tech', color: '#61d394', hp: 5, range: 3, damage: 2, move: 3, role: 'Support' },
  ];

  const canvas = document.getElementById('gameCanvas');
  const ctx = canvas.getContext('2d');
  const toast = document.getElementById('toast');
  const ui = {
    depth: document.getElementById('depthValue'),
    core: document.getElementById('coreValue'),
    data: document.getElementById('dataValue'),
    phase: document.getElementById('phaseLabel'),
    selected: document.getElementById('selectedLabel'),
    unitDetails: document.getElementById('unitDetails'),
    startButton: document.getElementById('startButton'),
    endTurnButton: document.getElementById('endTurnButton'),
    strikeButton: document.getElementById('strikeButton'),
    moveButton: document.getElementById('moveButton'),
    repairButton: document.getElementById('repairButton'),
    overwatchButton: document.getElementById('overwatchButton'),
    roster: document.getElementById('rosterPanel'),
    turn: document.getElementById('turnValue'),
    cleared: document.getElementById('clearedValue'),
    best: document.getElementById('bestDepthValue'),
  };

  let layout = { width: 1000, height: 700, tile: 70, offsetX: 80, offsetY: 60 };
  let state = loadState();
  let lastFrame = performance.now();
  let toastTimer = 0;

  bindEvents();
  resizeCanvas();
  installQaHooks();
  updateUi();
  requestAnimationFrame(frame);

  function defaultState() {
    const bestDepth = Number.parseInt(localStorage.getItem(BEST_KEY) || '1', 10) || 1;
    return {
      started: false,
      depth: 1,
      core: 12,
      data: 0,
      phase: 'player',
      turn: 0,
      cleared: 0,
      bestDepth,
      actionMode: 'strike',
      selectedId: 'vanguard',
      units: [],
      enemies: [],
      obstacles: [],
      effects: [],
      nextEffectId: 1,
    };
  }

  function loadState() {
    const fresh = defaultState();
    try {
      const saved = JSON.parse(localStorage.getItem(SAVE_KEY) || 'null');
      if (!saved || !Array.isArray(saved.units)) return fresh;
      return {
        ...fresh,
        started: Boolean(saved.started),
        depth: clampNumber(saved.depth, 1, 99, 1),
        core: clampNumber(saved.core, 0, 99, 12),
        data: clampNumber(saved.data, 0, 999, 0),
        phase: saved.phase === 'enemy' ? 'enemy' : 'player',
        turn: clampNumber(saved.turn, 0, 999, 0),
        cleared: clampNumber(saved.cleared, 0, 999, 0),
        bestDepth: Math.max(fresh.bestDepth, clampNumber(saved.bestDepth, 1, 99, 1)),
        selectedId: typeof saved.selectedId === 'string' ? saved.selectedId : fresh.selectedId,
        actionMode: ['strike', 'move', 'patch', 'guard'].includes(saved.actionMode) ? saved.actionMode : 'strike',
        units: saved.units.map(cleanUnit).filter(Boolean),
        enemies: saved.enemies.map(cleanEnemy).filter(Boolean),
        obstacles: Array.isArray(saved.obstacles) ? saved.obstacles.map(cleanCell).filter(Boolean) : [],
      };
    } catch {
      return fresh;
    }
  }

  function saveState() {
    const payload = {
      started: state.started,
      depth: state.depth,
      core: state.core,
      data: state.data,
      phase: state.phase,
      turn: state.turn,
      cleared: state.cleared,
      bestDepth: state.bestDepth,
      selectedId: state.selectedId,
      actionMode: state.actionMode,
      units: state.units,
      enemies: state.enemies,
      obstacles: state.obstacles,
    };
    localStorage.setItem(SAVE_KEY, JSON.stringify(payload));
    localStorage.setItem(BEST_KEY, String(state.bestDepth));
  }

  function bindEvents() {
    window.addEventListener('resize', resizeCanvas);
    canvas.addEventListener('pointerdown', handleCanvasPointer);
    ui.startButton.addEventListener('click', () => startRun(true));
    ui.endTurnButton.addEventListener('click', endPlayerTurn);
    ui.strikeButton.addEventListener('click', () => setMode('strike'));
    ui.moveButton.addEventListener('click', () => setMode('move'));
    ui.repairButton.addEventListener('click', () => setMode('patch'));
    ui.overwatchButton.addEventListener('click', () => setMode('guard'));
    window.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        if (!state.started) startRun(true);
        else endPlayerTurn();
      }
      if (event.key === '1') selectNextAlive(0);
      if (event.key === '2') selectNextAlive(1);
      if (event.key === '3') selectNextAlive(2);
    });
  }

  function startRun(forceNew) {
    if (state.started && !forceNew) return;
    const bestDepth = Math.max(state.bestDepth, state.depth);
    state = defaultState();
    state.bestDepth = bestDepth;
    state.started = true;
    state.turn = 1;
    state.units = OPERATORS.map((op, index) => ({
      id: op.id,
      name: op.name,
      role: op.role,
      color: op.color,
      x: 1,
      y: 2 + index * 2,
      hp: op.hp,
      maxHp: op.hp,
      move: op.move,
      range: op.range,
      damage: op.damage,
      acted: false,
      guarded: false,
    }));
    buildRoom();
    state.selectedId = 'vanguard';
    showToast('Run online. Breach the room.');
    saveState();
    updateUi();
  }

  function buildRoom() {
    state.phase = 'player';
    state.actionMode = 'strike';
    state.obstacles = [
      { x: 4, y: 1 },
      { x: 4, y: 5 },
      { x: 6, y: 3 },
      { x: 7, y: 6 },
    ].filter((cell) => (cell.x + cell.y + state.depth) % 3 !== 0);
    const count = 3 + Math.floor(state.depth / 2);
    state.enemies = [];
    for (let i = 0; i < count; i += 1) {
      const tough = state.depth >= 3 && i % 3 === 1;
      const hunter = state.depth >= 4 && i % 4 === 2;
      state.enemies.push({
        id: `drone-${state.depth}-${i}`,
        name: tough ? 'Bulwark Drone' : hunter ? 'Hunter Drone' : 'Sentry Drone',
        color: tough ? '#f3bf58' : hunter ? '#b994ff' : '#ef6b73',
        x: 7 + (i % 2),
        y: 1 + ((i * 2 + state.depth) % 6),
        hp: tough ? 6 + state.depth : 4 + Math.floor(state.depth / 2),
        maxHp: tough ? 6 + state.depth : 4 + Math.floor(state.depth / 2),
        damage: tough ? 2 : 1 + Math.floor(state.depth / 4),
        range: hunter ? 3 : 1,
        move: tough ? 1 : 2,
        acted: false,
      });
    }
  }

  function setMode(mode) {
    state.actionMode = mode;
    updateUi();
  }

  function handleCanvasPointer(event) {
    event.preventDefault();
    if (!state.started || state.phase !== 'player') return;
    const cell = cellFromPointer(event);
    if (!cell) return;
    applyCellAction(cell);
  }

  function applyCellAction(cell) {
    if (!state.started || state.phase !== 'player') return;
    const unit = unitAt(cell.x, cell.y);
    if (unit) {
      state.selectedId = unit.id;
      updateUi();
      return;
    }

    const selected = selectedUnit();
    if (!selected || selected.hp <= 0 || selected.acted) return;

    const enemy = enemyAt(cell.x, cell.y);
    if (state.actionMode === 'strike' && enemy) {
      attack(selected, enemy);
    } else if (state.actionMode === 'move' && !enemy) {
      moveUnit(selected, cell);
    } else if (state.actionMode === 'patch') {
      patchUnit(selected);
    } else if (state.actionMode === 'guard') {
      guardUnit(selected);
    } else if (!enemy && canMoveTo(selected, cell)) {
      moveUnit(selected, cell);
    } else if (enemy) {
      attack(selected, enemy);
    }
    saveState();
    updateUi();
  }

  function installQaHooks() {
    window.__lanArcadeGame = {
      startRun: () => startRun(true),
      setMode: (mode) => setMode(mode),
      clickCell: (x, y) => {
        if (!state.started) startRun(true);
        applyCellAction({ x, y });
      },
      endTurn: () => endPlayerTurn(),
    };
  }

  function attack(unit, enemy) {
    const dist = gridDistance(unit, enemy);
    if (dist > unit.range) {
      showToast('Target outside weapon range.');
      return;
    }
    enemy.hp -= unit.damage;
    unit.acted = true;
    addEffect(enemy.x, enemy.y, unit.color, 'strike');
    if (enemy.hp <= 0) {
      state.data += 2 + Math.floor(state.depth / 2);
      state.enemies = state.enemies.filter((item) => item.id !== enemy.id);
      showToast(`${enemy.name} disabled.`);
      if (state.enemies.length === 0) advanceDepth();
    } else {
      showToast(`${unit.name} hit ${enemy.name}.`);
    }
  }

  function moveUnit(unit, cell) {
    if (!canMoveTo(unit, cell)) {
      showToast('Move blocked.');
      return;
    }
    unit.x = cell.x;
    unit.y = cell.y;
    unit.acted = true;
    unit.guarded = false;
    addEffect(unit.x, unit.y, unit.color, 'move');
    showToast(`${unit.name} repositioned.`);
  }

  function patchUnit(unit) {
    if (unit.id !== 'tech') {
      showToast('Only Tech carries field patches.');
      return;
    }
    const target = state.units
      .filter((ally) => ally.hp > 0)
      .sort((a, b) => (a.hp / a.maxHp) - (b.hp / b.maxHp))[0];
    if (!target || target.hp >= target.maxHp) {
      showToast('No patch target needed.');
      return;
    }
    target.hp = Math.min(target.maxHp, target.hp + 2);
    unit.acted = true;
    addEffect(target.x, target.y, '#61d394', 'patch');
    showToast(`${target.name} patched.`);
  }

  function guardUnit(unit) {
    unit.guarded = true;
    unit.acted = true;
    addEffect(unit.x, unit.y, '#5ec8f2', 'guard');
    showToast(`${unit.name} is guarding.`);
  }

  function endPlayerTurn() {
    if (!state.started || state.phase !== 'player') return;
    state.phase = 'enemy';
    state.enemies.forEach((enemy) => { enemy.acted = false; });
    updateUi();
    setTimeout(enemyTurn, 260);
  }

  function enemyTurn() {
    if (!state.started || state.phase !== 'enemy') return;
    for (const enemy of state.enemies) {
      const target = nearestUnit(enemy);
      if (!target) continue;
      if (gridDistance(enemy, target) <= enemy.range) {
        damageUnit(enemy, target);
      } else {
        stepEnemyToward(enemy, target);
        if (gridDistance(enemy, target) <= enemy.range) damageUnit(enemy, target);
      }
    }
    state.units.forEach((unit) => {
      unit.acted = false;
      unit.guarded = false;
    });
    state.phase = 'player';
    state.turn += 1;
    if (state.units.every((unit) => unit.hp <= 0)) {
      state.started = false;
      showToast('Squad down. Start a new run.');
    }
    saveState();
    updateUi();
  }

  function damageUnit(enemy, unit) {
    const guarded = unit.guarded ? 1 : 0;
    const damage = Math.max(1, enemy.damage - guarded);
    unit.hp = Math.max(0, unit.hp - damage);
    state.core = Math.max(0, state.core - (unit.hp <= 0 ? 1 : 0));
    addEffect(unit.x, unit.y, enemy.color, 'hit');
    if (unit.hp <= 0 && selectedUnit()?.hp <= 0) selectFirstAlive();
  }

  function advanceDepth() {
    state.cleared += 1;
    state.depth += 1;
    state.bestDepth = Math.max(state.bestDepth, state.depth);
    state.units.forEach((unit) => {
      unit.hp = Math.min(unit.maxHp, unit.hp + 1);
      unit.acted = false;
      unit.guarded = false;
      unit.x = 1;
    });
    state.units[0].y = 2;
    state.units[1].y = 4;
    state.units[2].y = 6;
    buildRoom();
    showToast(`Depth ${state.depth} opened.`);
  }

  function canMoveTo(unit, cell) {
    if (!inside(cell.x, cell.y)) return false;
    if (isBlocked(cell.x, cell.y)) return false;
    if (unitAt(cell.x, cell.y) || enemyAt(cell.x, cell.y)) return false;
    return gridDistance(unit, cell) <= unit.move;
  }

  function stepEnemyToward(enemy, target) {
    let best = { x: enemy.x, y: enemy.y };
    let bestDist = gridDistance(enemy, target);
    const options = [
      { x: enemy.x + 1, y: enemy.y },
      { x: enemy.x - 1, y: enemy.y },
      { x: enemy.x, y: enemy.y + 1 },
      { x: enemy.x, y: enemy.y - 1 },
    ];
    for (const cell of options) {
      if (!inside(cell.x, cell.y) || isBlocked(cell.x, cell.y) || unitAt(cell.x, cell.y) || enemyAt(cell.x, cell.y)) continue;
      const dist = gridDistance(cell, target);
      if (dist < bestDist) {
        bestDist = dist;
        best = cell;
      }
    }
    enemy.x = best.x;
    enemy.y = best.y;
  }

  function frame(now) {
    const dt = Math.min(0.05, (now - lastFrame) / 1000);
    lastFrame = now;
    updateToast(dt);
    updateEffects(dt);
    draw();
    requestAnimationFrame(frame);
  }

  function resizeCanvas() {
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.max(1, Math.floor(rect.width * dpr));
    canvas.height = Math.max(1, Math.floor(rect.height * dpr));
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    layout.width = rect.width;
    layout.height = rect.height;
    layout.tile = Math.max(38, Math.min(rect.width / (COLS + 1.8), rect.height / (ROWS + 1.5)));
    layout.offsetX = (rect.width - layout.tile * COLS) / 2;
    layout.offsetY = (rect.height - layout.tile * ROWS) / 2;
  }

  function draw() {
    ctx.clearRect(0, 0, layout.width, layout.height);
    drawBackdrop();
    drawGrid();
    drawHighlights();
    drawUnits();
    drawEffects();
    if (!state.started) drawIntro();
  }

  function drawBackdrop() {
    const gradient = ctx.createLinearGradient(0, 0, layout.width, layout.height);
    gradient.addColorStop(0, '#101824');
    gradient.addColorStop(1, '#11101a');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, layout.width, layout.height);
    ctx.fillStyle = 'rgba(94, 200, 242, 0.08)';
    for (let i = 0; i < 22; i += 1) {
      ctx.fillRect((i * 89) % layout.width, (i * 47) % layout.height, 2, 2);
    }
  }

  function drawGrid() {
    const ox = layout.offsetX;
    const oy = layout.offsetY;
    const t = layout.tile;
    ctx.save();
    ctx.translate(ox, oy);
    ctx.fillStyle = 'rgba(8, 13, 20, 0.92)';
    ctx.fillRect(0, 0, COLS * t, ROWS * t);

    for (let y = 0; y < ROWS; y += 1) {
      for (let x = 0; x < COLS; x += 1) {
        ctx.fillStyle = (x + y) % 2 ? 'rgba(255,255,255,0.025)' : 'rgba(255,255,255,0.045)';
        ctx.fillRect(x * t, y * t, t, t);
        if (isBlocked(x, y)) {
          ctx.fillStyle = 'rgba(84, 94, 114, 0.58)';
          roundRect(ctx, x * t + 8, y * t + 8, t - 16, t - 16, 7);
          ctx.fill();
        }
      }
    }

    ctx.strokeStyle = 'rgba(170, 181, 199, 0.12)';
    ctx.lineWidth = 1;
    for (let x = 0; x <= COLS; x += 1) {
      ctx.beginPath();
      ctx.moveTo(x * t, 0);
      ctx.lineTo(x * t, ROWS * t);
      ctx.stroke();
    }
    for (let y = 0; y <= ROWS; y += 1) {
      ctx.beginPath();
      ctx.moveTo(0, y * t);
      ctx.lineTo(COLS * t, y * t);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawHighlights() {
    const unit = selectedUnit();
    if (!state.started || !unit || unit.hp <= 0 || state.phase !== 'player') return;
    for (let y = 0; y < ROWS; y += 1) {
      for (let x = 0; x < COLS; x += 1) {
        const dist = gridDistance(unit, { x, y });
        const screen = toScreenCell(x, y);
        if (state.actionMode === 'move' && dist <= unit.move && !isBlocked(x, y) && !unitAt(x, y) && !enemyAt(x, y)) {
          ctx.fillStyle = 'rgba(94, 200, 242, 0.13)';
          ctx.fillRect(screen.x + 2, screen.y + 2, layout.tile - 4, layout.tile - 4);
        }
        if (state.actionMode === 'strike' && dist <= unit.range) {
          ctx.strokeStyle = 'rgba(243, 191, 88, 0.2)';
          ctx.strokeRect(screen.x + 4, screen.y + 4, layout.tile - 8, layout.tile - 8);
        }
      }
    }
  }

  function drawUnits() {
    state.units.forEach((unit) => drawToken(unit, true));
    state.enemies.forEach((enemy) => drawToken(enemy, false));
  }

  function drawToken(token, friendly) {
    const p = toScreenCenter(token.x, token.y);
    const r = layout.tile * (friendly ? 0.31 : 0.28);
    ctx.save();
    ctx.fillStyle = token.color;
    ctx.strokeStyle = token.id === state.selectedId ? '#ffffff' : '#0f141d';
    ctx.lineWidth = token.id === state.selectedId ? 4 : 2.5;
    if (friendly) {
      roundRect(ctx, p.x - r, p.y - r, r * 2, r * 2, 8);
    } else {
      ctx.beginPath();
      ctx.arc(p.x, p.y, r, 0, Math.PI * 2);
    }
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = '#0f141d';
    ctx.font = `900 ${Math.max(12, layout.tile * 0.22)}px system-ui`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(token.name.slice(0, 1), p.x, p.y);
    drawHealthBar(p.x, p.y - r - 11, token.hp, token.maxHp);
    if (friendly && token.acted) {
      ctx.fillStyle = 'rgba(15, 20, 29, 0.58)';
      ctx.fillRect(p.x - r, p.y - r, r * 2, r * 2);
    }
    ctx.restore();
  }

  function drawHealthBar(x, y, hp, maxHp) {
    const width = layout.tile * 0.66;
    ctx.fillStyle = 'rgba(8, 10, 14, 0.82)';
    ctx.fillRect(x - width / 2, y, width, 5);
    ctx.fillStyle = hp / maxHp > 0.45 ? '#61d394' : hp / maxHp > 0.2 ? '#f3bf58' : '#ef6b73';
    ctx.fillRect(x - width / 2, y, width * Math.max(0, hp / maxHp), 5);
  }

  function drawEffects() {
    state.effects.forEach((effect) => {
      const p = toScreenCenter(effect.x, effect.y);
      const pct = 1 - effect.life / effect.maxLife;
      ctx.save();
      ctx.globalAlpha = Math.max(0, 1 - pct);
      ctx.strokeStyle = effect.color;
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(p.x, p.y, layout.tile * (0.22 + pct * 0.45), 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    });
  }

  function drawIntro() {
    ctx.save();
    ctx.fillStyle = 'rgba(8, 12, 18, 0.68)';
    ctx.fillRect(0, 0, layout.width, layout.height);
    ctx.fillStyle = '#f4f7fb';
    ctx.font = `900 ${Math.max(24, layout.tile * 0.5)}px system-ui`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('Ready Room', layout.width / 2, layout.height / 2 - 28);
    ctx.fillStyle = '#aab5c7';
    ctx.font = `800 ${Math.max(13, layout.tile * 0.2)}px system-ui`;
    ctx.fillText('Start a run to breach the first depth.', layout.width / 2, layout.height / 2 + 14);
    ctx.restore();
  }

  function updateUi() {
    ui.depth.textContent = String(state.depth);
    ui.core.textContent = String(state.core);
    ui.data.textContent = String(state.data);
    ui.phase.textContent = state.started ? (state.phase === 'player' ? 'Squad Turn' : 'Drone Turn') : 'Ready';
    ui.turn.textContent = String(state.turn);
    ui.cleared.textContent = String(state.cleared);
    ui.best.textContent = String(Math.max(state.bestDepth, state.depth));
    ui.startButton.textContent = state.started ? 'New Run' : 'Start Run';
    ui.endTurnButton.disabled = !state.started || state.phase !== 'player';

    const unit = selectedUnit();
    ui.selected.textContent = unit ? unit.name : 'None';
    ui.unitDetails.textContent = unit
      ? `${unit.role} | HP ${unit.hp}/${unit.maxHp} | Move ${unit.move} | Range ${unit.range}`
      : 'Select an operator on the grid.';
    ui.strikeButton.disabled = !state.started || !unit || unit.acted;
    ui.moveButton.disabled = !state.started || !unit || unit.acted;
    ui.repairButton.disabled = !state.started || !unit || unit.acted || unit.id !== 'tech';
    ui.overwatchButton.disabled = !state.started || !unit || unit.acted;

    ui.roster.innerHTML = '';
    state.units.forEach((operator) => {
      const card = document.createElement('div');
      card.className = `roster-card${operator.hp <= 0 ? ' is-down' : ''}`;
      card.innerHTML = `<span>${operator.role}</span><strong>${operator.name}</strong><span>HP ${operator.hp}/${operator.maxHp}</span>`;
      card.addEventListener('click', () => {
        if (operator.hp > 0) state.selectedId = operator.id;
        updateUi();
      });
      ui.roster.append(card);
    });
  }

  function updateToast(dt) {
    if (toastTimer <= 0) return;
    toastTimer -= dt;
    if (toastTimer <= 0) toast.classList.remove('is-visible');
  }

  function updateEffects(dt) {
    state.effects.forEach((effect) => { effect.life -= dt; });
    state.effects = state.effects.filter((effect) => effect.life > 0);
  }

  function showToast(message) {
    toast.textContent = message;
    toast.classList.add('is-visible');
    toastTimer = 2.1;
  }

  function addEffect(x, y, color, type) {
    state.effects.push({
      id: state.nextEffectId,
      x,
      y,
      color,
      type,
      life: 0.36,
      maxLife: 0.36,
    });
    state.nextEffectId += 1;
  }

  function selectNextAlive(index) {
    const unit = state.units[index];
    if (unit && unit.hp > 0) state.selectedId = unit.id;
    updateUi();
  }

  function selectFirstAlive() {
    const unit = state.units.find((item) => item.hp > 0);
    state.selectedId = unit ? unit.id : null;
  }

  function selectedUnit() {
    return state.units.find((unit) => unit.id === state.selectedId) || null;
  }

  function unitAt(x, y) {
    return state.units.find((unit) => unit.hp > 0 && unit.x === x && unit.y === y) || null;
  }

  function enemyAt(x, y) {
    return state.enemies.find((enemy) => enemy.hp > 0 && enemy.x === x && enemy.y === y) || null;
  }

  function nearestUnit(enemy) {
    return state.units
      .filter((unit) => unit.hp > 0)
      .sort((a, b) => gridDistance(enemy, a) - gridDistance(enemy, b))[0] || null;
  }

  function isBlocked(x, y) {
    return state.obstacles.some((cell) => cell.x === x && cell.y === y);
  }

  function inside(x, y) {
    return x >= 0 && y >= 0 && x < COLS && y < ROWS;
  }

  function gridDistance(a, b) {
    return Math.abs(a.x - b.x) + Math.abs(a.y - b.y);
  }

  function cellFromPointer(event) {
    const rect = canvas.getBoundingClientRect();
    const x = Math.floor((event.clientX - rect.left - layout.offsetX) / layout.tile);
    const y = Math.floor((event.clientY - rect.top - layout.offsetY) / layout.tile);
    if (!inside(x, y)) return null;
    return { x, y };
  }

  function toScreenCell(x, y) {
    return {
      x: layout.offsetX + x * layout.tile,
      y: layout.offsetY + y * layout.tile,
    };
  }

  function toScreenCenter(x, y) {
    return {
      x: layout.offsetX + (x + 0.5) * layout.tile,
      y: layout.offsetY + (y + 0.5) * layout.tile,
    };
  }

  function cleanCell(cell) {
    const x = clampNumber(cell.x, 0, COLS - 1, -1);
    const y = clampNumber(cell.y, 0, ROWS - 1, -1);
    return x >= 0 && y >= 0 ? { x, y } : null;
  }

  function cleanUnit(unit) {
    const base = OPERATORS.find((item) => item.id === unit.id);
    if (!base) return null;
    return {
      id: base.id,
      name: base.name,
      role: base.role,
      color: base.color,
      x: clampNumber(unit.x, 0, COLS - 1, 1),
      y: clampNumber(unit.y, 0, ROWS - 1, 1),
      hp: clampNumber(unit.hp, 0, base.hp, base.hp),
      maxHp: base.hp,
      move: base.move,
      range: base.range,
      damage: base.damage,
      acted: Boolean(unit.acted),
      guarded: Boolean(unit.guarded),
    };
  }

  function cleanEnemy(enemy) {
    if (!enemy || typeof enemy.id !== 'string') return null;
    return {
      id: enemy.id,
      name: String(enemy.name || 'Sentry Drone'),
      color: String(enemy.color || '#ef6b73'),
      x: clampNumber(enemy.x, 0, COLS - 1, 8),
      y: clampNumber(enemy.y, 0, ROWS - 1, 3),
      hp: clampNumber(enemy.hp, 0, 999, 4),
      maxHp: clampNumber(enemy.maxHp, 1, 999, 4),
      damage: clampNumber(enemy.damage, 1, 20, 1),
      range: clampNumber(enemy.range, 1, 6, 1),
      move: clampNumber(enemy.move, 1, 4, 1),
      acted: Boolean(enemy.acted),
    };
  }

  function roundRect(context, x, y, width, height, radius) {
    const r = Math.min(radius, width / 2, height / 2);
    context.beginPath();
    context.moveTo(x + r, y);
    context.lineTo(x + width - r, y);
    context.quadraticCurveTo(x + width, y, x + width, y + r);
    context.lineTo(x + width, y + height - r);
    context.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
    context.lineTo(x + r, y + height);
    context.quadraticCurveTo(x, y + height, x, y + height - r);
    context.lineTo(x, y + r);
    context.quadraticCurveTo(x, y, x + r, y);
    context.closePath();
  }

  function clampNumber(value, min, max, fallback) {
    const number = Number(value);
    if (!Number.isFinite(number)) return fallback;
    return Math.max(min, Math.min(max, number));
  }
})();
