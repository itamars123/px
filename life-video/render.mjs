// Renders the film frame-by-frame with headless Chromium and pipes PNGs into ffmpeg.
// usage: node render.mjs <outDir> [workers] [onlyFrom onlyTo]   (seconds, for previews)
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)(process.env.PLAYWRIGHT_PATH || 'playwright');
import { spawn } from 'node:child_process';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const tl = JSON.parse(readFileSync(path.join(here, 'timeline.json'), 'utf8'));
const outDir = process.argv[2] || 'out';
const workers = +(process.argv[3] || 4);
const from = +(process.argv[4] ?? 0), to = +(process.argv[5] ?? tl.duration);
mkdirSync(outDir, { recursive: true });

const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.ttf': 'font/ttf' };
const server = http.createServer((req, res) => {
  const f = path.join(here, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  try { res.writeHead(200, { 'content-type': types[path.extname(f)] || 'application/octet-stream' }); res.end(readFileSync(f)); }
  catch { res.writeHead(404); res.end(); }
}).listen(0);
const port = server.address().port;

const f0 = Math.round(from * tl.fps), f1 = Math.round(to * tl.fps);
const per = Math.ceil((f1 - f0) / workers);
const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });

async function work(w) {
  const a = f0 + w * per, b = Math.min(f1, a + per);
  if (a >= b) return null;
  const page = await browser.newPage({ viewport: { width: tl.width, height: tl.height } });
  await page.goto(`http://localhost:${port}/render.html`);
  await page.waitForFunction(() => window.READY);
  const seg = path.join(outDir, `seg${w}.mp4`);
  const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(tl.fps), '-c:v', 'png', '-i', '-',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '17', '-pix_fmt', 'yuv420p', seg], { stdio: ['pipe', 'inherit', 'inherit'] });
  const canvas = await page.$('canvas');
  const started = Date.now();
  for (let f = a; f < b; f++) {
    await page.evaluate(t => window.draw(t), f / tl.fps);
    const png = await canvas.screenshot({ type: 'png' });
    if (!ff.stdin.write(png)) await new Promise(r => ff.stdin.once('drain', r));
    if ((f - a) % 150 === 0) console.log(`worker ${w}: frame ${f - a}/${b - a} (${((Date.now() - started) / 1000).toFixed(0)}s)`);
  }
  ff.stdin.end();
  await new Promise(r => ff.on('close', r));
  await page.close();
  return seg;
}

const segs = (await Promise.all([...Array(workers).keys()].map(work))).filter(Boolean);
await browser.close(); server.close();
writeFileSync(path.join(outDir, 'segments.txt'), segs.map(s => `file '${path.resolve(s)}'`).join('\n'));
console.log('done', segs);
