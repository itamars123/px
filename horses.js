// ===================== נתונים =====================
const STABLE = [
    { name: "ברק", coat: "#6b3e1f", silk: "#d62828", cap: "#ffffff" },
    { name: "רעם", coat: "#2b1d14", silk: "#1d4ed8", cap: "#facc15" },
    { name: "סופה", coat: "#8d8d8d", silk: "#7c3aed", cap: "#ffffff" },
    { name: "חץ", coat: "#a0522d", silk: "#ea580c", cap: "#111111" },
    { name: "כוכב", coat: "#3a2412", silk: "#0891b2", cap: "#f472b6" },
    { name: "שביט", coat: "#d9c3a0", silk: "#16a34a", cap: "#111111" },
    { name: "להבה", coat: "#7a2e12", silk: "#facc15", cap: "#d62828" },
    { name: "ענבר", coat: "#b8763a", silk: "#ec4899", cap: "#ffffff" },
    { name: "סערה", coat: "#1c1c1c", silk: "#e5e7eb", cap: "#1d4ed8" },
    { name: "נסיך", coat: "#5c3317", silk: "#0f766e", cap: "#facc15" },
    { name: "טורנדו", coat: "#4a3426", silk: "#9333ea", cap: "#facc15" },
    { name: "פנינה", coat: "#efe8dc", silk: "#0ea5e9", cap: "#ec4899" },
];

const COATS = ["#6b3e1f", "#2b1d14", "#a0522d", "#b8763a", "#d9c3a0", "#8d8d8d", "#1c1c1c", "#efe8dc"];
const SILKS = ["#d62828", "#ea580c", "#facc15", "#16a34a", "#0891b2", "#1d4ed8", "#7c3aed", "#ec4899", "#e5e7eb", "#111111"];
const CAPS = ["#ffffff", "#111111", "#facc15", "#d62828", "#1d4ed8", "#16a34a", "#ec4899", "#ea580c"];

const CONDS = {
    day: { label: "יום בהיר", icon: "☀️", sky: ["#3f8fd2", "#8cc6ec", "#dff0ee"], tint: null, slow: 1 },
    sunset: { label: "שקיעה", icon: "🌇", sky: ["#27416e", "#c9786a", "#f5c27a"], tint: null, slow: 1 },
    night: { label: "לילה", icon: "🌙", sky: ["#04071a", "#10183c", "#232c62"], tint: "#4f5d92", slow: 1 },
    rain: { label: "גשם", icon: "🌧️", sky: ["#4e5964", "#6f7a85", "#929ba3"], tint: "#aab3bb", slow: 0.95 },
};

const SEASON = [
    { id: "s1", name: "פתיחת העונה", dist: 400, cond: "day", hurdles: 0, prize: 1 },
    { id: "s2", name: "ספרינט הגשם", dist: 600, cond: "rain", hurdles: 0, prize: 1.2 },
    { id: "s3", name: "קפיצות הגליל", dist: 700, cond: "sunset", hurdles: 4, prize: 1.4 },
    { id: "s4", name: "מרוץ הלילה", dist: 800, cond: "night", hurdles: 2, prize: 1.6 },
    { id: "s5", name: "גמר גביע הזהב", dist: 1000, cond: "sunset", hurdles: 0, prize: 2.2, final: true },
];

const BET_RACES = [
    { id: "sprint", name: "ספרינט", dist: 400, hurdles: 0, bonus: 1 },
    { id: "classic", name: "קלאסי", dist: 700, hurdles: 0, bonus: 1.15 },
    { id: "steeple", name: "משוכות", dist: 700, hurdles: 4, bonus: 1.3 },
    { id: "cup", name: "גביע הזהב", dist: 1000, hurdles: 0, bonus: 1.35 },
];

const POINTS = [10, 6, 4, 3, 2, 1];
const PRIZE = [120, 70, 45, 25, 15, 10];

// קצב יחסי למהירות המרבית לפי התקדמות במרוץ (0..1)
const STRATS = {
    front: { label: "פותח מהר", pace: p => (p < 0.6 ? 0.98 : 0.98 - (p - 0.6) * 0.25) },
    even: { label: "קצב אחיד", pace: () => 0.945 },
    closer: { label: "מסיים חזק", pace: p => (p < 0.65 ? 0.89 : 0.89 + (p - 0.65) * 0.55) },
};
const AVG_PACE = { front: 0.96, even: 0.945, closer: 0.924 };

const STATS = [
    { key: "speed", label: "מהירות" },
    { key: "stamina", label: "סיבולת" },
    { key: "accel", label: "תאוצה" },
    { key: "jump", label: "קפיצה" },
];

const ACH = [
    { id: "first", icon: "🥇", name: "ניצחון ראשון", desc: "לנצח במרוץ" },
    { id: "combo10", icon: "🔥", name: "קצב מושלם", desc: "רצף של 10 לחיצות מושלמות" },
    { id: "jump", icon: "🐎", name: "מעל המשוכה", desc: "קפיצה מושלמת" },
    { id: "clean", icon: "✨", name: "ריצה נקייה", desc: "לעבור 4 משוכות בלי נגיעה" },
    { id: "night", icon: "🌙", name: "מלך הלילה", desc: "לנצח במרוץ לילה" },
    { id: "rain", icon: "☔", name: "רוכב הגשם", desc: "לנצח במרוץ גשום" },
    { id: "photo", icon: "📸", name: "פוטו פיניש", desc: "לנצח בפער של פחות מ-0.1 שניות" },
    { id: "comeback", icon: "🚀", name: "קאמבק", desc: "לנצח אחרי שהיית אחרון בחצי המרוץ" },
    { id: "long", icon: "💰", name: "אאוטסיידר", desc: "לזכות בהימור ניצחון ביחס 8 ומעלה" },
    { id: "rich", icon: "🏦", name: "טייקון", desc: "להגיע ל-1000 מטבעות" },
    { id: "trainer", icon: "💪", name: "מאמן על", desc: "להעלות תכונה לרמה 10" },
    { id: "champ", icon: "🏆", name: "אלוף העונה", desc: "לסיים עונה במקום הראשון" },
];

const FIELD_SIZE = 6;
const TAU = Math.PI * 2;
const ZONE = [0.74, 0.96]; // חלון הלחיצה המושלמת במחזור הצעד
const JUMP_T = 0.7; // משך קפיצה בשניות

// ===================== שמירה =====================
const store = {
    get(k, d) {
        try {
            const v = localStorage.getItem("golden-cup-" + k);
            return v === null ? d : JSON.parse(v);
        } catch (e) { return d; }
    },
    set(k, v) {
        try { localStorage.setItem("golden-cup-" + k, JSON.stringify(v)); } catch (e) { /* לא חובה */ }
    },
};

const career = Object.assign(
    { coins: 100, races: 0, wins: 0, podiums: 0, best: {}, biggest: 0, ach: {}, trophies: 0 },
    store.get("career", {})
);
let myHorse = store.get("horse", null);
let season = store.get("season", null);

// ===================== צלילים =====================
const SFX = {
    ctx: null,
    muted: store.get("muted", false),
    init() {
        if (this.ctx) return;
        try {
            const AC = window.AudioContext || window.webkitAudioContext;
            this.ctx = new AC();
            this.master = this.ctx.createGain();
            this.master.gain.value = this.muted ? 0 : 0.6;
            this.master.connect(this.ctx.destination);
            const len = this.ctx.sampleRate * 2;
            this.noiseBuf = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
            const d = this.noiseBuf.getChannelData(0);
            for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
            // רעש קהל ברקע
            const src = this.ctx.createBufferSource();
            src.buffer = this.noiseBuf;
            src.loop = true;
            const bp = this.ctx.createBiquadFilter();
            bp.type = "bandpass"; bp.frequency.value = 900; bp.Q.value = 0.5;
            this.crowd = this.ctx.createGain();
            this.crowd.gain.value = 0.02;
            src.connect(bp).connect(this.crowd).connect(this.master);
            src.start();
        } catch (e) { this.ctx = null; }
    },
    toggle() {
        this.muted = !this.muted;
        store.set("muted", this.muted);
        if (this.master) this.master.gain.value = this.muted ? 0 : 0.6;
    },
    noise(dur, type, freq, vol, when = 0) {
        if (!this.ctx) return;
        const t = this.ctx.currentTime + when;
        const src = this.ctx.createBufferSource();
        src.buffer = this.noiseBuf;
        const f = this.ctx.createBiquadFilter();
        f.type = type; f.frequency.value = freq;
        const g = this.ctx.createGain();
        g.gain.setValueAtTime(vol, t);
        g.gain.exponentialRampToValueAtTime(0.001, t + dur);
        src.connect(f).connect(g).connect(this.master);
        src.start(t, Math.random()); src.stop(t + dur);
    },
    tone(freq, dur, type = "sine", vol = 0.2, when = 0) {
        if (!this.ctx) return;
        const t = this.ctx.currentTime + when;
        const o = this.ctx.createOscillator();
        o.type = type; o.frequency.value = freq;
        const g = this.ctx.createGain();
        g.gain.setValueAtTime(0.0001, t);
        g.gain.exponentialRampToValueAtTime(vol, t + 0.01);
        g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
        o.connect(g).connect(this.master);
        o.start(t); o.stop(t + dur + 0.02);
    },
    gallop(vol) {
        // שלוש פעימות של דהירה
        [0, 0.07, 0.14].forEach((w, i) => {
            this.noise(0.07, "lowpass", 220, vol * (i === 2 ? 1 : 0.7), w);
            this.tone(70 + i * 6, 0.06, "sine", vol * 0.5, w);
        });
    },
    gun() { this.noise(0.5, "highpass", 500, 0.9); this.tone(90, 0.25, "square", 0.25); },
    beep(hi) { this.tone(hi ? 880 : 440, hi ? 0.4 : 0.15, "square", 0.12); },
    perfect(combo) { this.tone(660 + Math.min(combo, 10) * 45, 0.09, "triangle", 0.18); },
    miss() { this.tone(160, 0.12, "sawtooth", 0.08); },
    whoosh() { this.noise(0.35, "bandpass", 1400, 0.25); },
    thud() { this.noise(0.3, "lowpass", 120, 0.9); this.tone(55, 0.3, "sine", 0.4); this.noise(0.8, "bandpass", 700, 0.25, 0.05); },
    chime() { [988, 1319, 1568].forEach((f, i) => this.tone(f, 0.25, "triangle", 0.14, i * 0.08)); },
    fanfare() { [523, 659, 784, 1047, 784, 1047].forEach((f, i) => this.tone(f, 0.28, "triangle", 0.2, i * 0.13)); },
    sad() { [392, 349, 294].forEach((f, i) => this.tone(f, 0.35, "sine", 0.15, i * 0.22)); },
    crowdLevel(v) {
        if (this.crowd) this.crowd.gain.setTargetAtTime(v, this.ctx.currentTime, 0.4);
    },
};

