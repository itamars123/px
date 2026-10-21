// "החיים" — a generative short film. Every frame is a pure function of time t,
// so the renderer can jump to any frame (and render chunks in parallel).

const TL = window.TIMELINE;
const W = TL.width, H = TL.height;

// ---------- helpers ----------
const clamp = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));
const lerp = (a, b, k) => a + (b - a) * k;
const smooth = (a, b, x) => { const k = clamp((x - a) / (b - a)); return k * k * (3 - 2 * k); };
const easeOut = k => 1 - Math.pow(1 - clamp(k), 3);
const easeInOut = k => { k = clamp(k); return k < .5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2; };
const TAU = Math.PI * 2;

function rng(seed) {
  let s = seed >>> 0 || 1;
  return () => { s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; };
}
function hash(n) { const x = Math.sin(n * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); }
function noise1(x) { const i = Math.floor(x), f = x - i, u = f * f * (3 - 2 * f); return lerp(hash(i), hash(i + 1), u); }

function mixColor(c1, c2, k) {
  return [lerp(c1[0], c2[0], k), lerp(c1[1], c2[1], k), lerp(c1[2], c2[2], k)];
}
const rgb = (c, a = 1) => `rgba(${c[0] | 0},${c[1] | 0},${c[2] | 0},${a})`;

function glow(ctx, x, y, r, color, alpha = 1) {
  const g = ctx.createRadialGradient(x, y, 0, x, y, r);
  g.addColorStop(0, rgb(color, alpha));
  g.addColorStop(0.25, rgb(color, alpha * 0.45));
  g.addColorStop(1, rgb(color, 0));
  ctx.fillStyle = g;
  ctx.fillRect(x - r, y - r, r * 2, r * 2);
}

function vGradient(ctx, stops) {
  const g = ctx.createLinearGradient(0, 0, 0, H);
  stops.forEach(([o, c]) => g.addColorStop(o, rgb(c)));
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, W, H);
}

// ---------- precomputed assets ----------
const STARS = (() => {
  const r = rng(7), a = [];
  for (let i = 0; i < 900; i++) a.push({ x: r() * W, y: r() * H, s: r() * r() * 2.2 + 0.3, p: r() * TAU, f: 0.5 + r() * 2 });
  return a;
})();

function drawStars(ctx, t, alpha = 1, drift = 0) {
  ctx.fillStyle = '#fff';
  for (const s of STARS) {
    const tw = 0.55 + 0.45 * Math.sin(t * s.f + s.p);
    ctx.globalAlpha = alpha * tw * Math.min(1, s.s);
    const x = (s.x + drift * s.s * t) % W;
    ctx.fillRect(x, s.y, s.s, s.s);
  }
  ctx.globalAlpha = 1;
}

// Deterministic fractal tree. Built once; drawn with a growth parameter.
const TREE = (() => {
  const r = rng(42), branches = [], leaves = [];
  function grow(x, y, ang, len, depth, born) {
    const x2 = x + Math.cos(ang) * len, y2 = y + Math.sin(ang) * len;
    const dur = 0.11 + depth * 0.004;
    branches.push({ x, y, x2, y2, w: Math.max(1.2, 30 * Math.pow(0.68, 10 - depth)), born, dur, depth });
    if (depth <= 0) {
      for (let i = 0; i < 3; i++) leaves.push({ x: x2 + (r() - .5) * 40, y: y2 + (r() - .5) * 40, born: born + dur, s: 9 + r() * 10, rot: r() * TAU, k: r() });
      return;
    }
    const n = depth > 7 ? 2 : (r() < 0.35 ? 3 : 2);
    for (let i = 0; i < n; i++) {
      const spread = (n === 2 ? (i ? 1 : -1) * (0.3 + r() * 0.25) : (i - 1) * 0.5) + (r() - .5) * 0.2;
      grow(x2, y2, ang + spread - 0.02 * Math.sign(ang + Math.PI / 2), len * (0.72 + r() * 0.12), depth - 1, born + dur);
    }
  }
  grow(0, 0, -Math.PI / 2, 150, 10, 0);
  const maxBorn = Math.max(...leaves.map(l => l.born));
  return { branches, leaves, maxBorn };
})();

function drawTree(ctx, cx, cy, scale, growth, opts = {}) {
  // growth in [0,1]; branches appear in order of 'born'
  const T = growth * (TREE.maxBorn + 0.15);
  const sway = opts.sway || 0;
  ctx.save();
  ctx.translate(cx, cy);
  ctx.scale(scale, scale);
  ctx.lineCap = 'round';
  ctx.strokeStyle = opts.bark || '#2a1a12';
  for (const b of TREE.branches) {
    if (T <= b.born) continue;
    const k = clamp((T - b.born) / b.dur);
    const sw = sway * (10 - b.depth) * 0.6;
    ctx.lineWidth = b.w * (0.4 + 0.6 * k);
    ctx.beginPath();
    ctx.moveTo(b.x + sway * (10 - b.depth - 1) * 0.6 * (b.y / -900), b.y);
    ctx.lineTo(lerp(b.x, b.x2, k) + sw * (b.y2 / -900), lerp(b.y, b.y2, k));
    ctx.stroke();
  }
  if (opts.leaves !== false) {
    const lc = opts.leafColor || [ [120, 200, 90] ];
    const fallT = opts.fallT || 0, density = opts.density ?? 1;
    for (let i = 0; i < TREE.leaves.length; i++) {
      const l = TREE.leaves[i];
      if (T <= l.born || l.k > density) continue;
      const k = easeOut((T - l.born) / 0.2);
      let x = l.x + sway * 6 * (l.y / -900), y = l.y, rot = l.rot, a = 1;
      // falling leaves: each detaches at its own moment, drifts down and vanishes at the ground
      const ft = fallT > 0 ? fallT - l.k * 4 : 0;
      if (ft > 0) {
        const hv = hash(i * 1.7), hd = hash(i * 3.1) - 0.35;
        y += ft * (380 + hv * 520);
        x += Math.sin(ft * (2 + hv * 3) + i) * 60 + ft * hd * 420;
        rot += ft * 4;
        a = clamp((10 - y) / 60);
        // most leaves simply wither away; only a sparse shower actually falls
        if (hash(i * 5.3) < 0.8) a = Math.min(a, clamp(1 - ft * 2.5));
      }
      if (a <= 0) continue;
      const c = lc[i % lc.length];
      ctx.save();
      ctx.translate(x, y); ctx.rotate(rot);
      ctx.fillStyle = rgb(c, 0.9 * a);
      ctx.beginPath();
      ctx.ellipse(0, 0, l.s * k, l.s * 0.55 * k, 0, 0, TAU);
      ctx.fill();
      ctx.restore();
    }
  }
  ctx.restore();
}

// ---------- scenes ----------
const SCENES = {};

SCENES.void = (ctx, lt, t) => {
  ctx.fillStyle = '#020205'; ctx.fillRect(0, 0, W, H);
  drawStars(ctx, t, smooth(0, 8, lt) * 0.15);
  // a single, patient spark
  const appear = smooth(0.8, 3.5, lt);
  const pulse = 0.75 + 0.25 * Math.sin(lt * 2.4);
  const grow = 1 + smooth(6.5, 9.4, lt) * 6;
  glow(ctx, W / 2, H / 2, 70 * pulse * grow, [180, 200, 255], appear * 0.9);
  glow(ctx, W / 2, H / 2, 10 * grow, [255, 255, 255], appear);
};

