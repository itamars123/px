// Fragile Haul: a first-person salvage game.
// Find valuables in a dark estate, float them to the drop zone with a grab beam,
// and don't break them (or wake the things that live there).
(() => {
"use strict";

// ====================================================================
// Config
// ====================================================================
const CELL = 8;            // size of one room
const WALL_H = 3.4;
const WALL_T = 0.4;
const DOOR_W = 2.2;
const PLAYER_R = 0.35;
const EYE = 1.6;
const CROUCH_EYE = 0.95;
const SPEED = { walk: 3.6, sprint: 6.2, crouch: 1.8 };
const GRAVITY = -18;
const GRAB_RANGE = 3.6;
const IMPACT_SAFE = 3.0;   // impact speed (m/s) an item can take without damage
const PHYS_DT = 1 / 120;
const ZONE_HALF = 1.6;

const ITEM_TYPES = [
    { name: "Porcelain Vase", shape: "vase",  r: 0.32, mass: 1.0, value: [700, 1500],  fragility: 1.7, color: 0xdfe8f0 },
    { name: "Brass Clock",    shape: "clock", r: 0.38, mass: 2.0, value: [900, 2000],  fragility: 1.0, color: 0xc9a227 },
    { name: "Crystal Orb",    shape: "orb",   r: 0.27, mass: 0.8, value: [1600, 3200], fragility: 2.4, color: 0x7fd4ff },
    { name: "Old Radio",      shape: "radio", r: 0.40, mass: 2.5, value: [500, 1100],  fragility: 0.6, color: 0x6b4f3a },
    { name: "Marble Bust",    shape: "bust",  r: 0.48, mass: 5.0, value: [2600, 4800], fragility: 0.5, color: 0xb9b5aa },
    { name: "Music Box",      shape: "box",   r: 0.25, mass: 0.6, value: [400, 900],   fragility: 1.2, color: 0x8e3b5f },
    { name: "Gilded Lamp",    shape: "lamp",  r: 0.34, mass: 1.4, value: [800, 1700],  fragility: 1.3, color: 0xe0b84a },
];

// ====================================================================
// Helpers
// ====================================================================
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const rand = (a, b) => a + Math.random() * (b - a);
const randInt = (a, b) => Math.floor(rand(a, b + 1));
const pick = arr => arr[Math.floor(Math.random() * arr.length)];
const money = n => "$" + Math.round(n).toLocaleString("en-US");
const cellCenter = (i, j) => new THREE.Vector3((i + 0.5) * CELL, 0, (j + 0.5) * CELL);
const cellOf = p => [clamp(Math.floor(p.x / CELL), 0, grid.w - 1), clamp(Math.floor(p.z / CELL), 0, grid.h - 1)];
const $ = id => document.getElementById(id);

function storageGet(key) {
    try { return localStorage.getItem(key); } catch { return null; }
}
function storageSet(key, val) {
    try { localStorage.setItem(key, val); } catch { /* ignore */ }
}

// ====================================================================
// Renderer / scene
// ====================================================================
const canvas = $("view");
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.15;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x020304);
scene.fog = new THREE.Fog(0x020304, 4, 26);

const camera = new THREE.PerspectiveCamera(75, 1, 0.05, 80);
camera.rotation.order = "YXZ";
scene.add(camera);

scene.add(new THREE.AmbientLight(0x3a4a66, 0.35));
scene.add(new THREE.HemisphereLight(0x405070, 0x100804, 0.25));

const flashlight = new THREE.SpotLight(0xfff1d6, 55, 28, 0.55, 0.45, 1.4);
flashlight.position.set(0.25, -0.15, 0);
camera.add(flashlight);
camera.add(flashlight.target);
flashlight.target.position.set(0, -0.1, -5);

function resize() {
    renderer.setSize(window.innerWidth, window.innerHeight, false);
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
}
window.addEventListener("resize", resize);
resize();

// ---------- Procedural textures ----------
function makeTexture(draw, size = 256) {
    const c = document.createElement("canvas");
    c.width = c.height = size;
    draw(c.getContext("2d"), size);
    const t = new THREE.CanvasTexture(c);
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.colorSpace = THREE.SRGBColorSpace;
    t.anisotropy = 4;
    return t;
}

const floorTex = makeTexture((g, s) => {
    g.fillStyle = "#4a3324";
    g.fillRect(0, 0, s, s);
    const plank = s / 8;
    for (let i = 0; i < 8; i++) {
        const shade = 60 + Math.random() * 25;
        g.fillStyle = `rgb(${shade + 20},${shade - 5},${shade - 25})`;
        g.fillRect(0, i * plank + 1, s, plank - 2);
        g.fillStyle = "rgba(0,0,0,0.35)";
        g.fillRect(Math.random() * s, i * plank, 2, plank);
        for (let k = 0; k < 30; k++) {
            g.fillStyle = `rgba(0,0,0,${Math.random() * 0.08})`;
            g.fillRect(Math.random() * s, i * plank + Math.random() * plank, rand(10, 60), 1);
        }
    }
});
floorTex.repeat.set(2, 2);

const wallTex = makeTexture((g, s) => {
    g.fillStyle = "#3d4a3f";
    g.fillRect(0, 0, s, s);
    for (let x = 0; x < s; x += 32) {
        g.fillStyle = "rgba(255,240,200,0.06)";
        g.fillRect(x, 0, 12, s * 0.7);
        g.fillStyle = "rgba(255,230,180,0.08)";
        for (let y = 10; y < s * 0.7; y += 26) {
            g.beginPath();
            g.arc(x + 22, y, 3, 0, Math.PI * 2);
            g.fill();
        }
    }
    g.fillStyle = "#2a1d14";                 // wainscot
    g.fillRect(0, s * 0.7, s, s * 0.3);
    g.fillStyle = "#1a120c";
    g.fillRect(0, s * 0.7, s, 6);
    for (let x = 0; x < s; x += 64) g.fillRect(x, s * 0.72, 3, s * 0.28);
    for (let k = 0; k < 400; k++) {              // grime
        g.fillStyle = `rgba(0,0,0,${Math.random() * 0.1})`;
        g.fillRect(Math.random() * s, Math.random() * s, rand(2, 10), rand(2, 10));
    }
});

const woodTex = makeTexture((g, s) => {
    g.fillStyle = "#3b2414";
    g.fillRect(0, 0, s, s);
    for (let k = 0; k < 120; k++) {
        g.strokeStyle = `rgba(0,0,0,${Math.random() * 0.2})`;
        g.beginPath();
        const y = Math.random() * s;
        g.moveTo(0, y);
        g.bezierCurveTo(s / 3, y + rand(-8, 8), (2 * s) / 3, y + rand(-8, 8), s, y);
        g.stroke();
    }
}, 128);

const MAT = {
    floor: new THREE.MeshStandardMaterial({ map: floorTex, roughness: 0.85 }),
    ceiling: new THREE.MeshStandardMaterial({ color: 0x15130f, roughness: 1 }),
    wall: new THREE.MeshStandardMaterial({ map: wallTex, roughness: 0.95 }),
    wood: new THREE.MeshStandardMaterial({ map: woodTex, roughness: 0.7 }),
    zone: new THREE.MeshBasicMaterial({ color: 0x3ee6c1, transparent: true, opacity: 0.22, depthWrite: false }),
    zoneEdge: new THREE.MeshBasicMaterial({ color: 0x3ee6c1 }),
    bulb: new THREE.MeshBasicMaterial({ color: 0xffd9a0 }),
    shard: new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.3 }),
    beam: new THREE.LineBasicMaterial({ color: 0x3ee6c1, transparent: true, opacity: 0.8 }),
};