// ===================== עזרים =====================
const $ = id => document.getElementById(id);
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const hash = n => { const x = Math.sin(n * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); };
const fmtTime = s => s.toFixed(2) + " ש'";
const pickOne = a => a[Math.floor(Math.random() * a.length)];
const esc = s => String(s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

function shade(hex, amt) {
    const n = parseInt(hex.slice(1), 16);
    const f = c => clamp(Math.round(c + (amt < 0 ? c * amt : (255 - c) * amt)), 0, 255);
    return `rgb(${f(n >> 16)},${f((n >> 8) & 255)},${f(n & 255)})`;
}

function shuffle(a) {
    for (let i = a.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
}

function hurdlesFor(dist, n) {
    if (!n) return [];
    return Array.from({ length: n }, (_, i) => Math.round(dist * (0.2 + (0.65 * i) / Math.max(1, n - 1))));
}

// ===================== מצב המשחק =====================
const G = {
    screen: "menu", // menu | countdown | race | results
    tab: myHorse ? "career" : "career",
    mode: "career", // career | bet
    editing: false,
    draft: null,
    race: null,
    field: [],
    betField: [],
    betRaceIdx: store.get("betRace", 1),
    betCond: "sunset",
    pick: null,
    bet: 25,
    betType: "win",
    selfBet: 0,
    t: 0,
    raceT: 0,
    cam: 0,
    timeScale: 1,
    gateOpen: false,
    power: 100,
    combo: 0,
    lastPress: -1,
    leader: null,
    leaderPos: 0,
    myRank: 0,
    finishOrder: [],
    endTimer: 0,
    calls: {},
    lastSay: 0,
    jumpReady: false,
};

let dust = [];
let confetti = [];
let floaters = [];

// ===================== סוסים ושדות =====================
function myStats(lv) {
    return {
        top: 15.9 + 0.22 * lv.speed,
        stamina: lv.stamina / 10,
        accel: 1.4 + 0.17 * lv.accel,
        jumpSkill: 0.8 + 0.02 * lv.jump,
    };
}

function randomRunner(base, boost = 0) {
    return {
        ...base,
        top: 15.3 + Math.random() * 1.8 + boost,
        stamina: clamp(Math.random() * 0.8 + boost * 0.1, 0, 1),
        accel: 1.5 + Math.random() * 1.4,
        strat: pickOne(Object.keys(STRATS)),
        jumpSkill: 0.84 + Math.random() * 0.13,
    };
}

function computeOdds(field) {
    field.forEach(h => {
        h.rating = h.isMe && G.mode === "career"
            ? h.top * 0.9 + 1.3
            : h.top * AVG_PACE[h.strat] * (1 - (1 - h.stamina) * 0.02) + h.accel * 0.05;
    });
    const max = Math.max(...field.map(h => h.rating));
    const w = field.map(h => Math.exp(1.15 * (h.rating - max)));
    const sum = w.reduce((a, b) => a + b, 0);
    field.forEach((h, i) => {
        const p = w[i] / sum;
        h.odds = clamp(Math.round((0.88 / p) * 10) / 10, 1.4, 18);
        h.placeOdds = Math.max(1.15, Math.round((h.odds / 3 + 0.2) * 10) / 10);
        h.form = Array.from({ length: 5 }, () => clamp(Math.round(1 + Math.random() * 5 * (1 - p * 1.6)), 1, 6)).join("-");
    });
}

function assignLanes(field) {
    shuffle(field.map((_, i) => i)).forEach((lane, i) => { field[i].lane = lane; });
    field.forEach((h, i) => { h.num = i + 1; });
}

function newBetField() {
    G.betField = shuffle(STABLE.slice()).slice(0, FIELD_SIZE).map(s => randomRunner(s));
    assignLanes(G.betField);
    G.mode = "bet";
    computeOdds(G.betField);
    G.betCond = pickOne(["day", "day", "sunset", "sunset", "night", "rain"]);
    G.pick = null;
}

function betRace() {
    const r = BET_RACES[G.betRaceIdx] || BET_RACES[1];
    return { ...r, cond: G.betCond, prize: 0, hurdleAt: hurdlesFor(r.dist, r.hurdles) };
}

function newSeason(n) {
    const boost = Math.min(n - 1, 6) * 0.35;
    season = {
        n, idx: 0, myPts: 0, results: [],
        rivals: shuffle(STABLE.slice()).slice(0, FIELD_SIZE - 1).map(s => ({ ...randomRunner(s, boost), pts: 0 })),
    };
    store.set("season", season);
}

function seasonRace() {
    const r = SEASON[season.idx];
    return { ...r, bonus: 1, hurdleAt: hurdlesFor(r.dist, r.hurdles) };
}

function careerField() {
    const mine = { ...myHorse, ...myStats(myHorse.lv), isMe: true, strat: "even" };
    const field = [mine, ...season.rivals.map(r => ({ ...r, isMe: false }))];
    assignLanes(field);
    G.mode = "career";
    computeOdds(field);
    return field;
}

function resetRunners() {
    G.field.forEach(h => {
        Object.assign(h, {
            pos: 0, v: 0, phase: Math.random() * TAU, burst: 0, noise: 0, noiseTarget: 0,
            noiseT: 0, finished: false, time: 0, whip: 0, place: 0, stumble: 0, airT: 0,
            aim: 0.5, prevPos: 0,
        });
        rerollAim(h);
    });
    G.cam = 0;
    G.gateOpen = false;
    G.power = 100;
    G.combo = 0;
    G.finishOrder = [];
    G.calls = {};
    G.leader = null;
    G.timeScale = 1;
    G.myClean = 0;
    G.myHits = 0;
    G.bestCombo = 0;
    G.lastAtHalf = false;
    dust = []; confetti = []; floaters = [];
}

function rerollAim(h) {
    h.aim = 0.5 + (Math.random() - 0.5) * (1.12 - h.jumpSkill) * 3.2;
}

const me = () => G.field.find(h => h.isMe);

// ===================== קנבס =====================
const canvas = $("scene");
const mainCtx = canvas.getContext("2d");
let ctx = mainCtx;
let W = 800, H = 400, PPM = 18, DPR = 1;

function resize() {
    const w = canvas.parentElement.clientWidth;
    W = w;
    H = clamp(Math.round(w * 0.5), 290, 470);
    DPR = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(W * DPR);
    canvas.height = Math.round(H * DPR);
    canvas.style.height = H + "px";
    PPM = clamp(W / 42, 9, 22);
}
window.addEventListener("resize", resize);

const camX = () => W * 0.62;
const worldX = m => camX() - (m - G.cam) * PPM;
const cond = () => CONDS[(G.race && G.race.cond) || "sunset"];

// מעבר על אריחים חוזרים בשכבת פרלקסה
function tiles(f, P, fn) {
    const off = G.cam * PPM * f + camX();
    const n0 = Math.ceil((off - W - P) / P), n1 = Math.floor((off + P) / P);
    for (let n = n0; n <= n1; n++) fn(off - n * P, n);
}

function laneY(i) {
    const top = H * 0.49, bot = H * 0.93;
    return top + (bot - top) * (0.1 + i * 0.178);
}
const laneScale = i => (H / 520) * (0.68 + i * 0.065);

// ===================== ציור הנוף =====================
function drawSky() {
    const c = cond();
    const g = ctx.createLinearGradient(0, 0, 0, H * 0.45);
    g.addColorStop(0, c.sky[0]);
    g.addColorStop(0.55, c.sky[1]);
    g.addColorStop(1, c.sky[2]);
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H * 0.46);
    const id = G.race ? G.race.cond : "sunset";
    if (id === "sunset" || id === "day") {
        const sx = id === "day" ? W * 0.82 : W * 0.2 + G.cam * PPM * 0.01;
        const sy = id === "day" ? H * 0.09 : H * 0.3;
        const sg = ctx.createRadialGradient(sx, sy, 4, sx, sy, H * (id === "day" ? 0.14 : 0.22));
        sg.addColorStop(0, "rgba(255,248,220,1)");
        sg.addColorStop(0.25, id === "day" ? "rgba(255,245,200,.7)" : "rgba(255,214,140,.8)");
        sg.addColorStop(1, "rgba(255,220,150,0)");
        ctx.fillStyle = sg;
        ctx.fillRect(0, 0, W, H * 0.46);
    }
    // עננים
    const rainy = id === "rain";
    tiles(0.04, 320, (x, n) => {
        if (hash(n) < (rainy ? 0.05 : 0.4)) return;
        const y = H * (0.04 + hash(n * 3) * (rainy ? 0.08 : 0.14));
        ctx.fillStyle = rainy ? "rgba(70,80,90,.55)" : id === "night" ? "rgba(120,130,170,.12)" : "rgba(255,235,215,.38)";
        for (let k = 0; k < 4; k++) {
            ctx.beginPath();
            ctx.ellipse(x + k * 22 - 30, y + Math.sin(k * 2 + n) * 4, rainy ? 44 : 30, rainy ? 14 : 9, 0, 0, TAU);
            ctx.fill();
        }
    });
}

function drawNightSky() {
    for (let i = 0; i < 80; i++) {
        const x = hash(i) * W, y = hash(i * 5 + 2) * H * 0.19;
        ctx.globalAlpha = 0.35 + 0.45 * Math.sin(G.t * 2 + i * 1.7) ** 2;
        ctx.fillStyle = "#fff";
        ctx.fillRect(x, y, 1.6, 1.6);
    }
    ctx.globalAlpha = 1;
    const mx = W * 0.16, my = H * 0.1;
    const mg = ctx.createRadialGradient(mx, my, 2, mx, my, H * 0.12);
    mg.addColorStop(0, "rgba(255,250,230,.5)");
    mg.addColorStop(1, "rgba(255,250,230,0)");
    ctx.fillStyle = mg;
    ctx.fillRect(mx - H * 0.12, my - H * 0.12, H * 0.24, H * 0.24);
    ctx.fillStyle = "#f6f1df";
    ctx.beginPath(); ctx.arc(mx, my, H * 0.035, 0, TAU); ctx.fill();
    ctx.fillStyle = "rgba(4,7,26,.9)";
    ctx.beginPath(); ctx.arc(mx + H * 0.015, my - H * 0.008, H * 0.03, 0, TAU); ctx.fill();
}

function drawHills() {
    const layers = [
        { f: 0.06, base: 0.34, amp: 0.07, col: "#5b4d6e" },
        { f: 0.14, base: 0.37, amp: 0.05, col: "#3f5946" },
    ];
    layers.forEach(L => {
        const off = G.cam * PPM * L.f;
        ctx.fillStyle = L.col;
        ctx.beginPath();
        ctx.moveTo(0, H * 0.46);
        for (let x = 0; x <= W + 8; x += 8) {
            const u = x - off;
            const y = H * L.base - H * L.amp * (0.5 + 0.5 * Math.sin(u * 0.0042) + 0.35 * Math.sin(u * 0.013 + 1));
            ctx.lineTo(x, y);
        }
        ctx.lineTo(W, H * 0.46);
        ctx.fill();
    });
    // עצים
    tiles(0.28, 46, (x, n) => {
        if (hash(n * 7) < 0.35) return;
        const h = H * (0.05 + hash(n) * 0.04);
        const y = H * 0.4;
        ctx.fillStyle = "#24402e";
        ctx.beginPath();
        ctx.ellipse(x, y - h, h * 0.45, h * 0.7, 0, 0, TAU);
        ctx.fill();
        ctx.fillRect(x - 1.5, y - h * 0.4, 3, h * 0.4);
    });
}

const LIGHT_P = 470;
function drawTowers() {
    tiles(0.5, LIGHT_P, x => {
        const tx = x - LIGHT_P * 0.5;
        ctx.fillStyle = "#4b5563";
        ctx.fillRect(tx - 2, H * 0.06, 4, H * 0.37);
        ctx.fillStyle = "#374151";
        ctx.fillRect(tx - 20, H * 0.04, 40, H * 0.035);
        for (let k = 0; k < 4; k++) {
            ctx.fillStyle = "#fff8d6";
            ctx.fillRect(tx - 17 + k * 9, H * 0.047, 6, H * 0.02);
        }
    });
}

function drawGrandstand() {
    const top = H * 0.235, bot = H * 0.425;
    const P = 240;
    const night = G.race && G.race.cond === "night";
    const excite = G.screen === "race" ? clamp(G.leaderPos / G.race.dist, 0, 1) : 0.1;
    tiles(0.5, P, (x, n) => {
        if (n % 6 === 3) { // מרווח עם דגלים בין היציעים
            for (let k = 0; k < 3; k++) {
                const fx = x - 50 - k * 70;
                ctx.fillStyle = "#e9dcc0";
                ctx.fillRect(fx, top - 6, 2, bot - top + 6);
                ctx.fillStyle = ["#d62828", "#e2b54d", "#1d4ed8"][k];
                const wave = Math.sin(G.t * 4 + k) * 3;
                ctx.beginPath();
                ctx.moveTo(fx, top - 6);
                ctx.lineTo(fx - 18, top + wave);
                ctx.lineTo(fx, top + 8);
                ctx.fill();
            }
            return;
        }
        const x0 = x - P, w = P;
        ctx.fillStyle = "#e9dcc0";
        ctx.fillRect(x0, top, w, bot - top);
        ctx.fillStyle = "#7a2e2e";
        ctx.beginPath();
        ctx.moveTo(x0 - 4, top + 4);
        ctx.lineTo(x0 + 10, top - H * 0.03);
        ctx.lineTo(x0 + w - 10, top - H * 0.03);
        ctx.lineTo(x0 + w + 4, top + 4);
        ctx.fill();
        // קהל
        ctx.fillStyle = "#3b2f2a";
        ctx.fillRect(x0 + 6, top + 8, w - 12, bot - top - 12);
        const rows = 5, cols = 30;
        const cw = (w - 16) / cols, rh = (bot - top - 16) / rows;
        const hats = ["#f3ead6", "#d62828", "#1d4ed8", "#e2b54d", "#16a34a", "#ec4899", "#ffffff", "#7c3aed"];
        for (let r = 0; r < rows; r++) {
            for (let c = 0; c < cols; c++) {
                const id = n * 997 + r * 31 + c;
                const jump = Math.max(0, Math.sin(G.t * (6 + hash(id) * 4) + id)) * excite * rh * 0.5;
                ctx.fillStyle = hats[Math.floor(hash(id) * hats.length)];
                ctx.fillRect(x0 + 10 + c * cw, top + 11 + r * rh - jump, cw * 0.6, rh * 0.55);
                // הבזקי מצלמות בלילה
                if (night && hash(id + Math.floor(G.t * 3)) > 0.995) {
                    ctx.fillStyle = "#fff";
                    ctx.fillRect(x0 + 8 + c * cw, top + 9 + r * rh, cw, rh * 0.8);
                }
            }
        }
        ctx.fillStyle = "#cdbf9f";
        ctx.fillRect(x0, top, 4, bot - top);
    });
}

function drawTrack() {
    const turfTop = H * 0.425, railY = H * 0.455, trackTop = H * 0.47, trackBot = H * 0.955;
    const rain = G.race && G.race.cond === "rain";
    ctx.fillStyle = "#3d7a3a";
    ctx.fillRect(0, turfTop, W, trackTop - turfTop);
    const g = ctx.createLinearGradient(0, trackTop, 0, trackBot);
    g.addColorStop(0, rain ? "#7a5536" : "#a8754a");
    g.addColorStop(1, rain ? "#8e6440" : "#c48a57");
    ctx.fillStyle = g;
    ctx.fillRect(0, trackTop, W, trackBot - trackTop);
    // פסי מגרפה
    tiles(1, PPM * 6, (x, n) => {
        ctx.fillStyle = n % 2 ? "rgba(0,0,0,.035)" : "rgba(255,255,255,.03)";
        ctx.fillRect(x - PPM * 6, trackTop, PPM * 6, trackBot - trackTop);
    });
    if (rain) {
        // שלוליות
        tiles(1, PPM * 7, (x, n) => {
            if (hash(n * 11) < 0.45) return;
            const y = trackTop + (trackBot - trackTop) * (0.1 + hash(n * 13) * 0.85);
            ctx.fillStyle = "rgba(190,205,220,.28)";
            ctx.beginPath(); ctx.ellipse(x, y, PPM * (1 + hash(n) * 1.5), 4 + hash(n * 2) * 4, 0, 0, TAU); ctx.fill();
        });
    }
    ctx.strokeStyle = "rgba(255,255,255,.07)";
    ctx.lineWidth = 1;
    for (let i = 0; i < FIELD_SIZE; i++) {
        const y = laneY(i) + 6;
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(W, y); ctx.stroke();
    }
    tiles(1, PPM * 4, x => {
        ctx.fillStyle = "#f4f1ea";
        ctx.fillRect(x - 1.5, railY, 3, trackTop - railY + 2);
    });
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, railY - 2, W, 4);
}