const BANG = (() => {
  const r = rng(99), a = [];
  for (let i = 0; i < 2600; i++) {
    const ang = r() * TAU, sp = Math.pow(r(), 0.6);
    const hue = r();
    a.push({ ang, sp, c: hue < .33 ? [255, 190, 120] : hue < .66 ? [140, 170, 255] : [255, 120, 200], s: 0.6 + r() * 2.2, d: r() });
  }
  return a;
})();

SCENES.bigbang = (ctx, lt, t) => {
  const bt = t - TL.events.bang;
  ctx.fillStyle = '#030208'; ctx.fillRect(0, 0, W, H);
  drawStars(ctx, t, smooth(1, 7, bt) * 0.8);
  // nebula clouds
  ctx.globalCompositeOperation = 'lighter';
  const neb = smooth(0.5, 6, bt);
  for (let i = 0; i < 7; i++) {
    const a = i * 0.9 + bt * 0.03, rr = 260 + i * 70 + bt * 25;
    glow(ctx, W / 2 + Math.cos(a) * rr * 0.8, H / 2 + Math.sin(a) * rr * 0.45, 420 + i * 30,
      i % 2 ? [90, 40, 160] : [30, 90, 170], 0.18 * neb);
  }
  // particles: an explosion that slowly settles into a spiral galaxy
  if (bt > 0) {
    const R = 1300 * easeOut(bt / 4.5) + bt * 30;
    const settle = easeInOut(clamp((bt - 1.6) / 5));
    for (let i = 0; i < BANG.length; i++) {
      const p = BANG[i];
      const rr = R * p.sp * (0.9 + 0.1 * Math.sin(p.d * 30 + bt));
      let x = W / 2 + Math.cos(p.ang) * rr, y = H / 2 + Math.sin(p.ang) * rr * 0.62;
      if (settle > 0) {
        const arm = i % 2, gr = 30 + p.d * 520, ga = arm * Math.PI + p.d * 7 + (p.ang - Math.PI) * 0.08 + bt * 0.12 * (1.2 - p.d);
        const gx = W / 2 + Math.cos(ga) * gr, gy = H / 2 - 30 + Math.sin(ga) * gr * 0.42;
        x = lerp(x, gx, settle); y = lerp(y, gy, settle);
      }
      const a = 0.55 + 0.45 * Math.sin(p.d * 50 + bt * 3);
      const sz = p.s * (1.6 - settle * 0.6);
      ctx.fillStyle = rgb(p.c, a);
      ctx.fillRect(x, y, sz, sz);
    }
    glow(ctx, W / 2, H / 2 - 30, 260, [255, 220, 180], 0.55 * settle);
    glow(ctx, W / 2, H / 2 - 30, 40, [255, 250, 235], 0.9 * settle);
    // expanding shock rings
    for (let k = 0; k < 3; k++) {
      const d = bt - k * 0.25; if (d <= 0) continue;
      ctx.strokeStyle = `rgba(255,230,200,${clamp(0.35 * Math.exp(-d * 1.6))})`; ctx.lineWidth = 3 - k;
      ctx.beginPath(); ctx.ellipse(W / 2, H / 2, d * 700, d * 700 * 0.62, 0, 0, TAU); ctx.stroke();
    }
    // the flash
    const flash = Math.exp(-bt * 2.2);
    glow(ctx, W / 2, H / 2, 300 + bt * 900, [255, 245, 230], flash);
    ctx.globalCompositeOperation = 'source-over';
    ctx.fillStyle = `rgba(255,250,240,${Math.exp(-bt * 5) * 0.9})`;
    ctx.fillRect(0, 0, W, H);
  } else {
    glow(ctx, W / 2, H / 2, 70 * 7, [180, 200, 255], 0.9);
  }
  ctx.globalCompositeOperation = 'source-over';
};

const PLANET_DUST = (() => {
  const r = rng(5), a = [];
  for (let i = 0; i < 1400; i++) a.push({ ang: r() * TAU, rad: 300 + r() * 700, sp: 0.2 + r() * 0.5, s: 0.5 + r() * 2, c: r() < .5 ? [200, 170, 140] : [150, 170, 220] });
  return a;
})();

SCENES.planet = (ctx, lt, t) => {
  ctx.fillStyle = '#02030a'; ctx.fillRect(0, 0, W, H);
  drawStars(ctx, t, 0.8, 2);
  const cx = W / 2, cy = H / 2 + 20;
  const form = easeInOut(lt / 6);
  // the sun, off to the side
  ctx.globalCompositeOperation = 'lighter';
  glow(ctx, W * 0.1, H * 0.2, 700, [255, 200, 130], 0.35);
  glow(ctx, W * 0.1, H * 0.2, 90, [255, 240, 200], 0.9);
  // accretion dust spiralling in
  for (const p of PLANET_DUST) {
    const rr = lerp(p.rad, 210 + (p.rad - 300) * 0.05, form);
    const a = p.ang + lt * p.sp * (1.5 - form);
    const x = cx + Math.cos(a) * rr, y = cy + Math.sin(a) * rr * 0.35;
    ctx.fillStyle = rgb(p.c, 0.7 * (1 - form * 0.85));
    ctx.fillRect(x, y, p.s, p.s);
  }
  ctx.globalCompositeOperation = 'source-over';
  // planet body
  const R = 230 * smooth(0.5, 6, lt);
  if (R > 1) {
    const zoom = 1 + Math.pow(smooth(6.5, 10.5, lt), 2) * 5;
    ctx.save();
    ctx.translate(cx, cy); ctx.scale(zoom, zoom); ctx.translate(-cx, -cy);
    const molten = 1 - smooth(2.5, 6.5, lt);
    const g = ctx.createRadialGradient(cx - R * .35, cy - R * .35, R * .1, cx, cy, R);
    g.addColorStop(0, rgb(mixColor([90, 170, 240], [255, 160, 70], molten)));
    g.addColorStop(0.7, rgb(mixColor([20, 70, 150], [170, 50, 20], molten)));
    g.addColorStop(1, rgb(mixColor([5, 20, 50], [60, 10, 5], molten)));
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(cx, cy, R, 0, TAU); ctx.fill();
    // continents + clouds
    ctx.save();
    ctx.beginPath(); ctx.arc(cx, cy, R, 0, TAU); ctx.clip();
    const land = smooth(4, 7, lt);
    for (let i = 0; i < 9; i++) {
      const lx = cx + ((i * 173 + lt * 18) % (R * 3)) - R * 1.5, ly = cy + Math.sin(i * 2.1) * R * 0.6;
      ctx.fillStyle = `rgba(70,140,70,${0.55 * land})`;
      ctx.beginPath(); ctx.ellipse(lx, ly, R * (0.18 + hash(i) * 0.2), R * (0.1 + hash(i + 9) * 0.12), i, 0, TAU); ctx.fill();
      ctx.fillStyle = `rgba(255,255,255,${0.35 * land})`;
      ctx.beginPath(); ctx.ellipse(lx + 60, ly - 30, R * 0.22, R * 0.04, 0.2, 0, TAU); ctx.fill();
    }
    // terminator shadow
    const sh = ctx.createLinearGradient(cx - R, cy - R, cx + R, cy + R);
    sh.addColorStop(0.35, 'rgba(0,0,0,0)'); sh.addColorStop(1, 'rgba(0,0,10,0.85)');
    ctx.fillStyle = sh; ctx.fillRect(cx - R, cy - R, R * 2, R * 2);
    ctx.restore();
    // atmosphere
    ctx.globalCompositeOperation = 'lighter';
    const atm = ctx.createRadialGradient(cx, cy, R * 0.95, cx, cy, R * 1.15);
    atm.addColorStop(0, `rgba(120,190,255,${0.45 * land})`); atm.addColorStop(1, 'rgba(120,190,255,0)');
    ctx.fillStyle = atm; ctx.beginPath(); ctx.arc(cx, cy, R * 1.15, 0, TAU); ctx.fill();
    ctx.globalCompositeOperation = 'source-over';
    ctx.restore();
    // dive into the ocean
    ctx.fillStyle = `rgba(10,50,90,${smooth(8.5, 10.5, lt)})`;
    ctx.fillRect(0, 0, W, H);
  }
};

