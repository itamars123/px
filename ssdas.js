// ===== נחש את המילה – Hebrew 4-letter word guessing game =====

const WORD_LENGTH = 4;
const MAX_GUESSES = 6;

// Secret words (4 Hebrew letters each, written with final forms).
const WORDS = [
    "שלום", "חלון", "חתול", "כדור", "מחשב", "מטבח", "ארון", "כוכב",
    "חורף", "סתיו", "אביב", "מיטה", "כיסא", "שעון", "מפתח", "עוגה",
    "ביצה", "תירס", "בננה", "שזיף", "ארנב", "אריה", "זברה", "כבשה",
    "עכבר", "יונה", "כריש", "חזיר", "רכבת", "מטוס", "שמחה", "אהבה",
    "חברה", "סבתא", "דודה", "ילדה", "מורה", "כיתה", "מבחן", "שירה",
    "ציור", "אדום", "כחול", "ירוק", "צהוב", "שחור", "סגול", "כתום",
    "עולם", "אדמה", "הרים", "מדבר", "גינה", "מלכה", "נסיך", "טירה",
    "תפוח", "חלום", "שוקו", "פיצה", "סוכר", "מלון", "ספרה", "מגדל",
    "שמלה", "כובע", "מעיל", "תנור", "כפית", "צלחת", "מגבת", "סבון",
    "מראה", "שכנה",
];

// Hebrew final letters <-> regular forms.
const TO_REGULAR = { "ך": "כ", "ם": "מ", "ן": "נ", "ף": "פ", "ץ": "צ" };
const TO_FINAL = { "כ": "ך", "מ": "ם", "נ": "ן", "פ": "ף", "צ": "ץ" };

// Standard Israeli keyboard layout, so players with an English layout can still type.
const EN_TO_HE = {
    e: "ק", r: "ר", t: "א", y: "ט", u: "ו", i: "ן", o: "ם", p: "פ",
    a: "ש", s: "ד", d: "ג", f: "כ", g: "ע", h: "י", j: "ח", k: "ל", l: "ך", ";": "ף",
    z: "ז", x: "ס", c: "ב", v: "ה", b: "נ", n: "מ", m: "צ", ",": "ת", ".": "ץ",
};

const KEY_ROWS = [
    ["ק", "ר", "א", "ט", "ו", "פ"],
    ["ש", "ד", "ג", "כ", "ע", "י", "ח", "ל"],
    ["ENTER", "ז", "ס", "ב", "ה", "נ", "מ", "צ", "ת", "BACK"],
];

const STATUS_RANK = { absent: 1, present: 2, correct: 3 };

const boardEl = document.getElementById("board");
const keyboardEl = document.getElementById("keyboard");
const messageEl = document.getElementById("message");
const newGameBtn = document.getElementById("new-game");

let secret = "";
let guesses = [];      // submitted guesses (regular-form letters)
let current = [];      // letters being typed (regular forms)
let gameOver = false;
let revealing = false;
const keyStatus = {};  // letter -> best known status

// ---------- Helpers ----------

const toRegular = ch => TO_REGULAR[ch] || ch;
const normalize = word => [...word].map(toRegular);

// Show a letter in its final form when it is the last letter of the word.
function displayLetter(ch, index, length) {
    return index === length - 1 && index === WORD_LENGTH - 1 ? (TO_FINAL[ch] || ch) : ch;
}

function scoreGuess(guess, answer) {
    const result = Array(WORD_LENGTH).fill("absent");
    const remaining = {};

    // First pass: exact matches.
    for (let i = 0; i < WORD_LENGTH; i++) {
        if (guess[i] === answer[i]) {
            result[i] = "correct";
        } else {
            remaining[answer[i]] = (remaining[answer[i]] || 0) + 1;
        }
    }
    // Second pass: right letter, wrong place (respecting duplicate counts).
    for (let i = 0; i < WORD_LENGTH; i++) {
        if (result[i] !== "correct" && remaining[guess[i]] > 0) {
            result[i] = "present";
            remaining[guess[i]]--;
        }
    }
    return result;
}