function drawMarkers() {
    const L = G.race.dist;
    const railY = H * 0.455;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    for (let m = 0; m < L; m += 100) {
        const x = worldX(m);
        if (x < -40 || x > W + 40) continue;
        const left = L - m;
        const red = left === 200 || left === 100;
        ctx.fillStyle = red ? "#d62828" : "#f4f1ea";
        ctx.fillRect(x - 2, railY - H * 0.07, 4, H * 0.07);
        ctx.fillStyle = red ? "#d62828" : "#1b3627";
        ctx.fillRect(x - 22, railY - H * 0.11, 44, H * 0.045);
        ctx.fillStyle = "#fff";
        ctx.font = `700 ${Math.round(H * 0.03)}px Heebo, sans-serif`;
        ctx.fillText(left + "", x, railY - H * 0.088);
    }
    // דגלי משוכה על המעקה
    G.race.hurdleAt.forEach(m => {
        const x = worldX(m);
        if (x < -30 || x > W + 30) return;
        ctx.fillStyle = "#f4f1ea";
        ctx.fillRect(x - 1.5, railY - H * 0.06, 3, H * 0.06);
        ctx.fillStyle = "#16a34a";
        ctx.beginPath();
        ctx.moveTo(x, railY - H * 0.06);
        ctx.lineTo(x + 14, railY - H * 0.045);
        ctx.lineTo(x, railY - H * 0.03);
        ctx.fill();
    });
}

function drawHurdle(m, lane) {
    const x = worldX(m);
    if (x < -40 || x > W + 40) return;
    const s = laneScale(lane), y = laneY(lane);
    const w = 16 * s, h = 34 * s;
    ctx.fillStyle = "#6b4a2b";
    ctx.fillRect(x - w * 0.5 - 2 * s, y - h, 3 * s, h);
    ctx.fillRect(x + w * 0.5 - 1 * s, y - h, 3 * s, h);
    ctx.fillStyle = "#2f6b33";
    ctx.beginPath();
    ctx.moveTo(x - w * 0.5, y);
    ctx.lineTo(x - w * 0.35, y - h * 0.92);
    ctx.lineTo(x + w * 0.35, y - h * 0.92);
    ctx.lineTo(x + w * 0.5, y);
    ctx.fill();
    ctx.fillStyle = "#3f8a44";
    for (let k = 0; k < 4; k++) {
        ctx.beginPath();
        ctx.arc(x - w * 0.3 + k * w * 0.2, y - h * 0.9, w * 0.16, 0, TAU);
        ctx.fill();
    }
    ctx.fillStyle = "#f4f1ea";
    ctx.fillRect(x - w * 0.6, y - h * 0.98, w * 1.2, 3 * s);
}

function drawFinish(front) {
    const x = worldX(G.race.dist);
    if (x < -60 || x > W + 60) return;
    const trackTop = H * 0.47, trackBot = H * 0.955, railY = H * 0.455;
    if (!front) {
        const sq = 6;
        for (let y = trackTop, k = 0; y < trackBot; y += sq, k++) {
            ctx.fillStyle = k % 2 ? "#111" : "#fff";
            ctx.fillRect(x - sq, y, sq, sq);
            ctx.fillStyle = k % 2 ? "#fff" : "#111";
            ctx.fillRect(x, y, sq, sq);
        }
        ctx.fillStyle = "#f4f1ea";
        ctx.fillRect(x - 3, railY - H * 0.2, 6, H * 0.2);
        ctx.fillStyle = "#d62828";
        ctx.beginPath(); ctx.arc(x, railY - H * 0.2, H * 0.035, 0, TAU); ctx.fill();
        ctx.fillStyle = "#fff";
        ctx.beginPath(); ctx.arc(x, railY - H * 0.2, H * 0.022, 0, TAU); ctx.fill();
        ctx.fillStyle = "#e2b54d";
        ctx.fillRect(x - 34, railY - H * 0.16, 68, H * 0.05);
        ctx.fillStyle = "#2a1e05";
        ctx.font = `700 ${Math.round(H * 0.035)}px "Secular One", Heebo, sans-serif`;
        ctx.textAlign = "center"; ctx.textBaseline = "middle";
        ctx.fillText("סיום", x, railY - H * 0.135);
    } else {
        ctx.fillStyle = "#f4f1ea";
        ctx.fillRect(x - 3, trackBot - 4, 6, H * 0.06);
    }
}

