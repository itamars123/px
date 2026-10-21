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
];

const RACES = [
    { id: "sprint", name: "ספרינט", dist: 400, bonus: 1 },
    { id: "classic", name: "קלאסי", dist: 700, bonus: 1.15 },
    { id: "cup", name: "גביע הזהב", dist: 1000, bonus: 1.35 },
];

// קצב יחסי למהירות המרבית לפי התקדמות במרוץ (0..1)
const STRATS = {
    front: { label: "פותח מהר", pace: p => (p < 0.6 ? 0.98 : 0.98 - (p - 0.6) * 0.25) },
    even: { label: "קצב אחיד", pace: () => 0.945 },
    closer: { label: "מסיים חזק", pace: p => (p < 0.65 ? 0.89 : 0.89 + (p - 0.65) * 0.55) },
};
const AVG_PACE = { front: 0.96, even: 0.945, closer: 0.924 };

const FIELD_SIZE = 6;
const TAU = Math.PI * 2;
const ZONE = [0.74, 0.96]; // חלון הלחיצה המושלמת במחזור הצעד

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

const career = store.get("career", { coins: 100, races: 0, wins: 0, podiums: 0, best: {}, biggest: 0 });

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

// ===================== מצב המשחק =====================
const G = {
    screen: "paddock", // paddock | countdown | race | results
    race: RACES[store.get("race", 1)] || RACES[1],
    field: [],
    pick: null,
    bet: 25,
    betType: "win",
    t: 0,
    raceT: 0,
    cam: 0,
    timeScale: 1,
    gateOpen: false,
    power: 100,
    combo: 0,
    lastPress: -1,
    leader: null,
    myRank: 0,
    finishOrder: [],
    endTimer: 0,
    calls: {},
    flashDone: false,
    leaderPos: 0,
    lastSay: 0,
};

let dust = [];
let confetti = [];
let floaters = [];

function newField() {
    const pool = shuffle(STABLE.slice()).slice(0, FIELD_SIZE);
    const strats = Object.keys(STRATS);
    G.field = pool.map((s, i) => {
        const top = 15.6 + Math.random() * 2.4;
        const stamina = Math.random();
        const accel = 1.5 + Math.random() * 1.5;
        const strat = strats[Math.floor(Math.random() * strats.length)];
        return {
            ...s, num: i + 1, lane: i, top, stamina, accel, strat,
            rating: top * AVG_PACE[strat] * (1 - (1 - stamina) * 0.02) + accel * 0.05,
        };
    });
    // יחסי זכייה מתוך דירוג הסוסים
    const max = Math.max(...G.field.map(h => h.rating));
    const w = G.field.map(h => Math.exp(1.15 * (h.rating - max)));
    const sum = w.reduce((a, b) => a + b, 0);
    G.field.forEach((h, i) => {
        const p = w[i] / sum;
        h.odds = clamp(Math.round((0.88 / p) * 10) / 10, 1.4, 18);
        h.placeOdds = Math.max(1.15, Math.round((h.odds / 3 + 0.2) * 10) / 10);
        h.form = Array.from({ length: 5 }, () => clamp(Math.round(1 + Math.random() * 5 * (1 - p * 1.6)), 1, 6)).join("-");
    });
    G.pick = null;
    resetRunners();
}

function resetRunners() {
    G.field.forEach(h => {
        Object.assign(h, {
            pos: 0, v: 0, phase: Math.random() * TAU, burst: 0, noise: 0, noiseTarget: 0,
            noiseT: 0, finished: false, time: 0, whip: 0, place: 0, stumble: 0,
        });
    });
    G.cam = 0;
    G.gateOpen = false;
    G.power = 100;
    G.combo = 0;
    G.finishOrder = [];
    G.calls = {};
    G.leader = null;
    G.flashDone = false;
    G.timeScale = 1;
    dust = []; confetti = []; floaters = [];
}

const me = () => G.field[G.pick];

