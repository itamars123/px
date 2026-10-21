// לוגיקת החנות: סינון, חיפוש, מומלצים, חלון משחק, עגלה, משאלות וספרייה.

const IMG_SOURCES = [
  (id) => `https://cdn.cloudflare.steamstatic.com/steam/apps/${id}/header.jpg`,
  (id) => `https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/${id}/header.jpg`,
  (id) => `https://cdn.akamai.steamstatic.com/steam/apps/${id}/header.jpg`,
];

const state = {
  search: "",
  price: "all",
  sort: "pop",
  genres: new Set(),
  cart: load("he-steam-cart", []),
  wish: load("he-steam-wish", []),
  library: load("he-steam-library", []),
  featIndex: 0,
};

function load(key, fallback) {
  try {
    const v = JSON.parse(localStorage.getItem(key));
    return Array.isArray(v) ? v : fallback;
  } catch (e) {
    return fallback;
  }
}

function save() {
  try {
    localStorage.setItem("he-steam-cart", JSON.stringify(state.cart));
    localStorage.setItem("he-steam-wish", JSON.stringify(state.wish));
    localStorage.setItem("he-steam-library", JSON.stringify(state.library));
  } catch (e) { /* אחסון לא זמין – ממשיכים בלי לשמור */ }
}

const $ = (sel) => document.querySelector(sel);
const byId = (id) => GAMES.find((g) => g.id === id);

// הנחה קבועה לכל משחק לפי המזהה שלו, כדי שהמבצעים לא ישתנו בכל רענון
function discountOf(game) {
  if (game.price === 0) return 0;
  const options = [0, 0, 0, 0, 10, 20, 25, 33, 40, 50, 66, 75];
  return options[(game.id * 7 + 3) % options.length];
}

function finalPrice(game) {
  const d = discountOf(game);
  return Math.round(game.price * (100 - d)) / 100;
}

function formatPrice(n) {
  return `${n.toFixed(2).replace(/\.00$/, "")} ₪`;
}

function priceHtml(game) {
  if (game.price === 0) return `<div class="price"><span class="now">חינם לשחק</span></div>`;
  const d = discountOf(game);
  if (!d) return `<div class="price"><span class="now">${formatPrice(game.price)}</span></div>`;
  return `<div class="price">
    <span class="discount">-${d}%</span>
    <span class="stack"><span class="old">${formatPrice(game.price)}</span><span class="now">${formatPrice(finalPrice(game))}</span></span>
  </div>`;
}

function storeUrl(game) {
  return `https://store.steampowered.com/app/${game.id}/?l=hebrew`;
}

// חיפוש תרגום קהילתי לעברית בסדנת Steam של המשחק
function workshopHebrewUrl(game) {
  return `https://steamcommunity.com/workshop/browse/?appid=${game.id}&searchtext=Hebrew&browsesort=textsearch`;
}

function webHebrewUrl(game) {
  return `https://www.google.com/search?q=${encodeURIComponent(`${game.en} תרגום לעברית מוד`)}`;
}

// צבע קבוע לכל משחק לתמונה החלופית
function hue(id) {
  return (id * 47) % 360;
}

function imgHtml(game) {
  return `<img src="${IMG_SOURCES[0](game.id)}" alt="${escapeHtml(game.he)}" loading="lazy"
    data-id="${game.id}" data-try="0" onerror="imgFallback(this)">`;
}

function imgFallback(img) {
  const id = Number(img.dataset.id);
  const next = Number(img.dataset.try) + 1;
  if (next < IMG_SOURCES.length) {
    img.dataset.try = next;
    img.src = IMG_SOURCES[next](id);
    return;
  }
  const game = byId(id);
  const box = img.parentElement;
  img.remove();
  box.style.background = `linear-gradient(135deg, hsl(${hue(id)},55%,35%), hsl(${(hue(id) + 60) % 360},60%,18%))`;
  const label = document.createElement("div");
  label.className = "img-fallback";
  label.textContent = game ? game.he : "";
  box.appendChild(label);
}
window.imgFallback = imgFallback;

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

