// LAST LIGHT — a top-down zombie apocalypse survival shooter.
// Plain JavaScript + Canvas 2D, no dependencies.
(() => {
  'use strict';

  // ---------- Setup ----------
  const canvas = document.getElementById('game');
  const ctx = canvas.getContext('2d');
  const $ = (id) => document.getElementById(id);
  let W = 0, H = 0, DPR = 1;

  function resize() {
    DPR = Math.min(window.devicePixelRatio || 1, 2);
    W = window.innerWidth; H = window.innerHeight;
    canvas.width = Math.floor(W * DPR); canvas.height = Math.floor(H * DPR);
    darkCanvas.width = canvas.width; darkCanvas.height = canvas.height;
  }
  const darkCanvas = document.createElement('canvas');
  const dctx = darkCanvas.getContext('2d');
  window.addEventListener('resize', resize);
  resize();

  const WORLD = 2400;
  const TAU = Math.PI * 2;
  const rand = (a, b) => a + Math.random() * (b - a);
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const dist2 = (ax, ay, bx, by) => (ax - bx) ** 2 + (ay - by) ** 2;

  let best = 0;
  try { best = +localStorage.getItem('lastlight-best') || 0; } catch (e) { /* storage unavailable */ }

  // ---------- Audio (synthesized) ----------
  let actx = null;
  function audio() {
    if (!actx) { try { actx = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { return null; } }
    if (actx.state === 'suspended') actx.resume();
    return actx;
  }
  function noise(dur, freq, vol, type = 'lowpass') {
    const a = audio(); if (!a) return;
    const len = Math.floor(a.sampleRate * dur);
    const buf = a.createBuffer(1, len, a.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / len) ** 2;
    const src = a.createBufferSource(); src.buffer = buf;
    const f = a.createBiquadFilter(); f.type = type; f.frequency.value = freq;
    const g = a.createGain(); g.gain.value = vol;
    src.connect(f).connect(g).connect(a.destination); src.start();
  }
  function tone(f1, f2, dur, vol, type = 'sawtooth') {
    const a = audio(); if (!a) return;
    const o = a.createOscillator(); o.type = type;
    const g = a.createGain();
    o.frequency.setValueAtTime(f1, a.currentTime);
    o.frequency.exponentialRampToValueAtTime(Math.max(f2, 1), a.currentTime + dur);
    g.gain.setValueAtTime(vol, a.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001, a.currentTime + dur);
    o.connect(g).connect(a.destination); o.start(); o.stop(a.currentTime + dur);
  }
  const sfx = {
    pistol: () => noise(0.12, 2200, 0.25),
    shotgun: () => noise(0.3, 1200, 0.45),
    smg: () => noise(0.07, 2800, 0.15),
    empty: () => tone(900, 700, 0.05, 0.08, 'square'),
    reload: () => { tone(300, 200, 0.06, 0.1, 'square'); setTimeout(() => tone(500, 400, 0.06, 0.1, 'square'), 120); },
    hit: () => noise(0.05, 600, 0.12),
    die: () => tone(140, 50, 0.4, 0.12),
    groan: () => tone(rand(70, 110), rand(40, 60), rand(0.6, 1.1), 0.04),
    hurt: () => tone(220, 90, 0.2, 0.15, 'square'),
    pickup: () => tone(600, 1200, 0.1, 0.08, 'triangle'),
    boom: () => { noise(0.8, 400, 0.7); tone(80, 30, 0.6, 0.3, 'sine'); },
    spit: () => noise(0.15, 900, 0.1, 'bandpass'),
  };

  // ---------- Input ----------
  const keys = new Set();
  const mouse = { x: 0, y: 0, down: false };
  const touch = { move: null, aim: null, active: false };

  window.addEventListener('keydown', (e) => {
    const k = e.key.toLowerCase();
    keys.add(k);
    if (state !== 'playing' && state !== 'paused') return;
    if (k === 'p' || k === 'escape') togglePause();
    if (state !== 'playing') return;
    if (k === '1') switchWeapon(0);
    if (k === '2') switchWeapon(1);
    if (k === '3') switchWeapon(2);
    if (k === 'q') cycleWeapon(1);
    if (k === 'r') startReload();
    if (k === 'g') throwGrenade();
    if ([' ', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright'].includes(k)) e.preventDefault();
  });
  window.addEventListener('keyup', (e) => keys.delete(e.key.toLowerCase()));
  canvas.addEventListener('mousemove', (e) => { mouse.x = e.clientX; mouse.y = e.clientY; touch.active = false; });
  canvas.addEventListener('mousedown', (e) => {
    audio();
    if (e.button === 2) { throwGrenade(); return; }
    mouse.down = true;
  });
  window.addEventListener('mouseup', () => { mouse.down = false; });
  canvas.addEventListener('contextmenu', (e) => e.preventDefault());
  canvas.addEventListener('wheel', (e) => { if (state === 'playing') cycleWeapon(e.deltaY > 0 ? 1 : -1); }, { passive: true });
  window.addEventListener('blur', () => { keys.clear(); mouse.down = false; if (state === 'playing') togglePause(); });

  // Touch: left half = move stick, right half = aim/fire stick, top-right buttons
  const touchButtons = () => [
    { id: 'swap', x: W - 50, y: 190, r: 28, label: 'SW' },
    { id: 'nade', x: W - 50, y: 255, r: 28, label: 'G' },
    { id: 'reload', x: W - 50, y: 320, r: 28, label: 'R' },
  ];
  canvas.addEventListener('touchstart', (e) => {
    e.preventDefault(); audio(); touch.active = true;
    for (const t of e.changedTouches) {
      const btn = touchButtons().find((b) => dist2(t.clientX, t.clientY, b.x, b.y) < (b.r + 8) ** 2);
      if (btn && state === 'playing') {
        if (btn.id === 'swap') cycleWeapon(1);
        if (btn.id === 'nade') throwGrenade();
        if (btn.id === 'reload') startReload();
        continue;
      }
      const stick = { id: t.identifier, ox: t.clientX, oy: t.clientY, x: t.clientX, y: t.clientY };
      if (t.clientX < W / 2) { if (!touch.move) touch.move = stick; }
      else if (!touch.aim) touch.aim = stick;
    }
  }, { passive: false });
  canvas.addEventListener('touchmove', (e) => {
    e.preventDefault();
    for (const t of e.changedTouches) {
      for (const s of [touch.move, touch.aim]) if (s && s.id === t.identifier) { s.x = t.clientX; s.y = t.clientY; }
    }
  }, { passive: false });
  const endTouch = (e) => {
    for (const t of e.changedTouches) {
      if (touch.move && touch.move.id === t.identifier) touch.move = null;
      if (touch.aim && touch.aim.id === t.identifier) touch.aim = null;
    }
  };
  canvas.addEventListener('touchend', endTouch);
  canvas.addEventListener('touchcancel', endTouch);

  // ---------- Definitions ----------
  const WEAPONS = [
    { name: 'Pistol', dmg: 26, rate: 0.28, mag: 12, reload: 1.0, spread: 0.04, pellets: 1, speed: 950, sound: 'pistol', infinite: true, kick: 2 },
    { name: 'Shotgun', dmg: 15, rate: 0.75, mag: 6, reload: 1.6, spread: 0.32, pellets: 8, speed: 850, sound: 'shotgun', kick: 7 },
    { name: 'SMG', dmg: 14, rate: 0.075, mag: 32, reload: 1.4, spread: 0.12, pellets: 1, speed: 1000, sound: 'smg', kick: 1.5 },
  ];

  const ZTYPES = {
    walker: { hp: 55, speed: 55, dmg: 10, r: 14, scrap: 1, color: '#5d7a3a', skin: '#7f9b55' },
    runner: { hp: 32, speed: 125, dmg: 7, r: 11, scrap: 1, color: '#7a5d3a', skin: '#a3895c' },
    brute: { hp: 280, speed: 40, dmg: 24, r: 24, scrap: 4, color: '#4a3a5d', skin: '#6c5a82' },
    spitter: { hp: 48, speed: 50, dmg: 12, r: 13, scrap: 2, color: '#3a6d5d', skin: '#5fa88f', ranged: true },
    boss: { hp: 1800, speed: 62, dmg: 35, r: 40, scrap: 40, color: '#6d2a2a', skin: '#9a4040', boss: true },
  };

  // ---------- World generation ----------
  let obstacles = [];
  let ground = null;

  function makeWorld() {
    obstacles = [];
    const safe = 260;
    const c = WORLD / 2;
    const overlaps = (r, pad) => obstacles.some((o) =>
      r.x < o.x + o.w + pad && r.x + r.w + pad > o.x && r.y < o.y + o.h + pad && r.y + r.h + pad > o.y);
    // Buildings
    for (let i = 0; i < 400 && obstacles.length < 28; i++) {
      const r = { x: rand(80, WORLD - 300), y: rand(80, WORLD - 300), w: rand(120, 260), h: rand(110, 240), kind: 'building' };
      if (Math.abs(r.x + r.w / 2 - c) < safe + r.w / 2 && Math.abs(r.y + r.h / 2 - c) < safe + r.h / 2) continue;
      if (!overlaps(r, 110)) obstacles.push(r);
    }
    // Wrecked cars
    for (let i = 0; i < 400 && obstacles.length < 62; i++) {
      const horiz = Math.random() < 0.5;
      const r = { x: rand(60, WORLD - 120), y: rand(60, WORLD - 120), w: horiz ? 76 : 38, h: horiz ? 38 : 76, kind: 'car',
        hue: [ '#6b2b2b', '#2b4a6b', '#5a5a5a', '#6b5b2b', '#2b6b4a' ][i % 5] };
      if (dist2(r.x + r.w / 2, r.y + r.h / 2, c, c) < (safe - 60) ** 2) continue;
      if (!overlaps(r, 50)) obstacles.push(r);
    }

    // Pre-render ground (asphalt, cracks, debris) — blood decals get painted onto it later
    ground = document.createElement('canvas');
    ground.width = WORLD; ground.height = WORLD;
    const g = ground.getContext('2d');
    g.fillStyle = '#26271f'; g.fillRect(0, 0, WORLD, WORLD);
    for (let i = 0; i < 9000; i++) {
      g.fillStyle = `rgba(${Math.random() < 0.5 ? '255,255,240' : '0,0,0'},${rand(0.02, 0.07)})`;
      const s = rand(2, 9); g.fillRect(rand(0, WORLD), rand(0, WORLD), s, s);
    }
    // Road grid
    g.fillStyle = '#1f201b';
    for (let p = 300; p < WORLD; p += 600) { g.fillRect(p - 70, 0, 140, WORLD); g.fillRect(0, p - 70, WORLD, 140); }
    g.strokeStyle = 'rgba(220,190,90,0.35)'; g.lineWidth = 4; g.setLineDash([30, 30]);
    for (let p = 300; p < WORLD; p += 600) {
      g.beginPath(); g.moveTo(p, 0); g.lineTo(p, WORLD); g.stroke();
      g.beginPath(); g.moveTo(0, p); g.lineTo(WORLD, p); g.stroke();
    }
    g.setLineDash([]);
    // Cracks
    g.strokeStyle = 'rgba(0,0,0,0.45)'; g.lineWidth = 1.5;
    for (let i = 0; i < 180; i++) {
      let x = rand(0, WORLD), y = rand(0, WORLD), a = rand(0, TAU);
      g.beginPath(); g.moveTo(x, y);
      for (let j = 0; j < 7; j++) { a += rand(-0.8, 0.8); x += Math.cos(a) * rand(10, 30); y += Math.sin(a) * rand(10, 30); g.lineTo(x, y); }
      g.stroke();
    }
    // Weeds
    for (let i = 0; i < 500; i++) {
      g.fillStyle = `rgba(${60 + rand(0, 40) | 0},${90 + rand(0, 50) | 0},40,0.5)`;
      g.beginPath(); g.arc(rand(0, WORLD), rand(0, WORLD), rand(3, 10), 0, TAU); g.fill();
    }
    // Old scorch marks
    for (let i = 0; i < 30; i++) {
      const x = rand(0, WORLD), y = rand(0, WORLD), r = rand(30, 90);
      const grd = g.createRadialGradient(x, y, 0, x, y, r);
      grd.addColorStop(0, 'rgba(0,0,0,0.6)'); grd.addColorStop(1, 'rgba(0,0,0,0)');
      g.fillStyle = grd; g.fillRect(x - r, y - r, r * 2, r * 2);
    }
  }

  function paintDecal(x, y, r, color) {
    const g = ground.getContext('2d');
    g.fillStyle = color;
    for (let i = 0; i < 5; i++) {
      g.beginPath(); g.arc(x + rand(-r, r), y + rand(-r, r), rand(r * 0.3, r * 0.8), 0, TAU); g.fill();
    }
  }

  // ---------- Game state ----------
  let state = 'menu';
  let player, zombies, bullets, enemyShots, pickups, particles, grenades, floaters;
  let night, toSpawn, spawnTimer, kills, scrapTotal, shake, camX, camY, time, groanTimer, nightTime;
  let upgrades;

  function newGame() {
    makeWorld();
    player = {
      x: WORLD / 2, y: WORLD / 2, r: 14, angle: 0, hp: 100, maxHp: 100, speed: 195,
      weapon: 0, owned: [true, false, false], mag: [12, 6, 32], reserve: [Infinity, 0, 0],
      cooldown: 0, reloading: 0, hurtFlash: 0, scrap: 0, grenades: 2, walk: 0,
    };
    upgrades = { maxHp: 0, dmg: 0, speed: 0, reloadSpd: 0 };
    zombies = []; bullets = []; enemyShots = []; pickups = []; particles = []; grenades = []; floaters = [];
    night = 0; kills = 0; scrapTotal = 0; shake = 0; time = 0; groanTimer = 2;
    camX = player.x - W / 2; camY = player.y - H / 2;
    startNight();
  }

  function startNight() {
    night++;
    toSpawn = 8 + night * 6;
    if (night % 5 === 0) toSpawn += 1; // boss counts as one
    spawnTimer = 1.5; nightTime = 0;
    state = 'playing';
    showOverlay(null);
    $('hud').classList.remove('hidden');
    banner(night % 5 === 0 ? `NIGHT ${night} — SOMETHING BIG IS COMING` : `NIGHT ${night}`);
  }

  let bannerTimeout;
  function banner(text) {
    const b = $('banner'); b.textContent = text; b.classList.add('show');
    clearTimeout(bannerTimeout); bannerTimeout = setTimeout(() => b.classList.remove('show'), 2400);
  }

  function showOverlay(id) {
    for (const o of ['menu', 'shop', 'pause', 'over']) $(o).classList.toggle('hidden', o !== id);
  }

  function togglePause() {
    if (state === 'playing') { state = 'paused'; showOverlay('pause'); }
    else if (state === 'paused') { state = 'playing'; showOverlay(null); last = performance.now(); }
  }

  // ---------- Weapons ----------
  function weaponDef(i = player.weapon) { return WEAPONS[i]; }
  function switchWeapon(i) {
    if (!player.owned[i] || player.weapon === i) return;
    player.weapon = i; player.reloading = 0; player.cooldown = 0.15;
  }
  function cycleWeapon(dir) {
    for (let s = 1; s <= 3; s++) {
      const i = (player.weapon + dir * s + 3) % 3;
      if (player.owned[i]) { switchWeapon(i); return; }
    }
  }
  function reloadTime() { return weaponDef().reload * (1 - 0.12 * upgrades.reloadSpd); }
  function startReload() {
    const w = weaponDef(), i = player.weapon;
    if (player.reloading > 0 || player.mag[i] >= w.mag || player.reserve[i] <= 0) return;
    player.reloading = reloadTime(); sfx.reload();
  }
  function finishReload() {
    const w = weaponDef(), i = player.weapon;
    const need = w.mag - player.mag[i];
    const take = Math.min(need, player.reserve[i]);
    player.mag[i] += take;
    if (player.reserve[i] !== Infinity) player.reserve[i] -= take;
  }

  function fire() {
    const w = weaponDef(), i = player.weapon;
    if (player.cooldown > 0 || player.reloading > 0) return;
    if (player.mag[i] <= 0) {
      player.cooldown = 0.25;
      if (player.reserve[i] > 0) startReload(); else sfx.empty();
      return;
    }
    player.mag[i]--; player.cooldown = w.rate;
    const dmgMul = 1 + 0.15 * upgrades.dmg;
    const mx = player.x + Math.cos(player.angle) * 22, my = player.y + Math.sin(player.angle) * 22;
    for (let p = 0; p < w.pellets; p++) {
      const a = player.angle + rand(-w.spread, w.spread);
      const sp = w.speed * rand(0.9, 1.05);
      bullets.push({ x: mx, y: my, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, dmg: w.dmg * dmgMul, life: 0.7, pierce: w.pellets > 1 ? 0 : 1 });
    }
    for (let k = 0; k < 5; k++) particles.push({ x: mx, y: my, vx: Math.cos(player.angle + rand(-0.5, 0.5)) * rand(100, 300), vy: Math.sin(player.angle + rand(-0.5, 0.5)) * rand(100, 300), life: 0.1, max: 0.1, size: 3, color: '#ffd27a' });
    flash = 0.06;
    shake = Math.max(shake, w.kick);
    sfx[w.sound]();
    if (player.mag[i] === 0 && player.reserve[i] > 0) startReload();
  }
  let flash = 0;

  function throwGrenade() {
    if (state !== 'playing' || player.grenades <= 0) return;
    player.grenades--;
    const tx = player.x + Math.cos(player.angle) * 320, ty = player.y + Math.sin(player.angle) * 320;
    grenades.push({ x: player.x, y: player.y, sx: player.x, sy: player.y, tx, ty, t: 0, dur: 0.8 });
  }

  function explode(x, y) {
    sfx.boom(); shake = 18;
    const R = 150;
    for (const z of zombies) {
      const d = Math.sqrt(dist2(x, y, z.x, z.y));
      if (d < R + z.r) {
        damageZombie(z, 180 * (1 - d / (R + z.r) * 0.6) * (1 + 0.15 * upgrades.dmg), x, y, 500);
      }
    }
    const pd = Math.sqrt(dist2(x, y, player.x, player.y));
    if (pd < R * 0.7) hurtPlayer(25 * (1 - pd / (R * 0.7)));
    for (let k = 0; k < 50; k++) {
      const a = rand(0, TAU), s = rand(50, 450);
      particles.push({ x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: rand(0.3, 0.8), max: 0.8, size: rand(3, 8), color: ['#ffb347', '#ff6a2a', '#ffe17a', '#555'][k % 4] });
    }
    paintDecal(x, y, 40, 'rgba(10,8,6,0.5)');
    explosions.push({ x, y, t: 0 });
  }
  let explosions = [];

  // ---------- Zombies ----------
  function spawnZombie(type) {
    const t = ZTYPES[type];
    // spawn just outside the view, inside the world
    let x, y, tries = 0;
    do {
      const a = rand(0, TAU), d = Math.max(W, H) * 0.6 + rand(40, 200);
      x = clamp(player.x + Math.cos(a) * d, 30, WORLD - 30);
      y = clamp(player.y + Math.sin(a) * d, 30, WORLD - 30);
      tries++;
    } while ((blocked(x, y, t.r) || dist2(x, y, player.x, player.y) < 400 ** 2) && tries < 30);
    const scale = 1 + 0.13 * (night - 1);
    zombies.push({
      type, x, y, r: t.r, hp: t.hp * scale, maxHp: t.hp * scale, speed: t.speed * rand(0.85, 1.15) * (1 + 0.02 * night),
      dmg: t.dmg * (1 + 0.05 * (night - 1)), attackCd: 0, shootCd: rand(1, 3), wobble: rand(0, TAU), hitFlash: 0, kx: 0, ky: 0,
      def: t,
    });
  }

  function pickType() {
    if (night % 5 === 0 && !zombies.some((z) => z.def.boss) && toSpawn === 1) return 'boss';
    const r = Math.random();
    if (night >= 4 && r < 0.12) return 'spitter';
    if (night >= 3 && r < 0.22) return 'brute';
    if (night >= 2 && r < 0.45) return 'runner';
    return 'walker';
  }

  function damageZombie(z, dmg, fx, fy, knock = 120) {
    if (z.hp <= 0) return;
    z.hp -= dmg; z.hitFlash = 0.08;
    const a = Math.atan2(z.y - fy, z.x - fx);
    const k = knock / (z.def.boss ? 6 : z.type === 'brute' ? 3 : 1);
    z.kx += Math.cos(a) * k; z.ky += Math.sin(a) * k;
    for (let i = 0; i < 4; i++) particles.push({ x: z.x, y: z.y, vx: Math.cos(a + rand(-0.6, 0.6)) * rand(60, 220), vy: Math.sin(a + rand(-0.6, 0.6)) * rand(60, 220), life: 0.35, max: 0.35, size: rand(2, 4), color: '#5a1010' });
    if (z.hp <= 0) killZombie(z);
  }

  function killZombie(z) {
    kills++; sfx.die();
    paintDecal(z.x, z.y, z.r, 'rgba(70,8,8,0.55)');
    for (let i = 0; i < 14; i++) {
      const a = rand(0, TAU), s = rand(40, 260);
      particles.push({ x: z.x, y: z.y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: rand(0.3, 0.7), max: 0.7, size: rand(2, 6), color: i % 3 ? '#6a0f0f' : z.def.skin });
    }
    pickups.push({ x: z.x, y: z.y, kind: 'scrap', value: z.def.scrap, t: 0 });
    const r = Math.random();
    if (z.def.boss) {
      pickups.push({ x: z.x + 20, y: z.y, kind: 'med', t: 0 });
      pickups.push({ x: z.x - 20, y: z.y, kind: 'nade', t: 0 });
    } else if (r < 0.04) pickups.push({ x: z.x + 10, y: z.y, kind: 'med', t: 0 });
    else if (r < 0.15) pickups.push({ x: z.x + 10, y: z.y, kind: 'ammo', t: 0 });
    else if (r < 0.17) pickups.push({ x: z.x + 10, y: z.y, kind: 'nade', t: 0 });
    if (z.def.boss) { shake = 25; banner('THE BEAST FALLS'); }
  }

  function hurtPlayer(d) {
    if (d <= 0) return;
    player.hp -= d; player.hurtFlash = 0.3; shake = Math.max(shake, 6); sfx.hurt();
    paintDecal(player.x, player.y, 6, 'rgba(90,10,10,0.5)');
    if (player.hp <= 0) gameOver();
  }

  // ---------- Collision ----------
  function circleRect(x, y, r, o) {
    const cx = clamp(x, o.x, o.x + o.w), cy = clamp(y, o.y, o.y + o.h);
    return dist2(x, y, cx, cy) < r * r;
  }
  function blocked(x, y, r) { return obstacles.some((o) => circleRect(x, y, r, o)); }
  function resolve(e) {
    for (const o of obstacles) {
      const cx = clamp(e.x, o.x, o.x + o.w), cy = clamp(e.y, o.y, o.y + o.h);
      const d2 = dist2(e.x, e.y, cx, cy);
      if (d2 < e.r * e.r) {
        if (d2 === 0) { // center inside rect: push out along the shortest axis
          const l = e.x - o.x, rr = o.x + o.w - e.x, t = e.y - o.y, b = o.y + o.h - e.y;
          const m = Math.min(l, rr, t, b);
          if (m === l) e.x = o.x - e.r; else if (m === rr) e.x = o.x + o.w + e.r; else if (m === t) e.y = o.y - e.r; else e.y = o.y + o.h + e.r;
        } else {
          const d = Math.sqrt(d2), push = e.r - d;
          e.x += (e.x - cx) / d * push; e.y += (e.y - cy) / d * push;
        }
      }
    }
    e.x = clamp(e.x, e.r, WORLD - e.r); e.y = clamp(e.y, e.r, WORLD - e.r);
  }
  function pointBlocked(x, y) {
    if (x < 0 || y < 0 || x > WORLD || y > WORLD) return true;
    return obstacles.some((o) => x > o.x && x < o.x + o.w && y > o.y && y < o.y + o.h);
  }

  // ---------- Update ----------
  function update(dt) {
    time += dt; nightTime += dt;

    // --- player movement
    let mx = 0, my = 0;
    if (keys.has('w') || keys.has('arrowup')) my -= 1;
    if (keys.has('s') || keys.has('arrowdown')) my += 1;
    if (keys.has('a') || keys.has('arrowleft')) mx -= 1;
    if (keys.has('d') || keys.has('arrowright')) mx += 1;
    if (touch.move) {
      const dx = touch.move.x - touch.move.ox, dy = touch.move.y - touch.move.oy, l = Math.hypot(dx, dy);
      if (l > 8) { const m = Math.min(l, 60) / 60; mx = dx / l * m; my = dy / l * m; }
    }
    const ml = Math.hypot(mx, my);
    if (ml > 1) { mx /= ml; my /= ml; }
    const spd = player.speed * (1 + 0.08 * upgrades.speed);
    player.x += mx * spd * dt; player.y += my * spd * dt;
    if (ml > 0) player.walk += dt * 10;
    resolve(player);

    // --- aim
    let wantFire = false;
    if (touch.aim) {
      const dx = touch.aim.x - touch.aim.ox, dy = touch.aim.y - touch.aim.oy;
      if (Math.hypot(dx, dy) > 12) { player.angle = Math.atan2(dy, dx); wantFire = true; }
    } else if (touch.active && zombies.length) {
      // auto-aim nearest zombie when using touch with no aim stick
      let bz = null, bd = 350 ** 2;
      for (const z of zombies) { const d = dist2(z.x, z.y, player.x, player.y); if (d < bd) { bd = d; bz = z; } }
      if (bz) player.angle = Math.atan2(bz.y - player.y, bz.x - player.x);
    } else if (!touch.active) {
      player.angle = Math.atan2(mouse.y + camY - player.y, mouse.x + camX - player.x);
      wantFire = mouse.down || keys.has(' ');
    }

    player.cooldown -= dt;
    if (player.reloading > 0) { player.reloading -= dt; if (player.reloading <= 0) { player.reloading = 0; finishReload(); } }
    if (wantFire) fire();
    player.hurtFlash = Math.max(0, player.hurtFlash - dt);
    flash = Math.max(0, flash - dt);

    // --- spawning
    spawnTimer -= dt;
    const alive = zombies.length;
    const cap = 18 + night * 4;
    if (toSpawn > 0 && spawnTimer <= 0 && alive < cap) {
      const burst = Math.min(toSpawn, 1 + Math.floor(night / 3));
      for (let i = 0; i < burst; i++) { spawnZombie(pickType()); toSpawn--; }
      spawnTimer = Math.max(0.35, 1.6 - night * 0.1) * rand(0.6, 1.3);
    }

    // --- zombies
    groanTimer -= dt;
    if (groanTimer <= 0 && zombies.length) { sfx.groan(); groanTimer = rand(1.5, 4); }
    for (const z of zombies) {
      const dx = player.x - z.x, dy = player.y - z.y, d = Math.hypot(dx, dy) || 1;
      let vx = dx / d, vy = dy / d;
      if (z.def.ranged) {
        if (d < 230) { vx = -vx; vy = -vy; } else if (d < 300) { vx = 0; vy = 0; }
        z.shootCd -= dt;
        if (z.shootCd <= 0 && d < 520) {
          z.shootCd = rand(2, 3.2); sfx.spit();
          const a = Math.atan2(dy, dx);
          enemyShots.push({ x: z.x, y: z.y, vx: Math.cos(a) * 300, vy: Math.sin(a) * 300, dmg: z.dmg, life: 2.5 });
        }
      }
      // wobble & simple separation
      z.wobble += dt * 3;
      const wob = Math.sin(z.wobble) * 0.3;
      const ax = vx - vy * wob, ay = vy + vx * wob;
      z.x += (ax * z.speed + z.kx) * dt; z.y += (ay * z.speed + z.ky) * dt;
      z.kx *= Math.pow(0.002, dt); z.ky *= Math.pow(0.002, dt);
      z.hitFlash = Math.max(0, z.hitFlash - dt);
      z.attackCd -= dt;
      if (d < z.r + player.r + 2 && z.attackCd <= 0) { hurtPlayer(z.dmg); z.attackCd = 0.8; }
    }
    // separation (O(n^2) is fine for these counts)
    for (let i = 0; i < zombies.length; i++) {
      const a = zombies[i];
      for (let j = i + 1; j < zombies.length; j++) {
        const b = zombies[j], min = a.r + b.r, d2v = dist2(a.x, a.y, b.x, b.y);
        if (d2v < min * min && d2v > 0) {
          const d = Math.sqrt(d2v), push = (min - d) / 2, nx = (a.x - b.x) / d, ny = (a.y - b.y) / d;
          const wa = b.r / min, wb = a.r / min;
          a.x += nx * push * wa * 2; a.y += ny * push * wa * 2; b.x -= nx * push * wb * 2; b.y -= ny * push * wb * 2;
        }
      }
    }
    for (const z of zombies) resolve(z);

    // --- bullets
    for (const b of bullets) {
      const steps = 3;
      for (let s = 0; s < steps && b.life > 0; s++) {
        b.x += b.vx * dt / steps; b.y += b.vy * dt / steps;
        if (pointBlocked(b.x, b.y)) {
          b.life = 0;
          for (let k = 0; k < 3; k++) particles.push({ x: b.x, y: b.y, vx: rand(-120, 120), vy: rand(-120, 120), life: 0.2, max: 0.2, size: 2, color: '#d9c58a' });
          break;
        }
        for (const z of zombies) {
          if (z.hp > 0 && dist2(b.x, b.y, z.x, z.y) < z.r * z.r && b.hitZ !== z) {
            damageZombie(z, b.dmg, b.x - b.vx * 0.01, b.y - b.vy * 0.01); sfx.hit();
            b.hitZ = z;
            if (b.pierce > 0) { b.pierce--; b.dmg *= 0.6; } else b.life = 0;
            break;
          }
        }
      }
      b.life -= dt;
    }
    bullets = bullets.filter((b) => b.life > 0);
    zombies = zombies.filter((z) => z.hp > 0);

    // --- enemy projectiles
    for (const s of enemyShots) {
      s.x += s.vx * dt; s.y += s.vy * dt; s.life -= dt;
      if (pointBlocked(s.x, s.y)) { s.life = 0; paintDecal(s.x, s.y, 5, 'rgba(90,160,60,0.4)'); }
      else if (dist2(s.x, s.y, player.x, player.y) < (player.r + 6) ** 2) {
        s.life = 0; hurtPlayer(s.dmg); paintDecal(s.x, s.y, 8, 'rgba(90,160,60,0.4)');
      }
      if (Math.random() < 0.5) particles.push({ x: s.x, y: s.y, vx: rand(-20, 20), vy: rand(-20, 20), life: 0.3, max: 0.3, size: 3, color: '#8fdc5a' });
    }
    enemyShots = enemyShots.filter((s) => s.life > 0);

    // --- grenades
    for (const g of grenades) {
      g.t += dt;
      const p = Math.min(g.t / g.dur, 1);
      const nx = g.sx + (g.tx - g.sx) * p, ny = g.sy + (g.ty - g.sy) * p;
      if (!pointBlocked(nx, ny)) { g.x = nx; g.y = ny; } else { g.sx = g.tx = g.x; g.sy = g.ty = g.y; }
      g.z = Math.sin(p * Math.PI) * 60;
      if (g.t >= g.dur + 0.5) { g.done = true; explode(g.x, g.y); }
    }
    grenades = grenades.filter((g) => !g.done);
    for (const e of explosions) e.t += dt;
    explosions = explosions.filter((e) => e.t < 0.4);

    // --- pickups
    for (const p of pickups) {
      p.t += dt;
      const d2v = dist2(p.x, p.y, player.x, player.y);
      if (d2v < 110 ** 2) {
        const d = Math.sqrt(d2v) || 1;
        p.x += (player.x - p.x) / d * 380 * dt; p.y += (player.y - p.y) / d * 380 * dt;
      }
      if (d2v < (player.r + 10) ** 2) {
        p.taken = true; sfx.pickup();
        if (p.kind === 'scrap') { player.scrap += p.value; scrapTotal += p.value; floater(`+${p.value} scrap`, '#9fd36a'); }
        if (p.kind === 'med') { const h = Math.min(35, player.maxHp - player.hp); player.hp += h; floater(`+${Math.round(h)} hp`, '#ff7a6a'); }
        if (p.kind === 'nade') { player.grenades++; floater('+1 grenade', '#f2c14e'); }
        if (p.kind === 'ammo') {
          const owned = [1, 2].filter((i) => player.owned[i]);
          if (owned.length) {
            const i = owned[Math.floor(Math.random() * owned.length)];
            const amt = i === 1 ? 12 : 64;
            player.reserve[i] += amt; floater(`+${amt} ${WEAPONS[i].name} ammo`, '#7ac8ff');
          } else { player.scrap += 2; scrapTotal += 2; floater('+2 scrap', '#9fd36a'); }
        }
      }
      if (p.t > 30) p.taken = true;
    }
    pickups = pickups.filter((p) => !p.taken);

    // --- particles & floaters
    for (const p of particles) { p.x += p.vx * dt; p.y += p.vy * dt; p.vx *= 0.9; p.vy *= 0.9; p.life -= dt; }
    particles = particles.filter((p) => p.life > 0);
    if (particles.length > 900) particles.splice(0, particles.length - 900);
    for (const f of floaters) { f.y -= 30 * dt; f.life -= dt; }
    floaters = floaters.filter((f) => f.life > 0);

    // --- camera
    shake = Math.max(0, shake - dt * 40);
    const tx = clamp(player.x - W / 2, 0, Math.max(0, WORLD - W)), ty = clamp(player.y - H / 2, 0, Math.max(0, WORLD - H));
    camX += (tx - camX) * Math.min(1, dt * 8); camY += (ty - camY) * Math.min(1, dt * 8);

    // --- night over?
    if (toSpawn <= 0 && zombies.length === 0 && state === 'playing') endNight();
  }

  function floater(text, color) { floaters.push({ x: player.x, y: player.y - 24, text, color, life: 1.2 }); }

  function endNight() {
    // grab any pickups left lying around
    for (const p of pickups) if (p.kind === 'scrap') { player.scrap += p.value; scrapTotal += p.value; }
    pickups = []; bullets = []; enemyShots = []; grenades = [];
    player.hp = Math.min(player.maxHp, player.hp + 15);
    state = 'shop';
    $('shop-title').textContent = `Dawn of day ${night + 1}`;
    renderShop();
    showOverlay('shop');
  }

  // ---------- Shop ----------
  function shopItems() {
    const u = upgrades;
    return [
      { name: 'Medkit', desc: `Restore to full health (${Math.ceil(player.hp)}/${player.maxHp}).`, cost: 12, can: player.hp < player.maxHp, buy: () => { player.hp = player.maxHp; } },
      { name: 'Body armor', desc: `+25 max health. Level ${u.maxHp}.`, cost: 25 + u.maxHp * 15, buy: () => { u.maxHp++; player.maxHp += 25; player.hp += 25; } },
      { name: 'Hollow points', desc: `+15% damage on everything. Level ${u.dmg}.`, cost: 25 + u.dmg * 20, buy: () => { u.dmg++; } },
      { name: 'Running shoes', desc: `+8% move speed. Level ${u.speed}/5.`, cost: 20 + u.speed * 15, can: u.speed < 5, buy: () => { u.speed++; } },
      { name: 'Speed loader', desc: `-12% reload time. Level ${u.reloadSpd}/4.`, cost: 18 + u.reloadSpd * 14, can: u.reloadSpd < 4, buy: () => { u.reloadSpd++; } },
      player.owned[1]
        ? { name: 'Shells x18', desc: `Shotgun ammo. Have ${player.reserve[1] + player.mag[1]}.`, cost: 8, buy: () => { player.reserve[1] += 18; } }
        : { name: 'Shotgun', desc: 'Close-range crowd shredder. Comes with 24 shells.', cost: 35, buy: () => { player.owned[1] = true; player.reserve[1] = 24; player.mag[1] = 6; } },
      player.owned[2]
        ? { name: 'SMG mags x96', desc: `SMG ammo. Have ${player.reserve[2] + player.mag[2]}.`, cost: 10, buy: () => { player.reserve[2] += 96; } }
        : { name: 'SMG', desc: 'Sprays fast. Comes with 128 rounds.', cost: 55, buy: () => { player.owned[2] = true; player.reserve[2] = 128; player.mag[2] = 32; } },
      { name: 'Grenades x2', desc: `G or right-click to throw. Have ${player.grenades}.`, cost: 14, buy: () => { player.grenades += 2; } },
    ];
  }
  function renderShop() {
    $('shop-scrap').textContent = `Scrap: ${player.scrap}`;
    const wrap = $('shop-items'); wrap.innerHTML = '';
    for (const it of shopItems()) {
      const el = document.createElement('div'); el.className = 'item';
      const h = document.createElement('h3'); h.textContent = it.name;
      const p = document.createElement('p'); p.textContent = it.desc;
      const b = document.createElement('button'); b.textContent = `Buy — ${it.cost} scrap`;
      b.disabled = player.scrap < it.cost || it.can === false;
      b.onclick = () => { if (player.scrap >= it.cost && it.can !== false) { player.scrap -= it.cost; it.buy(); sfx.pickup(); renderShop(); } };
      el.append(h, p, b); wrap.append(el);
    }
  }

  function gameOver() {
    state = 'over';
    const survived = night - 1;
    if (survived > best) { best = survived; try { localStorage.setItem('lastlight-best', String(best)); } catch (e) { /* ignore */ } }
    $('over-stats').textContent = `You fell on night ${night}. Nights survived: ${survived} · Zombies killed: ${kills} · Scrap found: ${scrapTotal} · Best: ${best}`;
    showOverlay('over');
    $('hud').classList.add('hidden');
  }

  // ---------- Render ----------
  function render() {
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    ctx.fillStyle = '#0b0c0a'; ctx.fillRect(0, 0, W, H);
    if (!player) return;
    const sx = (Math.random() - 0.5) * shake, sy = (Math.random() - 0.5) * shake;
    const ox = Math.round(-camX + sx), oy = Math.round(-camY + sy);
    ctx.save(); ctx.translate(ox, oy);

    // ground (only visible part)
    const vx = clamp(Math.floor(camX), 0, WORLD), vy = clamp(Math.floor(camY), 0, WORLD);
    const vw = Math.min(W + 2, WORLD - vx), vh = Math.min(H + 2, WORLD - vy);
    if (vw > 0 && vh > 0) ctx.drawImage(ground, vx, vy, vw, vh, vx, vy, vw, vh);

    // pickups
    for (const p of pickups) {
      const bob = Math.sin(p.t * 5) * 2;
      ctx.save(); ctx.translate(p.x, p.y + bob);
      if (p.kind === 'scrap') { ctx.fillStyle = '#9fd36a'; ctx.rotate(p.t * 2); ctx.fillRect(-4, -4, 8, 8); }
      if (p.kind === 'med') { ctx.fillStyle = '#eee'; ctx.fillRect(-8, -8, 16, 16); ctx.fillStyle = '#d22'; ctx.fillRect(-2, -6, 4, 12); ctx.fillRect(-6, -2, 12, 4); }
      if (p.kind === 'ammo') { ctx.fillStyle = '#3d4a2a'; ctx.fillRect(-9, -6, 18, 12); ctx.fillStyle = '#e8c35a'; ctx.fillRect(-6, -3, 3, 6); ctx.fillRect(-1, -3, 3, 6); ctx.fillRect(4, -3, 3, 6); }
      if (p.kind === 'nade') { ctx.fillStyle = '#4a5a2a'; ctx.beginPath(); ctx.arc(0, 0, 7, 0, TAU); ctx.fill(); ctx.fillStyle = '#aaa'; ctx.fillRect(-2, -10, 4, 4); }
      ctx.restore();
    }

    // obstacles: shadows first
    ctx.fillStyle = 'rgba(0,0,0,0.45)';
    for (const o of obstacles) ctx.fillRect(o.x + 10, o.y + 12, o.w, o.h);
    for (const o of obstacles) {
      if (o.x > camX + W + 20 || o.x + o.w < camX - 20 || o.y > camY + H + 20 || o.y + o.h < camY - 20) continue;
      if (o.kind === 'building') drawBuilding(o); else drawCar(o);
    }

    // acid shots
    ctx.fillStyle = '#8fdc5a';
    for (const s of enemyShots) { ctx.beginPath(); ctx.arc(s.x, s.y, 6, 0, TAU); ctx.fill(); }

    // zombies
    for (const z of zombies) drawZombie(z);

    // player
    drawPlayer();

    // bullets
    ctx.strokeStyle = '#ffe9a8'; ctx.lineWidth = 2;
    ctx.beginPath();
    for (const b of bullets) { ctx.moveTo(b.x, b.y); ctx.lineTo(b.x - b.vx * 0.02, b.y - b.vy * 0.02); }
    ctx.stroke();

    // grenades
    for (const g of grenades) {
      ctx.fillStyle = 'rgba(0,0,0,0.4)'; ctx.beginPath(); ctx.arc(g.x, g.y, 5, 0, TAU); ctx.fill();
      ctx.fillStyle = '#4a5a2a'; ctx.beginPath(); ctx.arc(g.x, g.y - (g.z || 0), 6, 0, TAU); ctx.fill();
      if (g.t > g.dur && Math.floor(g.t * 12) % 2) { ctx.fillStyle = '#f33'; ctx.beginPath(); ctx.arc(g.x, g.y, 3, 0, TAU); ctx.fill(); }
    }

    // particles
    for (const p of particles) {
      ctx.globalAlpha = clamp(p.life / p.max, 0, 1);
      ctx.fillStyle = p.color; ctx.fillRect(p.x - p.size / 2, p.y - p.size / 2, p.size, p.size);
    }
    ctx.globalAlpha = 1;

    // explosion flashes
    for (const e of explosions) {
      const k = e.t / 0.4;
      ctx.fillStyle = `rgba(255,200,100,${0.6 * (1 - k)})`;
      ctx.beginPath(); ctx.arc(e.x, e.y, 40 + 120 * k, 0, TAU); ctx.fill();
    }

    // floaters
    ctx.font = 'bold 14px Courier New'; ctx.textAlign = 'center';
    for (const f of floaters) { ctx.globalAlpha = clamp(f.life, 0, 1); ctx.fillStyle = f.color; ctx.fillText(f.text, f.x, f.y); }
    ctx.globalAlpha = 1;
    ctx.restore();

    drawDarkness(ox, oy);

    // hurt vignette
    if (player.hurtFlash > 0 || player.hp < player.maxHp * 0.3) {
      const a = Math.max(player.hurtFlash * 1.5, player.hp < player.maxHp * 0.3 ? 0.25 + Math.sin(time * 6) * 0.1 : 0);
      const grd = ctx.createRadialGradient(W / 2, H / 2, Math.min(W, H) * 0.3, W / 2, H / 2, Math.max(W, H) * 0.7);
      grd.addColorStop(0, 'rgba(120,0,0,0)'); grd.addColorStop(1, `rgba(140,0,0,${a})`);
      ctx.fillStyle = grd; ctx.fillRect(0, 0, W, H);
    }

    drawMinimap();
    drawReloadAndCrosshair();
    if (touch.active) drawTouchUI();
    updateHud();
  }

  function drawBuilding(o) {
    ctx.fillStyle = '#3a3630'; ctx.fillRect(o.x, o.y, o.w, o.h);
    ctx.fillStyle = '#4a453c'; ctx.fillRect(o.x + 6, o.y + 6, o.w - 12, o.h - 12);
    // roof details
    ctx.fillStyle = '#2d2a25';
    const seed = (o.x * 7 + o.y * 13) | 0;
    ctx.fillRect(o.x + 14 + (seed % 30), o.y + 14 + (seed % 20), 28, 22);
    ctx.fillRect(o.x + o.w - 50 - (seed % 15), o.y + o.h - 44, 32, 26);
    ctx.strokeStyle = 'rgba(0,0,0,0.4)'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(o.x + o.w * 0.3, o.y + 6); ctx.lineTo(o.x + o.w * 0.45, o.y + o.h * 0.5); ctx.lineTo(o.x + o.w * 0.4, o.y + o.h - 6); ctx.stroke();
    // a collapsed corner on some buildings
    if (seed % 3 === 0) { ctx.fillStyle = '#2a2722'; ctx.beginPath(); ctx.moveTo(o.x + o.w, o.y); ctx.lineTo(o.x + o.w - 40, o.y); ctx.lineTo(o.x + o.w, o.y + 40); ctx.fill(); }
    ctx.strokeStyle = '#1f1d19'; ctx.lineWidth = 3; ctx.strokeRect(o.x, o.y, o.w, o.h);
  }
  function drawCar(o) {
    ctx.fillStyle = o.hue; ctx.fillRect(o.x, o.y, o.w, o.h);
    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    if (o.w > o.h) ctx.fillRect(o.x + o.w * 0.3, o.y + 4, o.w * 0.4, o.h - 8);
    else ctx.fillRect(o.x + 4, o.y + o.h * 0.3, o.w - 8, o.h * 0.4);
    ctx.fillStyle = 'rgba(120,70,30,0.5)'; // rust
    ctx.fillRect(o.x + 3, o.y + 3, 10, 7);
    ctx.strokeStyle = '#111'; ctx.lineWidth = 2; ctx.strokeRect(o.x, o.y, o.w, o.h);
  }

  function drawZombie(z) {
    const a = Math.atan2(player.y - z.y, player.x - z.x);
    ctx.save(); ctx.translate(z.x, z.y); ctx.rotate(a);
    const sway = Math.sin(z.wobble * 2) * z.r * 0.25;
    // arms
    ctx.strokeStyle = z.def.skin; ctx.lineWidth = Math.max(3, z.r * 0.35); ctx.lineCap = 'round';
    if (!z.def.ranged) {
      ctx.beginPath(); ctx.moveTo(z.r * 0.2, -z.r * 0.7); ctx.lineTo(z.r * 1.4, -z.r * 0.5 + sway); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(z.r * 0.2, z.r * 0.7); ctx.lineTo(z.r * 1.4, z.r * 0.5 - sway); ctx.stroke();
    }
    // body
    ctx.fillStyle = z.hitFlash > 0 ? '#fff' : z.def.color;
    ctx.beginPath(); ctx.arc(0, 0, z.r, 0, TAU); ctx.fill();
    ctx.fillStyle = z.hitFlash > 0 ? '#fff' : z.def.skin;
    ctx.beginPath(); ctx.arc(z.r * 0.15, 0, z.r * 0.62, 0, TAU); ctx.fill();
    if (z.def.ranged) { ctx.fillStyle = '#8fdc5a'; ctx.beginPath(); ctx.arc(z.r * 0.6, 0, z.r * 0.3, 0, TAU); ctx.fill(); }
    // eyes
    ctx.fillStyle = z.def.boss ? '#ffde3a' : '#ff3a2a';
    const er = Math.max(1.6, z.r * 0.12);
    ctx.beginPath(); ctx.arc(z.r * 0.45, -z.r * 0.25, er, 0, TAU); ctx.arc(z.r * 0.45, z.r * 0.25, er, 0, TAU); ctx.fill();
    ctx.restore();
    // health bar for damaged tough ones
    if ((z.def.boss || z.type === 'brute') && z.hp < z.maxHp) {
      const w = z.r * 2;
      ctx.fillStyle = '#300'; ctx.fillRect(z.x - w / 2, z.y - z.r - 10, w, 4);
      ctx.fillStyle = '#e0502c'; ctx.fillRect(z.x - w / 2, z.y - z.r - 10, w * z.hp / z.maxHp, 4);
    }
  }

  function drawPlayer() {
    const p = player;
    ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.angle);
    // feet
    const step = Math.sin(p.walk) * 5;
    ctx.fillStyle = '#2a2a2a';
    ctx.fillRect(-4 + step, -9, 8, 6); ctx.fillRect(-4 - step, 3, 8, 6);
    // gun
    const w = p.weapon;
    ctx.fillStyle = '#1a1a1a';
    const len = w === 1 ? 26 : w === 2 ? 22 : 18;
    ctx.fillRect(6, 3, len, w === 1 ? 6 : 5);
    // body
    ctx.fillStyle = p.hurtFlash > 0 ? '#ff8a7a' : '#7a6a4a';
    ctx.beginPath(); ctx.arc(0, 0, p.r, 0, TAU); ctx.fill();
    ctx.fillStyle = '#5a4a32';
    ctx.beginPath(); ctx.arc(-3, 0, p.r * 0.75, -1.2, 1.2, true); ctx.fill(); // backpack
    ctx.fillStyle = '#d9b48a';
    ctx.beginPath(); ctx.arc(2, 0, 7, 0, TAU); ctx.fill(); // head
    ctx.fillStyle = '#3a2a1a';
    ctx.beginPath(); ctx.arc(0, 0, 7, Math.PI * 0.6, Math.PI * 1.4); ctx.fill(); // hair
    // hands on gun
    ctx.fillStyle = '#d9b48a';
    ctx.beginPath(); ctx.arc(10, 5, 3.5, 0, TAU); ctx.arc(16, 6, 3.5, 0, TAU); ctx.fill();
    ctx.restore();
  }

  function drawDarkness(ox, oy) {
    // night darkness with flashlight cone; slowly deepens over the first seconds of each night
    const darkness = clamp(0.35 + nightTime * 0.05, 0.35, 0.9);
    dctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    dctx.globalCompositeOperation = 'source-over';
    dctx.clearRect(0, 0, W, H);
    dctx.fillStyle = `rgba(4,6,14,${darkness})`;
    dctx.fillRect(0, 0, W, H);
    dctx.globalCompositeOperation = 'destination-out';
    const px = player.x + ox, py = player.y + oy;
    // ambient circle
    let g = dctx.createRadialGradient(px, py, 0, px, py, 150);
    g.addColorStop(0, 'rgba(0,0,0,1)'); g.addColorStop(1, 'rgba(0,0,0,0)');
    dctx.fillStyle = g; dctx.beginPath(); dctx.arc(px, py, 150, 0, TAU); dctx.fill();
    // flashlight cone
    const reach = 520, half = 0.5;
    g = dctx.createRadialGradient(px, py, 20, px, py, reach);
    g.addColorStop(0, 'rgba(0,0,0,1)'); g.addColorStop(0.7, 'rgba(0,0,0,0.85)'); g.addColorStop(1, 'rgba(0,0,0,0)');
    dctx.fillStyle = g;
    dctx.beginPath(); dctx.moveTo(px, py);
    dctx.arc(px, py, reach, player.angle - half, player.angle + half); dctx.closePath(); dctx.fill();
    // muzzle flash / explosions / acid glow light
    const lights = [];
    if (flash > 0) lights.push([px + Math.cos(player.angle) * 24, py + Math.sin(player.angle) * 24, 260]);
    for (const e of explosions) lights.push([e.x + ox, e.y + oy, 420 * (1 - e.t / 0.4)]);
    for (const s of enemyShots) lights.push([s.x + ox, s.y + oy, 50]);
    for (const [lx, ly, lr] of lights) {
      if (lr <= 0) continue;
      g = dctx.createRadialGradient(lx, ly, 0, lx, ly, lr);
      g.addColorStop(0, 'rgba(0,0,0,0.9)'); g.addColorStop(1, 'rgba(0,0,0,0)');
      dctx.fillStyle = g; dctx.beginPath(); dctx.arc(lx, ly, lr, 0, TAU); dctx.fill();
    }
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.drawImage(darkCanvas, 0, 0);
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    // zombie eyes glow through the dark
    for (const z of zombies) {
      const zx = z.x + ox, zy = z.y + oy;
      if (zx < -20 || zy < -20 || zx > W + 20 || zy > H + 20) continue;
      const a = Math.atan2(player.y - z.y, player.x - z.x), ca = Math.cos(a), sa = Math.sin(a);
      ctx.fillStyle = z.def.boss ? 'rgba(255,222,58,0.8)' : 'rgba(255,50,30,0.7)';
      for (const side of [-1, 1]) {
        const ex = zx + ca * z.r * 0.45 - sa * side * z.r * 0.25, ey = zy + sa * z.r * 0.45 + ca * side * z.r * 0.25;
        ctx.beginPath(); ctx.arc(ex, ey, Math.max(1.6, z.r * 0.12), 0, TAU); ctx.fill();
      }
    }
  }

  function drawMinimap() {
    const size = Math.min(140, W * 0.28), x = W - size - 12, y = 12, s = size / WORLD;
    ctx.fillStyle = 'rgba(10,10,8,0.75)'; ctx.fillRect(x, y, size, size);
    ctx.fillStyle = 'rgba(120,110,90,0.6)';
    for (const o of obstacles) ctx.fillRect(x + o.x * s, y + o.y * s, Math.max(1, o.w * s), Math.max(1, o.h * s));
    ctx.fillStyle = '#e0402c';
    for (const z of zombies) ctx.fillRect(x + z.x * s - 1, y + z.y * s - 1, z.def.boss ? 5 : 2, z.def.boss ? 5 : 2);
    ctx.fillStyle = '#f2c14e'; ctx.fillRect(x + player.x * s - 2, y + player.y * s - 2, 4, 4);
    ctx.strokeStyle = 'rgba(242,193,78,0.5)'; ctx.strokeRect(x + camX * s, y + camY * s, W * s, H * s);
    ctx.strokeStyle = '#5a3a2a'; ctx.strokeRect(x, y, size, size);
  }

  function drawReloadAndCrosshair() {
    const px = player.x - camX, py = player.y - camY;
    if (player.reloading > 0) {
      const k = 1 - player.reloading / reloadTime();
      ctx.strokeStyle = '#f2c14e'; ctx.lineWidth = 3;
      ctx.beginPath(); ctx.arc(px, py, 24, -Math.PI / 2, -Math.PI / 2 + TAU * k); ctx.stroke();
    }
    if (!touch.active) {
      ctx.strokeStyle = 'rgba(255,240,200,0.85)'; ctx.lineWidth = 1.5;
      const r = 8 + weaponDef().spread * 30;
      ctx.beginPath(); ctx.arc(mouse.x, mouse.y, r, 0, TAU);
      ctx.moveTo(mouse.x - r - 4, mouse.y); ctx.lineTo(mouse.x - r + 3, mouse.y);
      ctx.moveTo(mouse.x + r - 3, mouse.y); ctx.lineTo(mouse.x + r + 4, mouse.y);
      ctx.stroke();
    }
  }

  function drawTouchUI() {
    for (const s of [touch.move, touch.aim]) {
      if (!s) continue;
      ctx.strokeStyle = 'rgba(255,255,255,0.3)'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(s.ox, s.oy, 60, 0, TAU); ctx.stroke();
      const dx = s.x - s.ox, dy = s.y - s.oy, l = Math.hypot(dx, dy), m = Math.min(l, 60);
      ctx.fillStyle = 'rgba(255,255,255,0.35)';
      ctx.beginPath(); ctx.arc(s.ox + (l ? dx / l * m : 0), s.oy + (l ? dy / l * m : 0), 24, 0, TAU); ctx.fill();
    }
    ctx.font = 'bold 15px Courier New'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    for (const b of touchButtons()) {
      ctx.fillStyle = 'rgba(194,65,12,0.55)'; ctx.beginPath(); ctx.arc(b.x, b.y, b.r, 0, TAU); ctx.fill();
      ctx.fillStyle = '#fff4e0'; ctx.fillText(b.label, b.x, b.y);
    }
    ctx.textBaseline = 'alphabetic';
  }

  let hudCache = '';
  function updateHud() {
    const i = player.weapon, w = weaponDef();
    const ammo = player.reloading > 0 ? 'reloading…' : `${player.mag[i]}/${player.reserve[i] === Infinity ? '∞' : player.reserve[i]}`;
    const left = toSpawn + zombies.length;
    const s = [Math.max(0, Math.ceil(player.hp)), player.maxHp, night, left, w.name, ammo, player.grenades, player.scrap, kills].join('|');
    if (s === hudCache) return; hudCache = s;
    $('hp-bar').style.width = `${clamp(player.hp / player.maxHp, 0, 1) * 100}%`;
    $('hp-text').textContent = `${Math.max(0, Math.ceil(player.hp))} / ${player.maxHp}`;
    $('night').textContent = `Night ${night} · ${left} left`;
    $('weapon').textContent = `${w.name} ${ammo} · 💣${player.grenades}`;
    $('scrap').textContent = `Scrap ${player.scrap}`;
    $('kills').textContent = `Kills ${kills}`;
  }

  // ---------- Main loop ----------
  let last = performance.now();
  function loop(now) {
    const dt = Math.min(0.05, (now - last) / 1000); last = now;
    if (state === 'playing') update(dt);
    if (state !== 'menu') render(); else renderMenuBg(now);
    requestAnimationFrame(loop);
  }

  // Animated menu background: drifting embers over ash
  const embers = Array.from({ length: 80 }, () => ({ x: Math.random(), y: Math.random(), s: rand(1, 3), v: rand(0.02, 0.08) }));
  function renderMenuBg(now) {
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    ctx.fillStyle = '#0b0c0a'; ctx.fillRect(0, 0, W, H);
    for (const e of embers) {
      e.y -= e.v / 60; if (e.y < 0) { e.y = 1; e.x = Math.random(); }
      ctx.fillStyle = `rgba(255,${120 + (e.s * 30) | 0},40,${0.4 + 0.4 * Math.sin(now / 300 + e.x * 10)})`;
      ctx.fillRect(e.x * W + Math.sin(now / 1000 + e.y * 6) * 20, e.y * H, e.s, e.s);
    }
  }

  // ---------- Buttons ----------
  $('start-btn').onclick = () => { audio(); newGame(); };
  $('restart-btn').onclick = () => { newGame(); };
  $('next-night-btn').onclick = () => { startNight(); last = performance.now(); };
  $('resume-btn').onclick = () => togglePause();
  if (best > 0) $('best').textContent = `Best: ${best} night${best === 1 ? '' : 's'} survived`;

  requestAnimationFrame(loop);
})();
