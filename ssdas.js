// Hebrew Wordle game logic + AI hints (ChatGPT / Gemini via server.js).

// 4-letter secret words. Add more here.
const WORD_LIST = ["חציל", "תפוח", "חלון", "כיסא", "מטבח", "חתול", "שמלה", "פרפר", "כדור", "שעון", "סוכר", "גזרה"];

const WORD_LENGTH = 4;
const MAX_GUESSES = 6;

// Treat final letters (ך ם ן ף ץ) the same as their regular forms.
const FINALS = { "ך": "כ", "ם": "מ", "ן": "נ", "ף": "פ", "ץ": "צ" };
const normalize = (s) => [...s.trim()].map((c) => FINALS[c] || c).join("");

const secret = WORD_LIST[Math.floor(Math.random() * WORD_LIST.length)];
const guesses = [];
let finished = false;

const container = document.getElementById("container");
const input = document.getElementById("guess");
const message = document.getElementById("message");
const hintBox = document.getElementById("hint");

function scoreGuess(guess) {
  const g = [...normalize(guess)];
  const s = [...normalize(secret)];
  const result = Array(WORD_LENGTH).fill("absent");
  const left = {};
  s.forEach((c, i) => {
    if (g[i] === c) result[i] = "correct";
    else left[c] = (left[c] || 0) + 1;
  });
  g.forEach((c, i) => {
    if (result[i] !== "correct" && left[c]) {
      result[i] = "present";
      left[c]--;
    }
  });
  return result;
}

function drawBoard() {
  container.innerHTML = "";
  for (let row = 0; row < MAX_GUESSES; row++) {
    const guess = guesses[row];
    const colors = guess ? scoreGuess(guess) : [];
    for (let i = 0; i < WORD_LENGTH; i++) {
      const cell = document.createElement("div");
      cell.className = "letter " + (colors[i] || "");
      cell.textContent = guess ? [...guess][i] : "";
      container.appendChild(cell);
    }
  }
}

function makeGuess() {
  if (finished) return;
  const guess = input.value.trim();
  if ([...guess].length !== WORD_LENGTH) {
    message.textContent = `צריך מילה של ${WORD_LENGTH} אותיות`;
    return;
  }
  guesses.push(guess);
  input.value = "";
  drawBoard();

  if (normalize(guess) === normalize(secret)) {
    message.textContent = "כל הכבוד! ניחשת 🎉";
    finished = true;
  } else if (guesses.length === MAX_GUESSES) {
    message.textContent = `נגמרו הניסיונות. המילה הייתה: ${secret}`;
    finished = true;
  } else {
    message.textContent = `נשארו ${MAX_GUESSES - guesses.length} ניסיונות`;
  }
}

async function getHint() {
  const provider = document.getElementById("provider").value;
  const name = provider === "gemini" ? "Gemini" : "ChatGPT";
  hintBox.textContent = `${name} חושב...`;
  try {
    const res = await fetch("/api/hint", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ provider, word: secret, guesses }),
    });
    const data = await res.json();
    hintBox.textContent = res.ok ? `${name}: ${data.hint}` : `שגיאה: ${data.error}`;
  } catch {
    hintBox.textContent = "אין חיבור לשרת. הפעל את server.js (ראה README).";
  }
}

document.getElementById("guess-btn").addEventListener("click", makeGuess);
document.getElementById("hint-btn").addEventListener("click", getHint);
input.addEventListener("keydown", (e) => e.key === "Enter" && makeGuess());

drawBoard();