SCENES.cells = (ctx, lt, t) => {
  vGradient(ctx, [[0, [12, 70, 110]], [0.5, [6, 40, 75]], [1, [2, 12, 28]]]);
  // light shafts from the surface
  ctx.globalCompositeOperation = 'lighter';
  for (let i = 0; i < 7; i++) {
    const x = W * (0.1 + i * 0.14) + Math.sin(t * 0.3 + i) * 40;
    const g = ctx.createLinearGradient(x, 0, x + 200, H);
    g.addColorStop(0, `rgba(140,220,255,${0.10 + 0.05 * Math.sin(t * 0.7 + i * 2)})`);
    g.addColorStop(1, 'rgba(140,220,255,0)');
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.moveTo(x - 30, 0); ctx.lineTo(x + 50, 0); ctx.lineTo(x + 320, H); ctx.lineTo(x + 120, H); ctx.fill();
  }
  // plankton motes
  const r = rng(3);
  for (let i = 0; i < 260; i++) {
    const x = (r() * W + t * 8 * r()) % W, y = (r() * H - t * 12 * (0.3 + r())) % H;
    ctx.fillStyle = `rgba(200,240,255,${0.25 * r()})`;
    ctx.fillRect(x, (y + H) % H, 2, 2);
  }
  // dividing cells: 1 → 2 → 4 → 8 → 16
  const gen = clamp((lt - 2) / 1.6, 0, 4.2);
  const cx = W / 2, cy = H / 2 - 20;
  const done = Math.floor(gen), prog = easeInOut(gen - done);
  function cell(x, y, r, level, id) {
    // levels below `done` are fully divided; level `done` is mid-division
    const p = level < done ? 1 : level === done ? prog : 0;
    if (p > 0.5 || level < done) {
      const d = r * 0.95 * p, ang = level * 1.3 + id * 0.7, r2 = r * lerp(1, 0.78, p);
      cell(x + Math.cos(ang) * d, y + Math.sin(ang) * d, r2, level + 1, id * 2 + 1);
      cell(x - Math.cos(ang) * d, y - Math.sin(ang) * d, r2, level + 1, id * 2 + 2);
      return;
    }
    // membrane stretching as it prepares to divide
    const prep = p * 2;
    const ang = level * 1.3 + id * 0.7;
    const wob = Math.sin(t * 2 + id) * 0.04;
    ctx.save();
    ctx.translate(x, y); ctx.rotate(ang);
    const sx = 1 + prep * 0.35 + wob, sy = 1 - prep * 0.15 - wob;
    ctx.scale(sx, sy);
    const g = ctx.createRadialGradient(0, 0, r * 0.1, 0, 0, r);
    g.addColorStop(0, 'rgba(180,255,220,0.55)');
    g.addColorStop(0.7, 'rgba(60,200,180,0.22)');
    g.addColorStop(0.95, 'rgba(150,255,230,0.6)');
    g.addColorStop(1, 'rgba(150,255,230,0)');
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(0, 0, r, 0, TAU); ctx.fill();
    ctx.fillStyle = 'rgba(255,240,180,0.7)';
    ctx.beginPath(); ctx.arc(r * 0.15 * Math.sin(t + id), 0, r * 0.22, 0, TAU); ctx.fill();
    ctx.restore();
    glow(ctx, x, y, r * 2.2, [120, 255, 210], 0.18);
  }
  const R0 = 120 * smooth(0, 1.5, lt) * (1 + lt * 0.03);
  if (R0 > 1) cell(cx, cy, R0, 0, 0);
  ctx.globalCompositeOperation = 'source-over';
};

function drawSky(ctx, top, mid, bottom) { vGradient(ctx, [[0, top], [0.55, mid], [1, bottom]]); }

SCENES.sprout = (ctx, lt, t) => {
  const day = smooth(0, 9, lt);
  drawSky(ctx, mixColor([20, 25, 60], [70, 130, 200], day), mixColor([80, 60, 110], [250, 190, 140], day), [250, 220, 170]);
  // sun rising behind horizon
  ctx.globalCompositeOperation = 'lighter';
  glow(ctx, W * 0.7, lerp(H * 0.85, H * 0.45, day), 600, [255, 190, 120], 0.6);
  glow(ctx, W * 0.7, lerp(H * 0.85, H * 0.45, day), 80, [255, 245, 220], 0.9);
  ctx.globalCompositeOperation = 'source-over';
  // hills
  const gy = H * 0.8;
  ctx.fillStyle = rgb(mixColor([30, 30, 50], [80, 110, 80], day));
  ctx.beginPath(); ctx.moveTo(0, H);
  for (let x = 0; x <= W; x += 20) ctx.lineTo(x, gy - 60 - Math.sin(x * 0.003 + 1) * 40 - noise1(x * 0.01) * 30);
  ctx.lineTo(W, H); ctx.fill();
  ctx.fillStyle = rgb(mixColor([20, 15, 15], [55, 40, 25], day));
  ctx.beginPath(); ctx.moveTo(0, H);
  for (let x = 0; x <= W; x += 20) ctx.lineTo(x, gy + Math.sin(x * 0.004) * 10);
  ctx.lineTo(W, H); ctx.fill();
  // the seed and the tree
  const seedGlow = 1 - smooth(1, 3, lt);
  glow(ctx, W / 2, gy + 12, 50, [255, 220, 140], seedGlow * 0.9);
  const growth = easeInOut(clamp((lt - 1.2) / 9.2));
  drawTree(ctx, W / 2, gy + 6, 0.62 * (0.45 + growth * 0.55), growth, {
    bark: rgb(mixColor([30, 25, 20], [60, 40, 25], day)),
    leafColor: [[110, 190, 80], [140, 210, 90], [90, 170, 70]],
    sway: Math.sin(t * 0.8) * 1.2
  });
};

SCENES.heart = (ctx, lt, t) => {
  ctx.fillStyle = '#050307'; ctx.fillRect(0, 0, W, H);
  const beats = TL.events.heartbeats;
  // ECG trace: a scanning pen leaving a trail
  const speed = 520, y0 = H / 2 + 40;
  function ecg(time) {
    let v = 0;
    for (const b of beats) {
      const d = time - b;
      v += -Math.exp(-Math.pow((d + 0.10) / 0.025, 2)) * 22
        + Math.exp(-Math.pow(d / 0.018, 2)) * 170
        - Math.exp(-Math.pow((d - 0.045) / 0.02, 2)) * 55
        + Math.exp(-Math.pow((d - 0.25) / 0.06, 2)) * 30;
    }
    return v;
  }
  const penX = (lt * speed) % (W + 200) - 100;
  ctx.lineWidth = 3;
  ctx.shadowColor = 'rgba(255,90,110,0.9)'; ctx.shadowBlur = 18;
  ctx.beginPath();
  for (let x = -100; x <= penX; x += 3) {
    const tt = t - (penX - x) / speed;
    const y = y0 - ecg(tt);
    x === -100 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
  }
  const grad = ctx.createLinearGradient(penX - 900, 0, penX, 0);
  grad.addColorStop(0, 'rgba(255,80,100,0)'); grad.addColorStop(1, 'rgba(255,120,140,1)');
  ctx.strokeStyle = grad; ctx.stroke();
  ctx.shadowBlur = 0;
  glow(ctx, penX, y0 - ecg(t), 40, [255, 160, 170], 1);
  // a warm glow that blooms with each beat
  let pulse = 0;
  for (const b of beats) { const d = t - b; if (d > 0) pulse += Math.exp(-d * 4) * (b - beats[0] + 1) / 4; }
  ctx.globalCompositeOperation = 'lighter';
  glow(ctx, W / 2, H / 2 - 60, 380 + pulse * 160, [255, 110, 100], clamp(0.15 + pulse * 0.5));
  ctx.globalCompositeOperation = 'source-over';
};