// ---------- סינון ומיון ----------
function filteredGames() {
  const q = state.search.trim().toLowerCase();
  let list = GAMES.filter((g) => {
    if (q && !g.he.toLowerCase().includes(q) && !g.en.toLowerCase().includes(q) && !g.dev.toLowerCase().includes(q)) return false;
    if (state.price === "free" && g.price !== 0) return false;
    if (state.price === "sale" && !discountOf(g)) return false;
    if ((state.price === "50" || state.price === "100") && finalPrice(g) > Number(state.price)) return false;
    for (const genre of state.genres) if (!g.genres.includes(genre)) return false;
    return true;
  });

  const sorters = {
    pop: (a, b) => a.popularity - b.popularity,
    name: (a, b) => a.he.localeCompare(b.he, "he"),
    "price-asc": (a, b) => finalPrice(a) - finalPrice(b),
    "price-desc": (a, b) => finalPrice(b) - finalPrice(a),
    new: (a, b) => b.year - a.year,
    old: (a, b) => a.year - b.year,
  };
  return list.sort(sorters[state.sort]);
}

function cardHtml(game) {
  const wished = state.wish.includes(game.id);
  const tags = game.genres.map((g) => GENRES[g]).join(" · ");
  return `<article class="card" data-open="${game.id}">
    <div class="card-img">${imgHtml(game)}</div>
    <div class="card-body">
      <div class="card-title">${escapeHtml(game.he)}</div>
      <div class="card-en">${escapeHtml(game.en)}</div>
      <div class="card-tags">${tags}</div>
      <div class="card-foot">
        ${priceHtml(game)}
        <button class="wish-btn ${wished ? "on" : ""}" data-wish="${game.id}" title="רשימת משאלות">${wished ? "♥" : "♡"}</button>
      </div>
    </div>
  </article>`;
}

function renderGrid() {
  const list = filteredGames();
  $("#grid").innerHTML = list.map(cardHtml).join("");
  $("#result-count").textContent = `${list.length} משחקים נמצאו מתוך ${GAMES.length} בקטלוג`;
  const empty = list.length === 0;
  $("#no-results").classList.toggle("hidden", !empty);
  $("#steam-search-link").href = `https://store.steampowered.com/search/?term=${encodeURIComponent(state.search)}&l=hebrew`;
}

function renderGenres() {
  $("#genre-list").innerHTML = Object.entries(GENRES)
    .map(([key, label]) => `<button class="chip ${state.genres.has(key) ? "on" : ""}" data-genre="${key}">${label}</button>`)
    .join("");
}

// ---------- מומלצים ----------
const FEATURED = [1086940, 1245620, 1174180, 1091500, 1903340, 1030300, 2358720, 292030]
  .map(byId)
  .filter(Boolean);

function renderFeatured() {
  const game = FEATURED[state.featIndex];
  const rating = RATINGS[game.rating];
  $("#feat-slide").dataset.open = game.id;
  $("#feat-slide").innerHTML = `
    <div class="feat-img card-img">${imgHtml(game)}</div>
    <div class="feat-info">
      <h3>${escapeHtml(game.he)}</h3>
      <div class="en">${escapeHtml(game.en)}</div>
      <p>${escapeHtml(game.desc)}</p>
      <div>ביקורות: <span class="rating ${rating.cls}">${rating.label}</span></div>
      <div class="card-tags">${game.genres.map((g) => GENRES[g]).join(" · ")}</div>
      <div style="margin-top:auto">${priceHtml(game)}</div>
    </div>`;
  $("#feat-dots").innerHTML = FEATURED.map((_, i) => `<span class="${i === state.featIndex ? "on" : ""}" data-dot="${i}"></span>`).join("");
}

function moveFeatured(step) {
  state.featIndex = (state.featIndex + step + FEATURED.length) % FEATURED.length;
  renderFeatured();
}

