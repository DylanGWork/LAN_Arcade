#!/usr/bin/env node

import crypto from 'node:crypto';
import http from 'node:http';
import process from 'node:process';

const PORT = Number.parseInt(process.env.LAN_TANK_PORT || process.env.PORT || '8787', 10);
const HOST = process.env.LAN_TANK_HOST || '0.0.0.0';
const TICK_MS = 33;
const ARENA = { width: 1600, height: 1000 };
const MAX_PLAYERS = 8;

const rooms = new Map();
const sockets = new Set();

const server = http.createServer((req, res) => {
  const url = new URL(req.url || '/', `http://${req.headers.host || '127.0.0.1'}`);
  if (url.pathname === '/healthz' || url.pathname === '/tank-arena/healthz') {
    writeJson(res, 200, { ok: true, rooms: rooms.size, sockets: sockets.size });
    return;
  }
  if (url.pathname === '/tank-arena/status') {
    writeJson(res, 200, {
      ok: true,
      arena: ARENA,
      rooms: Array.from(rooms.values()).map((room) => ({
        id: room.id,
        players: room.players.size,
        bullets: room.bullets.length,
      })),
    });
    return;
  }
  writeJson(res, 404, { ok: false, error: 'not_found' });
});

server.on('upgrade', (req, socket) => {
  const url = new URL(req.url || '/', `http://${req.headers.host || '127.0.0.1'}`);
  if (url.pathname !== '/tank-arena/ws') {
    socket.destroy();
    return;
  }

  const key = req.headers['sec-websocket-key'];
  if (!key) {
    socket.destroy();
    return;
  }

  const accept = crypto
    .createHash('sha1')
    .update(`${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`)
    .digest('base64');

  socket.write([
    'HTTP/1.1 101 Switching Protocols',
    'Upgrade: websocket',
    'Connection: Upgrade',
    `Sec-WebSocket-Accept: ${accept}`,
    '',
    '',
  ].join('\r\n'));

  attachSocket(socket);
});

server.listen(PORT, HOST, () => {
  console.log(`LAN Tank Arena server listening on ${HOST}:${PORT}`);
});

const interval = setInterval(() => {
  for (const room of rooms.values()) tickRoom(room, TICK_MS / 1000);
}, TICK_MS);

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

function shutdown() {
  clearInterval(interval);
  for (const client of sockets) {
    try {
      client.socket.end();
    } catch {
      // ignored during shutdown
    }
  }
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 500).unref();
}

function writeJson(res, status, body) {
  const payload = `${JSON.stringify(body)}\n`;
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Content-Length': Buffer.byteLength(payload),
  });
  res.end(payload);
}

function attachSocket(socket) {
  const client = {
    id: crypto.randomUUID(),
    socket,
    buffer: Buffer.alloc(0),
    room: null,
    playerId: null,
    alive: true,
  };
  sockets.add(client);

  socket.on('data', (chunk) => {
    client.buffer = Buffer.concat([client.buffer, chunk]);
    readFrames(client);
  });
  socket.on('close', () => removeClient(client));
  socket.on('error', () => removeClient(client));

  send(client, {
    type: 'hello',
    clientId: client.id,
    arena: ARENA,
  });
}

function readFrames(client) {
  while (client.buffer.length >= 2) {
    const first = client.buffer[0];
    const second = client.buffer[1];
    const opcode = first & 0x0f;
    const masked = (second & 0x80) === 0x80;
    let length = second & 0x7f;
    let offset = 2;

    if (length === 126) {
      if (client.buffer.length < offset + 2) return;
      length = client.buffer.readUInt16BE(offset);
      offset += 2;
    } else if (length === 127) {
      if (client.buffer.length < offset + 8) return;
      const bigLength = client.buffer.readBigUInt64BE(offset);
      if (bigLength > BigInt(Number.MAX_SAFE_INTEGER)) {
        client.socket.destroy();
        return;
      }
      length = Number(bigLength);
      offset += 8;
    }

    const maskLength = masked ? 4 : 0;
    if (client.buffer.length < offset + maskLength + length) return;

    let payload = client.buffer.subarray(offset + maskLength, offset + maskLength + length);
    if (masked) {
      const mask = client.buffer.subarray(offset, offset + 4);
      payload = Buffer.from(payload.map((value, index) => value ^ mask[index % 4]));
    }
    client.buffer = client.buffer.subarray(offset + maskLength + length);

    if (opcode === 0x8) {
      removeClient(client);
      return;
    }
    if (opcode === 0x9) {
      writeFrame(client.socket, payload, 0x0a);
      continue;
    }
    if (opcode !== 0x1) continue;

    try {
      handleMessage(client, JSON.parse(payload.toString('utf8')));
    } catch {
      send(client, { type: 'error', error: 'bad_message' });
    }
  }
}