SCENES.childhood = (ctx, lt, t) => {
  drawSky(ctx, [80, 160, 235], [160, 210, 245], [235, 245, 230]);
  ctx.globalCompositeOperation = 'lighter';
  glow(ctx, W * 0.8, H * 0.18, 500, [255, 240, 190], 0.5);
  glow(ctx, W * 0.8, H * 0.18, 70, [255, 255, 240], 1);
  ctx.globalCompositeOperation = 'source-over';
  // clouds
  for (let i = 0; i < 6; i++) {
    const x = ((i * 380 + t * (12 + i * 3)) % (W + 600)) - 300, y = 120 + i * 55 % 260;
    ctx.fillStyle = 'rgba(255,255,255,0.85)';
    for (let j = 0; j < 5; j++) { ctx.beginPath(); ctx.arc(x + j * 45, y + Math.sin(j * 2) * 12, 40 + (j % 2) * 18, 0, TAU); ctx.fill(); }
  }
  // meadow with flowers
  ctx.fillStyle = '#6cbf5a';
  ctx.beginPath(); ctx.moveTo(0, H);
  for (let x = 0; x <= W; x += 20) ctx.lineTo(x, H * 0.78 + Math.sin(x * 0.003) * 25);
  ctx.lineTo(W, H); ctx.fill();
  const fr = rng(11);
  for (let i = 0; i < 160; i++) {
    const x = fr() * W, y = H * 0.82 + fr() * H * 0.18, c = [[255, 120, 140], [255, 220, 90], [255, 255, 255], [190, 140, 255]][i % 4];
    ctx.fillStyle = rgb(c, 0.95);
    ctx.beginPath(); ctx.arc(x + Math.sin(t * 2 + i) * 2, y, 3 + fr() * 4, 0, TAU); ctx.fill();
  }
  // balloons drifting upward
  const br = rng(21);
  for (let i = 0; i < 18; i++) {
    const delay = br() * 5, sp = 70 + br() * 70, x0 = br() * W;
    const k = lt - delay; if (k < 0) { br(); continue; }
    const x = x0 + Math.sin(k * 0.8 + i) * 50, y = H + 80 - k * sp;
    const c = [[255, 80, 90], [255, 190, 60], [90, 170, 255], [160, 110, 240], [80, 210, 140]][i % 5];
    const rr = 34 + br() * 18;
    ctx.strokeStyle = 'rgba(80,80,80,0.6)'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(x, y + rr * 1.2); ctx.quadraticCurveTo(x + 20 * Math.sin(k * 2), y + rr * 2.5, x, y + rr * 4); ctx.stroke();
    const g = ctx.createRadialGradient(x - rr * .3, y - rr * .4, rr * .1, x, y, rr * 1.2);
    g.addColorStop(0, rgb(mixColor(c, [255, 255, 255], 0.6))); g.addColorStop(1, rgb(c));
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.ellipse(x, y, rr, rr * 1.2, 0, 0, TAU); ctx.fill();
  }
  // a kite on a string
  const kx = W * 0.25 + Math.sin(t * 0.9) * 60, ky = H * 0.3 + Math.cos(t * 1.3) * 30;
  ctx.strokeStyle = 'rgba(60,60,60,0.6)'; ctx.lineWidth = 1.5;
  ctx.beginPath(); ctx.moveTo(W * 0.38, H * 0.85); ctx.quadraticCurveTo(W * 0.3, H * 0.6, kx, ky + 50); ctx.stroke();
  ctx.save(); ctx.translate(kx, ky); ctx.rotate(Math.sin(t * 1.4) * 0.2);
  ctx.fillStyle = '#ff5a6e'; ctx.beginPath(); ctx.moveTo(0, -60); ctx.lineTo(42, 0); ctx.lineTo(0, 55); ctx.lineTo(-42, 0); ctx.fill();
  ctx.fillStyle = '#ffd34d'; ctx.beginPath(); ctx.moveTo(0, -60); ctx.lineTo(42, 0); ctx.lineTo(0, 0); ctx.fill();
  ctx.restore();
  for (let i = 0; i < 6; i++) {
    ctx.fillStyle = ['#ff5a6e', '#4db8ff', '#ffd34d'][i % 3];
    ctx.fillRect(kx + Math.sin(t * 3 + i) * 10 - 5, ky + 60 + i * 22, 10, 6);
  }
};

const CITY = (() => {
  const r = rng(77), b = [];
  let x = 0;
  while (x < W) { const w = 40 + r() * 110; b.push({ x, w, h: 120 + r() * 340, seed: r() * 1000 }); x += w + 4; }
  return b;
})();

const FW = TL.events.fireworks.map((ft, i) => {
  const r = rng(500 + i);
  return { t: ft, x: W * (0.15 + r() * 0.7), y: H * (0.15 + r() * 0.3), c: [[255, 120, 90], [120, 200, 255], [255, 220, 110], [220, 120, 255], [120, 255, 170]][i % 5], n: 120, seed: 500 + i };
});

SCENES.youth = (ctx, lt, t) => {
  drawSky(ctx, [8, 8, 30], [30, 20, 60], [70, 40, 70]);
  drawStars(ctx, t, 0.5);
  // fireworks
  ctx.globalCompositeOperation = 'lighter';
  for (const f of FW) {
    const launch = 0.9, d = t - f.t; // f.t is the burst time
    if (d < -launch || d > 3.5) continue;
    if (d < 0) {
      const k = 1 + d / launch;
      const y = lerp(H, f.y, easeOut(k));
      glow(ctx, f.x, y, 14, [255, 220, 180], 1);
      continue;
    }
    glow(ctx, f.x, f.y, 500, f.c, 0.25 * Math.exp(-d * 3));
    const r = rng(f.seed);
    for (let i = 0; i < f.n; i++) {
      const ang = (i / f.n) * TAU + r() * 0.05, sp = 220 + r() * 160;
      const dd = sp * (1 - Math.exp(-d * 1.8)) / 1.8;
      const x = f.x + Math.cos(ang) * dd, y = f.y + Math.sin(ang) * dd + d * d * 40;
      const a = clamp(1 - d / 3.2) * (0.7 + 0.3 * Math.sin(d * 30 + i));
      ctx.fillStyle = rgb(mixColor(f.c, [255, 255, 255], 0.3), a);
      ctx.fillRect(x - 1.5, y - 1.5, 3, 3);
      ctx.fillStyle = rgb(f.c, a * 0.4);
      ctx.fillRect(x - Math.cos(ang) * 10, y - Math.sin(ang) * 10, 2, 2);
    }
  }
  ctx.globalCompositeOperation = 'source-over';
  // skyline with lit windows
  for (const b of CITY) {
    const top = H - b.h;
    ctx.fillStyle = '#0b0a16';
    ctx.fillRect(b.x, top, b.w, b.h);
    const r = rng(b.seed | 0);
    for (let wy = top + 14; wy < H - 10; wy += 22) for (let wx = b.x + 8; wx < b.x + b.w - 10; wx += 16) {
      if (r() < 0.45) continue;
      const on = noise1(b.seed + wx * 0.1 + wy * 0.05 + t * 0.2) > 0.35;
      if (!on) continue;
      ctx.fillStyle = `rgba(255,${200 + r() * 40 | 0},120,${0.5 + r() * 0.4})`;
      ctx.fillRect(wx, wy, 7, 10);
    }
  }
  // streaking lights of a running figure — light trails across
  ctx.globalCompositeOperation = 'lighter';
  for (let i = 0; i < 4; i++) {
    const x = ((lt * 600 + i * 520) % (W + 800)) - 400, y = H - 30 - i * 6;
    const g = ctx.createLinearGradient(x - 400, 0, x, 0);
    g.addColorStop(0, 'rgba(255,80,60,0)'); g.addColorStop(1, i % 2 ? 'rgba(255,230,180,0.9)' : 'rgba(255,90,70,0.9)');
    ctx.fillStyle = g; ctx.fillRect(x - 400, y, 400, 3);
  }
  ctx.globalCompositeOperation = 'source-over';
};