function drawGate() {
    // שער הזינוק: עמוד קדמי ליד האף של הסוסים ועמוד אחורי מאחוריהם
    const x = worldX(0.3), back = worldX(-3.6);
    if (back < -20 || x > W + 20) return;
    const top = H * 0.4, bot = H * 0.97;
    ctx.fillStyle = "#2f5d46";
    ctx.fillRect(x - 5, top, 10, bot - top);
    ctx.fillRect(back - 5, top, 10, bot - top);
    ctx.fillRect(x - 5, top, back - x + 10, H * 0.03);
    ctx.fillStyle = "#e2b54d";
    ctx.fillRect(x - 5, top + H * 0.03, back - x + 10, 3);
    if (!G.gateOpen) {
        for (let i = 0; i < FIELD_SIZE; i++) {
            const y = laneY(i), s = laneScale(i);
            ctx.fillStyle = "rgba(47,93,70,.9)";
            ctx.fillRect(x - 4, y - 72 * s, 8, 72 * s);
            ctx.fillStyle = "#e2b54d";
            ctx.fillRect(x - 4, y - 48 * s, 8, 3);
        }
    }
}

// ===================== ציור סוס =====================
function leg(hx, hy, a, amp, col, w, hind) {
    const t1 = (hind ? 0.1 : 0.05) + amp * 0.55 * Math.sin(a);
    const fold = amp * Math.max(0, Math.sin(a + (hind ? 2.4 : -0.9)));
    const t2 = hind ? t1 - 0.25 + fold * 0.3 : t1 - fold * 1.25;
    const kx = hx + Math.sin(t1) * 19, ky = hy + Math.cos(t1) * 19;
    const fx = kx + Math.sin(t2) * 22, fy = ky + Math.cos(t2) * 22;
    ctx.strokeStyle = col;
    ctx.lineCap = "round";
    ctx.lineWidth = w;
    ctx.beginPath(); ctx.moveTo(hx, hy); ctx.lineTo(kx, ky); ctx.stroke();
    ctx.lineWidth = w * 0.62;
    ctx.beginPath(); ctx.moveTo(kx, ky); ctx.lineTo(fx, fy); ctx.stroke();
    ctx.fillStyle = "#1a1310";
    ctx.beginPath(); ctx.ellipse(fx + 1, fy, 3.2, 2.4, 0, 0, TAU); ctx.fill();
}

function drawHorse(h, x, y, s, label) {
    const run = clamp(h.v / 8, 0, 1);
    const air = h.airT > 0;
    const amp = air ? 0.15 : 0.25 + run * 0.75;
    const ph = air ? 1.3 : h.phase;
    const lift = air ? Math.sin(Math.PI * h.airT) * 50 : 0;
    const tilt = air ? (0.5 - h.airT) * 0.6 : 0;
    const bob = air ? 0 : -Math.abs(Math.sin(ph)) * 3.5 * run - (1 - run) * Math.sin(G.t * 2 + h.num) * 0.6;
    const dark = shade(h.coat, -0.35);
    const light = shade(h.coat, 0.18);

    ctx.save();
    ctx.translate(x, y);
    // צל נשאר על הקרקע ומתכווץ בקפיצה
    const shrink = 1 - lift / 120;
    ctx.fillStyle = "rgba(40,20,5,.28)";
    ctx.beginPath(); ctx.ellipse(0, 0, 44 * s * shrink, 6 * s * shrink, 0, 0, TAU); ctx.fill();
    ctx.translate(0, -lift * s);
    ctx.rotate(tilt);
    ctx.scale(-s, s); // הסוס פונה שמאלה, לכיוון הסיום
    ctx.translate(0, bob);

    leg(-24, -44, ph + Math.PI * 0.85, amp, dark, 8, true);
    leg(22, -44, ph + 0.35, amp, dark, 7, false);

    // זנב
    const tw = Math.sin(ph) * 6 * run;
    ctx.strokeStyle = shade(h.coat, -0.55);
    ctx.lineWidth = 6; ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(-36, -58);
    ctx.quadraticCurveTo(-52, -54 + tw, -58 - run * 8, -34 + tw * 1.5 - run * 14);
    ctx.stroke();

    // גוף
    ctx.fillStyle = h.coat;
    ctx.beginPath(); ctx.ellipse(0, -51, 34, 15, 0, 0, TAU); ctx.fill();
    ctx.beginPath(); ctx.ellipse(-24, -53, 16, 16, 0, 0, TAU); ctx.fill();
    ctx.beginPath(); ctx.ellipse(23, -51, 15, 15, 0, 0, TAU); ctx.fill();
    ctx.fillStyle = light;
    ctx.beginPath(); ctx.ellipse(-4, -60, 24, 4, 0, 0, TAU); ctx.fill();

    // צוואר וראש
    const nod = Math.sin(ph) * 3 * run;
    ctx.fillStyle = h.coat;
    ctx.beginPath();
    ctx.moveTo(16, -60);
    ctx.lineTo(40, -86 + nod);
    ctx.lineTo(52, -80 + nod);
    ctx.lineTo(36, -42);
    ctx.closePath();
    ctx.fill();
    ctx.save();
    ctx.translate(50, -81 + nod);
    ctx.rotate(0.85 - run * 0.25);
    ctx.beginPath(); ctx.ellipse(10, 0, 15, 7.5, 0, 0, TAU); ctx.fill();
    ctx.fillStyle = shade(h.coat, -0.5);
    ctx.beginPath(); ctx.ellipse(22, 1, 4, 5, 0, 0, TAU); ctx.fill();
    ctx.fillStyle = "#111";
    ctx.beginPath(); ctx.arc(4, -3, 1.8, 0, TAU); ctx.fill();
    ctx.restore();
    ctx.fillStyle = dark;
    ctx.beginPath();
    ctx.moveTo(43, -88 + nod); ctx.lineTo(41, -98 + nod); ctx.lineTo(48, -90 + nod);
    ctx.fill();
    ctx.strokeStyle = shade(h.coat, -0.6);
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(18, -63);
    ctx.quadraticCurveTo(30 - run * 4, -80 + nod, 42, -90 + nod);
    ctx.stroke();

    // שמיכת אוכף עם מספר
    ctx.fillStyle = "#f7f3ea";
    ctx.fillRect(-14, -64, 22, 15);
    ctx.save();
    ctx.scale(-1, 1);
    ctx.fillStyle = "#111";
    ctx.font = "900 11px Heebo, sans-serif";
    ctx.textAlign = "center"; ctx.textBaseline = "middle";
    ctx.fillText(h.num, 3, -56);
    ctx.restore();

    leg(-28, -44, ph + Math.PI * 1.05, amp, h.coat, 9, true);
    leg(26, -44, ph + 0.6, amp, h.coat, 8, false);

    // רוכב
    const jb = Math.sin(ph * 2) * 1.5 * run;
    ctx.strokeStyle = "#f7f3ea"; ctx.lineWidth = 6;
    ctx.beginPath(); ctx.moveTo(0, -72 + jb); ctx.lineTo(10, -62); ctx.stroke();
    ctx.strokeStyle = "#2a1a10"; ctx.lineWidth = 5;
    ctx.beginPath(); ctx.moveTo(10, -62); ctx.lineTo(8, -56); ctx.stroke();
    ctx.save();
    ctx.translate(6, -78 + jb);
    ctx.rotate(-0.3 + run * 0.12);
    ctx.fillStyle = h.silk;
    ctx.beginPath(); ctx.ellipse(0, 0, 14, 7.5, 0, 0, TAU); ctx.fill();
    ctx.fillStyle = h.cap;
    ctx.fillRect(-3, -7, 5, 14);
    ctx.restore();
    ctx.strokeStyle = h.silk; ctx.lineWidth = 4.5;
    ctx.beginPath(); ctx.moveTo(14, -80 + jb);
    if (h.whip > 0) {
        ctx.lineTo(4, -98);
        ctx.stroke();
        ctx.strokeStyle = "#2a1a10"; ctx.lineWidth = 1.6;
        ctx.beginPath(); ctx.moveTo(4, -98); ctx.lineTo(-22, -84 - h.whip * 10); ctx.stroke();
    } else {
        ctx.lineTo(34, -78 + jb);
        ctx.stroke();
        ctx.strokeStyle = "#2a1a10"; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(34, -78 + jb); ctx.lineTo(54, -78 + nod); ctx.stroke();
    }
    ctx.fillStyle = "#e9b48a";
    ctx.beginPath(); ctx.arc(21, -88 + jb, 6.5, 0, TAU); ctx.fill();
    ctx.fillStyle = h.cap;
    ctx.beginPath(); ctx.arc(21, -89 + jb, 7, Math.PI * 1.02, Math.PI * 2.05); ctx.fill();
    ctx.fillRect(24, -90 + jb, 8, 2.5);
    ctx.restore();

    if (label) {
        const my = y - (112 + lift) * s + Math.sin(G.t * 5) * 3;
        const hot = G.jumpReady && G.screen === "race";
        ctx.fillStyle = hot ? "#ffe08a" : "#e2b54d";
        ctx.beginPath();
        ctx.moveTo(x, my + 10); ctx.lineTo(x - 8, my); ctx.lineTo(x + 8, my);
        ctx.fill();
        const text = hot ? "קפוץ!" : label;
        ctx.font = `900 ${Math.round((hot ? 18 : 13) * Math.max(s, 0.8))}px Heebo, sans-serif`;
        ctx.textAlign = "center"; ctx.textBaseline = "bottom";
        ctx.lineWidth = 3; ctx.strokeStyle = "rgba(0,0,0,.6)";
        ctx.strokeText(text, x, my - 2);
        ctx.fillText(text, x, my - 2);
    }
}

function drawFrontRail() {
    const y = H * 0.965;
    ctx.fillStyle = "#2f6a33";
    ctx.fillRect(0, y - 4, W, H - y + 4);
    tiles(1.12, PPM * 4.5, x => {
        ctx.fillStyle = "#f4f1ea";
        ctx.fillRect(x - 2.5, y - H * 0.05, 5, H * 0.05);
    });
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, y - H * 0.05, W, 5);
    tiles(1.25, 34, (x, n) => {
        if (hash(n * 5) < 0.5) return;
        ctx.fillStyle = ["#e2b54d", "#ef5a5f", "#f3ead6"][n % 3];
        ctx.beginPath(); ctx.arc(x, y + 6 + hash(n) * 6, 3, 0, TAU); ctx.fill();
    });
}

