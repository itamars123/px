// Small server for the Hebrew Wordle game.
// Serves the static files and forwards hint requests to ChatGPT (OpenAI) or Gemini,
// so the API keys stay on the server and never reach the browser.
//
// Run:  OPENAI_API_KEY=... GEMINI_API_KEY=... node server.js
// Then open http://localhost:3000

const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = process.env.PORT || 3000;
const OPENAI_MODEL = process.env.OPENAI_MODEL || "gpt-4o-mini";
const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-2.5-flash";

const STATIC_FILES = {
  "/": ["index.html", "text/html; charset=utf-8"],
  "/index.html": ["index.html", "text/html; charset=utf-8"],
  "/ssdas.js": ["ssdas.js", "text/javascript; charset=utf-8"],
  "/sss.css": ["sss.css", "text/css; charset=utf-8"],
};

function buildPrompt(word, guesses) {
  const tried = guesses.length ? guesses.join(", ") : "אין עדיין";
  return (
    `אתה עוזר במשחק וורדל בעברית. המילה הסודית היא "${word}". ` +
    `הניחושים של השחקן עד עכשיו: ${tried}. ` +
    "תן רמז קצר אחד בעברית (משפט אחד) שעוזר לנחש את המילה. " +
    "אסור לכתוב את המילה עצמה או את האותיות שלה ברצף."
  );
}

async function askChatGPT(prompt) {
  const key = process.env.OPENAI_API_KEY;
  if (!key) throw new Error("OPENAI_API_KEY is not set on the server");
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      messages: [{ role: "user", content: prompt }],
    }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error?.message || `OpenAI error ${res.status}`);
  return data.choices[0].message.content.trim();
}

async function askGemini(prompt) {
  const key = process.env.GEMINI_API_KEY;
  if (!key) throw new Error("GEMINI_API_KEY is not set on the server");
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": key },
    body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error?.message || `Gemini error ${res.status}`);
  return data.candidates[0].content.parts.map((p) => p.text).join("").trim();
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > 10000) reject(new Error("Body too large"));
    });
    req.on("end", () => resolve(body));
    req.on("error", reject);
  });
}

function sendJson(res, status, obj) {
  res.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(obj));
}

const server = http.createServer(async (req, res) => {
  if (req.method === "POST" && req.url === "/api/hint") {
    try {
      const { provider, word, guesses = [] } = JSON.parse(await readBody(req));
      if (typeof word !== "string" || !word) return sendJson(res, 400, { error: "missing word" });
      const prompt = buildPrompt(word, guesses.map(String).slice(0, 10));
      const hint = provider === "gemini" ? await askGemini(prompt) : await askChatGPT(prompt);
      return sendJson(res, 200, { hint });
    } catch (err) {
      return sendJson(res, 500, { error: err.message });
    }
  }

  const file = STATIC_FILES[req.url];
  if (req.method === "GET" && file) {
    fs.readFile(path.join(__dirname, file[0]), (err, content) => {
      if (err) return sendJson(res, 500, { error: "cannot read file" });
      res.writeHead(200, { "Content-Type": file[1] });
      res.end(content);
    });
    return;
  }

  sendJson(res, 404, { error: "not found" });
});

server.listen(PORT, () => {
  console.log(`Wordle running at http://localhost:${PORT}`);
  console.log(`ChatGPT: ${process.env.OPENAI_API_KEY ? "ready" : "missing OPENAI_API_KEY"}`);
  console.log(`Gemini:  ${process.env.GEMINI_API_KEY ? "ready" : "missing GEMINI_API_KEY"}`);
});