SCENES.love = (ctx, lt, t) => {
  drawSky(ctx, [25, 10, 35], [70, 25, 60], [120, 50, 70]);
  drawStars(ctx, t, 0.35);
  ctx.globalCompositeOperation = 'lighter';
  // two lights: wandering apart, finding each other, then orbiting as one
  const meet = easeInOut(clamp((lt - 0.5) / 4.5));
  const cx = W / 2, cy = H / 2 - 40;
  const ax = lerp(W * 0.12, cx, meet) + Math.sin(t * 1.1) * 60 * (1 - meet);
  const ay = lerp(H * 0.3, cy, meet) + Math.cos(t * 0.9) * 50 * (1 - meet);
  const bx = lerp(W * 0.88, cx, meet) + Math.sin(t * 1.3 + 2) * 60 * (1 - meet);
  const by = lerp(H * 0.65, cy, meet) + Math.cos(t * 0.7 + 1) * 50 * (1 - meet);
  const orb = smooth(4, 6, lt), r = lerp(0, 70, orb) + Math.sin(lt * 0.6) * 10 * orb;
  const oa = lt * 2.2;
  const p1 = [lerp(ax, cx + Math.cos(oa) * r, orb), lerp(ay, cy + Math.sin(oa) * r * 0.6, orb)];
  const p2 = [lerp(bx, cx - Math.cos(oa) * r, orb), lerp(by, cy - Math.sin(oa) * r * 0.6, orb)];
  // trails
  for (let k = 1; k < 40; k++) {
    const tt = lt - k * 0.03;
    const m = easeInOut(clamp((tt - 0.5) / 4.5)), o = smooth(4, 6, tt), rr = lerp(0, 70, o), a2 = tt * 2.2;
    const q1x = lerp(lerp(W * 0.12, cx, m) + Math.sin((t - k * .03) * 1.1) * 60 * (1 - m), cx + Math.cos(a2) * rr, o);
    const q1y = lerp(lerp(H * 0.3, cy, m) + Math.cos((t - k * .03) * 0.9) * 50 * (1 - m), cy + Math.sin(a2) * rr * .6, o);
    const q2x = lerp(lerp(W * 0.88, cx, m) + Math.sin((t - k * .03) * 1.3 + 2) * 60 * (1 - m), cx - Math.cos(a2) * rr, o);
    const q2y = lerp(lerp(H * 0.65, cy, m) + Math.cos((t - k * .03) * 0.7 + 1) * 50 * (1 - m), cy - Math.sin(a2) * rr * .6, o);
    const a = 0.25 * (1 - k / 40);
    ctx.fillStyle = `rgba(255,150,120,${a})`; ctx.beginPath(); ctx.arc(q1x, q1y, 6 * (1 - k / 40) + 1, 0, TAU); ctx.fill();
    ctx.fillStyle = `rgba(150,170,255,${a})`; ctx.beginPath(); ctx.arc(q2x, q2y, 6 * (1 - k / 40) + 1, 0, TAU); ctx.fill();
  }
  glow(ctx, p1[0], p1[1], 120, [255, 150, 110], 0.9);
  glow(ctx, p2[0], p2[1], 120, [140, 160, 255], 0.9);
  glow(ctx, p1[0], p1[1], 16, [255, 240, 230], 1);
  glow(ctx, p2[0], p2[1], 16, [235, 240, 255], 1);
  // when they meet, the world warms — a heart of light particles
  const bloom = smooth(5.5, 8, lt);
  glow(ctx, cx, cy, 700, [255, 110, 140], 0.3 * bloom);
  const hr = rng(8);
  for (let i = 0; i < 500; i++) {
    const th = hr() * TAU, s = 13 + hr() * 1.5;
    const hx = 16 * Math.pow(Math.sin(th), 3), hy = -(13 * Math.cos(th) - 5 * Math.cos(2 * th) - 2 * Math.cos(3 * th) - Math.cos(4 * th));
    const k = easeOut(clamp((lt - 5.5 - hr() * 1.5) / 2));
    const jitter = Math.sin(t * 2 + i) * 3;
    const x = cx + hx * s * k + jitter, y = cy + hy * s * k - 10;
    ctx.fillStyle = `rgba(255,${150 + hr() * 80 | 0},${170 + hr() * 60 | 0},${0.7 * k * (0.6 + 0.4 * Math.sin(t * 3 + i))})`;
    ctx.fillRect(x, y, 2.5, 2.5);
  }
  ctx.globalCompositeOperation = 'source-over';
};

SCENES.storm = (ctx, lt, t) => {
  drawSky(ctx, [12, 14, 20], [30, 34, 44], [16, 18, 24]);
  // churning clouds
  for (let i = 0; i < 26; i++) {
    const x = ((i * 157 + t * 30 * (1 + i % 3)) % (W + 500)) - 250, y = 40 + (i * 37) % 300;
    ctx.fillStyle = `rgba(${40 + i % 4 * 6},${44 + i % 4 * 6},${55 + i % 4 * 6},0.55)`;
    ctx.beginPath(); ctx.ellipse(x, y, 260, 90, 0, 0, TAU); ctx.fill();
  }
  // lightning
  let flash = 0;
  for (const lgt of TL.events.lightning) {
    const d = t - lgt;
    if (d < 0 || d > 0.9) continue;
    flash = Math.max(flash, Math.exp(-d * 7) * (d < 0.08 || (d > 0.14 && d < 0.2) ? 1 : 0.6));
    if (d < 0.35) {
      const r = rng(lgt * 1000 | 0);
      let x = W * (0.2 + r() * 0.6), y = 0;
      ctx.strokeStyle = `rgba(230,235,255,${1 - d / 0.35})`; ctx.lineWidth = 4;
      ctx.shadowColor = '#bcd'; ctx.shadowBlur = 30;
      ctx.beginPath(); ctx.moveTo(x, y);
      while (y < H * 0.8) { x += (r() - .5) * 120; y += 30 + r() * 50; ctx.lineTo(x, y); }
      ctx.stroke(); ctx.shadowBlur = 0;
    }
  }
  ctx.fillStyle = `rgba(200,210,255,${flash * 0.45})`; ctx.fillRect(0, 0, W, H);
  // sea of waves
  for (let layer = 0; layer < 4; layer++) {
    const base = H * (0.72 + layer * 0.07);
    ctx.fillStyle = rgb(mixColor([10, 18, 26], [60, 70, 90], flash * 0.5 + layer * 0.03));
    ctx.beginPath(); ctx.moveTo(0, H);
    for (let x = 0; x <= W; x += 12) ctx.lineTo(x, base + Math.sin(x * 0.008 + t * (1.5 + layer * .4) + layer) * (25 - layer * 3) + Math.sin(x * 0.02 - t * 2) * 8);
    ctx.lineTo(W, H); ctx.fill();
  }
  // a small boat, a small flame — still burning
  const bx = W * 0.5, by = H * 0.74 + Math.sin(t * 1.6) * 18, tilt = Math.sin(t * 1.3) * 0.18;
  ctx.save(); ctx.translate(bx, by); ctx.rotate(tilt);
  ctx.fillStyle = '#0a0a0e';
  ctx.beginPath(); ctx.moveTo(-70, 0); ctx.lineTo(70, 0); ctx.lineTo(50, 26); ctx.lineTo(-50, 26); ctx.fill();
  ctx.fillRect(-3, -110, 6, 110);
  ctx.beginPath(); ctx.moveTo(3, -105); ctx.lineTo(60, -20); ctx.lineTo(3, -20); ctx.fill();
  ctx.restore();
  ctx.globalCompositeOperation = 'lighter';
  const fl = 0.7 + 0.3 * noise1(t * 8);
  glow(ctx, bx - 40 * Math.cos(tilt), by - 12 - 40 * Math.sin(tilt), 70 * fl, [255, 170, 80], 0.8);
  ctx.globalCompositeOperation = 'source-over';
  // rain
  ctx.strokeStyle = 'rgba(180,195,220,0.35)'; ctx.lineWidth = 1.3;
  ctx.beginPath();
  const r = rng(31);
  for (let i = 0; i < 900; i++) {
    const sp = 1400 + r() * 700, x0 = r() * (W + 400), y0 = r() * H;
    const y = (y0 + t * sp) % (H + 100) - 50, x = (x0 - (y + t * sp * 0.25) * 0.25) % (W + 400);
    ctx.moveTo(x, y); ctx.lineTo(x - 8, y + 34);
  }
  ctx.stroke();
};