// ====================================================================
// Audio (tiny WebAudio synth – no files)
// ====================================================================
const audio = {
    ctx: null,
    drone: null,
    droneGain: null,
    init() {
        if (this.ctx) return;
        const AC = window.AudioContext || window.webkitAudioContext;
        if (!AC) return;
        this.ctx = new AC();
        this.master = this.ctx.createGain();
        this.master.gain.value = 0.6;
        this.master.connect(this.ctx.destination);
        // Monster proximity drone
        this.drone = this.ctx.createOscillator();
        this.drone.type = "sawtooth";
        this.drone.frequency.value = 46;
        const lp = this.ctx.createBiquadFilter();
        lp.type = "lowpass";
        lp.frequency.value = 220;
        this.droneGain = this.ctx.createGain();
        this.droneGain.gain.value = 0;
        this.drone.connect(lp).connect(this.droneGain).connect(this.master);
        this.drone.start();
    },
    noise(duration, freq, vol) {
        if (!this.ctx) return;
        const len = Math.floor(this.ctx.sampleRate * duration);
        const buf = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
        const d = buf.getChannelData(0);
        for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 3);
        const src = this.ctx.createBufferSource();
        src.buffer = buf;
        const f = this.ctx.createBiquadFilter();
        f.type = "bandpass";
        f.frequency.value = freq;
        f.Q.value = 0.8;
        const g = this.ctx.createGain();
        g.gain.value = vol;
        src.connect(f).connect(g).connect(this.master);
        src.start();
    },
    tone(freq, duration, type = "sine", vol = 0.2, delay = 0, slideTo = null) {
        if (!this.ctx) return;
        const t = this.ctx.currentTime + delay;
        const o = this.ctx.createOscillator();
        o.type = type;
        o.frequency.setValueAtTime(freq, t);
        if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t + duration);
        const g = this.ctx.createGain();
        g.gain.setValueAtTime(vol, t);
        g.gain.exponentialRampToValueAtTime(0.001, t + duration);
        o.connect(g).connect(this.master);
        o.start(t);
        o.stop(t + duration + 0.05);
    },
    impact(strength) { this.noise(0.15 + strength * 0.02, 900 + Math.random() * 1500, clamp(strength * 0.06, 0.05, 0.6)); },
    thud(strength) { this.noise(0.12, 180, clamp(strength * 0.05, 0.02, 0.3)); },
    shatter() { this.noise(0.6, 3200, 0.7); this.noise(0.4, 1600, 0.4); },
    hurt() { this.tone(160, 0.5, "sawtooth", 0.4, 0, 60); this.noise(0.3, 300, 0.5); },
    grab() { this.tone(520, 0.12, "sine", 0.08, 0, 880); },
    cash() { [523, 659, 784, 1047].forEach((f, i) => this.tone(f, 0.25, "triangle", 0.15, i * 0.09)); },
    alert() { this.tone(90, 0.8, "sawtooth", 0.25, 0, 45); },
    step(vol) { this.noise(0.06, 250, vol); },
    setDrone(level) {
        if (!this.droneGain) return;
        this.droneGain.gain.setTargetAtTime(level * 0.35, this.ctx.currentTime, 0.2);
        this.drone.frequency.setTargetAtTime(40 + level * 25, this.ctx.currentTime, 0.3);
    },
};

// ====================================================================
// Game state
// ====================================================================
const game = {
    state: "menu",          // menu | playing | paused | cleared | dead
    night: 1,
    banked: 0,
    quota: 0,
    nightLost: 0,           // value lost to damage this night
    nightBroken: 0,
};

let levelGroup = null;
let grid = { w: 0, h: 0, hOpen: [], vOpen: [] };
let boxes = [];            // static colliders {minX,maxX,minY,maxY,minZ,maxZ}
let obstacleMeshes = [];   // walls + furniture (for raycasts)
let items = [];
let monsters = [];
let lamps = [];
let shards = [];
let popups = [];
let zone = { x: 0, z: 0 };

const player = {
    pos: new THREE.Vector3(),
    yaw: 0,
    pitch: 0,
    health: 100,
    stamina: 100,
    crouch: false,
    eye: EYE,
    stepTimer: 0,
    hurtCd: 0,
};

let held = null;
let holdDist = 2.2;
const input = { keys: {}, mouseDown: false };
const raycaster = new THREE.Raycaster();

// ====================================================================
// Level generation
// ====================================================================
function disposeGroup(group) {
    group.traverse(o => {
        if (o.geometry) o.geometry.dispose();
        if (o.material && !Object.values(MAT).includes(o.material)) {
            (Array.isArray(o.material) ? o.material : [o.material]).forEach(m => m.dispose());
        }
    });
    scene.remove(group);
}

function canPass(i, j, di, dj) {
    const ni = i + di, nj = j + dj;
    if (ni < 0 || nj < 0 || ni >= grid.w || nj >= grid.h) return false;
    if (di === 1) return grid.hOpen[i][j];
    if (di === -1) return grid.hOpen[ni][j];
    if (dj === 1) return grid.vOpen[i][j];
    return grid.vOpen[i][nj];
}

function bfs(from, to) {
    const key = (i, j) => i * 100 + j;
    const prev = new Map([[key(...from), null]]);
    const queue = [from];
    while (queue.length) {
        const [i, j] = queue.shift();
        if (i === to[0] && j === to[1]) break;
        for (const [di, dj] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
            if (!canPass(i, j, di, dj)) continue;
            const k = key(i + di, j + dj);
            if (prev.has(k)) continue;
            prev.set(k, [i, j]);
            queue.push([i + di, j + dj]);
        }
    }
    if (!prev.has(key(...to))) return [];
    const path = [];
    let cur = to;
    while (cur && !(cur[0] === from[0] && cur[1] === from[1])) {
        path.unshift(cur);
        cur = prev.get(key(...cur));
    }
    return path;
}