function drawAtmosphere() {
    const c = cond();
    const id = G.race.cond;
    if (c.tint) {
        ctx.globalCompositeOperation = "multiply";
        ctx.fillStyle = c.tint;
        ctx.fillRect(0, 0, W, H);
        ctx.globalCompositeOperation = "source-over";
    }
    if (id === "night") {
        drawNightSky();
        // אורות הזרקורים
        ctx.globalCompositeOperation = "lighter";
        tiles(0.5, LIGHT_P, x => {
            const tx = x - LIGHT_P * 0.5;
            const lg = ctx.createRadialGradient(tx, H * 0.06, 2, tx, H * 0.06, H * 0.12);
            lg.addColorStop(0, "rgba(255,248,214,.9)");
            lg.addColorStop(1, "rgba(255,248,214,0)");
            ctx.fillStyle = lg;
            ctx.fillRect(tx - H * 0.12, 0, H * 0.24, H * 0.2);
            const pg = ctx.createRadialGradient(tx, H * 0.72, 10, tx, H * 0.72, W * 0.32);
            pg.addColorStop(0, "rgba(255,240,200,.22)");
            pg.addColorStop(1, "rgba(255,240,200,0)");
            ctx.fillStyle = pg;
            ctx.fillRect(tx - W * 0.32, H * 0.4, W * 0.64, H * 0.6);
        });
        ctx.globalCompositeOperation = "source-over";
    }
    if (id === "rain") {
        ctx.strokeStyle = "rgba(225,235,245,.45)";
        ctx.lineWidth = 1;
        ctx.beginPath();
        for (let i = 0; i < 160; i++) {
            const y = ((hash(i * 7) * H + G.t * 620 * (0.8 + hash(i) * 0.4)) % (H + 40)) - 20;
            const x = ((hash(i) * (W + 100) + y * 0.25 + G.cam * PPM * 0.4) % (W + 100)) - 50;
            ctx.moveTo(x, y);
            ctx.lineTo(x - 4, y + 15);
        }
        ctx.stroke();
    }
}

function drawMinimap() {
    if (G.screen === "menu") return;
    const x0 = W - 24, x1 = 24, y = 16;
    const L = G.race.dist;
    const px = m => x0 + (x1 - x0) * clamp(m / L, 0, 1);
    ctx.fillStyle = "rgba(10,22,15,.6)";
    ctx.fillRect(0, 0, W, 30);
    ctx.strokeStyle = "rgba(243,234,214,.4)";
    ctx.lineWidth = 3;
    ctx.beginPath(); ctx.moveTo(x0, y); ctx.lineTo(x1, y); ctx.stroke();
    ctx.fillStyle = "#3f8a44";
    G.race.hurdleAt.forEach(m => ctx.fillRect(px(m) - 2, y - 6, 4, 12));
    ctx.fillStyle = "#e2b54d";
    ctx.fillRect(x1 - 2, y - 8, 4, 16);
    G.field.slice().sort((a, b) => a.pos - b.pos).forEach(h => {
        const x = px(h.pos);
        ctx.fillStyle = h.silk;
        ctx.beginPath(); ctx.arc(x, y, h.isMe ? 7 : 5, 0, TAU); ctx.fill();
        if (h.isMe) {
            ctx.strokeStyle = "#e2b54d"; ctx.lineWidth = 2.5;
            ctx.stroke();
        }
    });
}

function drawParticles() {
    const rain = G.race.cond === "rain";
    dust.forEach(p => {
        ctx.fillStyle = rain ? `rgba(120,95,70,${p.life * 0.55})` : `rgba(214,170,120,${p.life * 0.5})`;
        ctx.beginPath(); ctx.arc(worldX(p.m), p.y - (p.up || 0) * (1 - p.life), p.r * (1.6 - p.life), 0, TAU); ctx.fill();
    });
}

function drawOverlayFx() {
    confetti.forEach(c => {
        ctx.save();
        ctx.translate(c.x, c.y);
        ctx.rotate(c.a);
        ctx.fillStyle = c.col;
        ctx.fillRect(-4, -2, 8, 4);
        ctx.restore();
    });
    floaters.forEach(f => {
        ctx.globalAlpha = clamp(f.life, 0, 1);
        ctx.font = `900 ${f.size}px Heebo, sans-serif`;
        ctx.textAlign = "center"; ctx.textBaseline = "middle";
        ctx.lineWidth = 4; ctx.strokeStyle = "rgba(0,0,0,.55)";
        ctx.strokeText(f.text, f.x, f.y);
        ctx.fillStyle = f.col;
        ctx.fillText(f.text, f.x, f.y);
        ctx.globalAlpha = 1;
    });
}

function render() {
    ctx = mainCtx;
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    ctx.clearRect(0, 0, W, H);
    if (!G.race) return;
    drawSky();
    drawHills();
    if (G.race.cond === "night") drawTowers();
    drawGrandstand();
    drawTrack();
    drawMarkers();
    drawFinish(false);
    drawParticles();
    // מהשורה האחורית לקדמית
    for (let i = 0; i < FIELD_SIZE; i++) {
        G.race.hurdleAt.forEach(m => drawHurdle(m, i));
        const h = G.field.find(f => f.lane === i);
        if (!h) continue;
        // המיקום במרוץ נמדד לפי האף, לכן מרכז הגוף מוזז אחורה
        drawHorse(h, worldX(h.pos) + 52 * laneScale(i), laneY(i), laneScale(i), h.isMe ? h.name : null);
    }
    drawGate();
    drawFinish(true);
    drawFrontRail();
    drawAtmosphere();
    drawMinimap();
    drawOverlayFx();
}

// תצוגה מקדימה של הסוס באורווה
function renderPreview(el, look) {
    if (!el || !look || el.offsetParent === null) return;
    const c = el.getContext("2d");
    ctx = c;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, el.width, el.height);
    const fake = { ...look, num: "★", v: 7, phase: G.t * 7, whip: 0, airT: 0 };
    drawHorse(fake, el.width / 2 + 10, el.height - 22, 1.45, null);
    ctx = mainCtx;
}

// ===================== סימולציה =====================
function speedTarget(h) {
    const c = cond();
    const p = clamp(h.pos / G.race.dist, 0, 1);
    const fade = G.race.cond === "rain" ? 0.12 : 0.07;
    const late = p > 0.7 ? 1 - (1 - h.stamina) * fade * ((p - 0.7) / 0.3) : 1;
    if (h.isMe) return (h.top * 0.9 * late + h.burst) * c.slow - h.stumble;
    return (h.top * STRATS[h.strat].pace(p) * late + h.noise) * c.slow - h.stumble;
}

function nextHurdle(h) {
    return G.race.hurdleAt.find(m => m > h.pos);
}

function startJump(h) {
    h.airT = 0.0001;
}

function jumpWindow(h) {
    return 0.12 + (h.jumpSkill - 0.8) * 0.6;
}

function hurdleCross(h, m) {
    const t = h.airT > 0 ? h.airT : -1;
    const sx = worldX(m), sy = laneY(h.lane) - 90 * laneScale(h.lane);
    if (t >= 0.2 && t <= 0.8) {
        if (h.isMe) {
            G.myClean++;
            if (Math.abs(t - 0.5) <= jumpWindow(h)) {
                h.burst = Math.min(5, h.burst + 1.8);
                float("קפיצה מושלמת!", sx, sy, "#e2b54d", 20);
                SFX.chime();
                unlock("jump");
            } else {
                float("יפה!", sx, sy, "#f3ead6", 16);
            }
        }
    } else if (t >= 0.08 && t <= 0.95) {
        h.v *= 0.8;
        if (h.isMe) { G.myHits++; float("נגיעה", sx, sy, "#f3ead6", 16); SFX.miss(); }
    } else {
        // נפילה: הסוס נתקל במשוכה
        h.v *= h.isMe ? 0.45 + 0.02 * ((h.jumpSkill - 0.8) / 0.02) : 0.45;
        h.stumble = 3;
        for (let k = 0; k < 14; k++) {
            dust.push({ m: m - Math.random() * 1.5, y: laneY(h.lane) - 4, r: 4 + Math.random() * 6, life: 1, up: 20 + Math.random() * 30 });
        }
        if (h.isMe) { G.myHits++; G.combo = 0; float("נתקל!", sx, sy, "#ef5a5f", 22); }
        SFX.thud();
        if (G.raceT - G.lastSay > 1) say(`${h.name} נתקל במשוכה!`);
    }
    rerollAim(h);
}

function step(dt) {
    G.t += dt;
    const racing = G.screen !== "menu" && G.gateOpen;
    if (G.screen === "race") G.raceT += dt;

    G.field.forEach(h => {
        if (racing) {
            if (!h.isMe) {
                h.noiseT -= dt;
                if (h.noiseT <= 0) {
                    h.noiseT = 1.2 + Math.random() * 2;
                    const lateKick = h.pos / G.race.dist > 0.75 && Math.random() < 0.35 ? 0.9 : 0;
                    h.noiseTarget = (Math.random() - 0.5) * 1.3 + lateKick;
                }
                h.noise += (h.noiseTarget - h.noise) * Math.min(1, dt * 0.9);
                // קפיצה אוטומטית של היריבים
                const nh = nextHurdle(h);
                if (nh !== undefined && h.airT === 0 && !h.finished) {
                    const tEst = (nh - h.pos) / (Math.max(h.v, 1) * JUMP_T);
                    if (tEst <= h.aim) startJump(h);
                }
            }
            const target = h.finished ? Math.max(4, h.v * 0.985) : speedTarget(h);
            h.v += (target - h.v) * Math.min(1, dt * h.accel * 0.45);
            h.v = Math.max(0, h.v);
            h.prevPos = h.pos;
            h.pos += h.v * dt;
            if (h.airT > 0) {
                h.airT += dt / JUMP_T;
                if (h.airT >= 1) {
                    h.airT = 0;
                    if (h.v > 5) for (let k = 0; k < 5; k++) dust.push({ m: h.pos - 1 - Math.random(), y: laneY(h.lane) - 2, r: 4 + Math.random() * 4, life: 1 });
                }
            }
            G.race.hurdleAt.forEach(m => {
                if (h.prevPos < m && h.pos >= m && !h.finished) hurdleCross(h, m);
            });
            h.burst *= Math.exp(-1.1 * dt);
            h.stumble = Math.max(0, h.stumble - dt * 2);
            h.whip = Math.max(0, h.whip - dt * 3);
            if (!h.finished && h.pos >= G.race.dist) {
                h.finished = true;
                h.time = G.raceT - (h.pos - G.race.dist) / Math.max(h.v, 0.1);
                G.finishOrder.push(h);
                h.place = G.finishOrder.length;
                onFinish(h);
            }
            if (h.v > 6 && h.airT === 0 && Math.random() < dt * h.v * 0.9) {
                dust.push({ m: h.pos - (52 * laneScale(h.lane)) / PPM + Math.random() - 0.5, y: laneY(h.lane) - 2, r: 3 + Math.random() * 4 * laneScale(h.lane), life: 1 });
            }
        }
        const prevFrac = (h.phase % TAU) / TAU;
        if (h.airT === 0) h.phase += dt * (2.2 + h.v * 0.45);
        if (h.isMe && racing && G.screen === "race" && h.airT === 0) {
            const frac = (h.phase % TAU) / TAU;
            if (prevFrac < 0.85 && frac >= 0.85) SFX.gallop(0.25 + h.v / 60);
        }
    });

    dust.forEach(p => { p.life -= dt * 1.4; });
    dust = dust.filter(p => p.life > 0);
    confetti.forEach(c => { c.x += c.vx * dt; c.y += c.vy * dt; c.vy += 140 * dt; c.a += c.va * dt; });
    confetti = confetti.filter(c => c.y < H + 20);
    floaters.forEach(f => { f.y -= 40 * dt; f.life -= dt * 1.2; });
    floaters = floaters.filter(f => f.life > 0);

    const m = me();
    if (G.screen !== "menu" && m) {
        G.cam += (m.pos - G.cam) * Math.min(1, dt * 3.5);
    } else {
        G.cam += (0 - G.cam) * Math.min(1, dt * 2);
    }

    if (G.screen === "race") {
        G.power = Math.min(100, G.power + dt * (6 + m.stamina * 3));
        raceLogic(dt);
    }
}