SCENES.sunrise = (ctx, lt, t) => {
  const k = easeInOut(clamp(lt / 9));
  drawSky(ctx, mixColor([20, 25, 45], [80, 140, 210], k), mixColor([60, 50, 70], [255, 170, 110], k), mixColor([40, 30, 40], [255, 220, 160], k));
  const sy = lerp(H * 0.86, H * 0.5, k), sx = W / 2;
  ctx.globalCompositeOperation = 'lighter';
  glow(ctx, sx, sy, 1100, [255, 160, 90], 0.55 * k + 0.1);
  // god rays
  ctx.save(); ctx.translate(sx, sy); ctx.rotate(t * 0.02);
  for (let i = 0; i < 18; i++) {
    ctx.rotate(TAU / 18);
    ctx.fillStyle = `rgba(255,220,160,${0.05 * k * (0.6 + 0.4 * Math.sin(t + i))})`;
    ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(1600, -60); ctx.lineTo(1600, 60); ctx.fill();
  }
  ctx.restore();
  glow(ctx, sx, sy, 130, [255, 250, 225], 1);
  ctx.globalCompositeOperation = 'source-over';
  // clouds part
  for (let i = 0; i < 10; i++) {
    const side = i % 2 ? 1 : -1, off = 260 + (i >> 1) * 140 + k * 600;
    const x = sx + side * off + Math.sin(t * .2 + i) * 20, y = 160 + (i * 61) % 260;
    ctx.fillStyle = rgb(mixColor([40, 40, 55], [255, 200, 170], k), 0.7);
    ctx.beginPath(); ctx.ellipse(x, y, 300, 70, 0, 0, TAU); ctx.fill();
  }
  // calm sea with shimmering reflection
  const hz = H * 0.72;
  vGradientRect(ctx, hz, H, [[0, mixColor([30, 30, 45], [230, 150, 110], k)], [1, mixColor([8, 10, 20], [60, 60, 110], k)]]);
  ctx.globalCompositeOperation = 'lighter';
  for (let y = hz + 4; y < H; y += 7) {
    const d = (y - hz) / (H - hz), w = (60 + d * 260) * (0.5 + 0.5 * noise1(y * 0.3 + t * 2));
    ctx.fillStyle = `rgba(255,220,170,${0.5 * k * (1 - d * 0.6)})`;
    ctx.fillRect(sx - w / 2 + Math.sin(y + t * 3) * 10, y, w, 2.2);
  }
  ctx.globalCompositeOperation = 'source-over';
  // the boat again, now on calm water, sail up
  const bx = W * 0.32 + lt * 12, by = hz + 26;
  ctx.fillStyle = '#1a1214';
  ctx.beginPath(); ctx.moveTo(bx - 50, by); ctx.lineTo(bx + 50, by); ctx.lineTo(bx + 36, by + 18); ctx.lineTo(bx - 36, by + 18); ctx.fill();
  ctx.fillRect(bx - 2, by - 80, 4, 80);
  ctx.beginPath(); ctx.moveTo(bx + 2, by - 78); ctx.lineTo(bx + 46, by - 12); ctx.lineTo(bx + 2, by - 12); ctx.fill();
  // birds
  for (let i = 0; i < 7; i++) {
    const x = W * 0.55 + i * 50 + lt * 40, y = H * 0.32 + Math.sin(i * 1.7) * 40, f = Math.sin(t * 6 + i) * 10;
    ctx.strokeStyle = 'rgba(40,30,40,0.8)'; ctx.lineWidth = 2.5;
    ctx.beginPath(); ctx.moveTo(x - 14, y - f); ctx.quadraticCurveTo(x - 6, y - 4, x, y); ctx.quadraticCurveTo(x + 6, y - 4, x + 14, y - f); ctx.stroke();
  }
};

function vGradientRect(ctx, y0, y1, stops) {
  const g = ctx.createLinearGradient(0, y0, 0, y1);
  stops.forEach(([o, c]) => g.addColorStop(o, rgb(c)));
  ctx.fillStyle = g; ctx.fillRect(0, y0, W, y1 - y0);
}

const SEASONS = [
  { sky: [[110, 170, 230], [200, 230, 240]], ground: [110, 180, 90], leaves: [[255, 190, 210], [250, 160, 190], [130, 200, 100]], density: 0.9 },  // spring
  { sky: [[60, 140, 230], [170, 215, 245]], ground: [80, 150, 60], leaves: [[60, 150, 60], [90, 180, 70], [40, 120, 50]], density: 1 },             // summer
  { sky: [[150, 130, 140], [240, 190, 140]], ground: [140, 110, 60], leaves: [[220, 120, 40], [200, 70, 30], [240, 180, 60]], density: 1 },          // autumn
  { sky: [[120, 130, 150], [210, 215, 225]], ground: [230, 235, 245], leaves: [[220, 120, 40]], density: 0 }                                          // winter
];