function writeFrame(socket, payload, opcode = 0x1) {
  const data = Buffer.isBuffer(payload) ? payload : Buffer.from(String(payload));
  let header;
  if (data.length < 126) {
    header = Buffer.from([0x80 | opcode, data.length]);
  } else if (data.length < 65536) {
    header = Buffer.alloc(4);
    header[0] = 0x80 | opcode;
    header[1] = 126;
    header.writeUInt16BE(data.length, 2);
  } else {
    header = Buffer.alloc(10);
    header[0] = 0x80 | opcode;
    header[1] = 127;
    header.writeBigUInt64BE(BigInt(data.length), 2);
  }
  socket.write(Buffer.concat([header, data]));
}

function send(client, message) {
  if (!client.alive || client.socket.destroyed) return;
  writeFrame(client.socket, JSON.stringify(message));
}

function broadcast(room, message) {
  const payload = JSON.stringify(message);
  for (const client of room.clients) {
    if (client.alive && !client.socket.destroyed) {
      writeFrame(client.socket, payload);
    }
  }
}

function handleMessage(client, message) {
  if (!message || typeof message.type !== 'string') return;
  if (message.type === 'join') {
    joinRoom(client, String(message.room || 'ALPHA').toUpperCase().slice(0, 12), String(message.name || 'Tank'));
  } else if (message.type === 'input') {
    const player = client.room?.players.get(client.playerId);
    if (!player) return;
    player.input = cleanInput(message.input || {});
    player.lastSeen = Date.now();
  } else if (message.type === 'ping') {
    send(client, { type: 'pong', now: Date.now() });
  }
}

function joinRoom(client, roomId, rawName) {
  if (client.room) removeClientFromRoom(client);
  const room = getRoom(roomId || 'ALPHA');
  if (room.players.size >= MAX_PLAYERS) {
    send(client, { type: 'error', error: 'room_full' });
    return;
  }

  const player = createPlayer(rawName, room.players.size);
  room.players.set(player.id, player);
  room.clients.add(client);
  client.room = room;
  client.playerId = player.id;

  send(client, {
    type: 'joined',
    playerId: player.id,
    room: room.id,
    arena: ARENA,
  });
  broadcastState(room);
}

function getRoom(roomId) {
  if (rooms.has(roomId)) return rooms.get(roomId);
  const room = {
    id: roomId,
    players: new Map(),
    clients: new Set(),
    bullets: [],
    pickups: makePickups(),
    nextBulletId: 1,
    tick: 0,
  };
  rooms.set(roomId, room);
  return room;
}

function createPlayer(rawName, index) {
  const spawns = [
    { x: 180, y: 170, angle: 0 },
    { x: 1420, y: 830, angle: Math.PI },
    { x: 1420, y: 170, angle: Math.PI },
    { x: 180, y: 830, angle: 0 },
    { x: 800, y: 160, angle: Math.PI / 2 },
    { x: 800, y: 840, angle: -Math.PI / 2 },
    { x: 200, y: 500, angle: 0 },
    { x: 1400, y: 500, angle: Math.PI },
  ];
  const colors = ['#5ec8f2', '#ef6b73', '#f3bf58', '#61d394', '#b994ff', '#ff8f5a', '#9ba9bd', '#f072b6'];
  const spawn = spawns[index % spawns.length];
  return {
    id: crypto.randomUUID(),
    name: rawName.replace(/[^\w .-]+/g, '').trim().slice(0, 18) || `Tank ${index + 1}`,
    color: colors[index % colors.length],
    x: spawn.x,
    y: spawn.y,
    angle: spawn.angle,
    hp: 100,
    shield: 0,
    score: 0,
    reload: 0,
    respawn: 0,
    input: cleanInput({}),
    lastSeen: Date.now(),
  };
}

function cleanInput(input) {
  return {
    up: Boolean(input.up),
    down: Boolean(input.down),
    left: Boolean(input.left),
    right: Boolean(input.right),
    fire: Boolean(input.fire),
  };
}

function tickRoom(room, dt) {
  room.tick += dt;
  for (const player of room.players.values()) updatePlayer(room, player, dt);
  updateBullets(room, dt);
  updatePickups(room);
  if (room.tick >= 1 / 15) {
    room.tick = 0;
    broadcastState(room);
  }
}