function raceLogic(dt) {
    const L = G.race.dist;
    const order = G.field.slice().sort((a, b) => {
        if (a.finished && b.finished) return a.time - b.time;
        if (a.finished) return -1;
        if (b.finished) return 1;
        return b.pos - a.pos;
    });
    const leader = order[0];
    const m = me();
    G.leaderPos = leader.pos;
    const myRank = order.indexOf(m) + 1;

    // פרשנות
    if (G.leader && leader !== G.leader && !leader.finished && G.raceT > 3 && G.raceT - G.lastSay > 1.5) {
        say(leader.isMe ? `${leader.name} שלך עולה לראשות!` : `${leader.name} עוקף ועולה לראשות!`);
    }
    G.leader = leader;
    if (G.myRank && myRank < G.myRank && myRank > 1 && !m.finished && G.raceT > 4 && G.raceT - G.lastSay > 1.5) {
        say(`${m.name} מתקדם למקום ${myRank}!`, 1.6);
    }
    G.myRank = myRank;

    const left = L - leader.pos;
    if (left < L / 2 && !G.calls.half) {
        G.calls.half = 1;
        G.lastAtHalf = myRank === FIELD_SIZE;
        say(`חצי מרוץ! ${leader.name} בראש, ${order[1].name} צמוד`);
    }
    if (left < 200 && !G.calls.c200) { G.calls.c200 = 1; say("200 מטר לסיום!"); }
    if (left < 100 && !G.calls.c100) { G.calls.c100 = 1; say("ישורת אחרונה! הקהל על הרגליים!"); }
    if (G.raceT - G.lastSay > 4.5 && !leader.finished) {
        const gap = order[0].pos - order[1].pos;
        say(gap < 1.5 ? `${order[0].name} ו${order[1].name} ראש בראש!` : `${leader.name} מוביל בפער של ${gap.toFixed(1)} מטר`);
    }

    // הילוך איטי בסיום צמוד
    const close = !leader.finished && left < 14 && order[0].pos - order[1].pos < 1.4;
    G.timeScale += ((close ? 0.35 : 1) - G.timeScale) * Math.min(1, dt * 6);
    if (close && !G.calls.photo) { G.calls.photo = 1; say("צמוד! צמוד מאוד! צילום פוטו פיניש!"); }

    SFX.crowdLevel(0.02 + clamp(leader.pos / L, 0, 1) ** 2 * 0.2);

    // רמז קפיצה
    const nh = nextHurdle(m);
    G.jumpReady = false;
    if (nh !== undefined && m.airT === 0 && !m.finished) {
        const tEst = (nh - m.pos) / (Math.max(m.v, 1) * JUMP_T);
        G.jumpReady = Math.abs(tEst - 0.5) <= jumpWindow(m);
    }
    $("jump").classList.toggle("ready", G.jumpReady);

    $("hud-rank").textContent = `${myRank}/${FIELD_SIZE}`;
    $("hud-left").textContent = m.finished ? "סיים" : `${Math.max(0, Math.ceil(L - m.pos))} מ'`;
    $("hud-speed").textContent = `${Math.round(m.v * 3.6)} קמ"ש`;
    const pw = $("power");
    pw.style.width = G.power + "%";
    pw.classList.toggle("low", G.power < 15);
    $("power-num").textContent = Math.round(G.power);
    const frac = (m.phase % TAU) / TAU;
    $("marker").style.right = (frac * 100) + "%";
    $("combo").textContent = G.combo > 1 ? `רצף x${G.combo}` : "";

    if (G.endTimer > 0) {
        G.endTimer -= dt;
        if (G.endTimer <= 0 || G.field.every(h => h.finished)) showResults();
    }
}

function onFinish(h) {
    if (h.place === 1) {
        flash();
        say(`${h.name} חוצה ראשון את קו הסיום!`, 0);
        SFX.crowdLevel(0.3);
    }
    if (h.isMe) {
        G.endTimer = 3.5;
        G.jumpReady = false;
        const x = worldX(h.pos), y = laneY(h.lane) - 90 * laneScale(h.lane);
        float(h.place === 1 ? "מקום ראשון!" : `מקום ${h.place}`, x, y, h.place === 1 ? "#e2b54d" : "#f3ead6", 26);
        if (h.place === 1) burst(140);
    }
}

// ===================== קלט =====================
function press() {
    SFX.init();
    if (G.screen !== "race" || !G.gateOpen) return;
    const h = me();
    if (h.finished) return;
    const btn = $("boost");
    btn.classList.add("press");
    setTimeout(() => btn.classList.remove("press"), 90);
    const x = worldX(h.pos) + 52 * laneScale(h.lane), y = laneY(h.lane) - 140 * laneScale(h.lane);

    if (G.raceT - G.lastPress < 0.2) {
        // לחיצות מהירות מדי
        h.stumble = 1.2;
        G.combo = 0;
        G.power = Math.max(0, G.power - 3);
        float("לאט יותר!", x, y, "#ef5a5f", 16);
        SFX.miss();
        G.lastPress = G.raceT;
        return;
    }
    G.lastPress = G.raceT;
    if (G.power < 5) {
        float("אין כוח!", x, y, "#ef5a5f", 16);
        SFX.miss();
        return;
    }
    const frac = (h.phase % TAU) / TAU;
    const perfect = h.airT === 0 && frac >= ZONE[0] && frac <= ZONE[1];
    h.whip = 1;
    if (perfect) {
        G.combo++;
        G.bestCombo = Math.max(G.bestCombo, G.combo);
        if (G.combo >= 10) unlock("combo10");
        h.burst = Math.min(5, h.burst + 1.55 + Math.min(G.combo, 8) * 0.08);
        G.power -= 6;
        float(G.combo > 2 ? `מושלם x${G.combo}` : "מושלם!", x, y, "#e2b54d", 18 + Math.min(G.combo, 8));
        SFX.perfect(G.combo);
        const r = document.querySelector(".rhythm");
        r.classList.remove("hit"); void r.offsetWidth; r.classList.add("hit");
    } else {
        G.combo = 0;
        h.burst = Math.min(5, h.burst + 0.85);
        G.power -= 9;
        float("טוב", x, y, "#f3ead6", 15);
        SFX.tone(330, 0.06, "triangle", 0.1);
    }
    G.power = Math.max(0, G.power);
}

function jump() {
    SFX.init();
    if (G.screen !== "race" || !G.gateOpen || !G.race.hurdleAt.length) return;
    const h = me();
    if (h.finished || h.airT > 0) return;
    startJump(h);
    SFX.whoosh();
    const b = $("jump");
    b.classList.add("press");
    setTimeout(() => b.classList.remove("press"), 90);
}

function float(text, x, y, col, size) {
    floaters.push({ text, x, y, col, size, life: 1.2 });
}

function burst(n) {
    const cols = ["#e2b54d", "#ef5a5f", "#f3ead6", "#5fd68a", "#1d4ed8", "#ec4899"];
    for (let i = 0; i < n; i++) {
        confetti.push({
            x: W / 2 + (Math.random() - 0.5) * W * 0.6, y: -10 - Math.random() * H * 0.4,
            vx: (Math.random() - 0.5) * 120, vy: Math.random() * 60,
            a: Math.random() * TAU, va: (Math.random() - 0.5) * 10,
            col: cols[i % cols.length],
        });
    }
}

function flash() {
    const f = $("flash");
    f.classList.add("on");
    setTimeout(() => f.classList.remove("on"), 60);
}

function say(text, hold = 0) {
    G.lastSay = G.raceT + hold;
    const el = $("ticker-text");
    el.textContent = text;
    el.classList.remove("in"); void el.offsetWidth; el.classList.add("in");
}

function big(text) {
    const el = $("big");
    el.hidden = !text;
    el.textContent = text || "";
    el.classList.remove("pop"); void el.offsetWidth; el.classList.add("pop");
}

function toast(text) {
    const t = document.createElement("div");
    t.className = "toast";
    t.textContent = text;
    $("toasts").appendChild(t);
    setTimeout(() => t.remove(), 3200);
}

function unlock(id) {
    if (career.ach[id]) return;
    career.ach[id] = Date.now();
    store.set("career", career);
    const a = ACH.find(x => x.id === id);
    toast(`${a.icon} הישג חדש: ${a.name}`);
    SFX.chime();
    G.newAch = (G.newAch || []).concat(a);
}

// ===================== מסכים =====================
function setCoins(v) {
    if (!Number.isFinite(v)) return;
    career.coins = Math.max(0, Math.round(v));
    const el = $("coins");
    el.textContent = career.coins;
    el.classList.remove("bump"); void el.offsetWidth; el.classList.add("bump");
    if (career.coins >= 1000) unlock("rich");
    store.set("career", career);
}

function show(screen) {
    G.screen = screen;
    const menu = screen === "menu";
    $("modes").hidden = !menu;
    $("create").hidden = !(menu && G.tab === "career" && (!myHorse || G.editing));
    $("career").hidden = !(menu && G.tab === "career" && myHorse && !G.editing);
    $("paddock").hidden = !(menu && G.tab === "bet");
    $("trophies").hidden = !(menu && G.tab === "trophies");
    $("ride").hidden = screen !== "countdown" && screen !== "race";
    $("results").hidden = screen !== "results";
    $("hud").hidden = menu;
    $("ticker").hidden = menu;
    $("jump").hidden = !(G.race && G.race.hurdleAt.length);
    document.querySelectorAll("#modes button").forEach(b => b.classList.toggle("on", b.dataset.mode === G.tab));
}

