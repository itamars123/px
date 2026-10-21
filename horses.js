const HORSES = [
    { name: "ברק", color: "#c62828" },
    { name: "רעם", color: "#1565c0" },
    { name: "סופה", color: "#6a1b9a" },
    { name: "חץ", color: "#ef6c00" },
    { name: "כוכב", color: "#00838f" },
];

const FINISH = 100; // אחוזים מאורך המסלול
const MAX_STAMINA = 100;

let coins = 100;
let wins = 0;
let races = 0;
let chosen = null;
let positions = [];
let stamina = MAX_STAMINA;
let running = false;
let timer = null;

const picker = document.getElementById("horse-picker");
const track = document.getElementById("track");
const betInput = document.getElementById("bet");
const startBtn = document.getElementById("start");
const boostBtn = document.getElementById("boost");
const boostArea = document.getElementById("boost-area");
const staminaEl = document.getElementById("stamina");
const message = document.getElementById("message");
const restartBtn = document.getElementById("restart");

function buildPicker() {
    HORSES.forEach((horse, i) => {
        const btn = document.createElement("button");
        btn.className = "pick";
        btn.style.background = horse.color;
        btn.textContent = `${i + 1}. ${horse.name}`;
        btn.addEventListener("click", () => {
            if (running) return;
            chosen = i;
            document.querySelectorAll(".pick").forEach(b => b.classList.remove("selected"));
            btn.classList.add("selected");
            drawTrack();
        });
        picker.appendChild(btn);
    });
}

function drawTrack() {
    track.innerHTML = "";
    HORSES.forEach((horse, i) => {
        const lane = document.createElement("div");
        lane.className = "lane" + (i === chosen ? " mine" : "");
        lane.innerHTML = `<div class="horse" id="horse-${i}">🏇<span class="tag" style="background:${horse.color}">${i + 1}</span></div>`;
        track.appendChild(lane);
    });
    positions = HORSES.map(() => 0);
    moveHorses();
}

function moveHorses() {
    const laneWidth = track.clientWidth - 90; // משאירים מקום לסוס בקו הסיום
    positions.forEach((pos, i) => {
        document.getElementById(`horse-${i}`).style.right = `${(pos / FINISH) * laneWidth}px`;
    });
}

function updateStats() {
    document.getElementById("coins").textContent = coins;
    document.getElementById("wins").textContent = wins;
    document.getElementById("races").textContent = races;
}

function startRace() {
    if (chosen === null) {
        message.textContent = "קודם צריך לבחור סוס! 🐴";
        return;
    }
    const bet = parseInt(betInput.value, 10);
    if (!bet || bet < 1 || bet > coins) {
        message.textContent = `ההימור צריך להיות בין 1 ל-${coins}`;
        return;
    }

    coins -= bet;
    updateStats();
    drawTrack();
    stamina = MAX_STAMINA;
    staminaEl.style.width = "100%";
    running = true;
    startBtn.disabled = true;
    betInput.disabled = true;
    boostArea.classList.remove("hidden");

    countdown(3, () => {
        message.textContent = "🏁 רוצו!";
        timer = setInterval(() => tick(bet), 50);
    });
}

function countdown(n, done) {
    if (n === 0) return done();
    message.textContent = n;
    setTimeout(() => countdown(n - 1, done), 700);
}

function tick(bet) {
    positions = positions.map(pos => pos + Math.random() * 0.9);
    stamina = Math.min(MAX_STAMINA, stamina + 0.3); // הכוח מתמלא לאט
    staminaEl.style.width = `${stamina}%`;
    moveHorses();

    const winner = positions.findIndex(pos => pos >= FINISH);
    if (winner !== -1) endRace(winner, bet);
}

function boost() {
    if (!running || stamina < 10) return;
    stamina -= 10;
    positions[chosen] += 1.2;
    staminaEl.style.width = `${stamina}%`;
}

function endRace(winner, bet) {
    clearInterval(timer);
    running = false;
    races++;
    boostArea.classList.add("hidden");

    // מצמידים את המנצח לקו הסיום
    positions[winner] = FINISH;
    moveHorses();

    const name = HORSES[winner].name;
    if (winner === chosen) {
        const prize = bet * 3;
        coins += prize;
        wins++;
        message.textContent = `🎉 ${name} ניצח! זכית ב-${prize} מטבעות!`;
    } else {
        message.textContent = `😢 ${name} ניצח. הסוס שלך הפסיד הפעם.`;
    }
    updateStats();

    if (coins <= 0) {
        message.textContent += " נגמרו לך המטבעות!";
        restartBtn.classList.remove("hidden");
        startBtn.disabled = true;
    } else {
        startBtn.disabled = false;
        betInput.disabled = false;
        betInput.value = Math.min(parseInt(betInput.value, 10), coins);
    }
}

function restart() {
    coins = 100;
    wins = 0;
    races = 0;
    updateStats();
    restartBtn.classList.add("hidden");
    startBtn.disabled = false;
    betInput.disabled = false;
    betInput.value = 10;
    message.textContent = "";
    drawTrack();
}

startBtn.addEventListener("click", startRace);
boostBtn.addEventListener("click", boost);
restartBtn.addEventListener("click", restart);
document.addEventListener("keydown", e => {
    if (e.code === "Space") {
        e.preventDefault();
        boost();
    }
});
window.addEventListener("resize", moveHorses);

buildPicker();
drawTrack();