SCENES.seasons = (ctx, lt, t) => {
  const s = clamp(lt / 11.5) * 3.999, i = Math.floor(s), f = smooth(0.6, 1, s - i);
  const A = SEASONS[i], B = SEASONS[Math.min(3, i + 1)];
  drawSky(ctx, mixColor(A.sky[0], B.sky[0], f), mixColor(A.sky[1], B.sky[1], f), mixColor(A.sky[1], B.sky[1], f));
  // sun arcs across the sky — days passing quickly
  const sa = lt * 1.6;
  ctx.globalCompositeOperation = 'lighter';
  glow(ctx, W / 2 + Math.cos(sa) * W * 0.45, H * 0.7 - Math.abs(Math.sin(sa)) * H * 0.55, 200, [255, 230, 180], 0.5);
  ctx.globalCompositeOperation = 'source-over';
  const gy = H * 0.84;
  ctx.fillStyle = rgb(mixColor(A.ground, B.ground, f));
  ctx.beginPath(); ctx.moveTo(0, H);
  for (let x = 0; x <= W; x += 20) ctx.lineTo(x, gy + Math.sin(x * 0.004) * 10);
  ctx.lineTo(W, H); ctx.fill();
  // tree: leaves fall during autumn → winter
  const fallT = Math.max(0, (s - 2) * 3.2 + 0.01);
  const leafColor = i < 2 ? (f > 0.5 ? B.leaves : A.leaves) : SEASONS[2].leaves;
  drawTree(ctx, W / 2, gy + 4, 0.75, 1, {
    bark: '#3b2a1e', leafColor, fallT, density: 1, sway: Math.sin(t * 0.9) * 1.5
  });
  // spring blossoms floating / winter snow
  const snow = smooth(3, 3.6, s);
  if (snow > 0) {
    const r = rng(17);
    ctx.fillStyle = `rgba(255,255,255,${0.85 * snow})`;
    for (let k = 0; k < 400; k++) {
      const sp = 40 + r() * 80, x = (r() * W + Math.sin(t + k) * 30) % W, y = (r() * H + t * sp) % H;
      ctx.beginPath(); ctx.arc(x, y, 1.5 + r() * 2.5, 0, TAU); ctx.fill();
    }
  }
};

const MEMORIES = (() => {
  const r = rng(123), a = [];
  for (let i = 0; i < 46; i++) a.push({ x: W * (0.12 + r() * 0.76), y: H * (0.1 + r() * 0.5), d: r() * 4, c: [[255, 200, 140], [180, 200, 255], [255, 160, 180], [200, 255, 210]][i % 4] });
  return a;
})();

SCENES.legacy = (ctx, lt, t) => {
  drawSky(ctx, [8, 10, 26], [26, 30, 60], [50, 50, 80]);
  drawStars(ctx, t, 0.6);
  const gy = H * 0.84;
  ctx.fillStyle = '#d6dbe6';
  ctx.beginPath(); ctx.moveTo(0, H);
  for (let x = 0; x <= W; x += 20) ctx.lineTo(x, gy + Math.sin(x * 0.004) * 10);
  ctx.lineTo(W, H); ctx.fill();
  ctx.fillStyle = 'rgba(10,12,30,0.55)'; ctx.fillRect(0, gy - 20, W, H);
  drawTree(ctx, W / 2, gy + 4, 0.75, 1, { bark: '#1a1620', leaves: false });
  // lanterns rise from the ground and become stars
  ctx.globalCompositeOperation = 'lighter';
  for (let i = 0; i < MEMORIES.length; i++) {
    const m = MEMORIES[i];
    const k = easeInOut(clamp((lt - m.d) / 5));
    if (k <= 0) continue;
    const x = lerp(W / 2 + (m.x - W / 2) * 0.2, m.x, k) + Math.sin(t + i) * 6 * (1 - k);
    const y = lerp(gy, m.y, k);
    const flick = 0.8 + 0.2 * Math.sin(t * 5 + i * 3);
    glow(ctx, x, y, lerp(46, 26, k) * flick, m.c, 0.75);
    glow(ctx, x, y, 4, [255, 255, 255], 1);
  }
  // constellations connect the memories
  const link = smooth(5, 8.5, lt);
  ctx.strokeStyle = `rgba(200,210,255,${0.25 * link})`; ctx.lineWidth = 1.2;
  ctx.beginPath();
  for (let i = 0; i < MEMORIES.length; i++) {
    const a = MEMORIES[i], b = MEMORIES[(i * 7 + 3) % MEMORIES.length];
    if (Math.hypot(a.x - b.x, a.y - b.y) > 380) continue;
    ctx.moveTo(a.x, a.y); ctx.lineTo(lerp(a.x, b.x, link), lerp(a.y, b.y, link));
  }
  ctx.stroke();
  ctx.globalCompositeOperation = 'source-over';
};

SCENES.rebirth = (ctx, lt, t) => {
  const thaw = smooth(2.5, 9.5, lt);
  drawSky(ctx, mixColor([20, 24, 50], [120, 175, 225], thaw), mixColor([60, 60, 90], [250, 215, 170], thaw), mixColor([90, 90, 110], [255, 235, 200], thaw));
  ctx.globalCompositeOperation = 'lighter';
  glow(ctx, W * 0.82, lerp(H * 0.8, H * 0.35, thaw), 700, [255, 200, 140], 0.5 * thaw);
  ctx.globalCompositeOperation = 'source-over';
  const gy = H * 0.84;
  ctx.fillStyle = rgb(mixColor([200, 205, 220], [100, 170, 80], thaw));
  ctx.beginPath(); ctx.moveTo(0, H);
  for (let x = 0; x <= W; x += 20) ctx.lineTo(x, gy + Math.sin(x * 0.004) * 10);
  ctx.lineTo(W, H); ctx.fill();
  // the old tree, to the side, gently fading into the sky
  ctx.globalAlpha = lerp(1, 0.35, thaw);
  drawTree(ctx, W * 0.3, gy + 4, 0.7, 1, { bark: rgb(mixColor([30, 25, 35], [70, 55, 45], thaw)), leaves: false });
  ctx.globalAlpha = 1;
  // a single seed drops from a branch, glowing
  const d = t - TL.events.seedDrop;
  const sx = W * 0.3 + 230 + Math.sin(Math.max(0, d) * 3) * 25 * (1 - smooth(0, 1.6, d)) + smooth(0, 1.8, d) * 130;
  const sy = lerp(H * 0.38, gy - 4, easeInOut(clamp(d / 1.8)));
  glow(ctx, sx, sy, 60, [255, 225, 150], 0.9);
  glow(ctx, sx, sy, 8, [255, 255, 230], 1);
  // landing ripple
  if (d > 1.8) {
    const rr = (d - 1.8) * 160;
    ctx.strokeStyle = `rgba(255,230,170,${clamp(0.8 - (d - 1.8) * 0.4)})`; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.ellipse(sx, gy - 2, rr, rr * 0.18, 0, 0, TAU); ctx.stroke();
  }
  // a new sprout
  const g = easeOut(clamp((t - TL.events.sproutStart) / 6));
  drawTree(ctx, sx, gy - 2, 0.35, g * 0.5, { bark: '#4a6a2a', leafColor: [[140, 220, 100], [170, 235, 120]], sway: Math.sin(t) * 1 });
};

SCENES.title = (ctx, lt, t) => {
  ctx.fillStyle = '#050508'; ctx.fillRect(0, 0, W, H);
  drawStars(ctx, t, 0.4 * (1 - smooth(7.5, 10, lt)));
  ctx.globalCompositeOperation = 'lighter';
  glow(ctx, W / 2, H / 2 - 40, 700, [255, 190, 130], 0.18 * smooth(0.5, 3, lt) * (1 - smooth(7.5, 10, lt)));
  ctx.globalCompositeOperation = 'source-over';
  const a = smooth(1.0, 3.2, lt) * (1 - smooth(7.4, 9.4, lt));
  const spread = lerp(40, 4, easeOut(smooth(1.0, 5, lt)));
  ctx.save();
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  ctx.font = '700 230px "Playfair Display"';
  ctx.letterSpacing = (spread + 34) + 'px';
  ctx.shadowColor = 'rgba(255,200,140,0.6)'; ctx.shadowBlur = 50;
  ctx.fillStyle = `rgba(255,245,230,${a})`;
  ctx.fillText('LIFE', W / 2 + (spread + 34) / 2, H / 2 - 70);
  ctx.shadowBlur = 0; ctx.letterSpacing = '14px';
  const b = smooth(3.4, 5, lt) * (1 - smooth(7.4, 9.4, lt));
  ctx.font = '300 46px "Montserrat"';
  ctx.fillStyle = `rgba(255,230,200,${b * 0.9})`;
  ctx.fillText('LIVE IT. ALL THE WAY.', W / 2 + 7, H / 2 + 110);
  ctx.restore();
};

