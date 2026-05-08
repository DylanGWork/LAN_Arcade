(() => {
  'use strict';

  const ARENA = { width: 1600, height: 1000 };
  const params = new URLSearchParams(window.location.search);
  const defaultName = localStorage.getItem('lanTankArena.callsign') || '';
  const defaultRoom = localStorage.getItem('lanTankArena.room') || 'ALPHA';

  const canvas = document.getElementById('gameCanvas');
  const ctx = canvas.getContext('2d');
  const toast = document.getElementById('toast');
  const ui = {
    status: document.getElementById('statusValue'),
    room: document.getElementById('roomValue'),
    players: document.getElementById('playersValue'),
    callsign: document.getElementById('callsignLabel'),
    nameInput: document.getElementById('nameInput'),
    roomInput: document.getElementById('roomInput'),
    joinButton: document.getElementById('joinButton'),
    driveButton: document.getElementById('driveButton'),
    turnLeftButton: document.getElementById('turnLeftButton'),
    turnRightButton: document.getElementById('turnRightButton'),
    fireButton: document.getElementById('fireButton'),
    hp: document.getElementById('hpValue'),
    shield: document.getElementById('shieldValue'),
    score: document.getElementById('scoreValue'),
    leader: document.getElementById('leaderValue'),
    scoreboard: document.getElementById('scoreboard'),
  };

  let socket = null;
  let playerId = null;
  let state = {
    connected: false,
    room: defaultRoom,
    arena: ARENA,
    players: [],
    bullets: [],
    pickups: [],
  };
  let input = { up: false, down: false, left: false, right: false, fire: false };
  let layout = { width: 1000, height: 700, scale: 0.6, offsetX: 20, offsetY: 50 };
  let lastFrame = performance.now();
  let toastTimer = 0;
  let inputTimer = 0;

  ui.nameInput.value = params.get('name') || defaultName;
  ui.roomInput.value = params.get('room') || defaultRoom;

  bindEvents();
  installQaHooks();
  resizeCanvas();
  updateUi();
  requestAnimationFrame(frame);

  function bindEvents() {
    window.addEventListener('resize', resizeCanvas);
    ui.nameInput.addEventListener('input', updateUi);
    ui.roomInput.addEventListener('input', updateUi);
    ui.joinButton.addEventListener('click', () => joinArena());

    bindHold(ui.driveButton, { up: true });
    bindHold(ui.turnLeftButton, { left: true });
    bindHold(ui.turnRightButton, { right: true });
    bindHold(ui.fireButton, { fire: true });

    window.addEventListener('keydown', (event) => {
      if (event.repeat) return;
      setKey(event.key, true);
    });
    window.addEventListener('keyup', (event) => setKey(event.key, false));
  }

  function installQaHooks() {
    window.__lanTankQa = {
      join: (name = 'QA Tank', room = 'QA') => {
        ui.nameInput.value = name;
        ui.roomInput.value = room;
        updateUi();
        joinArena();
      },
      input: (nextInput = {}) => {
        input = { ...input, ...nextInput };
        sendInput();
      },
      waitForPlayers: (count = 2) => new Promise((resolve) => {
        const started = Date.now();
        const timer = window.setInterval(() => {
          if (state.players.length >= count || Date.now() - started > 7000) {
            window.clearInterval(timer);
            resolve(state.players.length);
          }
        }, 100);
      }),
      snapshot: () => ({ playerId, state }),
    };
  }

  function joinArena() {
    const name = ui.nameInput.value.trim();
    const room = ui.roomInput.value.trim().toUpperCase() || 'ALPHA';
    if (!name) {
      showToast('Enter a callsign first.');
      return;
    }
    localStorage.setItem('lanTankArena.callsign', name);
    localStorage.setItem('lanTankArena.room', room);

    closeSocket();
    const wsUrl = params.get('server') || defaultServerUrl();
    socket = new WebSocket(wsUrl);
    ui.status.textContent = 'Linking';
    showToast('Connecting to LAN arena server...');

    socket.addEventListener('open', () => {
      socket.send(JSON.stringify({ type: 'join', name, room }));
      sendInput();
    });
    socket.addEventListener('message', (event) => handleMessage(JSON.parse(event.data)));
    socket.addEventListener('close', () => {
      state.connected = false;
      updateUi();
      showToast('Disconnected from arena server.');
    });
    socket.addEventListener('error', () => showToast('Arena server not reachable.'));
  }

  function defaultServerUrl() {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = params.get('host') || window.location.hostname || '127.0.0.1';
    const port = params.get('port') || '8787';
    return `${protocol}//${host}:${port}/tank-arena/ws`;
  }

  function closeSocket() {
    if (socket && socket.readyState < WebSocket.CLOSING) socket.close();
    socket = null;
    playerId = null;
  }

  function handleMessage(message) {
    if (message.type === 'joined') {
      playerId = message.playerId;
      state.connected = true;
      state.room = message.room;
      state.arena = message.arena || ARENA;
      showToast(`Joined room ${message.room}.`);
    } else if (message.type === 'state') {
      state = {
        ...state,
        connected: true,
        room: message.room,
        arena: message.arena || ARENA,
        players: Array.isArray(message.players) ? message.players : [],
        bullets: Array.isArray(message.bullets) ? message.bullets : [],
        pickups: Array.isArray(message.pickups) ? message.pickups : [],
      };
    } else if (message.type === 'error') {
      showToast(`Server: ${message.error}`);
    }
    updateUi();
  }

  function setKey(key, value) {
    const lower = key.toLowerCase();
    if (lower === 'w' || key === 'ArrowUp') input.up = value;
    if (lower === 's' || key === 'ArrowDown') input.down = value;
    if (lower === 'a' || key === 'ArrowLeft') input.left = value;
    if (lower === 'd' || key === 'ArrowRight') input.right = value;
    if (key === ' ' || lower === 'f') input.fire = value;
    sendInput();
  }

  function bindHold(button, values) {
    const on = (event) => {
      event.preventDefault();
      input = { ...input, ...values };
      sendInput();
    };
    const off = (event) => {
      event.preventDefault();
      for (const key of Object.keys(values)) input[key] = false;
      sendInput();
    };
    button.addEventListener('pointerdown', on);
    button.addEventListener('pointerup', off);
    button.addEventListener('pointercancel', off);
    button.addEventListener('pointerleave', off);
  }

  function sendInput() {
    if (!socket || socket.readyState !== WebSocket.OPEN) return;
    socket.send(JSON.stringify({ type: 'input', input }));
  }

  function resizeCanvas() {
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.max(1, Math.floor(rect.width * dpr));
    canvas.height = Math.max(1, Math.floor(rect.height * dpr));
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    layout.width = rect.width;
    layout.height = rect.height;
    layout.scale = Math.min(rect.width / ARENA.width, rect.height / ARENA.height) * 0.92;
    layout.offsetX = (rect.width - ARENA.width * layout.scale) / 2;
    layout.offsetY = (rect.height - ARENA.height * layout.scale) / 2;
  }

  function frame(now) {
    const dt = Math.min(0.05, (now - lastFrame) / 1000);
    lastFrame = now;
    inputTimer += dt;
    if (inputTimer > 0.06) {
      inputTimer = 0;
      sendInput();
    }
    updateToast(dt);
    draw();
    requestAnimationFrame(frame);
  }

  function draw() {
    ctx.clearRect(0, 0, layout.width, layout.height);
    drawBackdrop();
    drawArena();
    drawPickups();
    drawBullets();
    drawPlayers();
    if (!state.connected) drawLobbyOverlay();
  }

  function drawBackdrop() {
    const gradient = ctx.createLinearGradient(0, 0, layout.width, layout.height);
    gradient.addColorStop(0, '#101722');
    gradient.addColorStop(1, '#11111b');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, layout.width, layout.height);
    ctx.fillStyle = 'rgba(94, 200, 242, 0.08)';
    for (let i = 0; i < 24; i += 1) {
      ctx.fillRect((i * 103) % layout.width, (i * 47) % layout.height, 2, 2);
    }
  }

  function drawArena() {
    const area = worldRect();
    ctx.save();
    ctx.fillStyle = '#0b1018';
    ctx.fillRect(area.x, area.y, area.w, area.h);
    ctx.strokeStyle = '#303c52';
    ctx.lineWidth = 2;
    ctx.strokeRect(area.x, area.y, area.w, area.h);

    ctx.strokeStyle = 'rgba(174, 184, 200, 0.08)';
    ctx.lineWidth = 1;
    for (let x = 0; x <= ARENA.width; x += 160) {
      const sx = area.x + x * layout.scale;
      ctx.beginPath();
      ctx.moveTo(sx, area.y);
      ctx.lineTo(sx, area.y + area.h);
      ctx.stroke();
    }
    for (let y = 0; y <= ARENA.height; y += 160) {
      const sy = area.y + y * layout.scale;
      ctx.beginPath();
      ctx.moveTo(area.x, sy);
      ctx.lineTo(area.x + area.w, sy);
      ctx.stroke();
    }

    drawBlock(520, 330, 220, 90);
    drawBlock(860, 580, 220, 90);
    drawBlock(730, 120, 140, 120);
    drawBlock(730, 760, 140, 120);
    ctx.restore();
  }

  function drawBlock(x, y, w, h) {
    const p = worldToScreen(x, y);
    ctx.fillStyle = 'rgba(74, 89, 113, 0.58)';
    roundRect(ctx, p.x, p.y, w * layout.scale, h * layout.scale, 8);
    ctx.fill();
    ctx.strokeStyle = 'rgba(174, 184, 200, 0.14)';
    ctx.stroke();
  }

  function drawPickups() {
    for (const pickup of state.pickups) {
      const p = worldToScreen(pickup.x, pickup.y);
      ctx.save();
      ctx.globalAlpha = pickup.active ? 1 : 0.2;
      ctx.fillStyle = pickup.type === 'repair' ? '#61d394' : '#5ec8f2';
      ctx.beginPath();
      ctx.arc(p.x, p.y, 18 * layout.scale, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#101722';
      ctx.lineWidth = 3;
      ctx.stroke();
      ctx.fillStyle = '#101722';
      ctx.font = `900 ${Math.max(10, 18 * layout.scale)}px system-ui`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(pickup.type === 'repair' ? '+' : 'S', p.x, p.y);
      ctx.restore();
    }
  }

  function drawBullets() {
    ctx.fillStyle = '#f3bf58';
    for (const bullet of state.bullets) {
      const p = worldToScreen(bullet.x, bullet.y);
      ctx.beginPath();
      ctx.arc(p.x, p.y, Math.max(2, 5 * layout.scale), 0, Math.PI * 2);
      ctx.fill();
    }
  }

  function drawPlayers() {
    for (const player of state.players) {
      const p = worldToScreen(player.x, player.y);
      const r = 31 * layout.scale;
      ctx.save();
      ctx.translate(p.x, p.y);
      ctx.rotate(player.angle);
      ctx.fillStyle = player.color;
      ctx.strokeStyle = player.id === playerId ? '#ffffff' : '#0d1119';
      ctx.lineWidth = player.id === playerId ? 4 : 2.5;
      roundRect(ctx, -r, -r * 0.72, r * 2, r * 1.44, 7);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = '#0d1119';
      ctx.fillRect(r * 0.1, -r * 0.16, r * 1.08, r * 0.32);
      ctx.restore();

      drawHealthBar(p.x, p.y - r - 14, player.hp, 100, '#61d394');
      if (player.shield > 0) drawHealthBar(p.x, p.y - r - 7, player.shield, 60, '#5ec8f2');
      ctx.fillStyle = '#f4f7fb';
      ctx.font = `800 ${Math.max(10, 14 * layout.scale)}px system-ui`;
      ctx.textAlign = 'center';
      ctx.fillText(player.name, p.x, p.y + r + 18);

      if (player.respawn > 0) {
        ctx.fillStyle = 'rgba(8, 13, 20, 0.62)';
        ctx.beginPath();
        ctx.arc(p.x, p.y, r * 1.5, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }

  function drawHealthBar(x, y, value, max, color) {
    const width = 64 * layout.scale;
    const height = Math.max(4, 6 * layout.scale);
    ctx.fillStyle = 'rgba(8, 10, 14, 0.82)';
    ctx.fillRect(x - width / 2, y, width, height);
    ctx.fillStyle = color;
    ctx.fillRect(x - width / 2, y, width * Math.max(0, Math.min(1, value / max)), height);
  }

  function drawLobbyOverlay() {
    ctx.save();
    ctx.fillStyle = 'rgba(8, 12, 18, 0.66)';
    ctx.fillRect(0, 0, layout.width, layout.height);
    ctx.fillStyle = '#f4f7fb';
    ctx.font = '900 34px system-ui';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('Waiting For LAN Arena', layout.width / 2, layout.height / 2 - 28);
    ctx.fillStyle = '#aeb8c8';
    ctx.font = '800 15px system-ui';
    ctx.fillText('Start the local tank server, enter a callsign, then join a room.', layout.width / 2, layout.height / 2 + 18);
    ctx.restore();
  }

  function updateUi() {
    const name = ui.nameInput.value.trim();
    const room = ui.roomInput.value.trim().toUpperCase() || 'ALPHA';
    const me = state.players.find((player) => player.id === playerId);
    const sorted = [...state.players].sort((a, b) => b.score - a.score || a.name.localeCompare(b.name));

    ui.joinButton.disabled = !name;
    ui.status.textContent = state.connected ? 'Online' : socket ? 'Linking' : 'Lobby';
    ui.room.textContent = state.connected ? state.room : room;
    ui.players.textContent = String(state.players.length);
    ui.callsign.textContent = me ? me.name : name || 'Offline';
    ui.hp.textContent = me ? String(me.hp) : '--';
    ui.shield.textContent = me ? String(me.shield) : '--';
    ui.score.textContent = me ? String(me.score) : '0';
    ui.leader.textContent = sorted[0] ? sorted[0].name : 'None';

    ui.scoreboard.innerHTML = '';
    if (sorted.length === 0) {
      const empty = document.createElement('div');
      empty.className = 'score-row';
      empty.textContent = 'No tanks deployed.';
      ui.scoreboard.append(empty);
    } else {
      for (const player of sorted) {
        const row = document.createElement('div');
        row.className = 'score-row';
        const chip = document.createElement('span');
        chip.className = 'score-chip';
        chip.style.background = player.color;
        const label = document.createElement('span');
        label.className = 'score-name';
        label.textContent = player.name;
        const score = document.createElement('strong');
        score.textContent = String(player.score);
        row.append(chip, label, score);
        ui.scoreboard.append(row);
      }
    }
  }

  function updateToast(dt) {
    if (toastTimer <= 0) return;
    toastTimer -= dt;
    if (toastTimer <= 0) toast.classList.remove('is-visible');
  }

  function showToast(message) {
    toast.textContent = message;
    toast.classList.add('is-visible');
    toastTimer = 2.2;
  }

  function worldRect() {
    return {
      x: layout.offsetX,
      y: layout.offsetY,
      w: ARENA.width * layout.scale,
      h: ARENA.height * layout.scale,
    };
  }

  function worldToScreen(x, y) {
    return {
      x: layout.offsetX + x * layout.scale,
      y: layout.offsetY + y * layout.scale,
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
})();
