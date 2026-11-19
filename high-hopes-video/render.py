"""Original motion-graphic video for "High Hopes" (no lyrics, no song audio).

Beat-synced to ~82 BPM. Theme: a night city, lanterns and stars rising,
the camera climbing higher with each chorus.

Usage:
  python3 render.py [--seconds 190] [--fps 30] [--out high_hopes_visual.mp4] [--audio song.mp3]
"""
import argparse, math, subprocess, sys
from multiprocessing import Pool
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1280, 720
BPM = 82.0
BEAT = 60.0 / BPM
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_LIGHT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

# (start_s, name, top_color, bottom_color, energy, word)
SECTIONS = [
    (0,   "intro",   (8, 10, 35),   (40, 20, 70),   0.2, None),
    (14,  "verse",   (10, 14, 45),  (70, 30, 90),   0.4, "LOOK UP"),
    (40,  "chorus",  (60, 20, 90),  (255, 120, 80), 1.0, "HIGHER"),
    (70,  "verse",   (14, 18, 60),  (90, 40, 110),  0.45, "KEEP CLIMBING"),
    (98,  "chorus",  (70, 20, 100), (255, 140, 70), 1.0, "HIGHER"),
    (128, "bridge",  (5, 30, 60),   (20, 120, 140), 0.6, "DREAM BIG"),
    (156, "chorus",  (90, 20, 110), (255, 170, 60), 1.0, "HIGH HOPES"),
    (184, "outro",   (8, 10, 35),   (40, 20, 70),   0.2, None),
]

rng = np.random.default_rng(7)
STARS = [(rng.uniform(0, W), rng.uniform(0, H * 3), rng.uniform(0.5, 2.2), rng.uniform(0, 6.28))
         for _ in range(420)]
LANTERNS = [(rng.uniform(0, W), rng.uniform(0, 1), rng.uniform(0.6, 1.4), rng.uniform(0, 6.28))
            for _ in range(46)]
# skyline: list of (x, w, h, window seed)
BUILDINGS = []
x = -20
while x < W + 40:
    w = int(rng.uniform(40, 110)); h = int(rng.uniform(80, 330))
    BUILDINGS.append((x, w, h, int(rng.integers(0, 1 << 30))))
    x += w + int(rng.uniform(-6, 10))
BACK = []
x = -20
while x < W + 40:
    w = int(rng.uniform(30, 80)); h = int(rng.uniform(140, 420))
    BACK.append((x, w, h)); x += w

_font_cache = {}
def font(size, light=False):
    k = (size, light)
    if k not in _font_cache:
        _font_cache[k] = ImageFont.truetype(FONT_LIGHT if light else FONT, size)
    return _font_cache[k]

def lerp(a, b, t): return a + (b - a) * t
def lerpc(a, b, t): return tuple(int(lerp(a[i], b[i], t)) for i in range(3))
def ease(t): t = max(0.0, min(1.0, t)); return t * t * (3 - 2 * t)
def ease_out(t): t = max(0.0, min(1.0, t)); return 1 - (1 - t) ** 3

def section_at(t):
    idx = 0
    for i, s in enumerate(SECTIONS):
        if t >= s[0]: idx = i
    cur = SECTIONS[idx]
    nxt = SECTIONS[min(idx + 1, len(SECTIONS) - 1)]
    span = max(1e-3, nxt[0] - cur[0])
    local = t - cur[0]
    # blend colors into next section over last 3 seconds
    blend = ease((local - (span - 3)) / 3) if nxt is not cur else 0
    return idx, cur, nxt, local, blend

def camera_height(t):
    """How far the camera has risen (px). Rises during choruses, stays otherwise."""
    h = 0.0
    for i, s in enumerate(SECTIONS):
        end = SECTIONS[i + 1][0] if i + 1 < len(SECTIONS) else s[0] + 10
        if s[1] == "chorus":
            span = end - s[0]
            h += 260 * ease((t - s[0]) / span)
        if s[1] == "outro":
            h -= 0 * ease((t - s[0]) / 6)
    return h

def gradient(top, bot):
    y = np.linspace(0, 1, H)[:, None, None]
    a = np.array(top, float)[None, None, :]; b = np.array(bot, float)[None, None, :]
    g = a + (b - a) * (y ** 1.4)
    return np.repeat(g, W, axis=1)