let messageTimer;
function showMessage(text, sticky = false) {
    clearTimeout(messageTimer);
    messageEl.textContent = text;
    messageEl.classList.add("show");
    if (!sticky) {
        messageTimer = setTimeout(() => {
            messageEl.textContent = "";
            messageEl.classList.remove("show");
        }, 1800);
    }
}

function clearMessage() {
    clearTimeout(messageTimer);
    messageEl.textContent = "";
    messageEl.classList.remove("show");
}

// ---------- Storage (stats) ----------

const STATS_KEY = "hebrew-word-game-stats";

function loadStats() {
    const empty = { played: 0, wins: 0, streak: 0, best: 0, dist: [0, 0, 0, 0, 0, 0] };
    try {
        return { ...empty, ...JSON.parse(localStorage.getItem(STATS_KEY)) };
    } catch {
        return empty;
    }
}

function saveStats(stats) {
    try {
        localStorage.setItem(STATS_KEY, JSON.stringify(stats));
    } catch {
        /* storage unavailable – stats just won't persist */
    }
}

function recordResult(won, guessCount) {
    const stats = loadStats();
    stats.played++;
    if (won) {
        stats.wins++;
        stats.streak++;
        stats.best = Math.max(stats.best, stats.streak);
        stats.dist[guessCount - 1]++;
    } else {
        stats.streak = 0;
    }
    saveStats(stats);
    return stats;
}

function renderStats(highlightRow = -1) {
    const stats = loadStats();
    document.getElementById("stat-played").textContent = stats.played;
    document.getElementById("stat-winpct").textContent =
        stats.played ? Math.round((stats.wins / stats.played) * 100) : 0;
    document.getElementById("stat-streak").textContent = stats.streak;
    document.getElementById("stat-best").textContent = stats.best;

    const max = Math.max(1, ...stats.dist);
    const dist = document.getElementById("distribution");
    dist.innerHTML = "";
    stats.dist.forEach((count, i) => {
        const row = document.createElement("div");
        row.className = "dist-row";
        const bar = document.createElement("div");
        bar.className = "dist-bar" + (i === highlightRow ? " current" : "");
        bar.style.width = `${Math.max(8, (count / max) * 100)}%`;
        bar.textContent = count;
        row.append(String(i + 1), bar);
        dist.appendChild(row);
    });
}

// ---------- Rendering ----------

function buildBoard() {
    boardEl.innerHTML = "";
    for (let r = 0; r < MAX_GUESSES; r++) {
        const row = document.createElement("div");
        row.className = "row";
        for (let c = 0; c < WORD_LENGTH; c++) {
            const tile = document.createElement("div");
            tile.className = "letter";
            row.appendChild(tile);
        }
        boardEl.appendChild(row);
    }
}

function buildKeyboard() {
    keyboardEl.innerHTML = "";
    KEY_ROWS.forEach(keys => {
        const row = document.createElement("div");
        row.className = "key-row";
        keys.forEach(k => {
            const btn = document.createElement("button");
            btn.className = "key";
            btn.dataset.key = k;
            if (k === "ENTER") {
                btn.textContent = "נחש";
                btn.classList.add("wide");
            } else if (k === "BACK") {
                btn.textContent = "⌫";
                btn.classList.add("wide");
                btn.setAttribute("aria-label", "מחק");
            } else {
                btn.textContent = k;
            }
            btn.addEventListener("click", () => {
                handleKey(k);
                btn.blur();
            });
            row.appendChild(btn);
        });
        keyboardEl.appendChild(row);
    });
}

function renderCurrentRow() {
    const row = boardEl.children[guesses.length];
    if (!row) return;
    [...row.children].forEach((tile, i) => {
        const ch = current[i];
        tile.textContent = ch ? displayLetter(ch, i, current.length) : "";
        tile.classList.toggle("filled", Boolean(ch));
    });
}

function updateKey(letter, status) {
    if ((STATUS_RANK[status] || 0) <= (STATUS_RANK[keyStatus[letter]] || 0)) return;
    keyStatus[letter] = status;
    const btn = keyboardEl.querySelector(`[data-key="${letter}"]`);
    if (btn) {
        btn.classList.remove("correct", "present", "absent");
        btn.classList.add(status);
    }
}