function addBox(minX, maxX, minY, maxY, minZ, maxZ, material, uvScale = 3) {
    const w = maxX - minX, h = maxY - minY, d = maxZ - minZ;
    const geo = new THREE.BoxGeometry(w, h, d);
    const uv = geo.attributes.uv;
    for (let k = 0; k < uv.count; k++) {
        uv.setXY(k, uv.getX(k) * Math.max(w, d) / uvScale, uv.getY(k) * h / uvScale);
    }
    const mesh = new THREE.Mesh(geo, material);
    mesh.position.set((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2);
    levelGroup.add(mesh);
    boxes.push({ minX, maxX, minY, maxY, minZ, maxZ });
    obstacleMeshes.push(mesh);
    return mesh;
}

// Wall along a cell edge, optionally with a doorway in the middle.
function addWallSegment(x0, z0, x1, z1, door) {
    const alongX = z0 === z1;
    const len = alongX ? x1 - x0 : z1 - z0;
    const parts = door
        ? [[0, (len - DOOR_W) / 2], [(len + DOOR_W) / 2, len]]
        : [[0, len]];
    const t = WALL_T / 2;
    for (const [a, b] of parts) {
        if (alongX) addBox(x0 + a - t, x0 + b + t, 0, WALL_H, z0 - t, z0 + t, MAT.wall);
        else addBox(x0 - t, x0 + t, 0, WALL_H, z0 + a - t, z0 + b + t, MAT.wall);
    }
    if (door) {   // lintel above the doorway
        const mid = len / 2;
        if (alongX) addBox(x0 + mid - DOOR_W / 2, x0 + mid + DOOR_W / 2, 2.5, WALL_H, z0 - t, z0 + t, MAT.wall);
        else addBox(x0 - t, x0 + t, 2.5, WALL_H, z0 + mid - DOOR_W / 2, z0 + mid + DOOR_W / 2, MAT.wall);
    }
}

function buildLevel(n) {
    if (levelGroup) disposeGroup(levelGroup);
    levelGroup = new THREE.Group();
    scene.add(levelGroup);
    boxes = [];
    obstacleMeshes = [];
    items = [];
    monsters = [];
    lamps = [];
    shards = [];
    popups.forEach(p => p.el.remove());
    popups = [];
    held = null;

    // ---- maze layout (random spanning tree + a few loops) ----
    const w = Math.min(3 + n, 7);
    const h = Math.min(3 + Math.ceil(n / 2), 6);
    grid = {
        w, h,
        hOpen: Array.from({ length: w }, () => Array(h).fill(false)),
        vOpen: Array.from({ length: w }, () => Array(h).fill(false)),
    };
    const seen = Array.from({ length: w }, () => Array(h).fill(false));
    const stack = [[0, 0]];
    seen[0][0] = true;
    while (stack.length) {
        const [i, j] = stack[stack.length - 1];
        const options = [[1, 0], [-1, 0], [0, 1], [0, -1]].filter(([di, dj]) => {
            const ni = i + di, nj = j + dj;
            return ni >= 0 && nj >= 0 && ni < w && nj < h && !seen[ni][nj];
        });
        if (!options.length) { stack.pop(); continue; }
        const [di, dj] = pick(options);
        const ni = i + di, nj = j + dj;
        if (di) grid.hOpen[Math.min(i, ni)][j] = true;
        else grid.vOpen[i][Math.min(j, nj)] = true;
        seen[ni][nj] = true;
        stack.push([ni, nj]);
    }
    for (let i = 0; i < w; i++) for (let j = 0; j < h; j++) {
        if (i < w - 1 && Math.random() < 0.25) grid.hOpen[i][j] = true;
        if (j < h - 1 && Math.random() < 0.25) grid.vOpen[i][j] = true;
    }

    // ---- floor, ceiling, walls ----
    const W = w * CELL, H = h * CELL;
    const floorGeo = new THREE.PlaneGeometry(W, H);
    const fuv = floorGeo.attributes.uv;
    for (let k = 0; k < fuv.count; k++) fuv.setXY(k, fuv.getX(k) * w, fuv.getY(k) * h);
    const floor = new THREE.Mesh(floorGeo, MAT.floor);
    floor.rotation.x = -Math.PI / 2;
    floor.position.set(W / 2, 0, H / 2);
    levelGroup.add(floor);
    const ceil = new THREE.Mesh(new THREE.PlaneGeometry(W, H), MAT.ceiling);
    ceil.rotation.x = Math.PI / 2;
    ceil.position.set(W / 2, WALL_H, H / 2);
    levelGroup.add(ceil);

    for (let i = 0; i <= w; i++) for (let j = 0; j < h; j++) {
        const door = i > 0 && i < w && grid.hOpen[i - 1][j];
        addWallSegment(i * CELL, j * CELL, i * CELL, (j + 1) * CELL, door);
    }
    for (let j = 0; j <= h; j++) for (let i = 0; i < w; i++) {
        const door = j > 0 && j < h && grid.vOpen[i][j - 1];
        addWallSegment(i * CELL, j * CELL, (i + 1) * CELL, j * CELL, door);
    }

    // ---- drop zone in the starting room ----
    zone = { x: CELL / 2, z: CELL / 2 };
    const zonePlane = new THREE.Mesh(new THREE.PlaneGeometry(ZONE_HALF * 2, ZONE_HALF * 2), MAT.zone);
    zonePlane.rotation.x = -Math.PI / 2;
    zonePlane.position.set(zone.x, 0.01, zone.z);
    levelGroup.add(zonePlane);
    const edgeGeo = new THREE.EdgesGeometry(new THREE.BoxGeometry(ZONE_HALF * 2, 0.02, ZONE_HALF * 2));
    const edge = new THREE.LineSegments(edgeGeo, new THREE.LineBasicMaterial({ color: 0x3ee6c1 }));
    edge.position.set(zone.x, 0.02, zone.z);
    levelGroup.add(edge);
    const zoneLight = new THREE.PointLight(0x3ee6c1, 6, 7, 2);
    zoneLight.position.set(zone.x, 1.2, zone.z);
    levelGroup.add(zoneLight);

    // ---- furniture & lamps ----
    const furnitureTops = [];
    let lampCount = 0;
    for (let i = 0; i < w; i++) for (let j = 0; j < h; j++) {
        const c = cellCenter(i, j);
        const start = i === 0 && j === 0;
        if (!start) {
            const corners = [[1, 1], [1, -1], [-1, 1], [-1, -1]].sort(() => Math.random() - 0.5);
            const count = randInt(1, 2);
            for (let k = 0; k < count; k++) {
                const [sx, sz] = corners[k];
                const kind = Math.random();
                const fx = c.x + sx * 2.7, fz = c.z + sz * 2.7;
                if (kind < 0.55) {          // table
                    const hw = 0.75, hd = 0.55, top = 0.8;
                    addBox(fx - hw, fx + hw, top - 0.08, top, fz - hd, fz + hd, MAT.wood, 1.5);
                    for (const [lx, lz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
                        const leg = new THREE.Mesh(new THREE.BoxGeometry(0.08, top - 0.08, 0.08), MAT.wood);
                        leg.position.set(fx + lx * (hw - 0.08), (top - 0.08) / 2, fz + lz * (hd - 0.08));
                        levelGroup.add(leg);
                    }
                    // legs block the player/monsters but not rolling items: thin collider under the table
                    boxes.push({ minX: fx - hw + 0.05, maxX: fx + hw - 0.05, minY: 0, maxY: 0.05, minZ: fz - hd + 0.05, maxZ: fz + hd - 0.05, walkBlock: true });
                    furnitureTops.push({ x: fx, z: fz, y: top, hw, hd });
                } else if (kind < 0.85) {   // cabinet
                    addBox(fx - 0.6, fx + 0.6, 0, 1.3, fz - 0.45, fz + 0.45, MAT.wood, 1.5);
                    furnitureTops.push({ x: fx, z: fz, y: 1.3, hw: 0.6, hd: 0.45 });
                } else {                    // tall wardrobe
                    addBox(fx - 0.7, fx + 0.7, 0, 2.3, fz - 0.5, fz + 0.5, MAT.wood, 1.5);
                }
            }
        }
        if (lampCount < 9 && (start || Math.random() < 0.35)) {
            lampCount++;
            const light = new THREE.PointLight(0xffb070, 9, 11, 2);
            light.position.set(c.x, WALL_H - 0.5, c.z);
            levelGroup.add(light);
            const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.12, 12, 8), MAT.bulb);
            bulb.position.copy(light.position);
            levelGroup.add(bulb);
            const cord = new THREE.Mesh(new THREE.CylinderGeometry(0.01, 0.01, 0.4), MAT.wood);
            cord.position.set(c.x, WALL_H - 0.25, c.z);
            levelGroup.add(cord);
            lamps.push({ light, bulb, base: start ? 5 : 9, flicker: Math.random() < 0.5 });
        }
    }

    // ---- valuables ----
    game.quota = 4000 + (n - 1) * 3000;
    const itemCount = Math.round(w * h * 1.4) + 2;
    let total = 0;
    let tries = 0;
    while ((items.length < itemCount || total < game.quota * 2.2) && tries++ < 500) {
        const type = pick(ITEM_TYPES);
        let pos = null;
        if (furnitureTops.length && Math.random() < 0.35) {
            const top = pick(furnitureTops);
            pos = new THREE.Vector3(top.x + rand(-top.hw, top.hw) * 0.5, top.y + type.r + 0.02, top.z + rand(-top.hd, top.hd) * 0.5);
        } else {
            const i = randInt(0, w - 1), j = randInt(0, h - 1);
            if (i === 0 && j === 0) continue;
            const c = cellCenter(i, j);
            pos = new THREE.Vector3(c.x + rand(-3, 3), type.r + 0.02, c.z + rand(-3, 3));
        }
        if (boxes.some(b => sphereHitsBox(pos, type.r + 0.05, b))) continue;
        if (items.some(it => it.pos.distanceTo(pos) < it.type.r + type.r + 0.1)) continue;
        const it = spawnItem(type, pos);
        total += it.value;
    }

    // ---- monsters (spawn far from the start) ----
    const monsterCount = Math.min(1 + Math.floor(n / 2), 4);
    const farCells = [];
    for (let i = 0; i < w; i++) for (let j = 0; j < h; j++) {
        if (bfs([0, 0], [i, j]).length >= 3) farCells.push([i, j]);
    }
    for (let k = 0; k < monsterCount && farCells.length; k++) {
        const idx = Math.floor(Math.random() * farCells.length);
        spawnMonster(farCells.splice(idx, 1)[0]);
    }

    // ---- player ----
    player.pos.set(zone.x - 1.2, 0, zone.z - 1.2);
    player.yaw = -Math.PI * 0.75;
    player.pitch = -0.1;
    player.health = 100;
    player.stamina = 100;
    game.nightLost = 0;
    game.nightBroken = 0;
}