// מעבר בין לשוניות: הבמה מציגה את המרוץ הרלוונטי
function setTab(tab) {
    G.tab = tab;
    if (tab === "bet") {
        G.mode = "bet";
        G.race = betRace();
        G.field = G.betField;
        G.field.forEach(h => { h.isMe = G.pick !== null && h === G.betField[G.pick]; });
        renderTabs();
        renderCards();
        renderBet();
    } else if (myHorse) {
        G.race = seasonRace();
        G.field = careerField();
        renderCareer();
    } else {
        G.race = { ...SEASON[0], hurdleAt: [] };
        G.field = [];
    }
    if (tab === "trophies") renderTrophies();
    if (tab === "career" && (!myHorse || G.editing)) renderCreate();
    resetRunners();
    show("menu");
}

// ---------- יצירת סוס ----------
function renderCreate() {
    if (!G.draft) {
        G.draft = myHorse
            ? { name: myHorse.name, coat: myHorse.coat, silk: myHorse.silk, cap: myHorse.cap }
            : { name: "", coat: pickOne(COATS), silk: pickOne(SILKS), cap: pickOne(CAPS) };
    }
    $("create-title").textContent = myHorse ? "עריכת הסוס" : "הסוס הראשון שלך";
    $("create-go").textContent = myHorse ? "שמירה" : "לאורווה";
    $("horse-name").value = G.draft.name;
    const sw = (id, list, key) => {
        const el = $(id);
        el.innerHTML = "";
        list.forEach(col => {
            const b = document.createElement("button");
            b.type = "button";
            b.className = "swatch" + (G.draft[key] === col ? " on" : "");
            b.style.background = col;
            b.setAttribute("aria-label", col);
            b.addEventListener("click", () => { G.draft[key] = col; renderCreate(); });
            el.appendChild(b);
        });
    };
    sw("sw-coat", COATS, "coat");
    sw("sw-silk", SILKS, "silk");
    sw("sw-cap", CAPS, "cap");
}

function saveHorse() {
    SFX.init();
    const name = $("horse-name").value.trim();
    if (!name) { $("create-msg").textContent = "צריך לתת לסוס שם."; return; }
    if (STABLE.some(s => s.name === name)) { $("create-msg").textContent = "השם הזה כבר תפוס במסלול. נסו שם אחר."; return; }
    $("create-msg").textContent = "";
    if (myHorse) {
        Object.assign(myHorse, G.draft, { name });
    } else {
        myHorse = { ...G.draft, name, lv: { speed: 1, stamina: 1, accel: 1, jump: 1 } };
        newSeason(1);
        toast(`ברוכים הבאים לאורווה, ${name}!`);
    }
    store.set("horse", myHorse);
    G.editing = false;
    G.draft = null;
    SFX.chime();
    setTab("career");
}

// ---------- אורווה ועונה ----------
const trainCost = lv => 40 + 30 * lv;

function renderCareer() {
    $("my-name").textContent = myHorse.name;
    const total = STATS.reduce((a, s) => a + myHorse.lv[s.key], 0);
    $("my-rating").textContent = `דירוג ${total}/40`;
    $("train").innerHTML = STATS.map(s => {
        const lv = myHorse.lv[s.key];
        const pips = Array.from({ length: 10 }, (_, i) => `<i class="${i < lv ? "on" : ""}${i === lv - 1 && G.justTrained === s.key ? " new" : ""}"></i>`).join("");
        const cost = trainCost(lv);
        const btn = lv >= 10
            ? `<button class="train-btn" type="button" disabled>מקסימום</button>`
            : `<button class="train-btn" type="button" data-stat="${s.key}" ${career.coins < cost ? "disabled" : ""}>אימון · ${cost}</button>`;
        return `<div class="train-row"><span>${s.label}</span><span class="pips">${pips}</span>${btn}</div>`;
    }).join("");
    G.justTrained = null;
    $("train").querySelectorAll("[data-stat]").forEach(b => b.addEventListener("click", () => train(b.dataset.stat)));

    $("season-title").textContent = `עונה ${season.n}`;
    $("calendar").innerHTML = SEASON.map((r, i) => {
        const c = CONDS[r.cond];
        const res = season.results[i];
        const cls = i < season.idx ? "done" : i === season.idx ? "next" : "";
        return `<li class="${cls}">
            <span class="cal-n">${i + 1}</span>
            <span>${r.name}${r.final ? " 🏆" : ""}</span>
            <span class="cal-meta">${c.icon} ${r.dist} מ'${r.hurdles ? ` · ${r.hurdles} משוכות` : ""}</span>
            <span class="cal-res">${res ? res + "׳" : i === season.idx ? "הבא" : ""}</span>
        </li>`;
    }).join("");

    const table = [{ name: myHorse.name, pts: season.myPts, me: true }, ...season.rivals.map(r => ({ name: r.name, pts: r.pts }))]
        .sort((a, b) => b.pts - a.pts);
    $("standings").innerHTML = table.map((r, i) => `<tr class="${r.me ? "me" : ""}"><td>${i + 1}</td><td>${esc(r.name)}</td><td>${r.pts}</td></tr>`).join("");

    const mine = G.field.find(h => h.isMe);
    $("self-odds").textContent = mine ? mine.odds.toFixed(1) : "—";
    G.selfBet = Math.min(G.selfBet, career.coins);
    $("self-line").textContent = G.selfBet ? `זכייה אפשרית ${Math.round(G.selfBet * mine.odds)}` : "פרס כספי לכל מקום, בלי סיכון";
    document.querySelectorAll("#self-chips button").forEach(b => {
        b.classList.toggle("on", +b.dataset.v === G.selfBet);
        b.disabled = +b.dataset.v > career.coins;
    });
    const r = SEASON[season.idx];
    $("career-go").textContent = `למרוץ: ${r.name}`;
    renderStats();
}

function train(key) {
    const lv = myHorse.lv[key];
    const cost = trainCost(lv);
    if (lv >= 10 || career.coins < cost) return;
    setCoins(career.coins - cost);
    myHorse.lv[key]++;
    store.set("horse", myHorse);
    if (myHorse.lv[key] >= 10) unlock("trainer");
    G.justTrained = key;
    SFX.tone(523, 0.1, "triangle", 0.15);
    SFX.tone(784, 0.15, "triangle", 0.15, 0.08);
    G.field = careerField();
    resetRunners();
    renderCareer();
}

// ---------- הימורים ----------
function renderTabs() {
    const tabs = $("race-tabs");
    tabs.innerHTML = "";
    BET_RACES.forEach((r, i) => {
        const b = document.createElement("button");
        b.type = "button";
        b.className = "tab" + (i === G.betRaceIdx ? " on" : "");
        b.setAttribute("role", "tab");
        b.innerHTML = `${r.name}<small>${r.dist} מ'${r.bonus > 1 ? ` · x${r.bonus}` : ""}</small>`;
        b.addEventListener("click", () => {
            G.betRaceIdx = i;
            store.set("betRace", i);
            G.race = betRace();
            renderTabs();
            renderBet();
            show("menu");
        });
        tabs.appendChild(b);
    });
    const c = CONDS[G.betCond];
    $("bet-cond").textContent = `${c.icon} ${c.label}`;
}

function renderCards() {
    const wrap = $("cards");
    wrap.innerHTML = "";
    G.betField.forEach((h, i) => {
        const c = document.createElement("button");
        c.type = "button";
        c.className = "card" + (G.pick === i ? " on" : "");
        const bar = v => `<span class="stat-bar"><i style="width:${Math.round(clamp(v, 0.06, 1) * 100)}%"></i></span>`;
        c.innerHTML = `
            <div class="card-top">
                <span class="saddle" style="background:${h.silk}">${h.num}</span>
                <span class="card-name">${h.name}</span>
                <span class="card-odds">${h.odds.toFixed(1)}</span>
            </div>
            <div class="card-strat">${STRATS[h.strat].label}</div>
            <div class="stat">מהירות ${bar((h.top - 15.5) / 1.8)}</div>
            <div class="stat">סיבולת ${bar(h.stamina)}</div>
            <div class="stat">תאוצה ${bar((h.accel - 1.5) / 1.4)}</div>
            <div class="stat">קפיצה ${bar((h.jumpSkill - 0.84) / 0.13)}</div>
            <div class="form">כושר: ${h.form}</div>`;
        c.addEventListener("click", () => {
            SFX.init();
            G.pick = i;
            G.betField.forEach((x, k) => { x.isMe = k === i; });
            renderCards();
            renderBet();
            $("paddock-msg").textContent = "";
            SFX.tone(520, 0.08, "triangle", 0.12);
        });
        wrap.appendChild(c);
    });
}

function renderBet() {
    G.bet = Math.min(G.bet, career.coins);
    document.querySelectorAll("#chips button").forEach(b => {
        const v = b.dataset.v === "all" ? career.coins : +b.dataset.v;
        b.disabled = v > career.coins || v <= 0;
        b.classList.toggle("on", b.dataset.v === "all" ? G.bet === career.coins && ![10, 25, 50, 100].includes(G.bet) : +b.dataset.v === G.bet);
    });
    document.querySelectorAll("#bet-type button").forEach(b => b.classList.toggle("on", b.dataset.type === G.betType));
    if (career.coins < 1) {
        $("potential").textContent = "—";
        $("bet-line").textContent = "אין מטבעות. אפשר להרוויח במרוצי הקריירה.";
        return;
    }
    if (G.pick === null) {
        $("potential").textContent = "—";
        $("bet-line").textContent = "בחר סוס";
        return;
    }
    const h = G.betField[G.pick];
    const r = BET_RACES[G.betRaceIdx];
    const odds = G.betType === "win" ? h.odds : h.placeOdds;
    $("potential").textContent = Math.round(G.bet * odds * r.bonus);
    $("bet-line").textContent = `${G.bet} × ${odds.toFixed(1)}${r.bonus > 1 ? ` × ${r.bonus}` : ""}`;
}

// ---------- גביעים ----------
function renderTrophies() {
    const got = ACH.filter(a => career.ach[a.id]).length;
    $("ach-count").textContent = `${got} מתוך ${ACH.length} · ${career.trophies} גביעי עונה`;
    $("ach-grid").innerHTML = ACH.map(a => `
        <div class="ach ${career.ach[a.id] ? "got" : ""}">
            <span class="ach-icon">${a.icon}</span>
            <div><b>${a.name}</b><span>${a.desc}</span></div>
        </div>`).join("");
}

