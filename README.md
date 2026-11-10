# וורדל בעברית

A 4-letter Hebrew Wordle with AI hints from ChatGPT or Gemini.

## Running it

You need [Node.js](https://nodejs.org) 18 or newer. No `npm install` is needed.

1. Get API keys:
   - ChatGPT: https://platform.openai.com/api-keys
   - Gemini: https://aistudio.google.com/apikey
2. Start the server with the keys (you can set just one of them):

   ```bash
   OPENAI_API_KEY=sk-... GEMINI_API_KEY=... node server.js
   ```

   On Windows PowerShell:

   ```powershell
   $env:OPENAI_API_KEY="sk-..."; $env:GEMINI_API_KEY="..."; node server.js
   ```

3. Open http://localhost:3000, pick ChatGPT or Gemini, and press **תן לי רמז**.

The keys stay on the server. Never put them in `index.html` or `ssdas.js`, because anyone
who opens the page can read those files.

Optional settings: `PORT`, `OPENAI_MODEL` (default `gpt-4o-mini`), `GEMINI_MODEL` (default `gemini-2.5-flash`).