// ====================================================================
// Items
// ====================================================================
function buildItemMesh(type) {
    const g = new THREE.Group();
    const mat = new THREE.MeshStandardMaterial({
        color: type.color,
        roughness: type.shape === "orb" ? 0.1 : 0.45,
        metalness: ["clock", "lamp"].includes(type.shape) ? 0.7 : 0.05,
        emissive: type.shape === "orb" ? 0x2a7fb0 : 0x000000,
        emissiveIntensity: type.shape === "orb" ? 0.9 : 0,
        transparent: type.shape === "orb",
        opacity: type.shape === "orb" ? 0.85 : 1,
    });
    const r = type.r;
    const add = (geo, y = 0, m = mat) => {
        const mesh = new THREE.Mesh(geo, m);
        mesh.position.y = y;
        g.add(mesh);
        return mesh;
    };
    switch (type.shape) {
        case "vase": {
            const pts = [];
            for (let k = 0; k <= 10; k++) {
                const t = k / 10;
                pts.push(new THREE.Vector2(r * (0.35 + 0.55 * Math.sin(Math.PI * t * 0.95)) + 0.02, -r + t * 2 * r));
            }
            add(new THREE.LatheGeometry(pts, 20));
            const band = new THREE.MeshStandardMaterial({ color: 0x2850a8, roughness: 0.4 });
            add(new THREE.TorusGeometry(r * 0.88, 0.025, 6, 20), 0, band).rotation.x = Math.PI / 2;
            break;
        }
        case "clock":
            add(new THREE.BoxGeometry(r * 1.1, r * 2, r * 0.7));
            add(new THREE.CylinderGeometry(r * 0.42, r * 0.42, 0.04, 20), r * 0.35,
                new THREE.MeshStandardMaterial({ color: 0xf3ead2 })).rotation.x = Math.PI / 2;
            g.children[1].position.z = r * 0.36;
            break;
        case "orb": {
            add(new THREE.SphereGeometry(r * 0.8, 24, 16), r * 0.15);
            add(new THREE.CylinderGeometry(r * 0.45, r * 0.6, r * 0.4, 16), -r * 0.75,
                new THREE.MeshStandardMaterial({ color: 0x3a2a1a, metalness: 0.5, roughness: 0.4 }));
            const glow = new THREE.PointLight(0x7fd4ff, 1.5, 3, 2);
            g.add(glow);
            break;
        }
        case "radio":
            add(new THREE.BoxGeometry(r * 1.7, r * 1.2, r * 0.9));
            add(new THREE.CylinderGeometry(r * 0.3, r * 0.3, 0.03, 16), 0,
                new THREE.MeshStandardMaterial({ color: 0x222222 })).rotation.x = Math.PI / 2;
            g.children[1].position.set(-r * 0.4, 0, r * 0.46);
            break;
        case "bust":
            add(new THREE.CylinderGeometry(r * 0.55, r * 0.7, r * 0.6, 16), -r * 0.7);
            add(new THREE.CylinderGeometry(r * 0.25, r * 0.35, r * 0.4, 12), -r * 0.2);
            add(new THREE.SphereGeometry(r * 0.45, 16, 12), r * 0.35);
            break;
        case "lamp":
            add(new THREE.CylinderGeometry(r * 0.4, r * 0.55, r * 0.25, 16), -r * 0.85);
            add(new THREE.CylinderGeometry(0.03, 0.03, r * 1.2, 8), -r * 0.15);
            add(new THREE.CylinderGeometry(r * 0.35, r * 0.75, r * 0.6, 16, 1, true), r * 0.55,
                new THREE.MeshStandardMaterial({ color: 0xf5e6c4, side: THREE.DoubleSide, emissive: 0x553311 }));
            break;
        default:
            add(new THREE.BoxGeometry(r * 1.4, r * 1.1, r * 1.0));
            add(new THREE.BoxGeometry(r * 1.45, r * 0.12, r * 1.05), r * 0.3,
                new THREE.MeshStandardMaterial({ color: 0xd4af37, metalness: 0.8, roughness: 0.3 }));
    }
    return g;
}

function spawnItem(type, pos) {
    const mesh = buildItemMesh(type);
    mesh.position.copy(pos);
    mesh.rotation.y = Math.random() * Math.PI * 2;
    levelGroup.add(mesh);
    const base = Math.round(rand(type.value[0], type.value[1]) / 10) * 10;
    const item = {
        type, mesh,
        pos: mesh.position,
        vel: new THREE.Vector3(),
        spin: new THREE.Vector3(),
        r: type.r,
        mass: type.mass,
        baseValue: base,
        value: base,
        hitCd: 0,
        flash: 0,
        alive: true,
    };
    mesh.traverse(o => { o.userData.item = item; });
    items.push(item);
    return item;
}

function sphereHitsBox(p, r, b) {
    const cx = clamp(p.x, b.minX, b.maxX), cy = clamp(p.y, b.minY, b.maxY), cz = clamp(p.z, b.minZ, b.maxZ);
    const dx = p.x - cx, dy = p.y - cy, dz = p.z - cz;
    return dx * dx + dy * dy + dz * dz < r * r;
}

// Resolve sphere vs AABB. Returns {impact, ny} or null.
function collideSphereBox(item, b) {
    const p = item.pos, v = item.vel, r = item.r;
    if (p.x + r < b.minX || p.x - r > b.maxX || p.z + r < b.minZ || p.z - r > b.maxZ ||
        p.y + r < b.minY || p.y - r > b.maxY) return null;
    const cx = clamp(p.x, b.minX, b.maxX), cy = clamp(p.y, b.minY, b.maxY), cz = clamp(p.z, b.minZ, b.maxZ);
    let dx = p.x - cx, dy = p.y - cy, dz = p.z - cz;
    const d2 = dx * dx + dy * dy + dz * dz;
    if (d2 >= r * r) return null;
    let nx, ny, nz, pen;
    if (d2 > 1e-9) {
        const d = Math.sqrt(d2);
        nx = dx / d; ny = dy / d; nz = dz / d;
        pen = r - d;
    } else {
        const opts = [
            [p.x - b.minX, -1, 0, 0], [b.maxX - p.x, 1, 0, 0],
            [p.y - b.minY, 0, -1, 0], [b.maxY - p.y, 0, 1, 0],
            [p.z - b.minZ, 0, 0, -1], [b.maxZ - p.z, 0, 0, 1],
        ].sort((a, c) => a[0] - c[0]);
        [pen, nx, ny, nz] = opts[0];
        pen += r;
    }
    p.x += nx * pen; p.y += ny * pen; p.z += nz * pen;
    const vn = v.x * nx + v.y * ny + v.z * nz;
    if (vn < 0) {
        const e = 0.3;
        v.x -= (1 + e) * vn * nx;
        v.y -= (1 + e) * vn * ny;
        v.z -= (1 + e) * vn * nz;
        return { impact: -vn, ny };
    }
    return { impact: 0, ny };
}