def render(fi_fps):
    fi, fps, total = fi_fps
    t = fi / fps
    idx, cur, nxt, local, blend = section_at(t)
    top = lerpc(cur[2], nxt[2], blend); bot = lerpc(cur[3], nxt[3], blend)
    energy = lerp(cur[4], nxt[4], blend)
    beat_pos = t / BEAT
    beat_phase = beat_pos % 1.0
    kick = math.exp(-beat_phase * 5.0)                # 1 at beat, decays
    bar_phase = (beat_pos / 4) % 1.0
    cam = camera_height(t)

    bg = gradient(top, bot)
    # beat brightness pulse
    bg *= 1.0 + 0.08 * kick * energy
    img = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img, "RGBA")
    glow = Image.new("RGB", (W // 4, H // 4), (0, 0, 0))
    gd = ImageDraw.Draw(glow)

    # ---- stars (parallax with camera) ----
    for sx, sy, sr, ph in STARS:
        y = (sy - H * 2 + cam * 0.25) % (H * 1.0)
        tw = 0.55 + 0.45 * math.sin(t * 2.0 + ph)
        a = int(255 * tw)
        r = sr * (1 + 0.3 * kick * energy)
        d.ellipse([sx - r, y - r, sx + r, y + r], fill=(255, 250, 230, a))

    # ---- sun/moon glow orb ----
    orb_y = 470 - cam * 0.35 + 30 * math.sin(t * 0.1)
    orb_r = 120 + 18 * kick * energy
    oc = lerpc((200, 210, 255), (255, 210, 120), energy)
    gd.ellipse([(W/2 - orb_r*2)/4, (orb_y - orb_r*2)/4, (W/2 + orb_r*2)/4, (orb_y + orb_r*2)/4], fill=tuple(int(c*0.5) for c in oc))
    d.ellipse([W/2 - orb_r, orb_y - orb_r, W/2 + orb_r, orb_y + orb_r], fill=oc + (235,))

    # ---- beat rings in high-energy sections ----
    if energy > 0.5:
        for k in range(3):
            ph = (beat_phase + k / 3) % 1.0
            rr = 60 + ph * 700
            a = int(180 * (1 - ph) * (energy - 0.5) * 2)
            d.ellipse([W/2 - rr, orb_y - rr, W/2 + rr, orb_y + rr], outline=(255, 240, 220, a), width=3)

    # ---- back skyline ----
    base = H + cam * 0.6
    for bx, bw, bh in BACK:
        d.rectangle([bx, base - bh * 0.9 - 40, bx + bw, H + 400], fill=lerpc(bot, (10, 10, 30), 0.55) + (255,))

    # ---- front skyline with windows ----
    fbase = H + cam * 1.0
    for bx, bw, bh, seed in BUILDINGS:
        ytop = fbase - bh
        if ytop > H: continue
        d.rectangle([bx, ytop, bx + bw, H + 500], fill=(12, 10, 28, 255))
        brng = np.random.default_rng(seed)
        cols = max(1, bw // 16); rows = max(1, int(bh // 22))
        lit = brng.random((rows, cols))
        flick = brng.random((rows, cols))
        for r in range(rows):
            wy = ytop + 12 + r * 22
            if wy > H: break
            for c in range(cols):
                thresh = 0.55 - 0.25 * energy - 0.15 * kick * energy
                on = lit[r, c] > thresh and math.sin(t * 0.7 + flick[r, c] * 40) > -0.8
                if on:
                    wx = bx + 6 + c * 16
                    wc = (255, 210, 120) if flick[r, c] > 0.3 else (140, 220, 255)
                    d.rectangle([wx, wy, wx + 7, wy + 10], fill=wc + (230,))

    # ---- rising lanterns ----
    n_lan = int(10 + 36 * energy)
    for i, (lx, ly, ls, ph) in enumerate(LANTERNS[:n_lan]):
        speed = 40 * ls * (0.6 + energy)
        y = H + 60 - ((ly * (H + 200) + t * speed + cam * 0.8) % (H + 200))
        x = lx + 25 * math.sin(t * 0.6 + ph)
        s = 9 * ls
        flame = 0.8 + 0.2 * math.sin(t * 9 + ph)
        col = (255, int(150 + 60 * flame), 70)
        d.rounded_rectangle([x - s, y - s * 1.3, x + s, y + s * 1.3], radius=s * 0.6, fill=col + (230,))
        gd.ellipse([(x - s*3)/4, (y - s*3)/4, (x + s*3)/4, (y + s*3)/4], fill=(150, 80, 30))

    # ---- shooting stars every 2 bars in choruses ----
    if energy > 0.8:
        sp = (beat_pos / 8) % 1.0
        if sp < 0.35:
            p = sp / 0.35
            seed = int(beat_pos / 8)
            r2 = np.random.default_rng(seed)
            x0 = r2.uniform(100, W - 300); y0 = r2.uniform(40, 220)
            x1 = x0 + 500 * p; y1 = y0 + 200 * p
            for k in range(12):
                q = k / 12
                xa = lerp(x0, x1, q * p if p else 0) if False else x1 - (x1 - x0) * q * 0.5
                ya = y1 - (y1 - y0) * q * 0.5
                d.ellipse([xa - 3 * (1 - q), ya - 3 * (1 - q), xa + 3 * (1 - q), ya + 3 * (1 - q)], fill=(255, 255, 255, int(255 * (1 - q) * (1 - p))))

    # ---- glow composite ----
    glow = glow.filter(ImageFilter.GaussianBlur(10)).resize((W, H), Image.BILINEAR)
    img = Image.fromarray(np.clip(np.asarray(img, np.int16) + np.asarray(glow, np.int16), 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img, "RGBA")

    # ---- typography ----
    def centered(text, size, y, alpha=255, spacing=0, light=False, color=(255, 255, 255), rise=0.0):
        f = font(size, light)
        widths = [d.textlength(ch, font=f) + spacing for ch in text]
        total = sum(widths) - spacing
        x = W / 2 - total / 2
        for i, ch in enumerate(text):
            # per-letter staggered rise
            lt = ease_out(rise * 1.6 - i * 0.06) if rise < 10 else 1
            dy = (1 - lt) * 60
            a = int(alpha * lt)
            d.text((x + 3, y + dy + 4), ch, font=f, fill=(0, 0, 0, a // 3))
            d.text((x, y + dy), ch, font=f, fill=color + (a,))
            x += widths[i]

    # intro title
    if t < 14:
        a = 255 * ease(t / 1.5) * (1 - ease((t - 11.5) / 2))
        centered("HIGH HOPES", 120, 230, int(a), spacing=14, rise=t / 2)
        centered("a motion graphic", 30, 380, int(a * 0.8), spacing=4, light=True, rise=max(0, t - 1) / 2)
    # outro title
    if t >= SECTIONS[-1][0]:
        lt = t - SECTIONS[-1][0]
        a = 255 * ease(lt / 1.5) * (1 - ease((lt - (total / fps - SECTIONS[-1][0] - 2)) / 2))
        centered("HIGH HOPES", 120, 240, int(a), spacing=14, rise=lt / 2)

    # section words: pop in for the first 4 bars of the section
    word = cur[5]
    if word:
        wl = local
        dur = BEAT * 16
        if wl < dur:
            a = 255 * ease(wl / 0.6) * (1 - ease((wl - dur + 1.2) / 1.2))
            size = 96 if cur[1] == "chorus" else 64
            scale_kick = 1 + 0.06 * kick * energy
            centered(word, int(size * scale_kick), 110, int(a), spacing=10, rise=wl / 1.2,
                     color=(255, 245, 225))

    # beat bar indicator (bottom equalizer) in choruses
    if energy > 0.3:
        n = 48
        bw = W / n
        for i in range(n):
            v = (0.5 + 0.5 * math.sin(i * 0.7 + t * 6)) * (0.4 + 0.6 * kick) * energy
            v *= 0.6 + 0.4 * math.sin(i * 0.31 + t * 1.3)
            hgt = 6 + 70 * max(0, v)
            d.rectangle([i * bw + 3, H - hgt, (i + 1) * bw - 3, H], fill=(255, 230, 200, 110))

    # vignette + white flash on chorus downbeats
    if cur[1] == "chorus" and local < 0.4:
        a = int(200 * (1 - local / 0.4))
        d.rectangle([0, 0, W, H], fill=(255, 255, 255, a))
    if fi + 1 >= total - fps:  # fade out last second
        a = int(255 * ((fi + 1 - (total - fps)) / fps))
        d.rectangle([0, 0, W, H], fill=(0, 0, 0, a))
    if fi < fps // 2:
        a = int(255 * (1 - fi / (fps // 2)))
        d.rectangle([0, 0, W, H], fill=(0, 0, 0, a))

    return img.tobytes()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seconds", type=float, default=190)
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--out", default="high_hopes_visual.mp4")
    ap.add_argument("--audio", default=None)
    ap.add_argument("--start", type=float, default=0, help="render from this time (preview)")
    a = ap.parse_args()
    total = int(a.seconds * a.fps)
    first = int(a.start * a.fps)
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
           "-s", f"{W}x{H}", "-r", str(a.fps), "-i", "-"]
    if a.audio:
        cmd += ["-i", a.audio, "-c:a", "aac", "-b:a", "192k", "-shortest"]
    cmd += ["-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p",
            "-movflags", "+faststart", a.out]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    with Pool(4) as pool:
        for i, fr in enumerate(pool.imap(render, [(f, a.fps, total) for f in range(first, total)], chunksize=8)):
            p.stdin.write(fr)
            if i % (a.fps * 10) == 0:
                print(f"{(first + i) / a.fps:6.1f}s / {a.seconds}s", file=sys.stderr, flush=True)
    p.stdin.close(); p.wait()
    print("wrote", a.out)

if __name__ == "__main__":
    main()