// ---------- חלון משחק ----------
function openGame(id) {
  const game = byId(id);
  if (!game) return;
  const rating = RATINGS[game.rating];
  const inCart = state.cart.includes(id);
  const owned = state.library.includes(id);
  const wished = state.wish.includes(id);
  const buyLabel = game.price === 0 ? "שחקו בחינם" : `קנו את ${escapeHtml(game.he)}`;

  let action;
  if (owned) action = `<a class="btn btn-green" href="steam://run/${game.id}">▶ שחק עכשיו</a>`;
  else if (game.price === 0) action = `<button class="btn btn-green" data-add-library="${id}">הוסף לספרייה</button>`;
  else action = `<button class="btn btn-green" data-add-cart="${id}">${inCart ? "✓ בעגלה" : "הוסף לעגלה"}</button>`;

  $("#modal-content").innerHTML = `
    <div class="game-hero card-img">${imgHtml(game)}</div>
    <div class="game-detail">
      <div>
        <h2>${escapeHtml(game.he)}</h2>
        <div class="en">${escapeHtml(game.en)}</div>
        <p>${escapeHtml(game.desc)}</p>
      </div>
      <div class="meta">
        <span class="k">ביקורות</span><span class="v rating ${rating.cls}">${rating.label}</span>
        <span class="k">שנת יציאה</span><span class="v">${game.year}</span>
        <span class="k">מפתח</span><span class="v">${escapeHtml(game.dev)}</span>
        <span class="k">ז'אנרים</span><span class="v">${game.genres.map((g) => GENRES[g]).join(", ")}</span>
        <span class="k">שפה</span><span class="v">דף החנות: עברית (מוד) ✓</span>
        <span class="k">Steam</span><span class="v"><a href="${storeUrl(game)}" target="_blank" rel="noopener">לדף המשחק ↗</a></span>
      </div>
      <div class="buy-box">
        <h4>${buyLabel}</h4>
        <div class="buy-actions">
          ${owned ? "" : priceHtml(game)}
          ${action}
        </div>
        <div style="display:flex;gap:8px">
          <button class="btn btn-blue" data-wish="${id}">${wished ? "♥ ברשימת המשאלות" : "♡ הוסף לרשימת המשאלות"}</button>
          <a class="btn btn-blue" href="${storeUrl(game)}" target="_blank" rel="noopener">פתח ב-Steam</a>
        </div>
      </div>
      <div class="he-box">
        <h4>🇮🇱 עברית בתוך המשחק</h4>
        <p>המוד מתרגם את דף החנות. כדי לשחק בעברית בתוך המשחק אפשר להשתמש במתרגם המסך שלנו, שעובד על כל משחק, או לחפש מוד תרגום של הקהילה.</p>
        <div class="he-actions">
          <a class="btn btn-green" href="translator.html">מתרגם מסך לעברית (כל המשחקים)</a>
          <a class="btn btn-blue" href="${workshopHebrewUrl(game)}" target="_blank" rel="noopener">חפש תרגום לעברית בסדנת Steam</a>
          <a class="btn btn-blue" href="${webHebrewUrl(game)}" target="_blank" rel="noopener">חפש תרגום ברשת</a>
        </div>
        <p class="muted small">שימו לב: חלק מהמשחקים אינם תומכים בסדנה, ובמשחקים רבים טקסט עברי עלול להופיע הפוך משמאל לימין.</p>
      </div>
    </div>`;
  $("#modal").classList.remove("hidden");
}

function closeModal() {
  $("#modal").classList.add("hidden");
}

// ---------- עגלה, משאלות, ספרייה ----------
function toggleWish(id) {
  const i = state.wish.indexOf(id);
  if (i >= 0) {
    state.wish.splice(i, 1);
    toast("הוסר מרשימת המשאלות");
  } else {
    state.wish.push(id);
    toast("נוסף לרשימת המשאלות ♥");
  }
  save();
  refresh();
}

function addToCart(id) {
  if (!state.cart.includes(id)) {
    state.cart.push(id);
    save();
    toast("נוסף לעגלה 🛒");
  }
  refresh();
}

function addToLibrary(id) {
  if (!state.library.includes(id)) state.library.push(id);
  save();
  toast("נוסף לספרייה שלך 🎮");
  refresh();
}

function renderCart() {
  $("#cart-count").textContent = state.cart.length;
  $("#cart-items").innerHTML = state.cart.length
    ? state.cart.map(byId).filter(Boolean).map((g) => `
        <div class="cart-item">
          <div class="card-img">${imgHtml(g)}</div>
          <div><div class="t">${escapeHtml(g.he)}</div>${priceHtml(g)}</div>
          <button class="link-btn" data-remove="${g.id}">הסר</button>
        </div>`).join("")
    : `<p class="muted">העגלה ריקה. לכו לקנות משהו!</p>`;
  const total = state.cart.map(byId).filter(Boolean).reduce((sum, g) => sum + finalPrice(g), 0);
  $("#cart-total").textContent = formatPrice(total);
}