// ---------- captions ----------
// Karaoke captions on a translucent "glass" bar: each word lights up as it is spoken.
const CAP = { size: 52, maxW: 1240, lineH: 70, padX: 44, padY: 26, y: H - 175 };
const capLayout = new Map();
function layoutCaption(ctx, c) {
  if (capLayout.has(c)) return capLayout.get(c);
  ctx.save();
  ctx.font = `600 ${CAP.size}px "Montserrat"`; ctx.letterSpacing = '0.5px';
  const space = ctx.measureText(' ').width;
  const total = c.words.reduce((n, w) => n + ctx.measureText(w.w).width + space, -space);
  // wrap into balanced rows rather than leaving one word dangling
  const nRows = Math.ceil(total / CAP.maxW), target = total / nRows + 40;
  const rows = [[]];
  let x = 0;
  for (const w of c.words) {
    const ww = ctx.measureText(w.w).width;
    if (x > 0 && x + ww > target) { rows.push([]); x = 0; }
    rows[rows.length - 1].push({ ...w, x, ww });
    x += ww + space;
  }
  ctx.restore();
  const rowsW = rows.map(r => r[r.length - 1].x + r[r.length - 1].ww);
  const L = { rows, rowsW, w: Math.max(...rowsW) };
  capLayout.set(c, L);
  return L;
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
}

function drawCaption(ctx, t) {
  for (const c of TL.captions) {
    const t0 = c.start - 0.25, t1 = c.end + 0.7;
    if (t < t0 || t > t1) continue;
    const a = smooth(t0, t0 + 0.3, t) * (1 - smooth(t1 - 0.3, t1, t));
    if (a <= 0) continue;
    const L = layoutCaption(ctx, c);
    const rise = (1 - easeOut((t - t0) / 0.45)) * 16;
    const boxW = L.w + CAP.padX * 2, boxH = L.rows.length * CAP.lineH + CAP.padY * 2 - (CAP.lineH - CAP.size) + 6;
    const bx = W / 2 - boxW / 2, by = CAP.y - boxH / 2 + rise;
    ctx.save();
    ctx.globalAlpha = a;
    // frosted glass: blur what is behind the bar, then tint it lightly
    roundRect(ctx, bx, by, boxW, boxH, boxH > 140 ? 34 : boxH / 2);
    ctx.save(); ctx.clip();
    ctx.filter = 'blur(14px)';
    ctx.drawImage(ctx.canvas, bx - 30, by - 30, boxW + 60, boxH + 60, bx - 30, by - 30, boxW + 60, boxH + 60);
    ctx.filter = 'none';
    ctx.fillStyle = 'rgba(12,12,18,0.34)'; ctx.fillRect(bx, by, boxW, boxH);
    ctx.restore();
    roundRect(ctx, bx + 0.75, by + 0.75, boxW - 1.5, boxH - 1.5, boxH > 140 ? 34 : boxH / 2 - 1);
    ctx.strokeStyle = 'rgba(255,255,255,0.16)'; ctx.lineWidth = 1.5; ctx.stroke();
    // words
    ctx.font = `600 ${CAP.size}px "Montserrat"`; ctx.letterSpacing = '0.5px';
    ctx.textBaseline = 'middle'; ctx.textAlign = 'left';
    let cur = -1;
    c.words.forEach((w, i) => { if (t >= w.s - 0.04) cur = i; });
    const curW = c.words[cur];
    L.rows.forEach((row, ri) => {
      const ox = W / 2 - L.rowsW[ri] / 2, oy = by + CAP.padY + CAP.size / 2 + 3 + ri * CAP.lineH;
      for (const w of row) {
        const spoken = smooth(w.s - 0.06, w.s + 0.06, t);
        const active = curW && w.s === curW.s && t < w.e + 0.3;
        const pop = active ? 1 + 0.07 * Math.sin(Math.PI * clamp((t - w.s + 0.04) / 0.25)) : 1;
        const cx = ox + w.x + w.ww / 2;
        ctx.save();
        ctx.translate(cx, oy); ctx.scale(pop, pop);
        if (active) { ctx.shadowColor = 'rgba(255,190,90,0.9)'; ctx.shadowBlur = 22; }
        ctx.fillStyle = active ? 'rgb(255,206,110)' : `rgba(255,255,255,${0.42 + 0.58 * spoken})`;
        ctx.fillText(w.w, -w.ww / 2, 0);
        ctx.restore();
      }
    });
    ctx.restore();
  }
}

// ---------- compositor ----------
const layers = {};
function layer(id) {
  if (!layers[id]) { const c = document.createElement('canvas'); c.width = W; c.height = H; layers[id] = c; }
  return layers[id];
}

const GRAIN = (() => {
  const frames = [];
  for (let f = 0; f < 6; f++) {
    const c = document.createElement('canvas'); c.width = 480; c.height = 270;
    const g = c.getContext('2d'), img = g.createImageData(480, 270), r = rng(900 + f);
    for (let i = 0; i < img.data.length; i += 4) { const v = r() * 255; img.data[i] = img.data[i + 1] = img.data[i + 2] = v; img.data[i + 3] = 255; }
    g.putImageData(img, 0, 0); frames.push(c);
  }
  return frames;
})();

function renderFrame(ctx, t) {
  const F = TL.fade;
  ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
  ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, H);
  for (let i = 0; i < TL.scenes.length; i++) {
    const s = TL.scenes[i];
    const first = i === 0, last = i === TL.scenes.length - 1;
    const from = first ? s.start : s.start - F / 2, to = last ? s.end : s.end + F / 2;
    if (t < from || t > to) continue;
    let a = 1;
    if (!first) a = Math.min(a, smooth(s.start - F / 2, s.start + F / 2, t));
    const c = layer(s.id), g = c.getContext('2d');
    g.save(); g.globalAlpha = 1; g.globalCompositeOperation = 'source-over';
    // slow cinematic push-in on every scene
    // each scene plays its original animation compressed into its (shorter) slot
    const z = 1 + 0.035 * clamp((t - from) / (to - from));
    const k = (s.src[1] - s.src[0]) / (s.end - s.start), lt = (t - s.start) * k;
    g.translate(W / 2, H / 2); g.scale(z, z); g.translate(-W / 2, -H / 2);
    SCENES[s.id](g, lt, s.src[0] + lt);
    g.restore();
    ctx.globalAlpha = a;
    ctx.drawImage(c, 0, 0);
    ctx.globalAlpha = 1;
  }
  drawCaption(ctx, t);
  // vignette
  const v = ctx.createRadialGradient(W / 2, H / 2, H * 0.35, W / 2, H / 2, H * 1.05);
  v.addColorStop(0, 'rgba(0,0,0,0)'); v.addColorStop(1, 'rgba(0,0,0,0.6)');
  ctx.fillStyle = v; ctx.fillRect(0, 0, W, H);
  // film grain
  ctx.globalAlpha = 0.045; ctx.globalCompositeOperation = 'overlay';
  ctx.drawImage(GRAIN[Math.floor(t * TL.fps) % GRAIN.length], 0, 0, W, H);
  ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
  // letterbox (2.39:1-ish bars) + global fade in/out
  const bar = 60;
  ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, bar); ctx.fillRect(0, H - bar, W, bar);
  const fade = smooth(0, 1.5, t) * (1 - smooth(TL.duration - 1.2, TL.duration, t));
  if (fade < 1) { ctx.fillStyle = `rgba(0,0,0,${1 - fade})`; ctx.fillRect(0, 0, W, H); }
}

window.renderFrame = renderFrame;