function revealRow(rowIndex, guess, result) {
    return new Promise(resolve => {
        const tiles = boardEl.children[rowIndex].children;
        result.forEach((status, i) => {
            setTimeout(() => {
                tiles[i].classList.add("reveal");
                setTimeout(() => tiles[i].classList.add(status), 250);
                setTimeout(() => {
                    updateKey(guess[i], status);
                    if (i === WORD_LENGTH - 1) resolve();
                }, 500);
            }, i * 300);
        });
    });
}

function shakeRow() {
    const row = boardEl.children[guesses.length];
    row.classList.remove("shake");
    void row.offsetWidth; // restart animation
    row.classList.add("shake");
}

// ---------- Game flow ----------

async function submitGuess() {
    if (current.length < WORD_LENGTH) {
        showMessage("אין מספיק אותיות");
        shakeRow();
        return;
    }

    const guess = [...current];
    const answer = normalize(secret);
    const result = scoreGuess(guess, answer);
    const rowIndex = guesses.length;

    guesses.push(guess);
    current = [];
    revealing = true;
    await revealRow(rowIndex, guess, result);
    revealing = false;

    const won = result.every(s => s === "correct");
    if (won) {
        const praise = ["גאוני!", "מדהים!", "מצוין!", "יפה מאוד!", "כל הכבוד!", "בנס!"];
        showMessage(praise[rowIndex], true);
        [...boardEl.children[rowIndex].children].forEach((t, i) =>
            setTimeout(() => t.classList.add("win"), i * 100));
        endGame(true, rowIndex + 1);
    } else if (guesses.length === MAX_GUESSES) {
        showMessage(`המילה הייתה: ${secret}`, true);
        endGame(false);
    }
}

function endGame(won, guessCount) {
    gameOver = true;
    recordResult(won, guessCount);
    newGameBtn.classList.remove("hidden");
    setTimeout(() => {
        renderStats(won ? guessCount - 1 : -1);
        document.getElementById("stats-dialog").showModal();
    }, 1600);
}

function handleKey(key) {
    if (gameOver || revealing) return;

    if (key === "ENTER") {
        submitGuess();
    } else if (key === "BACK") {
        current.pop();
        renderCurrentRow();
    } else if (/^[א-ת]$/.test(key) && current.length < WORD_LENGTH) {
        current.push(toRegular(key));
        renderCurrentRow();
    }
}

function newGame() {
    let next;
    do {
        next = WORDS[Math.floor(Math.random() * WORDS.length)];
    } while (WORDS.length > 1 && next === secret);
    secret = next;
    guesses = [];
    current = [];
    gameOver = false;
    revealing = false;
    Object.keys(keyStatus).forEach(k => delete keyStatus[k]);
    clearMessage();
    newGameBtn.classList.add("hidden");
    buildBoard();
    buildKeyboard();
}

// ---------- Events ----------

document.addEventListener("keydown", e => {
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    if (document.querySelector("dialog[open]")) return;

    if (e.key === "Enter") {
        e.preventDefault();
        handleKey("ENTER");
    } else if (e.key === "Backspace") {
        handleKey("BACK");
    } else {
        const he = EN_TO_HE[e.key.toLowerCase()] || e.key;
        handleKey(he);
    }
});

newGameBtn.addEventListener("click", () => {
    newGame();
    newGameBtn.blur();
});

document.getElementById("help-btn").addEventListener("click", () =>
    document.getElementById("help-dialog").showModal());

document.getElementById("stats-btn").addEventListener("click", () => {
    renderStats();
    document.getElementById("stats-dialog").showModal();
});

document.querySelectorAll("[data-close]").forEach(btn =>
    btn.addEventListener("click", () => btn.closest("dialog").close()));

// ---------- Start ----------

newGame();
try {
    if (!localStorage.getItem("hebrew-word-game-seen-help")) {
        document.getElementById("help-dialog").showModal();
        localStorage.setItem("hebrew-word-game-seen-help", "1");
    }
} catch {
    /* ignore */
}