// ===================== קנבס =====================
const canvas = $("scene");
const ctx = canvas.getContext("2d");
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
    const g = ctx.createLinearGradient(0, 0, 0, H * 0.45);
    g.addColorStop(0, "#27416e");
    g.addColorStop(0.55, "#c9786a");
    g.addColorStop(1, "#f5c27a");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H * 0.46);
    // שמש שוקעת
    const sx = W * 0.2 + G.cam * PPM * 0.01, sy = H * 0.3;
    const sg = ctx.createRadialGradient(sx, sy, 4, sx, sy, H * 0.22);
    sg.addColorStop(0, "rgba(255,240,200,1)");
    sg.addColorStop(0.2, "rgba(255,214,140,.8)");
    sg.addColorStop(1, "rgba(255,200,120,0)");
    ctx.fillStyle = sg;
    ctx.fillRect(0, 0, W, H * 0.46);
    // עננים
    tiles(0.04, 320, (x, n) => {
        if (hash(n) < 0.4) return;
        const y = H * (0.06 + hash(n * 3) * 0.14);
        ctx.fillStyle = "rgba(255,225,200,.35)";
        for (let k = 0; k < 4; k++) {
            ctx.beginPath();
            ctx.ellipse(x + k * 22 - 30, y + Math.sin(k * 2 + n) * 4, 30, 9, 0, 0, TAU);
            ctx.fill();
        }
    });
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

function drawGrandstand() {
    const top = H * 0.235, bot = H * 0.425;
    const P = 240;
    const excite = G.screen === "race" ? clamp(G.leaderPos / G.race.dist, 0, 1) : 0.1;
    tiles(0.5, P, (x, n) => {
        if (n % 6 === 3) { // מרווח עם דגלים בין היציעים
            ctx.fillStyle = "#e9dcc0";
            for (let k = 0; k < 3; k++) {
                const fx = x - 50 - k * 70;
                ctx.fillRect(fx, top - 6, 2, bot - top + 6);
                ctx.fillStyle = ["#d62828", "#e2b54d", "#1d4ed8"][k];
                const wave = Math.sin(G.t * 4 + k) * 3;
                ctx.beginPath();
                ctx.moveTo(fx, top - 6);
                ctx.lineTo(fx - 18, top + wave);
                ctx.lineTo(fx, top + 8);
                ctx.fill();
                ctx.fillStyle = "#e9dcc0";
            }
            return;
        }
        const x0 = x - P, w = P;
        // מבנה
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
            }
        }
        // עמודים
        ctx.fillStyle = "#cdbf9f";
        ctx.fillRect(x0, top, 4, bot - top);
    });
}

function drawTrack() {
    const turfTop = H * 0.425, railY = H * 0.455, trackTop = H * 0.47, trackBot = H * 0.955;
    // דשא
    ctx.fillStyle = "#3d7a3a";
    ctx.fillRect(0, turfTop, W, trackTop - turfTop);
    // מסלול חול
    const g = ctx.createLinearGradient(0, trackTop, 0, trackBot);
    g.addColorStop(0, "#a8754a");
    g.addColorStop(1, "#c48a57");
    ctx.fillStyle = g;
    ctx.fillRect(0, trackTop, W, trackBot - trackTop);
    // פסי מגרפה
    tiles(1, PPM * 6, (x, n) => {
        ctx.fillStyle = n % 2 ? "rgba(0,0,0,.035)" : "rgba(255,255,255,.03)";
        ctx.fillRect(x - PPM * 6, trackTop, PPM * 6, trackBot - trackTop);
    });
    // קווי מסלולים עדינים
    ctx.strokeStyle = "rgba(255,255,255,.07)";
    ctx.lineWidth = 1;
    for (let i = 0; i < FIELD_SIZE; i++) {
        const y = laneY(i) + 6;
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(W, y); ctx.stroke();
    }
    // מעקה עליון
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
    for (let m = 0; m <= L; m += 100) {
        const x = worldX(m);
        if (x < -40 || x > W + 40) continue;
        const left = L - m;
        if (m === L) continue;
        const red = left === 200 || left === 100;
        ctx.fillStyle = red ? "#d62828" : "#f4f1ea";
        ctx.fillRect(x - 2, railY - H * 0.07, 4, H * 0.07);
        ctx.fillStyle = red ? "#d62828" : "#1b3627";
        ctx.fillRect(x - 22, railY - H * 0.11, 44, H * 0.045);
        ctx.fillStyle = "#fff";
        ctx.font = `700 ${Math.round(H * 0.03)}px Heebo, sans-serif`;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText(left + "", x, railY - H * 0.088);
    }
}