function checkout() {
  if (!state.cart.length) return;
  state.cart.forEach((id) => { if (!state.library.includes(id)) state.library.push(id); });
  const n = state.cart.length;
  state.cart = [];
  save();
  $("#cart").classList.add("hidden");
  toast(`תודה על הרכישה! ${n} משחקים נוספו לספרייה 🎉`);
  refresh();
}

function renderLists() {
  $("#wish-count").textContent = state.wish.length;
  const wishGames = state.wish.map(byId).filter(Boolean);
  $("#wish-grid").innerHTML = wishGames.length ? wishGames.map(cardHtml).join("") : `<p class="muted">רשימת המשאלות ריקה.</p>`;
  const libGames = state.library.map(byId).filter(Boolean);
  $("#library-grid").innerHTML = libGames.length ? libGames.map(cardHtml).join("") : `<p class="muted">הספרייה ריקה. משחקים חינמיים או משחקים שקניתם יופיעו כאן.</p>`;
}

function refresh() {
  renderGrid();
  renderCart();
  renderLists();
  if (!$("#modal").classList.contains("hidden")) {
    const open = $("#modal-content [data-wish]");
    if (open) openGame(Number(open.dataset.wish));
  }
}

let toastTimer;
function toast(msg) {
  const t = $("#toast");
  t.textContent = msg;
  t.classList.remove("hidden");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.add("hidden"), 2200);
}

function showView(name) {
  document.querySelectorAll(".view").forEach((v) => v.classList.add("hidden"));
  $(`#view-${name}`).classList.remove("hidden");
  document.querySelectorAll(".main-nav a").forEach((a) => a.classList.toggle("active", a.dataset.view === name));
  window.scrollTo(0, 0);
}

// ---------- אירועים ----------
document.addEventListener("click", (e) => {
  const el = (sel) => e.target.closest(sel);
  let t;
  if ((t = el("[data-wish]"))) { e.stopPropagation(); toggleWish(Number(t.dataset.wish)); return; }
  if ((t = el("[data-add-cart]"))) { addToCart(Number(t.dataset.addCart)); return; }
  if ((t = el("[data-add-library]"))) { addToLibrary(Number(t.dataset.addLibrary)); return; }
  if ((t = el("[data-remove]"))) {
    state.cart = state.cart.filter((id) => id !== Number(t.dataset.remove));
    save(); refresh(); return;
  }
  if ((t = el("[data-genre]"))) {
    const g = t.dataset.genre;
    state.genres.has(g) ? state.genres.delete(g) : state.genres.add(g);
    renderGenres(); renderGrid(); return;
  }
  if ((t = el("[data-dot]"))) { state.featIndex = Number(t.dataset.dot); renderFeatured(); return; }
  if ((t = el("[data-view]"))) { e.preventDefault(); showView(t.dataset.view); return; }
  if ((t = el("[data-open]"))) { openGame(Number(t.dataset.open)); return; }
});

$("#search").addEventListener("input", (e) => { state.search = e.target.value; renderGrid(); });
$("#price-filter").addEventListener("change", (e) => { state.price = e.target.value; renderGrid(); });
$("#sort").addEventListener("change", (e) => { state.sort = e.target.value; renderGrid(); });
$("#clear-filters").addEventListener("click", () => {
  state.search = ""; state.price = "all"; state.sort = "pop"; state.genres.clear();
  $("#search").value = ""; $("#price-filter").value = "all"; $("#sort").value = "pop";
  renderGenres(); renderGrid();
});
// ב-RTL החץ הימני הוא "הקודם"
$("#feat-prev").addEventListener("click", (e) => { e.stopPropagation(); moveFeatured(-1); });
$("#feat-next").addEventListener("click", (e) => { e.stopPropagation(); moveFeatured(1); });
$("#modal-close").addEventListener("click", closeModal);
$("#modal").addEventListener("click", (e) => { if (e.target.id === "modal") closeModal(); });
$("#cart-btn").addEventListener("click", () => $("#cart").classList.toggle("hidden"));
$("#cart-close").addEventListener("click", () => $("#cart").classList.add("hidden"));
$("#checkout").addEventListener("click", checkout);
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") { closeModal(); $("#cart").classList.add("hidden"); }
});

let featTimer = setInterval(() => moveFeatured(1), 7000);
$("#featured").addEventListener("mouseenter", () => clearInterval(featTimer));
$("#featured").addEventListener("mouseleave", () => { featTimer = setInterval(() => moveFeatured(1), 7000); });

renderGenres();
renderFeatured();
refresh();