function damageItem(item, impact) {
    if (!item.alive) return;
    if (impact > 1.6 && item.hitCd <= 0) audio.thud(impact);
    if (impact > 1.6) emitNoise(item.pos, 2 + impact * 1.2);
    if (impact < IMPACT_SAFE || item.hitCd > 0) return;
    item.hitCd = 0.15;
    const frac = Math.min(0.6, (impact - IMPACT_SAFE) * 0.045 * item.type.fragility + 0.02 * item.type.fragility);
    const loss = Math.min(item.value, Math.max(10, Math.round(item.baseValue * frac / 10) * 10));
    item.value -= loss;
    item.flash = 0.3;
    game.nightLost += loss;
    addPopup(item.pos, `-${money(loss)}`, false);
    audio.impact(impact);
    emitNoise(item.pos, 6 + impact * 2.5);
    if (item.value <= item.baseValue * 0.1) destroyItem(item);
}

function destroyItem(item) {
    item.alive = false;
    game.nightBroken++;
    game.nightLost += item.value;
    if (item.value > 0) addPopup(item.pos, "BROKEN", false);
    item.value = 0;
    if (held === item) held = null;
    audio.shatter();
    emitNoise(item.pos, 16);
    const color = item.type.color;
    for (let k = 0; k < 14; k++) {
        const m = new THREE.Mesh(new THREE.TetrahedronGeometry(rand(0.03, 0.09)),
            new THREE.MeshStandardMaterial({ color, roughness: 0.4 }));
        m.position.copy(item.pos);
        levelGroup.add(m);
        shards.push({
            mesh: m,
            vel: new THREE.Vector3(rand(-3, 3), rand(1, 5), rand(-3, 3)),
            life: rand(1.2, 2),
        });
    }
    levelGroup.remove(item.mesh);
    items = items.filter(i => i !== item);
}

function stepItems(dt) {
    const camPos = camera.position;
    const dir = new THREE.Vector3();
    camera.getWorldDirection(dir);

    for (const it of items) {
        it.hitCd -= dt;
        const acc = new THREE.Vector3(0, GRAVITY, 0);
        if (it === held) {
            const target = camPos.clone().addScaledVector(dir, holdDist);
            target.y -= Math.max(0, it.mass - 1) * 0.08;   // heavy things sag
            const K = 95 / (0.5 + 0.5 * it.mass);
            const D = 2 * Math.sqrt(K) * 0.85;
            acc.copy(target).sub(it.pos).multiplyScalar(K).addScaledVector(it.vel, -D);
            if (it.pos.distanceTo(target) > 3.5) dropHeld();
        }
        it.vel.addScaledVector(acc, dt);
        if (it.vel.lengthSq() > 196) it.vel.setLength(14);
        it.pos.addScaledVector(it.vel, dt);

        let grounded = false;
        // floor
        if (it.pos.y < it.r) {
            const impact = -it.vel.y;
            it.pos.y = it.r;
            if (it.vel.y < 0) it.vel.y = -it.vel.y * 0.25;
            if (impact > 0.5) damageItem(it, impact);
            grounded = true;
        }
        // ceiling
        if (it.pos.y > WALL_H - it.r) {
            const impact = it.vel.y;
            it.pos.y = WALL_H - it.r;
            if (it.vel.y > 0) it.vel.y = -it.vel.y * 0.25;
            damageItem(it, impact);
        }
        // static geometry
        for (const b of boxes) {
            if (b.walkBlock) continue;
            const hit = collideSphereBox(it, b);
            if (!hit) continue;
            if (hit.ny > 0.7) grounded = true;
            damageItem(it, hit.impact);
        }
        // player body pushes items
        if (it !== held && it.pos.y - it.r < 1.7) {
            const dx = it.pos.x - player.pos.x, dz = it.pos.z - player.pos.z;
            const d = Math.hypot(dx, dz), min = it.r + PLAYER_R;
            if (d < min && d > 1e-6) {
                it.pos.x += (dx / d) * (min - d);
                it.pos.z += (dz / d) * (min - d);
                const vn = (it.vel.x * dx + it.vel.z * dz) / d;
                if (vn < 1.2) {
                    it.vel.x += (dx / d) * (1.2 - vn);
                    it.vel.z += (dz / d) * (1.2 - vn);
                }
            }
        }
        if (grounded && it !== held) {
            const f = Math.max(0, 1 - 5 * dt);
            it.vel.x *= f;
            it.vel.z *= f;
            if (it.vel.lengthSq() < 0.0025) it.vel.set(0, 0, 0);
        }
    }

    // item vs item
    for (let a = 0; a < items.length; a++) {
        for (let b = a + 1; b < items.length; b++) {
            const A = items[a], B = items[b];
            const dx = B.pos.x - A.pos.x, dy = B.pos.y - A.pos.y, dz = B.pos.z - A.pos.z;
            const rs = A.r + B.r;
            const d2 = dx * dx + dy * dy + dz * dz;
            if (d2 >= rs * rs || d2 < 1e-10) continue;
            const d = Math.sqrt(d2);
            const nx = dx / d, ny = dy / d, nz = dz / d;
            const wa = A === held ? 0.2 / A.mass : 1 / A.mass;
            const wb = B === held ? 0.2 / B.mass : 1 / B.mass;
            const pen = rs - d;
            const sa = pen * wa / (wa + wb), sb = pen * wb / (wa + wb);
            A.pos.x -= nx * sa; A.pos.y -= ny * sa; A.pos.z -= nz * sa;
            B.pos.x += nx * sb; B.pos.y += ny * sb; B.pos.z += nz * sb;
            const rel = (B.vel.x - A.vel.x) * nx + (B.vel.y - A.vel.y) * ny + (B.vel.z - A.vel.z) * nz;
            if (rel < 0) {
                const j = -(1.3 * rel) / (wa + wb);
                A.vel.x -= nx * j * wa; A.vel.y -= ny * j * wa; A.vel.z -= nz * j * wa;
                B.vel.x += nx * j * wb; B.vel.y += ny * j * wb; B.vel.z += nz * j * wb;
                damageItem(A, -rel * 0.85);
                damageItem(B, -rel * 0.85);
            }
        }
    }
}

function updateItemVisuals(dt) {
    for (const it of items) {
        // roll/tumble a bit with velocity
        const hv = Math.hypot(it.vel.x, it.vel.z);
        if (hv > 0.05) {
            it.mesh.rotation.z -= it.vel.x * dt * 0.8 / it.r * 0.3;
            it.mesh.rotation.x += it.vel.z * dt * 0.8 / it.r * 0.3;
        } else {   // settle upright
            it.mesh.rotation.x *= 0.9;
            it.mesh.rotation.z *= 0.9;
        }
        if (it === held) it.mesh.rotation.y += dt * 0.6;
        if (it.flash > 0) it.flash -= dt;
        const flashing = it.flash > 0;
        it.mesh.traverse(o => {
            if (!o.material || !o.material.emissive) return;
            if (o.userData.baseEmissive === undefined) o.userData.baseEmissive = o.material.emissive.getHex();
            o.material.emissive.setHex(flashing ? 0xaa0000 : (it === held ? 0x0c3a32 : o.userData.baseEmissive));
        });
    }
    for (const s of shards) {
        s.vel.y += GRAVITY * dt;
        s.mesh.position.addScaledVector(s.vel, dt);
        if (s.mesh.position.y < 0.03) {
            s.mesh.position.y = 0.03;
            s.vel.set(s.vel.x * 0.5, -s.vel.y * 0.3, s.vel.z * 0.5);
        }
        s.mesh.rotation.x += dt * 5;
        s.life -= dt;
        if (s.life < 0) levelGroup.remove(s.mesh);
    }
    shards = shards.filter(s => s.life >= 0);
}