function drawFinish(front) {
    const x = worldX(G.race.dist);
    if (x < -60 || x > W + 60) return;
    const trackTop = H * 0.47, trackBot = H * 0.955, railY = H * 0.455;
    if (!front) {
        // קו סיום משובץ
        const sq = 6;
        for (let y = trackTop, k = 0; y < trackBot; y += sq, k++) {
            ctx.fillStyle = k % 2 ? "#111" : "#fff";
            ctx.fillRect(x - sq, y, sq, sq);
            ctx.fillStyle = k % 2 ? "#fff" : "#111";
            ctx.fillRect(x, y, sq, sq);
        }
        // עמוד הסיום והשלט
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

function drawHorse(h, x, y, s, isMe) {
    const run = clamp(h.v / 8, 0, 1);
    const amp = 0.25 + run * 0.75;
    const ph = h.phase;
    const bob = -Math.abs(Math.sin(ph)) * 3.5 * run - (1 - run) * Math.sin(G.t * 2 + h.num) * 0.6;
    const dark = shade(h.coat, -0.35);
    const light = shade(h.coat, 0.18);

    ctx.save();
    ctx.translate(x, y);
    // צל
    ctx.fillStyle = "rgba(40,20,5,.28)";
    ctx.beginPath(); ctx.ellipse(0, 0, 44 * s, 6 * s, 0, 0, TAU); ctx.fill();
    ctx.scale(-s, s); // הסוס פונה שמאלה, לכיוון הסיום
    ctx.translate(0, bob);

    // רגליים רחוקות
    leg(-24, -44, ph + Math.PI * 0.85, amp, dark, 8, true);
    leg(22, -44, ph + 0.35, amp, dark, 7, false);

    // זנב
    const tw = Math.sin(ph * 1) * 6 * run;
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
    // ברק על הגב
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
    // אוזן
    ctx.fillStyle = dark;
    ctx.beginPath();
    ctx.moveTo(43, -88 + nod); ctx.lineTo(41, -98 + nod); ctx.lineTo(48, -90 + nod);
    ctx.fill();
    // רעמה
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

    // רגליים קרובות
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
    // יד ומושכות או שוט
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
    // ראש וכובע
    ctx.fillStyle = "#e9b48a";
    ctx.beginPath(); ctx.arc(21, -88 + jb, 6.5, 0, TAU); ctx.fill();
    ctx.fillStyle = h.cap;
    ctx.beginPath(); ctx.arc(21, -89 + jb, 7, Math.PI * 1.02, Math.PI * 2.05); ctx.fill();
    ctx.fillRect(24, -90 + jb, 8, 2.5);
    ctx.restore();

    if (isMe) {
        // סמן לשחקן
        const my = y - 112 * s + Math.sin(G.t * 5) * 3;
        ctx.fillStyle = "#e2b54d";
        ctx.beginPath();
        ctx.moveTo(x, my + 10); ctx.lineTo(x - 8, my); ctx.lineTo(x + 8, my);
        ctx.fill();
        ctx.font = `900 ${Math.round(13 * Math.max(s, 0.8))}px Heebo, sans-serif`;
        ctx.textAlign = "center"; ctx.textBaseline = "bottom";
        ctx.lineWidth = 3; ctx.strokeStyle = "rgba(0,0,0,.6)";
        ctx.strokeText("הסוס שלך", x, my - 2);
        ctx.fillText("הסוס שלך", x, my - 2);
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
    // פרחים בקדמת התמונה
    tiles(1.25, 34, (x, n) => {
        if (hash(n * 5) < 0.5) return;
        ctx.fillStyle = ["#e2b54d", "#ef5a5f", "#f3ead6"][n % 3];
        ctx.beginPath(); ctx.arc(x, y + 6 + hash(n) * 6, 3, 0, TAU); ctx.fill();
    });
}

function drawMinimap() {
    if (G.screen === "paddock") return;
    const x0 = W - 24, x1 = 24, y = 16;
    const L = G.race.dist;
    ctx.fillStyle = "rgba(10,22,15,.6)";
    ctx.fillRect(0, 0, W, 30);
    ctx.strokeStyle = "rgba(243,234,214,.4)";
    ctx.lineWidth = 3;
    ctx.beginPath(); ctx.moveTo(x0, y); ctx.lineTo(x1, y); ctx.stroke();
    ctx.fillStyle = "#e2b54d";
    ctx.fillRect(x1 - 2, y - 8, 4, 16);
    const sorted = G.field.slice().sort((a, b) => a.pos - b.pos);
    sorted.forEach(h => {
        const x = x0 + (x1 - x0) * clamp(h.pos / L, 0, 1);
        const mine = h === me();
        ctx.fillStyle = h.silk;
        ctx.beginPath(); ctx.arc(x, y, mine ? 7 : 5, 0, TAU); ctx.fill();
        if (mine) {
            ctx.strokeStyle = "#e2b54d"; ctx.lineWidth = 2.5;
            ctx.stroke();
        }
    });
}

function drawParticles() {
    dust.forEach(p => {
        ctx.fillStyle = `rgba(214,170,120,${p.life * 0.5})`;
        ctx.beginPath(); ctx.arc(worldX(p.m), p.y, p.r * (1.6 - p.life), 0, TAU); ctx.fill();
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
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    ctx.clearRect(0, 0, W, H);
    drawSky();
    drawHills();
    drawGrandstand();
    drawTrack();
    drawMarkers();
    drawFinish(false);
    drawParticles();
    // מהשורה האחורית לקדמית
    for (let i = 0; i < FIELD_SIZE; i++) {
        const h = G.field.find(f => f.lane === i);
        if (!h) continue;
        // המיקום במרוץ נמדד לפי האף, לכן מרכז הגוף מוזז אחורה
        drawHorse(h, worldX(h.pos) + 52 * laneScale(i), laneY(i), laneScale(i), h === me());
    }
    drawGate();
    drawFinish(true);
    drawFrontRail();
    drawMinimap();
    drawOverlayFx();
}

// ===================== סימולציה =====================
function speedTarget(h) {
    const p = clamp(h.pos / G.race.dist, 0, 1);
    const late = p > 0.7 ? 1 - (1 - h.stamina) * 0.07 * ((p - 0.7) / 0.3) : 1;
    if (h === me()) {
        return h.top * 0.9 * late + h.burst - h.stumble;
    }
    return h.top * STRATS[h.strat].pace(p) * late + h.noise;
}

function step(dt) {
    G.t += dt;
    const racing = G.screen !== "paddock" && G.gateOpen;

    if (G.screen === "race") G.raceT += dt;

    G.field.forEach(h => {
        if (racing) {
            if (h !== me()) {
                h.noiseT -= dt;
                if (h.noiseT <= 0) {
                    h.noiseT = 1.2 + Math.random() * 2;
                    const lateKick = h.pos / G.race.dist > 0.75 && Math.random() < 0.35 ? 0.9 : 0;
                    h.noiseTarget = (Math.random() - 0.5) * 1.3 + lateKick;
                }
                h.noise += (h.noiseTarget - h.noise) * Math.min(1, dt * 0.9);
            }
            const target = h.finished ? Math.max(4, h.v * 0.985) : speedTarget(h);
            h.v += (target - h.v) * Math.min(1, dt * h.accel * 0.45);
            h.pos += h.v * dt;
            h.burst *= Math.exp(-1.1 * dt);
            h.stumble = Math.max(0, h.stumble - dt * 2);
            h.whip = Math.max(0, h.whip - dt * 3);
            if (!h.finished && h.pos >= G.race.dist) {
                h.finished = true;
                // זמן מדויק לפי אינטרפולציה של חציית הקו
                h.time = G.raceT - (h.pos - G.race.dist) / Math.max(h.v, 0.1);
                G.finishOrder.push(h);
                h.place = G.finishOrder.length;
                onFinish(h);
            }
            // אבק מהפרסות
            if (h.v > 6 && Math.random() < dt * h.v * 0.9) {
                dust.push({ m: h.pos - (52 * laneScale(h.lane)) / PPM + Math.random() - 0.5, y: laneY(h.lane) - 2, r: 3 + Math.random() * 4 * laneScale(h.lane), life: 1 });
            }
        }
        const prevFrac = (h.phase % TAU) / TAU;
        h.phase += dt * (2.2 + h.v * 0.45);
        if (h === me() && racing && G.screen === "race") {
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

    if (G.pick !== null && G.screen !== "paddock") {
        const m = me();
        const target = m.pos;
        G.cam += (target - G.cam) * Math.min(1, dt * 3.5);
    } else if (G.screen === "paddock") {
        G.cam += (0 - G.cam) * Math.min(1, dt * 2);
    }

    if (G.screen === "race") {
        G.power = Math.min(100, G.power + dt * 7);
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
    G.leaderPos = leader.pos;
    const myRank = order.indexOf(me()) + 1;

    // פרשנות
    if (G.leader && leader !== G.leader && !leader.finished && G.raceT > 3 && G.raceT - G.lastSay > 1.5) {
        say(leader === me() ? `${leader.name} שלך עולה לראשות!` : `${leader.name} עוקף ועולה לראשות!`);
    }
    G.leader = leader;
    if (G.myRank && myRank < G.myRank && myRank > 1 && !me().finished && G.raceT > 4 && G.raceT - G.lastSay > 1.5) {
        say(`${me().name} מתקדם למקום ${myRank}!`, 1.6);
    }
    G.myRank = myRank;

    const left = L - leader.pos;
    if (left < L / 2 && !G.calls.half) { G.calls.half = 1; say(`חצי מרוץ! ${leader.name} בראש, ${order[1].name} צמוד`); }
    if (left < 200 && !G.calls.c200) { G.calls.c200 = 1; say("200 מטר לסיום!"); }
    if (left < 100 && !G.calls.c100) { G.calls.c100 = 1; say("ישורת אחרונה! הקהל על הרגליים!"); }
    if (G.raceT - (G.lastSay || 0) > 4.5 && !leader.finished) {
        const gap = order[0].pos - order[1].pos;
        say(gap < 1.5 ? `${order[0].name} ו${order[1].name} ראש בראש!` : `${leader.name} מוביל בפער של ${gap.toFixed(1)} מטר`);
    }

    // הילוך איטי בסיום צמוד
    const close = !leader.finished && left < 14 && order[0].pos - order[1].pos < 1.4;
    G.timeScale += ((close ? 0.35 : 1) - G.timeScale) * Math.min(1, dt * 6);
    if (close && !G.calls.photo) { G.calls.photo = 1; say("צמוד! צמוד מאוד! צילום פוטו פיניש!"); }

    SFX.crowdLevel(0.02 + clamp(leader.pos / L, 0, 1) ** 2 * 0.2);

    // HUD
    $("hud-rank").textContent = `${myRank}/${FIELD_SIZE}`;
    $("hud-left").textContent = me().finished ? "סיים" : `${Math.max(0, Math.ceil(L - me().pos))} מ'`;
    $("hud-speed").textContent = `${Math.round(me().v * 3.6)} קמ"ש`;
    const pw = $("power");
    pw.style.width = G.power + "%";
    pw.classList.toggle("low", G.power < 15);
    $("power-num").textContent = Math.round(G.power);
    const frac = (me().phase % TAU) / TAU;
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
    if (h === me()) {
        G.endTimer = 3.5;
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
    const perfect = frac >= ZONE[0] && frac <= ZONE[1];
    h.whip = 1;
    if (perfect) {
        G.combo++;
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

// ===================== מסכים =====================
function setCoins(v) {
    career.coins = Math.max(0, Math.round(v));
    const el = $("coins");
    el.textContent = career.coins;
    el.classList.remove("bump"); void el.offsetWidth; el.classList.add("bump");
    store.set("career", career);
}

function show(screen) {
    G.screen = screen;
    $("paddock").hidden = screen !== "paddock";
    $("ride").hidden = screen !== "countdown" && screen !== "race";
    $("results").hidden = screen !== "results";
    $("hud").hidden = screen === "paddock";
    $("ticker").hidden = screen === "paddock";
}

function renderTabs() {
    const tabs = $("race-tabs");
    tabs.innerHTML = "";
    RACES.forEach((r, i) => {
        const b = document.createElement("button");
        b.type = "button";
        b.className = "tab" + (r === G.race ? " on" : "");
        b.setAttribute("role", "tab");
        b.innerHTML = `${r.name}<small>${r.dist} מ'${r.bonus > 1 ? ` · בונוס x${r.bonus}` : ""}</small>`;
        b.addEventListener("click", () => { G.race = r; store.set("race", i); renderTabs(); renderBet(); });
        tabs.appendChild(b);
    });
}

function renderCards() {
    const wrap = $("cards");
    wrap.innerHTML = "";
    G.field.forEach((h, i) => {
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
            <div class="stat">מהירות ${bar((h.top - 15.6) / 2.4)}</div>
            <div class="stat">סיבולת ${bar(h.stamina)}</div>
            <div class="stat">תאוצה ${bar((h.accel - 1.5) / 1.5)}</div>
            <div class="form">כושר: ${h.form}</div>`;
        c.addEventListener("click", () => {
            SFX.init();
            G.pick = i;
            renderCards();
            renderBet();
            $("paddock-msg").textContent = "";
            SFX.tone(520, 0.08, "triangle", 0.12);
        });
        wrap.appendChild(c);
    });
}

function renderBet() {
    document.querySelectorAll("#chips button").forEach(b => {
        const v = b.dataset.v === "all" ? career.coins : +b.dataset.v;
        b.disabled = v > career.coins || v <= 0;
        b.classList.toggle("on", b.dataset.v === "all" ? G.bet === career.coins && ![10, 25, 50, 100].includes(G.bet) : +b.dataset.v === G.bet);
    });
    document.querySelectorAll("#bet-type button").forEach(b => b.classList.toggle("on", b.dataset.type === G.betType));
    G.bet = Math.min(G.bet, career.coins);
    if (G.pick === null) {
        $("potential").textContent = "—";
        $("bet-line").textContent = "בחר סוס";
        return;
    }
    const h = G.field[G.pick];
    const odds = G.betType === "win" ? h.odds : h.placeOdds;
    $("potential").textContent = Math.round(G.bet * odds * G.race.bonus);
    $("bet-line").textContent = `${G.bet} × ${odds.toFixed(1)}${G.race.bonus > 1 ? ` × ${G.race.bonus}` : ""}`;
}

function renderCareer() {
    const best = career.best[G.race.id];
    $("career").innerHTML = `
        <span>מרוצים <b>${career.races}</b></span>
        <span>ניצחונות <b>${career.wins}</b></span>
        <span>פודיומים <b>${career.podiums}</b></span>
        <span>הזכייה הגדולה <b>${career.biggest}</b></span>
        <span>שיא ב${G.race.name} <b>${best ? fmtTime(best) : "—"}</b></span>`;
}

function startRace() {
    SFX.init();
    const msg = $("paddock-msg");
    if (G.pick === null) { msg.textContent = "קודם בוחרים סוס."; return; }
    if (G.bet < 1 || G.bet > career.coins) { msg.textContent = "אין מספיק מטבעות להימור הזה."; return; }
    msg.textContent = "";
    setCoins(career.coins - G.bet);
    resetRunners();
    G.stake = { bet: G.bet, type: G.betType, odds: G.betType === "win" ? me().odds : me().placeOdds, bonus: G.race.bonus };
    G.raceT = 0;
    G.lastPress = -1;
    G.lastSay = 0;
    G.myRank = 0;
    G.leaderPos = 0;
    G.endTimer = 0;
    show("countdown");
    say(`${G.race.name} ל-${G.race.dist} מטר. הסוסים בשער...`);
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
    // סוסים שעוד לא סיימו מקבלים זמן משוער
    G.field.filter(h => !h.finished).sort((a, b) => b.pos - a.pos).forEach(h => {
        h.finished = true;
        h.time = G.raceT + (G.race.dist - h.pos) / Math.max(h.v, 1);
        G.finishOrder.push(h);
        h.place = G.finishOrder.length;
    });
    // שני סוסים שחצו באותו פריים מסודרים לפי הזמן המדויק
    G.finishOrder.sort((a, b) => a.time - b.time).forEach((h, i) => { h.place = i + 1; });
    show("results");
    G.timeScale = 1;
    SFX.crowdLevel(0.04);

    const m = me();
    const s = G.stake;
    const hit = s.type === "win" ? m.place === 1 : m.place <= 3;
    const winnings = hit ? Math.round(s.bet * s.odds * s.bonus) : 0;
    const prize = [0, 20, 10, 5][m.place] || 0;
    setCoins(career.coins + winnings + prize);

    career.races++;
    if (m.place === 1) career.wins++;
    if (m.place <= 3) career.podiums++;
    career.biggest = Math.max(career.biggest, winnings);
    const prevBest = career.best[G.race.id];
    const record = !prevBest || m.time < prevBest;
    if (record) career.best[G.race.id] = m.time;
    store.set("career", career);

    $("res-title").textContent = m.place === 1 ? `${m.name} ניצח!` : `${m.name} במקום ${m.place}`;
    const net = winnings + prize - s.bet;
    const money = $("res-money");
    money.textContent = (net >= 0 ? "+" : "−") + Math.abs(net) + " מטבעות";
    money.className = "res-money " + (net >= 0 ? "win" : "lose");

    const winT = G.finishOrder[0].time;
    $("res-body").innerHTML = G.finishOrder.map(h => `
        <tr class="${h === m ? "me" : ""}">
            <td class="place-num">${h.place}</td>
            <td><span class="res-horse"><span class="saddle" style="background:${h.silk}">${h.num}</span>${h.name}</span></td>
            <td>${fmtTime(h.time)}</td>
            <td>${h.place === 1 ? "—" : "+" + (h.time - winT).toFixed(2)}</td>
        </tr>`).join("");

    const parts = [];
    parts.push(hit ? `ההימור (${s.type === "win" ? "ניצחון" : "מקום"}) הצליח: ${winnings} מטבעות` : `ההימור (${s.type === "win" ? "ניצחון" : "מקום"}) לא נכנס`);
    if (prize) parts.push(`פרס מקום: ${prize}`);
    if (record && prevBest) parts.push(`שיא אישי חדש ב${G.race.name}!`);
    $("res-stats").textContent = parts.join(" · ");

    if (hit) { SFX.fanfare(); if (m.place !== 1) burst(60); } else SFX.sad();

    const next = $("next");
    if (career.coins < 1) {
        next.textContent = "הדוד מהמושב שולח 100 מטבעות";
        next.dataset.loan = "1";
    } else {
        next.textContent = "למרוץ הבא";
        delete next.dataset.loan;
    }
    renderCareer();
}

function toPaddock() {
    const next = $("next");
    if (next.dataset.loan) setCoins(100);
    newField();
    G.bet = Math.min(Math.max(G.bet, 10), career.coins);
    show("paddock");
    renderCards();
    renderBet();
    renderCareer();
}

// ===================== חיבור אירועים =====================
$("start").addEventListener("click", startRace);
$("next").addEventListener("click", toPaddock);
$("boost").addEventListener("pointerdown", e => { e.preventDefault(); press(); });
$("stage").addEventListener("pointerdown", () => { if (G.screen === "race") press(); });
document.addEventListener("keydown", e => {
    if (e.code !== "Space" && e.code !== "Enter") return;
    if (G.screen === "race" || G.screen === "countdown") {
        e.preventDefault();
        if (!e.repeat) press();
    }
});
document.querySelectorAll("#chips button").forEach(b => b.addEventListener("click", () => {
    G.bet = b.dataset.v === "all" ? career.coins : +b.dataset.v;
    renderBet();
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
    requestAnimationFrame(loop);
}

if (career.coins < 1) setCoins(100);
$("coins").textContent = career.coins;
resize();
newField();
show("paddock");
renderTabs();
renderCards();
renderBet();
renderCareer();
requestAnimationFrame(loop);