function updatePlayer(room, player, dt) {
  if (player.respawn > 0) {
    player.respawn -= dt;
    if (player.respawn <= 0) {
      player.hp = 100;
      player.shield = 0;
      player.x = 250 + Math.random() * (ARENA.width - 500);
      player.y = 220 + Math.random() * (ARENA.height - 440);
    }
    return;
  }

  player.reload = Math.max(0, player.reload - dt);
  if (player.input.left) player.angle -= 3.2 * dt;
  if (player.input.right) player.angle += 3.2 * dt;
  const speed = (player.input.up ? 230 : 0) + (player.input.down ? -145 : 0);
  player.x = clamp(player.x + Math.cos(player.angle) * speed * dt, 42, ARENA.width - 42);
  player.y = clamp(player.y + Math.sin(player.angle) * speed * dt, 42, ARENA.height - 42);

  if (player.input.fire && player.reload <= 0) {
    room.bullets.push({
      id: room.nextBulletId,
      ownerId: player.id,
      x: player.x + Math.cos(player.angle) * 42,
      y: player.y + Math.sin(player.angle) * 42,
      vx: Math.cos(player.angle) * 620,
      vy: Math.sin(player.angle) * 620,
      life: 1.4,
    });
    room.nextBulletId += 1;
    player.reload = 0.42;
  }
}

function updateBullets(room, dt) {
  for (const bullet of room.bullets) {
    bullet.x += bullet.vx * dt;
    bullet.y += bullet.vy * dt;
    bullet.life -= dt;
    if (bullet.x < 0 || bullet.y < 0 || bullet.x > ARENA.width || bullet.y > ARENA.height) {
      bullet.life = 0;
      continue;
    }
    for (const player of room.players.values()) {
      if (player.id === bullet.ownerId || player.respawn > 0) continue;
      if (distance(bullet, player) > 36) continue;
      const blocked = Math.min(player.shield, 20);
      player.shield = Math.max(0, player.shield - 20);
      player.hp -= Math.max(6, 28 - blocked);
      bullet.life = 0;
      if (player.hp <= 0) {
        player.hp = 0;
        player.respawn = 2.2;
        const owner = room.players.get(bullet.ownerId);
        if (owner) owner.score += 1;
      }
      break;
    }
  }
  room.bullets = room.bullets.filter((bullet) => bullet.life > 0);
}

function updatePickups(room) {
  for (const pickup of room.pickups) {
    if (pickup.cooldown > 0) {
      pickup.cooldown -= TICK_MS / 1000;
      continue;
    }
    for (const player of room.players.values()) {
      if (player.respawn > 0 || distance(pickup, player) > 42) continue;
      if (pickup.type === 'repair') player.hp = Math.min(100, player.hp + 28);
      if (pickup.type === 'shield') player.shield = Math.min(60, player.shield + 35);
      pickup.cooldown = 6;
      break;
    }
  }
}

function makePickups() {
  return [
    { id: 'repair-a', type: 'repair', x: 800, y: 500, cooldown: 0 },
    { id: 'shield-a', type: 'shield', x: 420, y: 500, cooldown: 0 },
    { id: 'shield-b', type: 'shield', x: 1180, y: 500, cooldown: 0 },
  ];
}

function broadcastState(room) {
  broadcast(room, {
    type: 'state',
    room: room.id,
    arena: ARENA,
    players: Array.from(room.players.values()).map((player) => ({
      id: player.id,
      name: player.name,
      color: player.color,
      x: round(player.x),
      y: round(player.y),
      angle: round(player.angle),
      hp: Math.round(player.hp),
      shield: Math.round(player.shield),
      score: player.score,
      respawn: Math.max(0, round(player.respawn)),
    })),
    bullets: room.bullets.map((bullet) => ({
      id: bullet.id,
      x: round(bullet.x),
      y: round(bullet.y),
    })),
    pickups: room.pickups.map((pickup) => ({
      id: pickup.id,
      type: pickup.type,
      x: pickup.x,
      y: pickup.y,
      active: pickup.cooldown <= 0,
    })),
  });
}

function removeClient(client) {
  if (!client.alive) return;
  client.alive = false;
  removeClientFromRoom(client);
  sockets.delete(client);
}

function removeClientFromRoom(client) {
  const room = client.room;
  if (!room) return;
  room.clients.delete(client);
  if (client.playerId) room.players.delete(client.playerId);
  broadcastState(room);
  if (room.clients.size === 0) rooms.delete(room.id);
  client.room = null;
  client.playerId = null;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function distance(a, b) {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

function round(value) {
  return Math.round(value * 100) / 100;
}