// ====================================================================
// Grab beam
// ====================================================================
const beamGeo = new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(), new THREE.Vector3()]);
const beam = new THREE.Line(beamGeo, MAT.beam);
beam.frustumCulled = false;
beam.visible = false;
scene.add(beam);

function lookTarget() {
    const dir = new THREE.Vector3();
    camera.getWorldDirection(dir);
    raycaster.set(camera.position, dir);
    raycaster.far = GRAB_RANGE;
    const itemHits = raycaster.intersectObjects(items.map(i => i.mesh), true);
    if (!itemHits.length) return null;
    const wallHits = raycaster.intersectObjects(obstacleMeshes, false);
    if (wallHits.length && wallHits[0].distance < itemHits[0].distance) return null;
    return { item: itemHits[0].object.userData.item, distance: itemHits[0].distance };
}

function tryGrab() {
    const t = lookTarget();
    if (!t) return;
    held = t.item;
    holdDist = clamp(t.distance, 1.3, 3.2);
    audio.grab();
}

function dropHeld() {
    held = null;
}

function throwHeld() {
    if (!held) return;
    const dir = new THREE.Vector3();
    camera.getWorldDirection(dir);
    held.vel.addScaledVector(dir, 9 / Math.sqrt(held.mass));
    emitNoise(player.pos, 4);
    held = null;
    input.mouseDown = false;
}

function updateBeam() {
    if (!held) { beam.visible = false; return; }
    beam.visible = true;
    const start = new THREE.Vector3(0.25, -0.25, -0.4).applyMatrix4(camera.matrixWorld);
    const pos = beam.geometry.attributes.position;
    pos.setXYZ(0, start.x, start.y, start.z);
    pos.setXYZ(1, held.pos.x, held.pos.y, held.pos.z);
    pos.needsUpdate = true;
}

// ====================================================================
// Noise & monsters
// ====================================================================
function emitNoise(pos, radius) {
    for (const m of monsters) {
        const d = Math.hypot(m.pos.x - pos.x, m.pos.z - pos.z);
        if (d < radius && m.state !== "chase") {
            m.state = "investigate";
            m.goal = new THREE.Vector3(pos.x, 0, pos.z);
            m.path = bfs(cellOf(m.pos), cellOf(pos));
            m.linger = 2.5;
        }
    }
}

function buildMonsterMesh() {
    const g = new THREE.Group();
    const skin = new THREE.MeshStandardMaterial({ color: 0x14100f, roughness: 0.9 });
    const body = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.42, 1.7, 10), skin);
    body.position.y = 0.95;
    g.add(body);
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.28, 14, 10), skin);
    head.position.y = 2.0;
    head.scale.set(1, 1.25, 0.9);
    g.add(head);
    const eyeMat = new THREE.MeshBasicMaterial({ color: 0xff3020 });
    for (const sx of [-0.1, 0.1]) {
        const eye = new THREE.Mesh(new THREE.SphereGeometry(0.045, 8, 6), eyeMat);
        eye.position.set(sx, 2.05, 0.24);
        g.add(eye);
    }
    const arms = [];
    for (const sx of [-0.38, 0.38]) {
        const arm = new THREE.Mesh(new THREE.BoxGeometry(0.08, 1.4, 0.08), skin);
        arm.geometry.translate(0, -0.7, 0);
        arm.position.set(sx, 1.65, 0);
        g.add(arm);
        arms.push(arm);
    }
    g.userData.arms = arms;
    g.userData.eyeMat = eyeMat;
    return g;
}

function spawnMonster([i, j]) {
    const mesh = buildMonsterMesh();
    const c = cellCenter(i, j);
    mesh.position.copy(c);
    levelGroup.add(mesh);
    monsters.push({
        mesh,
        pos: mesh.position,
        state: "patrol",
        path: [],
        goal: null,
        linger: 0,
        sightTimer: 0,
        lostTimer: 0,
        attackCd: 0,
        stun: 0,
        lastSeen: new THREE.Vector3(),
        sees: false,
        t: Math.random() * 10,
    });
}

function hasLineOfSight(from, to) {
    const dir = to.clone().sub(from);
    const dist = dir.length();
    raycaster.set(from, dir.normalize());
    raycaster.far = dist;
    return raycaster.intersectObjects(obstacleMeshes, false).length === 0;
}

// Circle (xz) vs static colliders.
function collideCircle(pos, r, ignoreLow = false) {
    for (const b of boxes) {
        if (b.minY > 1.5) continue;            // lintels
        if (ignoreLow && b.maxY < 0.3 && !b.walkBlock) continue;
        const cx = clamp(pos.x, b.minX, b.maxX), cz = clamp(pos.z, b.minZ, b.maxZ);
        let dx = pos.x - cx, dz = pos.z - cz;
        const d2 = dx * dx + dz * dz;
        if (d2 >= r * r) continue;
        if (d2 > 1e-9) {
            const d = Math.sqrt(d2);
            pos.x += (dx / d) * (r - d);
            pos.z += (dz / d) * (r - d);
        } else {
            const opts = [[pos.x - b.minX, -1, 0], [b.maxX - pos.x, 1, 0], [pos.z - b.minZ, 0, -1], [b.maxZ - pos.z, 0, 1]]
                .sort((a, c) => a[0] - c[0]);
            pos.x += opts[0][1] * (opts[0][0] + r);
            pos.z += opts[0][2] * (opts[0][0] + r);
        }
    }
}

function moveToward(m, target, speed, dt) {
    const dx = target.x - m.pos.x, dz = target.z - m.pos.z;
    const d = Math.hypot(dx, dz);
    if (d < 0.05) return d;
    const step = Math.min(d, speed * dt);
    m.pos.x += (dx / d) * step;
    m.pos.z += (dz / d) * step;
    collideCircle(m.pos, 0.4);
    const targetYaw = Math.atan2(dx, dz);
    let diff = targetYaw - m.mesh.rotation.y;
    diff = Math.atan2(Math.sin(diff), Math.cos(diff));
    m.mesh.rotation.y += diff * Math.min(1, dt * 8);
    return d;
}

function followPath(m, speed, dt) {
    if (m.path.length) {
        const [i, j] = m.path[0];
        if (moveToward(m, cellCenter(i, j), speed, dt) < 0.4) m.path.shift();
        return false;
    }
    if (m.goal) {
        if (moveToward(m, m.goal, speed, dt) < 0.5) { m.goal = null; return true; }
        return false;
    }
    return true;
}