function renderStats() {
    $("trophy-count").textContent = career.trophies;
    $("coins").textContent = career.coins;
    $("career-stats").innerHTML = `
        <span>מרוצים <b>${career.races}</b></span>
        <span>ניצחונות <b>${career.wins}</b></span>
        <span>פודיומים <b>${career.podiums}</b></span>
        <span>הזכייה הגדולה <b>${career.biggest}</b></span>
        <span>הישגים <b>${ACH.filter(a => career.ach[a.id]).length}/${ACH.length}</b></span>`;
}

// ===================== מרוץ =====================
function startRace(mode) {
    SFX.init();
    if (mode === "bet") {
        const msg = $("paddock-msg");
        if (G.pick === null) { msg.textContent = "קודם בוחרים סוס."; return; }
        if (G.bet < 1 || G.bet > career.coins) { msg.textContent = "אין מספיק מטבעות להימור הזה."; return; }
        msg.textContent = "";
        G.mode = "bet";
        G.race = betRace();
        G.field = G.betField;
        setCoins(career.coins - G.bet);
        G.stake = { bet: G.bet, type: G.betType, odds: G.betType === "win" ? me().odds : me().placeOdds, bonus: G.race.bonus };
    } else {
        G.mode = "career";
        G.race = seasonRace();
        G.field = careerField();
        const bet = Math.min(G.selfBet, career.coins);
        if (bet) setCoins(career.coins - bet);
        G.stake = { bet, type: "win", odds: me().odds, bonus: 1 };
    }
    resetRunners();
    G.raceT = 0;
    G.lastPress = -1;
    G.lastSay = 0;
    G.myRank = 0;
    G.leaderPos = 0;
    G.endTimer = 0;
    G.newAch = [];
    show("countdown");
    const c = cond();
    say(`${G.race.name} · ${G.race.dist} מטר · ${c.icon} ${c.label}${G.race.hurdleAt.length ? ` · ${G.race.hurdleAt.length} משוכות` : ""}`);
    let n = 3;
    const tick = () => {
        if (n > 0) {
            big(String(n));
            SFX.beep(false);
            n--;
            setTimeout(tick, 800);
        } else {
            big("יצאו!");
            SFX.gun();
            G.gateOpen = true;
            G.screen = "race";
            say("והם יצאו לדרך!", 1);
            setTimeout(() => big(""), 700);
        }
    };
    setTimeout(tick, 600);
    $("stage").scrollIntoView({ behavior: "smooth", block: "nearest" });
}

function showResults() {
    if (G.screen === "results") return;
    G.field.filter(h => !h.finished).sort((a, b) => b.pos - a.pos).forEach(h => {
        h.finished = true;
        h.time = G.raceT + (G.race.dist - h.pos) / Math.max(h.v, 1);
        G.finishOrder.push(h);
    });
    // שני סוסים שחצו באותו פריים מסודרים לפי הזמן המדויק
    G.finishOrder.sort((a, b) => a.time - b.time).forEach((h, i) => { h.place = i + 1; });
    show("results");
    G.timeScale = 1;
    G.jumpReady = false;
    SFX.crowdLevel(0.04);

    const m = me();
    const s = G.stake;
    const lines = [];
    const hit = s.bet > 0 && (s.type === "win" ? m.place === 1 : m.place <= 3);
    const winnings = hit ? Math.round(s.bet * s.odds * s.bonus) : 0;
    let earned = winnings;
    if (s.bet) lines.push(hit ? [`ההימור הצליח: ${winnings} מטבעות`, "good"] : [`ההימור (${s.bet}) לא נכנס`, ""]);
    if (hit && s.type === "win" && s.odds >= 8) unlock("long");

    career.races++;
    if (m.place === 1) { career.wins++; unlock("first"); }
    if (m.place <= 3) career.podiums++;
    if (m.place === 1 && G.race.cond === "night") unlock("night");
    if (m.place === 1 && G.race.cond === "rain") unlock("rain");
    if (m.place === 1 && G.lastAtHalf) unlock("comeback");
    if (m.place === 1 && G.finishOrder[1].time - m.time < 0.1) unlock("photo");
    if (G.race.hurdleAt.length >= 4 && G.myClean === G.race.hurdleAt.length && G.myHits === 0) unlock("clean");
    career.biggest = Math.max(career.biggest, winnings);

    const bestKey = G.mode === "career" ? G.race.id : G.race.id + "-bet";
    const prevBest = career.best[bestKey];
    if (!prevBest || m.time < prevBest) {
        career.best[bestKey] = m.time;
        if (prevBest) lines.push([`שיא אישי חדש ב${G.race.name}: ${fmtTime(m.time)}`, "gold"]);
    }
    if (G.bestCombo >= 3) lines.push([`הרצף הכי ארוך: ${G.bestCombo} לחיצות מושלמות`, ""]);

    let nextLabel = "למרוץ הבא";
    if (G.mode === "career") {
        const prize = Math.round(PRIZE[m.place - 1] * G.race.prize);
        earned += prize;
        lines.unshift([`פרס כספי על מקום ${m.place}: ${prize} מטבעות`, "good"]);
        const mult = G.race.final ? 2 : 1;
        const pts = POINTS[m.place - 1] * mult;
        season.myPts += pts;
        G.field.forEach(h => {
            if (h.isMe) return;
            const rv = season.rivals.find(r => r.name === h.name);
            if (rv) rv.pts += POINTS[h.place - 1] * mult;
        });
        season.results[season.idx] = m.place;
        lines.push([`+${pts} נקודות לעונה${mult > 1 ? " (גמר כפול)" : ""}`, ""]);
        season.idx++;
        nextLabel = "חזרה לאורווה";
        if (season.idx >= SEASON.length) {
            const table = [{ name: myHorse.name, pts: season.myPts, me: true }, ...season.rivals].sort((a, b) => b.pts - a.pts);
            const rank = table.findIndex(r => r.me) + 1;
            if (rank === 1) {
                career.trophies++;
                earned += 300;
                unlock("champ");
                lines.unshift([`🏆 ${myHorse.name} אלוף עונה ${season.n}! בונוס 300 מטבעות`, "gold"]);
                burst(200);
            } else {
                lines.unshift([`העונה הסתיימה: ${myHorse.name} במקום ${rank} בטבלה`, "gold"]);
            }
            newSeason(season.n + 1);
            lines.push([`עונה ${season.n} מתחילה, והיריבים חזקים יותר`, ""]);
            nextLabel = "לעונה הבאה";
        }
        store.set("season", season);
    }
    setCoins(career.coins + earned);
    store.set("career", career);

    $("res-title").textContent = m.place === 1 ? `${m.name} ניצח!` : `${m.name} במקום ${m.place}`;
    const net = earned - s.bet;
    const money = $("res-money");
    money.textContent = (net >= 0 ? "+" : "−") + Math.abs(net) + " מטבעות";
    money.className = "res-money " + (net >= 0 ? "win" : "lose");

    const winT = G.finishOrder[0].time;
    $("res-body").innerHTML = G.finishOrder.map(h => `
        <tr class="${h.isMe ? "me" : ""}">
            <td class="place-num">${h.place}</td>
            <td><span class="res-horse"><span class="saddle" style="background:${h.silk}">${h.num}</span>${esc(h.name)}</span></td>
            <td>${fmtTime(h.time)}</td>
            <td>${h.place === 1 ? "—" : "+" + (h.time - winT).toFixed(2)}</td>
        </tr>`).join("");

    (G.newAch || []).forEach(a => lines.push([`${a.icon} הישג חדש: ${a.name}`, "gold"]));
    $("res-lines").innerHTML = lines.map(([t, c]) => `<li class="${c}">${esc(t)}</li>`).join("");

    if (m.place <= 3) { SFX.fanfare(); if (m.place !== 1) burst(50); } else SFX.sad();
    $("next").textContent = nextLabel;
    renderStats();
}

function afterResults() {
    if (G.mode === "bet") {
        newBetField();
        G.bet = Math.min(Math.max(G.bet, 10), career.coins);
        setTab("bet");
    } else {
        setTab("career");
    }
}

// ===================== חיבור אירועים =====================
$("start").addEventListener("click", () => startRace("bet"));
$("career-go").addEventListener("click", () => startRace("career"));
$("next").addEventListener("click", afterResults);
$("create-go").addEventListener("click", saveHorse);
$("horse-name").addEventListener("input", e => { if (G.draft) G.draft.name = e.target.value; });
$("horse-name").addEventListener("keydown", e => { if (e.key === "Enter") saveHorse(); });
$("edit-horse").addEventListener("click", () => { G.editing = true; G.draft = null; setTab("career"); });
$("boost").addEventListener("pointerdown", e => { e.preventDefault(); press(); });
$("jump").addEventListener("pointerdown", e => { e.preventDefault(); jump(); });
$("stage").addEventListener("pointerdown", () => { if (G.screen === "race") press(); });
document.addEventListener("keydown", e => {
    if (G.screen !== "race" && G.screen !== "countdown") return;
    if (e.code === "Space" || e.code === "Enter") {
        e.preventDefault();
        if (!e.repeat) press();
    } else if (e.code === "ArrowUp" || e.code === "KeyW") {
        e.preventDefault();
        if (!e.repeat) jump();
    }
});
document.querySelectorAll("#modes button").forEach(b => b.addEventListener("click", () => {
    SFX.init();
    G.editing = false;
    setTab(b.dataset.mode);
}));
document.querySelectorAll("#chips button").forEach(b => b.addEventListener("click", () => {
    G.bet = b.dataset.v === "all" ? career.coins : +b.dataset.v;
    renderBet();
}));
document.querySelectorAll("#self-chips button").forEach(b => b.addEventListener("click", () => {
    G.selfBet = +b.dataset.v;
    renderCareer();
}));
document.querySelectorAll("#bet-type button").forEach(b => b.addEventListener("click", () => {
    G.betType = b.dataset.type;
    renderBet();
}));
$("mute").addEventListener("click", () => {
    SFX.init();
    SFX.toggle();
    $("mute").textContent = SFX.muted ? "🔇" : "🔊";
});
$("mute").textContent = SFX.muted ? "🔇" : "🔊";

// ===================== לולאה =====================
let last = performance.now();
function loop(now) {
    const raw = Math.min(0.05, (now - last) / 1000);
    last = now;
    step(raw * G.timeScale);
    render();
    if (!$("create").hidden) renderPreview($("preview-create"), G.draft);
    if (!$("career").hidden) renderPreview($("preview-stable"), myHorse);
    requestAnimationFrame(loop);
}

if (myHorse && !season) newSeason(1);
resize();
newBetField();
renderStats();
setTab(myHorse ? "career" : "career");
requestAnimationFrame(loop);
