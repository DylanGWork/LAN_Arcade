(() => {
  'use strict';

  const COLS = 12;
  const ROWS = 8;
  const SAVE_KEY = 'lanArcade.circuitFoundry.save.v1';
  const BEST_KEY = 'lanArcade.circuitFoundry.best.v1';
  const DIRS = [
    { x: 1, y: 0, label: 'E' },
    { x: 0, y: 1, label: 'S' },
    { x: -1, y: 0, label: 'W' },
    { x: 0, y: -1, label: 'N' },
  ];

  const TOOLS = {
    extractor: { label: 'Extractor', cost: 55, color: '#f3bf58', power: -1 },
    belt: { label: 'Belt', cost: 8, color: '#9ba9bd', power: 0 },
    smelter: { label: 'Smelter', cost: 75, color: '#ef6b73', power: -2 },
    assembler: { label: 'Assembler', cost: 95, color: '#5ec8f2', power: -2 },
    generator: { label: 'Generator', cost: 65, color: '#61d394', power: 6 },
    erase: { label: 'Erase', cost: 0, color: '#aeb8c8', power: 0 },
  };

  const RESOURCE_NODES = [
    { x: 1, y: 1, type: 'ore' },
    { x: 1, y: 5, type: 'ore' },
    { x: 3, y: 6, type: 'ore' },
  ];

  const canvas = document.getElementById('gameCanvas');
  const ctx = canvas.getContext('2d');
  const toast = document.getElementById('toast');
  const ui = {
    credits: document.getElementById('creditsValue'),
    circuits: document.getElementById('circuitsValue'),
    power: document.getElementById('powerValue'),
    toolLabel: document.getElementById('toolLabel'),
    toolButtons: document.getElementById('toolButtons'),
    selectedLabel: document.getElementById('selectedLabel'),
    selectedDetails: document.getElementById('selectedDetails'),
    rotateButton: document.getElementById('rotateButton'),
    runButton: document.getElementById('runButton'),
    speedButton: document.getElementById('speedButton'),
    resetButton: document.getElementById('resetButton'),
    ore: document.getElementById('oreValue'),
    plates: document.getElementById('platesValue'),
    best: document.getElementById('bestValue'),
  };

  let layout = { width: 1000, height: 700, tile: 66, offsetX: 80, offsetY: 70 };
  let state = loadState();
  let lastFrame = performance.now();
  let toastTimer = 0;

  createToolButtons();
  bindEvents();
  resizeCanvas();
  installQaHooks();
  updateUi();
  requestAnimationFrame(frame);

  function defaultState() {
    return {
      credits: 360,
      circuits: 0,
      ore: 0,
      plates: 0,
      running: false,
      speed: 1,
      selectedTool: 'extractor',
      selectedMachineId: null,
      direction: 0,
      machines: [],
      items: [],
      tick: 0,
      best: Number.parseInt(localStorage.getItem(BEST_KEY) || '0', 10) || 0,
      nextMachineId: 1,
      nextItemId: 1,
    };
  }

  function loadState() {
    const fresh = defaultState();
    try {
      const saved = JSON.parse(localStorage.getItem(SAVE_KEY) || 'null');
      if (!saved || !Array.isArray(saved.machines)) return fresh;
      const machines = saved.machines.map(cleanMachine).filter(Boolean);
      return {
        ...fresh,
        credits: clampNumber(saved.credits, 0, 99999, fresh.credits),
        circuits: clampNumber(saved.circuits, 0, 99999, fresh.circuits),
        ore: clampNumber(saved.ore, 0, 99999, fresh.ore),
        plates: clampNumber(saved.plates, 0, 99999, fresh.plates),
        running: Boolean(saved.running),
        speed: [1, 2, 3].includes(saved.speed) ? saved.speed : 1,
        selectedTool: TOOLS[saved.selectedTool] ? saved.selectedTool : fresh.selectedTool,
        direction: clampNumber(saved.direction, 0, 3, 0),
        machines,
        best: Math.max(fresh.best, clampNumber(saved.best, 0, 99999, fresh.best)),
        nextMachineId: machines.reduce((max, machine) => Math.max(max, machine.id + 1), 1),
      };
    } catch {
      return fresh;
    }
  }

  function saveState() {
    const payload = {
      credits: state.credits,
      circuits: state.circuits,
      ore: state.ore,
      plates: state.plates,
      running: state.running,
      speed: state.speed,
      selectedTool: state.selectedTool,
      direction: state.direction,
      machines: state.machines,
      best: state.best,
    };
    localStorage.setItem(SAVE_KEY, JSON.stringify(payload));
    localStorage.setItem(BEST_KEY, String(state.best));
  }

  function createToolButtons() {
    ui.toolButtons.innerHTML = '';
    Object.entries(TOOLS).forEach(([id, tool]) => {
      const button = document.createElement('button');
      button.className = 'tool-button';
      button.type = 'button';
      button.dataset.tool = id;
      const name = document.createElement('span');
      name.className = 'tool-name';
      name.textContent = tool.label;
      const cost = document.createElement('span');
      cost.className = 'tool-cost';
      cost.textContent = id === 'erase' ? 'refunds half' : `${tool.cost} credits`;
      button.append(name, cost);
      button.addEventListener('click', () => {
        state.selectedTool = id;
        state.selectedMachineId = null;
        updateUi();
      });
      ui.toolButtons.append(button);
    });
  }

  function bindEvents() {
    window.addEventListener('resize', resizeCanvas);
    canvas.addEventListener('pointerdown', handleCanvasPointer);
    ui.rotateButton.addEventListener('click', rotateSelection);
    ui.runButton.addEventListener('click', () => {
      state.running = !state.running;
      showToast(state.running ? 'Factory running.' : 'Factory paused.');
      saveState();
      updateUi();
    });
    ui.speedButton.addEventListener('click', () => {
      state.speed = state.speed === 1 ? 2 : state.speed === 2 ? 3 : 1;
      updateUi();
      saveState();
    });
    ui.resetButton.addEventListener('click', resetLayout);
    window.addEventListener('keydown', (event) => {
      const keys = ['1', '2', '3', '4', '5', '6'];
      const index = keys.indexOf(event.key);
      const toolId = Object.keys(TOOLS)[index];
      if (toolId) {
        state.selectedTool = toolId;
        state.selectedMachineId = null;
        updateUi();
      }
      if (event.key === 'r' || event.key === 'R') rotateSelection();
      if (event.key === ' ') {
        event.preventDefault();
        state.running = !state.running;
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
    layout.tile = Math.max(36, Math.min(rect.width / (COLS + 1.7), rect.height / (ROWS + 1.5)));
    layout.offsetX = (rect.width - layout.tile * COLS) / 2;
    layout.offsetY = (rect.height - layout.tile * ROWS) / 2;
  }

  function handleCanvasPointer(event) {
    event.preventDefault();
    const cell = cellFromPointer(event);
    if (!cell) return;
    applyCellAction(cell);
  }

  function applyCellAction(cell) {
    const existing = machineAt(cell.x, cell.y);

    if (existing) {
      state.selectedMachineId = existing.id;
      if (state.selectedTool === 'erase') eraseMachine(existing);
      else if (state.selectedTool !== 'belt') state.selectedTool = existing.type;
      updateUi();
      return;
    }

    if (state.selectedTool === 'erase') return;
    placeMachine(cell.x, cell.y);
  }

  function installQaHooks() {
    window.__lanArcadeGame = {
      setTool: (tool) => {
        if (TOOLS[tool]) {
          state.selectedTool = tool;
          state.selectedMachineId = null;
          updateUi();
        }
      },
      setDirection: (dir) => {
        state.direction = clampNumber(dir, 0, 3, state.direction);
        updateUi();
      },
      clickCell: (x, y) => applyCellAction({ x, y }),
      run: () => {
        state.running = true;
        saveState();
        updateUi();
      },
    };
  }

  function placeMachine(x, y) {
    const tool = TOOLS[state.selectedTool];
    if (!tool || !inside(x, y) || machineAt(x, y)) return;
    if (state.selectedTool === 'extractor' && !resourceAt(x, y)) {
      showToast('Extractors must sit on ore nodes.');
      return;
    }
    if (state.selectedTool !== 'extractor' && resourceAt(x, y)) {
      showToast('Ore node reserved for extractors.');
      return;
    }
    if (state.credits < tool.cost) {
      showToast('Not enough credits.');
      return;
    }
    state.credits -= tool.cost;
    const machine = {
      id: state.nextMachineId,
      type: state.selectedTool,
      x,
      y,
      dir: state.direction,
      timer: 0,
      stock: {},
    };
    state.nextMachineId += 1;
    state.machines.push(machine);
    state.selectedMachineId = machine.id;
    showToast(`${tool.label} placed.`);
    saveState();
    updateUi();
  }

  function eraseMachine(machine) {
    const tool = TOOLS[machine.type];
    state.credits += Math.floor(tool.cost / 2);
    state.machines = state.machines.filter((item) => item.id !== machine.id);
    state.selectedMachineId = null;
    showToast(`${tool.label} removed.`);
    saveState();
  }

  function rotateSelection() {
    const machine = selectedMachine();
    if (machine) {
      machine.dir = (machine.dir + 1) % 4;
      showToast(`${TOOLS[machine.type].label} rotated.`);
    } else {
      state.direction = (state.direction + 1) % 4;
      showToast(`Build direction ${DIRS[state.direction].label}.`);
    }
    saveState();
    updateUi();
  }

  function resetLayout() {
    const best = Math.max(state.best, state.circuits);
    state = defaultState();
    state.best = best;
    localStorage.setItem(BEST_KEY, String(best));
    localStorage.removeItem(SAVE_KEY);
    showToast('Layout reset.');
    updateUi();
  }

  function frame(now) {
    const dt = Math.min(0.05, (now - lastFrame) / 1000);
    lastFrame = now;
    if (state.running && powerBalance().ok) {
      updateFactory(dt * state.speed);
    }
    updateToast(dt);
    draw();
    requestAnimationFrame(frame);
  }

  function updateFactory(dt) {
    state.tick += dt;
    updateMachines(dt);
    updateItems(dt);
    if (state.tick >= 2) {
      state.tick = 0;
      state.credits += Math.max(1, Math.floor(state.circuits / 4));
      saveState();
      updateUi();
    }
  }

  function updateMachines(dt) {
    state.machines.forEach((machine) => {
      machine.timer += dt;
      if (machine.type === 'extractor' && machine.timer >= 1.15) {
        machine.timer = 0;
        emitItem(machine, 'ore');
      }
      if (machine.type === 'smelter' && machine.timer >= 1.55) {
        machine.timer = 0;
        if ((machine.stock.ore || 0) > 0) {
          machine.stock.ore -= 1;
          emitItem(machine, 'plate');
        }
      }
      if (machine.type === 'assembler' && machine.timer >= 2.05) {
        machine.timer = 0;
        if ((machine.stock.plate || 0) >= 2) {
          machine.stock.plate -= 2;
          state.circuits += 1;
          state.best = Math.max(state.best, state.circuits);
          addPulse(machine.x, machine.y, '#5ec8f2');
          saveState();
          updateUi();
        }
      }
    });
  }

  function emitItem(machine, kind) {
    const dir = DIRS[machine.dir];
    const target = { x: machine.x + dir.x, y: machine.y + dir.y };
    if (!inside(target.x, target.y)) return;
    state.items.push({
      id: state.nextItemId,
      kind,
      x: machine.x,
      y: machine.y,
      tx: target.x,
      ty: target.y,
      progress: 0,
      dir: machine.dir,
    });
    state.nextItemId += 1;
    if (kind === 'ore') state.ore += 1;
    if (kind === 'plate') state.plates += 1;
    addPulse(machine.x, machine.y, kind === 'ore' ? '#f3bf58' : '#9ba9bd');
  }

  function updateItems(dt) {
    state.items.forEach((item) => {
      item.progress += dt * 1.8;
      if (item.progress < 1) return;
      item.x = item.tx;
      item.y = item.ty;
      const receiver = machineAt(item.x, item.y);
      if (receiver && accepts(receiver, item.kind)) {
        receiver.stock[item.kind] = (receiver.stock[item.kind] || 0) + 1;
        item.done = true;
      } else if (receiver && receiver.type === 'belt') {
        const dir = DIRS[receiver.dir];
        item.tx = receiver.x + dir.x;
        item.ty = receiver.y + dir.y;
        item.dir = receiver.dir;
        item.progress = 0;
        if (!inside(item.tx, item.ty)) item.done = true;
      } else {
        item.done = true;
      }
    });
    state.items = state.items.filter((item) => !item.done);
  }

  function accepts(machine, kind) {
    if (machine.type === 'smelter') return kind === 'ore' && (machine.stock.ore || 0) < 4;
    if (machine.type === 'assembler') return kind === 'plate' && (machine.stock.plate || 0) < 6;
    return false;
  }

  function draw() {
    ctx.clearRect(0, 0, layout.width, layout.height);
    drawBackdrop();
    drawGrid();
    drawMachines();
    drawItems();
    drawPulses();
    drawSelection();
    if (!powerBalance().ok) drawPowerWarning();
  }

  function drawBackdrop() {
    const gradient = ctx.createLinearGradient(0, 0, layout.width, layout.height);
    gradient.addColorStop(0, '#101822');
    gradient.addColorStop(1, '#10111a');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, layout.width, layout.height);
    ctx.fillStyle = 'rgba(97, 211, 148, 0.08)';
    for (let i = 0; i < 24; i += 1) {
      ctx.fillRect((i * 83) % layout.width, (i * 61) % layout.height, 2, 2);
    }
  }

  function drawGrid() {
    ctx.save();
    ctx.translate(layout.offsetX, layout.offsetY);
    ctx.fillStyle = 'rgba(8, 13, 20, 0.92)';
    ctx.fillRect(0, 0, COLS * layout.tile, ROWS * layout.tile);
    for (let y = 0; y < ROWS; y += 1) {
      for (let x = 0; x < COLS; x += 1) {
        ctx.fillStyle = (x + y) % 2 ? 'rgba(255,255,255,0.025)' : 'rgba(255,255,255,0.045)';
        ctx.fillRect(x * layout.tile, y * layout.tile, layout.tile, layout.tile);
      }
    }
    RESOURCE_NODES.forEach((node) => {
      const x = node.x * layout.tile;
      const y = node.y * layout.tile;
      ctx.fillStyle = 'rgba(243, 191, 88, 0.18)';
      ctx.beginPath();
      ctx.arc(x + layout.tile / 2, y + layout.tile / 2, layout.tile * 0.33, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = 'rgba(243, 191, 88, 0.65)';
      ctx.lineWidth = 2;
      ctx.stroke();
    });
    ctx.strokeStyle = 'rgba(174, 184, 200, 0.12)';
    ctx.lineWidth = 1;
    for (let x = 0; x <= COLS; x += 1) {
      ctx.beginPath();
      ctx.moveTo(x * layout.tile, 0);
      ctx.lineTo(x * layout.tile, ROWS * layout.tile);
      ctx.stroke();
    }
    for (let y = 0; y <= ROWS; y += 1) {
      ctx.beginPath();
      ctx.moveTo(0, y * layout.tile);
      ctx.lineTo(COLS * layout.tile, y * layout.tile);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawMachines() {
    state.machines.forEach((machine) => {
      const tool = TOOLS[machine.type];
      const p = center(machine.x, machine.y);
      const size = layout.tile * 0.62;
      ctx.save();
      ctx.fillStyle = tool.color;
      ctx.strokeStyle = machine.id === state.selectedMachineId ? '#ffffff' : '#0f141d';
      ctx.lineWidth = machine.id === state.selectedMachineId ? 4 : 2.5;
      if (machine.type === 'belt') {
        roundRect(ctx, p.x - size / 2, p.y - size / 2, size, size, 6);
      } else {
        ctx.beginPath();
        ctx.arc(p.x, p.y, size / 2, 0, Math.PI * 2);
      }
      ctx.fill();
      ctx.stroke();
      drawDirection(machine, p);
      ctx.fillStyle = '#10151d';
      ctx.font = `900 ${Math.max(11, layout.tile * 0.2)}px system-ui`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(tool.label.slice(0, 1), p.x, p.y);
      if (machine.stock && (machine.stock.ore || machine.stock.plate)) {
        ctx.fillStyle = '#f4f7fb';
        ctx.font = `800 ${Math.max(9, layout.tile * 0.13)}px system-ui`;
        ctx.fillText(`${machine.stock.ore || 0}/${machine.stock.plate || 0}`, p.x, p.y + size * 0.54);
      }
      ctx.restore();
    });
  }

  function drawDirection(machine, p) {
    const dir = DIRS[machine.dir];
    ctx.strokeStyle = '#10151d';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(p.x, p.y);
    ctx.lineTo(p.x + dir.x * layout.tile * 0.34, p.y + dir.y * layout.tile * 0.34);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(p.x + dir.x * layout.tile * 0.36, p.y + dir.y * layout.tile * 0.36, 4, 0, Math.PI * 2);
    ctx.fillStyle = '#10151d';
    ctx.fill();
  }

  function drawItems() {
    state.items.forEach((item) => {
      const x = layout.offsetX + (item.x + 0.5 + (item.tx - item.x) * item.progress) * layout.tile;
      const y = layout.offsetY + (item.y + 0.5 + (item.ty - item.y) * item.progress) * layout.tile;
      ctx.fillStyle = item.kind === 'ore' ? '#f3bf58' : '#9ba9bd';
      ctx.beginPath();
      ctx.arc(x, y, layout.tile * 0.1, 0, Math.PI * 2);
      ctx.fill();
    });
  }

  function drawPulses() {
    state.pulses = (state.pulses || []).filter((pulse) => pulse.life > 0);
    state.pulses.forEach((pulse) => {
      const p = center(pulse.x, pulse.y);
      const pct = 1 - pulse.life / pulse.maxLife;
      ctx.save();
      ctx.globalAlpha = Math.max(0, 1 - pct);
      ctx.strokeStyle = pulse.color;
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(p.x, p.y, layout.tile * (0.2 + pct * 0.5), 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
      pulse.life -= 0.016;
    });
  }

  function drawSelection() {
    const machine = selectedMachine();
    if (machine) return;
    const tool = TOOLS[state.selectedTool];
    if (!tool || state.selectedTool === 'erase') return;
    ctx.save();
    ctx.fillStyle = 'rgba(94, 200, 242, 0.08)';
    for (let y = 0; y < ROWS; y += 1) {
      for (let x = 0; x < COLS; x += 1) {
        if (machineAt(x, y)) continue;
        if (state.selectedTool === 'extractor' && !resourceAt(x, y)) continue;
        if (state.selectedTool !== 'extractor' && resourceAt(x, y)) continue;
        ctx.fillRect(layout.offsetX + x * layout.tile + 2, layout.offsetY + y * layout.tile + 2, layout.tile - 4, layout.tile - 4);
      }
    }
    ctx.restore();
  }

  function drawPowerWarning() {
    ctx.save();
    ctx.fillStyle = 'rgba(8, 12, 18, 0.58)';
    ctx.fillRect(0, 0, layout.width, layout.height);
    ctx.fillStyle = '#ef6b73';
    ctx.font = `900 ${Math.max(24, layout.tile * 0.45)}px system-ui`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('Power Deficit', layout.width / 2, layout.height / 2);
    ctx.restore();
  }

  function updateUi() {
    const power = powerBalance();
    ui.credits.textContent = String(Math.floor(state.credits));
    ui.circuits.textContent = String(state.circuits);
    ui.power.textContent = `${power.use}/${power.gen}`;
    ui.ore.textContent = String(state.ore);
    ui.plates.textContent = String(state.plates);
    ui.best.textContent = String(Math.max(state.best, state.circuits));
    ui.toolLabel.textContent = TOOLS[state.selectedTool].label;
    ui.runButton.textContent = state.running ? 'Pause Factory' : 'Run Factory';
    ui.speedButton.textContent = `${state.speed}x`;

    Array.from(ui.toolButtons.querySelectorAll('button')).forEach((button) => {
      button.classList.toggle('is-selected', button.dataset.tool === state.selectedTool && !state.selectedMachineId);
    });

    const machine = selectedMachine();
    if (machine) {
      const tool = TOOLS[machine.type];
      ui.selectedLabel.textContent = tool.label;
      ui.selectedDetails.textContent = `Tile ${machine.x + 1},${machine.y + 1} | Facing ${DIRS[machine.dir].label} | Stock ${machine.stock.ore || 0} ore / ${machine.stock.plate || 0} plates`;
    } else {
      ui.selectedLabel.textContent = 'None';
      ui.selectedDetails.textContent = `Build direction ${DIRS[state.direction].label}. Choose a tile.`;
    }
  }

  function powerBalance() {
    let gen = 0;
    let use = 0;
    state.machines.forEach((machine) => {
      const power = TOOLS[machine.type].power;
      if (power > 0) gen += power;
      if (power < 0) use += Math.abs(power);
    });
    return { gen, use, ok: gen >= use || use === 0 };
  }

  function addPulse(x, y, color) {
    state.pulses = state.pulses || [];
    state.pulses.push({ x, y, color, life: 0.4, maxLife: 0.4 });
  }

  function updateToast(dt) {
    if (toastTimer <= 0) return;
    toastTimer -= dt;
    if (toastTimer <= 0) toast.classList.remove('is-visible');
  }

  function showToast(message) {
    toast.textContent = message;
    toast.classList.add('is-visible');
    toastTimer = 2.1;
  }

  function machineAt(x, y) {
    return state.machines.find((machine) => machine.x === x && machine.y === y) || null;
  }

  function selectedMachine() {
    return state.machines.find((machine) => machine.id === state.selectedMachineId) || null;
  }

  function resourceAt(x, y) {
    return RESOURCE_NODES.find((node) => node.x === x && node.y === y) || null;
  }

  function inside(x, y) {
    return x >= 0 && y >= 0 && x < COLS && y < ROWS;
  }

  function cellFromPointer(event) {
    const rect = canvas.getBoundingClientRect();
    const x = Math.floor((event.clientX - rect.left - layout.offsetX) / layout.tile);
    const y = Math.floor((event.clientY - rect.top - layout.offsetY) / layout.tile);
    if (!inside(x, y)) return null;
    return { x, y };
  }

  function center(x, y) {
    return {
      x: layout.offsetX + (x + 0.5) * layout.tile,
      y: layout.offsetY + (y + 0.5) * layout.tile,
    };
  }

  function cleanMachine(machine) {
    if (!machine || !TOOLS[machine.type] || machine.type === 'erase') return null;
    return {
      id: Number.isFinite(machine.id) ? machine.id : 1,
      type: machine.type,
      x: clampNumber(machine.x, 0, COLS - 1, 0),
      y: clampNumber(machine.y, 0, ROWS - 1, 0),
      dir: clampNumber(machine.dir, 0, 3, 0),
      timer: 0,
      stock: {
        ore: clampNumber(machine.stock?.ore, 0, 999, 0),
        plate: clampNumber(machine.stock?.plate, 0, 999, 0),
      },
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