function updateMonsters(dt) {
    let nearest = Infinity;
    let anyChasing = false;
    const eye = new THREE.Vector3();
    for (const m of monsters) {
        m.t += dt;
        m.attackCd -= dt;
        const toPlayer = Math.hypot(player.pos.x - m.pos.x, player.pos.z - m.pos.z);
        nearest = Math.min(nearest, toPlayer);

        // vision (checked a few times per second)
        m.sightTimer -= dt;
        if (m.sightTimer <= 0) {
            m.sightTimer = 0.2;
            const range = player.crouch ? 6 : 13;
            m.sees = false;
            if (toPlayer < range) {
                const fx = Math.sin(m.mesh.rotation.y), fz = Math.cos(m.mesh.rotation.y);
                const dot = ((player.pos.x - m.pos.x) * fx + (player.pos.z - m.pos.z) * fz) / Math.max(toPlayer, 0.01);
                if (dot > 0.2 || toPlayer < 3.5 || m.state === "chase") {
                    eye.set(m.pos.x, 1.9, m.pos.z);
                    m.sees = hasLineOfSight(eye, camera.position);
                }
            }
            if (m.sees) {
                if (m.state !== "chase") { audio.alert(); toast("Something saw you. RUN.", "#ff6b6b"); }
                m.state = "chase";
                m.lastSeen.copy(player.pos);
                m.lostTimer = 0;
            }
        }

        if (m.stun > 0) {
            m.stun -= dt;
        } else if (m.state === "chase") {
            anyChasing = true;
            if (m.sees) {
                m.path = [];
                moveToward(m, player.pos, 4.4, dt);
            } else {
                m.lostTimer += dt;
                if (!m.path.length && !m.goal) {
                    m.path = bfs(cellOf(m.pos), cellOf(m.lastSeen));
                    m.goal = m.lastSeen.clone();
                }
                followPath(m, 4.0, dt);
                if (m.lostTimer > 6) { m.state = "patrol"; m.path = []; m.goal = null; }
            }
        } else if (m.state === "investigate") {
            if (followPath(m, 2.8, dt)) {
                m.linger -= dt;
                m.mesh.rotation.y += dt * 1.5;
                if (m.linger <= 0) m.state = "patrol";
            }
        } else {
            if (followPath(m, 1.7, dt)) {
                const target = [randInt(0, grid.w - 1), randInt(0, grid.h - 1)];
                m.path = bfs(cellOf(m.pos), target);
            }
        }

        // attack
        if (toPlayer < 1.15 && m.attackCd <= 0 && game.state === "playing") {
            m.attackCd = 1.6;
            m.stun = 1.0;
            hurtPlayer(34, m.pos);
        }

        // animation
        const speedBob = m.state === "chase" ? 10 : 4;
        m.mesh.children[0].position.y = 0.95 + Math.sin(m.t * speedBob) * 0.04;
        m.mesh.userData.arms.forEach((a, k) => {
            a.rotation.x = m.state === "chase" ? -1.1 + Math.sin(m.t * 10 + k * Math.PI) * 0.3 : Math.sin(m.t * 2 + k) * 0.15;
        });
        m.mesh.userData.eyeMat.color.setHex(m.state === "chase" ? 0xff1000 : m.state === "investigate" ? 0xff8a20 : 0xaa2010);
    }
    const proximity = clamp(1 - nearest / 14, 0, 1);
    audio.setDrone(anyChasing ? Math.max(0.6, proximity) : proximity * 0.4);
    $("danger").style.opacity = anyChasing ? 0.35 + proximity * 0.5 : proximity * 0.25;
}

function hurtPlayer(amount, from) {
    player.health -= amount;
    audio.hurt();
    if (held) { held.vel.y += 2; dropHeld(); }
    const dx = player.pos.x - from.x, dz = player.pos.z - from.z;
    const d = Math.hypot(dx, dz) || 1;
    player.pos.x += (dx / d) * 1.2;
    player.pos.z += (dz / d) * 1.2;
    collideCircle(player.pos, PLAYER_R);
    $("danger").style.opacity = 1;
    if (player.health <= 0) {
        player.health = 0;
        endShift();
    }
}

// ====================================================================
// Player
// ====================================================================
function updatePlayer(dt) {
    const k = input.keys;
    player.crouch = !!(k.KeyC || k.ControlLeft || k.ControlRight);
    let fwd = (k.KeyW || k.ArrowUp ? 1 : 0) - (k.KeyS || k.ArrowDown ? 1 : 0);
    let strafe = (k.KeyD || k.ArrowRight ? 1 : 0) - (k.KeyA || k.ArrowLeft ? 1 : 0);
    const moving = fwd !== 0 || strafe !== 0;
    const wantSprint = (k.ShiftLeft || k.ShiftRight) && moving && !player.crouch;
    const sprint = wantSprint && player.stamina > 1;
    if (sprint) player.stamina = Math.max(0, player.stamina - 28 * dt);
    else player.stamina = Math.min(100, player.stamina + (moving ? 12 : 22) * dt);

    let speed = player.crouch ? SPEED.crouch : sprint ? SPEED.sprint : SPEED.walk;
    if (held) speed *= clamp(1.1 - held.mass * 0.08, 0.6, 1);

    if (moving) {
        const len = Math.hypot(fwd, strafe);
        fwd /= len; strafe /= len;
        const sy = Math.sin(player.yaw), cy = Math.cos(player.yaw);
        player.pos.x += (-sy * fwd + cy * strafe) * speed * dt;
        player.pos.z += (-cy * fwd - sy * strafe) * speed * dt;
        collideCircle(player.pos, PLAYER_R, true);

        player.stepTimer -= dt * (sprint ? 1.6 : 1);
        if (player.stepTimer <= 0) {
            player.stepTimer = 0.5;
            if (!player.crouch) {
                audio.step(sprint ? 0.12 : 0.05);
                emitNoise(player.pos, sprint ? 8 : 3.5);
            }
        }
    }

    const targetEye = player.crouch ? CROUCH_EYE : EYE;
    player.eye += (targetEye - player.eye) * Math.min(1, dt * 10);
    const bob = moving ? Math.sin(performance.now() / (sprint ? 90 : 140)) * (sprint ? 0.05 : 0.025) : 0;
    camera.position.set(player.pos.x, player.eye + bob, player.pos.z);
    camera.rotation.set(player.pitch, player.yaw, 0);
}

// ====================================================================
// Drop zone / extraction
// ====================================================================
function inZone(p) {
    return Math.abs(p.x - zone.x) < ZONE_HALF && Math.abs(p.z - zone.z) < ZONE_HALF;
}

function zoneValue() {
    return items.reduce((s, it) => s + (it !== held && inZone(it.pos) && it.pos.y < 1.5 ? it.value : 0), 0);
}

function tryCashOut() {
    if (!inZone(player.pos)) {
        toast("Stand in the drop zone to cash out", "#3ee6c1");
        return;
    }
    const value = zoneValue();
    if (value < game.quota) {
        toast(`Need ${money(game.quota - value)} more in the zone`, "#f2c14e");
        return;
    }
    const delivered = items.filter(it => it !== held && inZone(it.pos) && it.pos.y < 1.5);
    delivered.forEach(it => addPopup(it.pos, `+${money(it.value)}`, true));
    game.banked += value;
    audio.cash();
    game.state = "cleared";
    document.exitPointerLock && document.exitPointerLock();
    const bonus = value - game.quota;
    $("cleared-title").textContent = `Night ${game.night} cleared`;
    $("cleared-summary").innerHTML = `
        <span>Quota</span><span class="num">${money(game.quota)}</span>
        <span>Delivered</span><span class="num gold">${money(value)}</span>
        <span>Over quota</span><span class="num">${money(bonus)}</span>
        <span>Lost to damage</span><span class="num bad">${money(game.nightLost)}</span>
        <span>Items broken</span><span class="num bad">${game.nightBroken}</span>
        <span>Total banked</span><span class="num gold">${money(game.banked)}</span>`;
    showPanel("cleared");
}

function endShift() {
    game.state = "dead";
    document.exitPointerLock && document.exitPointerLock();
    audio.setDrone(0);
    const best = Number(storageGet("fragile-haul-best") || 0);
    const isBest = game.banked > best;
    if (isBest) storageSet("fragile-haul-best", String(game.banked));
    $("dead-summary").innerHTML = `
        <span>Nights survived</span><span class="num">${game.night - 1}</span>
        <span>Total banked</span><span class="num gold">${money(game.banked)}</span>
        <span>Best shift</span><span class="num">${money(Math.max(best, game.banked))}${isBest ? " (new!)" : ""}</span>`;
    showPanel("dead");
}

// ====================================================================
// HUD
// ====================================================================
let toastTimer = 0;
function toast(text, color = "#e8ecef") {
    const el = $("toast");
    el.textContent = text;
    el.style.color = color;
    el.classList.add("show");
    toastTimer = 2.2;
}

function addPopup(pos, text, good) {
    const el = document.createElement("div");
    el.className = "popup" + (good ? " good" : "");
    el.textContent = text;
    $("popups").appendChild(el);
    popups.push({ el, pos: pos.clone(), life: 1.2 });
}

const projVec = new THREE.Vector3();
function updateHud(dt) {
    $("hud-level").textContent = `NIGHT ${game.night}`;
    const zv = zoneValue();
    $("hud-zone").textContent = money(zv);
    $("hud-quota").textContent = money(game.quota);
    $("hud-quota-fill").style.width = `${clamp(zv / game.quota, 0, 1) * 100}%`;
    $("hud-quota-fill").style.background = zv >= game.quota ? "#f2c14e" : "";
    $("hud-banked").textContent = money(game.banked);
    $("hud-health").style.width = `${player.health}%`;
    $("hud-stamina").style.width = `${player.stamina}%`;

    const look = held ? null : lookTarget();
    $("crosshair").classList.toggle("can-grab", !!look);
    const label = $("hover-label");
    if (look) {
        const it = look.item;
        const pct = it.value / it.baseValue;
        const col = pct > 0.75 ? "#e8ecef" : pct > 0.4 ? "#f2c14e" : "#ff6b6b";
        const frag = it.type.fragility >= 1.6 ? " · very fragile" : it.type.fragility >= 1.1 ? " · fragile" : "";
        const heavy = it.mass >= 4 ? " · heavy" : "";
        label.innerHTML = `${it.type.name} <b style="color:${col}">${money(it.value)}</b>${frag}${heavy}`;
    } else {
        label.textContent = "";
    }

    const heldEl = $("hud-held");
    if (held) {
        heldEl.innerHTML = `Holding <b>${held.type.name}</b>: <span style="color:#f2c14e">${money(held.value)}</span>`;
    } else if (inZone(player.pos) && zv >= game.quota) {
        heldEl.innerHTML = `Quota met. Press <kbd>E</kbd> to cash out`;
    } else {
        heldEl.textContent = "";
    }

    if (toastTimer > 0) {
        toastTimer -= dt;
        if (toastTimer <= 0) $("toast").classList.remove("show");
    }

    for (const p of popups) {
        p.life -= dt;
        p.pos.y += dt * 0.8;
        projVec.copy(p.pos).project(camera);
        const visible = projVec.z < 1;
        p.el.style.display = visible ? "" : "none";
        p.el.style.left = `${(projVec.x * 0.5 + 0.5) * window.innerWidth}px`;
        p.el.style.top = `${(-projVec.y * 0.5 + 0.5) * window.innerHeight}px`;
        p.el.style.opacity = clamp(p.life, 0, 1);
        if (p.life <= 0) p.el.remove();
    }
    popups = popups.filter(p => p.life > 0);
}

function updateLamps(t) {
    for (const l of lamps) {
        let k = 1;
        if (l.flicker) {
            const n = Math.sin(t * 13 + l.base) * Math.sin(t * 7.3) + Math.sin(t * 31);
            k = n > 1.3 ? 0.15 : 0.9 + Math.sin(t * 50) * 0.05;
        }
        l.light.intensity = l.base * k;
        l.bulb.material = k < 0.5 ? MAT.ceiling : MAT.bulb;
    }
}

// ====================================================================
// Menus / flow
// ====================================================================
function showPanel(name) {
    $("overlay").classList.toggle("hidden", !name);
    for (const p of ["menu", "pause", "cleared", "dead"]) {
        $(`panel-${p}`).classList.toggle("hidden", p !== name);
    }
    $("hud").classList.toggle("hidden", name === "menu");
}

function lockPointer() {
    try {
        const r = canvas.requestPointerLock && canvas.requestPointerLock();
        if (r && r.catch) r.catch(() => {});
    } catch { /* not supported */ }
}

function startNight() {
    buildLevel(game.night);
    game.state = "playing";
    showPanel(null);
    toast(`Night ${game.night}: deliver ${money(game.quota)}`, "#3ee6c1");
    lockPointer();
}

$("btn-start").addEventListener("click", () => {
    audio.init();
    game.night = 1;
    game.banked = 0;
    startNight();
});
$("btn-restart").addEventListener("click", () => {
    game.night = 1;
    game.banked = 0;
    startNight();
});
$("btn-next").addEventListener("click", () => {
    game.night++;
    startNight();
});
$("btn-resume").addEventListener("click", () => {
    game.state = "playing";
    showPanel(null);
    lockPointer();
});

document.addEventListener("pointerlockchange", () => {
    if (!document.pointerLockElement && game.state === "playing") {
        game.state = "paused";
        input.mouseDown = false;
        held = null;
        showPanel("pause");
    }
});

canvas.addEventListener("click", () => {
    if (game.state === "playing" && !document.pointerLockElement) lockPointer();
});

document.addEventListener("mousemove", e => {
    if (game.state !== "playing" || !document.pointerLockElement) return;
    player.yaw -= e.movementX * 0.0022;
    player.pitch = clamp(player.pitch - e.movementY * 0.0022, -1.45, 1.45);
});

document.addEventListener("mousedown", e => {
    if (game.state !== "playing") return;
    if (e.button === 0) { input.mouseDown = true; tryGrab(); }
    if (e.button === 2) throwHeld();
});
document.addEventListener("mouseup", e => {
    if (e.button === 0) { input.mouseDown = false; dropHeld(); }
});
document.addEventListener("contextmenu", e => e.preventDefault());
document.addEventListener("wheel", e => {
    if (held) holdDist = clamp(holdDist - Math.sign(e.deltaY) * 0.25, 1.3, 3.2);
}, { passive: true });

document.addEventListener("keydown", e => {
    input.keys[e.code] = true;
    if (game.state !== "playing") return;
    if (e.code === "KeyE") tryCashOut();
    if (e.code === "KeyP") document.exitPointerLock ? document.exitPointerLock() : null;
    if (e.code.startsWith("Control")) e.preventDefault();
});
document.addEventListener("keyup", e => { input.keys[e.code] = false; });
window.addEventListener("blur", () => { input.keys = {}; });

const best = Number(storageGet("fragile-haul-best") || 0);
if (best > 0) $("best-score").textContent = `Best shift: ${money(best)}`;

// ====================================================================
// Main loop
// ====================================================================
// A small spinning showcase behind the main menu.
buildLevel(1);
monsters.forEach(m => levelGroup.remove(m.mesh));
monsters = [];

let last = performance.now();
let accumulator = 0;
function frame(now) {
    requestAnimationFrame(frame);
    const dt = Math.min((now - last) / 1000, 0.05);
    last = now;
    const t = now / 1000;

    if (game.state === "playing") {
        updatePlayer(dt);
        accumulator += dt;
        while (accumulator >= PHYS_DT) {
            stepItems(PHYS_DT);
            accumulator -= PHYS_DT;
        }
        updateMonsters(dt);
        updateItemVisuals(dt);
        updateHud(dt);
    } else if (game.state === "menu") {
        camera.position.set(zone.x + Math.cos(t * 0.1) * 2, 1.7, zone.z + Math.sin(t * 0.1) * 2);
        camera.rotation.set(-0.15, -t * 0.1 - Math.PI / 2, 0);
    } else if (game.state === "cleared" || game.state === "dead") {
        updateItemVisuals(dt);
        updateHud(dt);
    }
    updateBeam();
    updateLamps(t);
    renderer.render(scene, camera);
}
requestAnimationFrame(frame);

// Exposed for debugging / automated tests.
window.fragileHaul = { game, player, get items() { return items; }, get monsters() { return monsters; },
    get held() { return held; }, zone: () => zone, zoneValue, tryGrab, dropHeld, tryCashOut, input };
})();
