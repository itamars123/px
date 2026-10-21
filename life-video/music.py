"""Score, sound design and narration mix for "Life", synthesized from scratch with numpy.

Reads timeline.json so every boom, heartbeat, firework and thunderclap lands on
the frame where it happens on screen, and places the narrator's lines (vo/narration.mp3)
where the captions say. The music ducks under the voice.
usage: python3 music.py out.wav
"""
import json
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
TL = json.loads((Path(__file__).parent / "timeline.json").read_text())
DUR = TL["duration"]
N = int(SR * DUR)
EV = TL["events"]
rng = np.random.default_rng(2026)

music = np.zeros((2, N))   # pads, piano, bells — gets the long reverb
sfx = np.zeros((2, N))     # sound design — shorter, drier


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def add(bus, t0, sig, pan=0.0, gain=1.0):
    """Mix a mono signal into a stereo bus at time t0 (seconds) with equal-power pan."""
    i = int(t0 * SR)
    if i >= N:
        return
    if i < 0:
        sig, i = sig[-i:], 0
    sig = sig[: N - i]
    l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    bus[0, i:i + len(sig)] += sig * gain * l
    bus[1, i:i + len(sig)] += sig * gain * r


def env_adsr(n, a, r, sustain_level=1.0):
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(a, 1e-4)) * sustain_level
    rel = np.clip((n / SR - t) / max(r, 1e-4), 0, 1)
    return e * rel


def spectral_filter(x, lo=None, hi=None):
    """Zero-phase filter in the frequency domain with soft (cosine) skirts."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    g = np.ones_like(f)
    if hi is not None:
        g *= np.clip(1 - (f - hi) / (hi * 0.6), 0, 1) ** 2
    if lo is not None:
        g *= np.clip((f - lo * 0.6) / (lo * 0.4), 0, 1) ** 2
    return np.fft.irfft(X * g, len(x))


def noise(n):
    return rng.standard_normal(n)


# ---------------------------------------------------------------- instruments
def pad(freqs, dur, attack=2.5, release=2.5, bright=6):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f in freqs:
        for det in (-0.12, 0.0, 0.13):            # chorus of three slightly detuned voices
            ff = f * 2 ** (det / 12)
            ph = rng.uniform(0, 2 * np.pi)
            for h in range(1, bright + 1):        # soft saw: harmonics falling off fast
                if ff * h > 9000:
                    break
                out += np.sin(2 * np.pi * ff * h * t + ph * h) / (h ** 1.6)
    lfo = 1 + 0.12 * np.sin(2 * np.pi * 0.17 * t + rng.uniform(0, 6))
    return out * env_adsr(n, attack, release) * lfo / (len(freqs) * 3)


def piano(f, vel=1.0, dur=3.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for h, amp in enumerate([1, 0.55, 0.3, 0.18, 0.1, 0.06, 0.03], start=1):
        fh = f * h * np.sqrt(1 + 0.0004 * h * h)  # slight string inharmonicity
        if fh > 12000:
            break
        decay = (1.2 + 2.5 * (220 / f) ** 0.5) / h ** 0.7
        out += amp * np.sin(2 * np.pi * fh * t) * np.exp(-t / decay)
    hammer = spectral_filter(noise(min(n, 900)), lo=1500, hi=6000) * np.exp(-np.arange(min(n, 900)) / 120) * 0.08
    out[: len(hammer)] += hammer
    out *= np.minimum(1, t / 0.004) * env_adsr(n, 0.001, 0.3)
    return out * vel * 0.35


def bell(f, dur=4.0, vel=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp, dec in [(1, 1, 2.2), (2.76, 0.4, 1.0), (5.4, 0.2, 0.5), (8.93, 0.1, 0.3)]:
        out += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / dec)
    return out * np.minimum(1, t / 0.002) * vel * 0.18


# ---------------------------------------------------------------- timeline helpers
SC = {s["id"]: s for s in TL["scenes"]}


def M(t_orig):
    """Map a time on the original (150 s) clock to the new, faster cut."""
    for s in TL["scenes"]:
        a, b = s["src"]
        if a <= t_orig < b or s is TL["scenes"][-1]:
            return s["start"] + (t_orig - a) * (s["end"] - s["start"]) / (b - a)


def at(sid, frac):
    s = SC[sid]
    return s["start"] + frac * (s["end"] - s["start"])


# ---------------------------------------------------------------- harmony (D major / B minor)
D, A, Bm, G, Em, Fsm = [50, 57, 62, 66], [45, 57, 61, 64], [47, 54, 62, 66], [43, 55, 59, 62], [40, 55, 59, 64], [42, 54, 57, 61]
Dadd9 = [38, 50, 57, 64, 66]
PROG = {
    "void": [[38, 45]], "bigbang": [D, A], "planet": [Bm, G], "cells": [D, A], "sprout": [Bm, G],
    "heart": [[38, 45, 50]], "childhood": [D, A, G], "youth": [Bm, G, D, A], "love": [G, D, A],
    "storm": [Bm, Em, Fsm], "sunrise": [G, A, D], "seasons": [D, Bm, G, A], "legacy": [Bm, G],
    "rebirth": [D, A], "title": [Dadd9],
}
LEVEL = {"void": .35, "bigbang": .5, "planet": .55, "cells": .5, "sprout": .55, "heart": .25, "childhood": .6,
         "youth": .65, "love": .6, "storm": .7, "sunrise": 1.0, "seasons": .65, "legacy": .5, "rebirth": .6, "title": .8}

chords = []
for s in TL["scenes"]:
    prog = PROG[s["id"]]
    step = (s["end"] - s["start"]) / len(prog)
    for i, c in enumerate(prog):
        chords.append((s["start"] + i * step, s["start"] + (i + 1) * step, c, s["id"]))
# the drone must hold until the bang, which happens just inside the next scene
chords[0] = (0, M(EV["bang"]), chords[0][2], "void")
chords[1] = (M(EV["bang"]),) + chords[1][1:]

for s, e, notes, sid in chords:
    quiet = sid in ("void", "heart")
    bright = 3 if quiet else (8 if sid == "sunrise" else 5)
    freqs = [midi(m) for m in notes] + ([midi(notes[-1] + 12)] if sid in ("sunrise", "title") else [])
    add(music, s - 0.3, pad(freqs, (e - s) + 1.6, attack=1.2 if s else 3, release=1.8, bright=bright), gain=0.55 * LEVEL[sid])
    if not quiet:
        n = int((e - s + 0.8) * SR)
        t = np.arange(n) / SR
        root = notes[0] - 12 if notes[0] > 40 else notes[0]
        add(music, s - 0.1, np.sin(2 * np.pi * midi(root) * t) * env_adsr(n, 0.5, 0.8), gain=0.16 * LEVEL[sid])
        if s >= SC["cells"]["start"] and sid != "legacy":
            add(music, s, piano(midi(notes[0]), 0.55, 4.5), pan=-0.2)


def chord_at(t):
    for s, e, notes, _ in chords:
        if s <= t < e:
            return notes
    return chords[-1][2]


# ---------------------------------------------------------------- piano arpeggios (100 bpm grid)
BEAT = 0.6


def arpeggio(t0, t1, step, pattern, octave=12, vel=0.6, dur=2.6):
    t, k = t0, 0
    while t < t1:
        notes = chord_at(t)
        upper = sorted(set([m + octave for m in notes[1:]] + [notes[1] + octave + 12]))
        m = upper[pattern[k % len(pattern)] % len(upper)]
        v = vel * (1.0 if k % len(pattern) == 0 else 0.7) * (0.9 + 0.2 * rng.random())
        add(music, t + rng.normal(0, 0.005), piano(midi(m), v, dur), pan=float(np.clip((m - 66) / 18, -0.7, 0.7)))
        t += step
        k += 1


ARPS = [  # scene, step, pattern, velocity, octave
    ("cells", BEAT, [0, 1, 2, 3, 2, 1], .42, 12), ("sprout", BEAT / 2, [0, 1, 2, 3, 2, 1], .42, 12),
    ("childhood", BEAT / 2, [0, 2, 1, 3, 2, 4, 3, 1], .48, 12), ("youth", BEAT / 2, [0, 1, 2, 3, 4, 3, 2, 1], .55, 0),
    ("love", BEAT / 2, [0, 2, 3, 2], .42, 12), ("sunrise", BEAT / 2, [0, 1, 2, 3, 4, 3, 2, 1], .55, 12),
    ("seasons", BEAT / 2, [0, 1, 2, 3, 2, 1], .45, 12), ("legacy", BEAT, [3, 2, 1, 0], .32, 24),
    ("rebirth", BEAT / 2, [0, 1, 2, 3], .4, 12),
]
for sid, step, pat, vel, octv in ARPS:
    arpeggio(SC[sid]["start"] + 0.05, SC[sid]["end"] - 0.1, step, pat, octave=octv, vel=vel)

# ---------------------------------------------------------------- melodies (written against the original clock)
melody = [
    (79.0, 74, 1.2), (80.2, 73, .6), (80.8, 71, 1.6), (82.6, 69, 1.0), (83.6, 71, .6), (84.2, 74, 1.8), (86.2, 78, 2.0),
    (98.4, 74, 1.0), (99.4, 76, .5), (99.9, 78, 1.5), (101.4, 81, 1.0), (102.4, 79, .5), (102.9, 78, 1.6),
    (104.6, 76, .8), (105.4, 78, .8), (106.2, 81, 2.4),
    (131.0, 69, 1.4), (132.4, 71, .7), (133.1, 74, 2.0), (135.2, 73, 1.0), (136.2, 71, .7), (136.9, 69, 2.4),
    (141.0, 74, 1.4), (142.4, 76, .7), (143.1, 78, 2.2), (145.4, 74, 4.5),
]
for t, m, l in melody:
    v = 0.75 if 98 <= t < 108 else 0.6
    add(music, M(t), piano(midi(m), v, max(3.0, l + 2.0)), pan=0.1)
    add(music, M(t), piano(midi(m + 12), v * 0.25, 2.5), pan=0.15)

# bells / sparkles
for t in np.arange(at("childhood", .05), at("childhood", .95), BEAT):
    add(music, t, bell(midi(rng.choice([86, 88, 90, 93]))), pan=rng.uniform(-.8, .8), gain=0.5)
for t in np.arange(at("legacy", .1), at("legacy", .95), BEAT * 1.5):
    add(music, t, bell(midi(rng.choice([81, 83, 86, 90])), 5), pan=rng.uniform(-.8, .8), gain=0.6)
add(music, M(EV["seedDrop"] + 1.8), bell(midi(86), 6, 1.2))
add(music, M(EV["sproutStart"] + 0.3), bell(midi(93), 6, 0.9), pan=0.3)
add(music, at("title", .05), bell(midi(86), 8, 1.0), pan=-0.2)
add(music, at("title", .06), bell(midi(90), 8, 0.7), pan=0.2)

# ---------------------------------------------------------------- sound design
def wind(dur, gain, lo=60, hi=500):
    n = int(dur * SR)
    t = np.arange(n) / SR
    w = spectral_filter(noise(n), lo=lo, hi=hi)
    w /= np.abs(w).max() + 1e-9
    mod = 0.6 + 0.4 * np.sin(2 * np.pi * 0.11 * t) * np.sin(2 * np.pi * 0.047 * t + 1)
    return w * mod * env_adsr(n, 1.5, 1.5) * gain


bang = M(EV["bang"])
add(sfx, 0, wind(bang + 0.5, 0.08, 40, 300))
add(sfx, SC["planet"]["start"], wind(6, 0.06, 80, 900), pan=-0.3)

n = int(2.0 * SR); t = np.arange(n) / SR
riser = spectral_filter(noise(n), lo=300, hi=7000) * (t / t[-1]) ** 3
riser += np.sin(2 * np.pi * (60 * t + 180 * t ** 2)) * (t / t[-1]) ** 2 * 0.5
add(sfx, bang - 2.0, riser / np.abs(riser).max(), gain=0.35)

n = int(6 * SR); t = np.arange(n) / SR
boom = np.sin(2 * np.pi * np.cumsum(30 + 70 * np.exp(-t * 2)) / SR) * np.exp(-t / 1.6)
roar = spectral_filter(noise(n), hi=900) * np.exp(-t / 1.2)
roar /= np.abs(roar).max()
add(sfx, bang, boom * 0.9 + roar * 0.5, gain=1.8)

for _ in range(50):
    n = int(0.09 * SR); t = np.arange(n) / SR
    f0 = rng.uniform(500, 1400)
    b = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 3 * t / t[-1])) / SR) * np.exp(-t / 0.03)
    add(sfx, rng.uniform(at("cells", .05), at("cells", .95)), b, pan=rng.uniform(-.8, .8), gain=0.05)
n = int(6 * SR)
add(sfx, SC["cells"]["start"], spectral_filter(noise(n), lo=40, hi=250) * 0.04 * env_adsr(n, 1, 1))

for hb in EV["heartbeats"]:
    for dt, f, g in [(0.0, 55, 1.0), (0.16, 48, 0.7)]:
        n = int(0.3 * SR); t = np.arange(n) / SR
        thump = np.sin(2 * np.pi * np.cumsum(f * (1 + 1.5 * np.exp(-t * 40))) / SR) * np.exp(-t / 0.07) * np.minimum(1, t / 0.004)
        add(sfx, M(hb) - 0.012 + dt, thump, gain=0.85 * g)

for _ in range(18):
    t0 = rng.uniform(at("childhood", .05), at("childhood", .9))
    for j in range(rng.integers(2, 5)):
        n = int(0.07 * SR); t = np.arange(n) / SR
        f0 = rng.uniform(2800, 4200)
        c = np.sin(2 * np.pi * np.cumsum(f0 + 1500 * np.sin(np.pi * t / t[-1])) / SR) * np.sin(np.pi * t / t[-1]) ** 2
        add(sfx, t0 + j * 0.09, c, pan=rng.uniform(-.9, .9), gain=0.025)

k_youth = (SC["youth"]["end"] - SC["youth"]["start"]) / (SC["youth"]["src"][1] - SC["youth"]["src"][0])
for ft in EV["fireworks"]:
    pan = rng.uniform(-.7, .7)
    lead = 0.88 * k_youth
    n = int(lead * SR); t = np.arange(n) / SR
    whistle = np.sin(2 * np.pi * np.cumsum(900 + 1400 * t / t[-1]) / SR) * (t / t[-1]) * 0.15
    add(sfx, M(ft) - lead, whistle, pan=pan, gain=0.25)
    n = int(2.0 * SR); t = np.arange(n) / SR
    burst = spectral_filter(noise(n), hi=2500) * np.exp(-t / 0.3)
    burst += np.sin(2 * np.pi * np.cumsum(70 * np.exp(-t * 3) + 30) / SR) * np.exp(-t / 0.35)
    add(sfx, M(ft), burst / np.abs(burst).max(), pan=pan, gain=0.45)
    for _ in range(30):
        cn = 180
        add(sfx, M(ft) + 0.15 + rng.exponential(0.3), noise(cn) * np.exp(-np.arange(cn) / 25), pan=pan + rng.uniform(-.3, .3), gain=0.12)

st = SC["storm"]
n = int((st["end"] - st["start"] + 1.5) * SR)
rain = spectral_filter(noise(n), lo=900, hi=9000) * env_adsr(n, 0.8, 1.2)
add(sfx, st["start"] - 0.5, rain / np.abs(rain).max(), gain=0.16)
add(sfx, st["start"] - 0.5, wind(n / SR, 0.18, 50, 700), pan=0.4)
for lt in EV["lightning"]:
    n = int(4 * SR); t = np.arange(n) / SR
    crack = spectral_filter(noise(n), lo=200, hi=5000) * np.exp(-t / 0.12)
    rumble = spectral_filter(noise(n), hi=160) * np.exp(-t / 1.3) * (1 + 0.5 * np.sin(2 * np.pi * 3 * t))
    add(sfx, M(lt), crack / (np.abs(crack).max() + 1e-9) * 0.4, pan=rng.uniform(-.6, .6), gain=0.8)
    add(sfx, M(lt) + 0.12, rumble / (np.abs(rumble).max() + 1e-9), gain=1.2)

su = SC["sunrise"]
n = int((su["end"] - su["start"] + 1) * SR)
add(sfx, su["start"] - 0.5, spectral_filter(noise(n), lo=100, hi=1200) * 0.05 *
    (0.6 + 0.4 * np.sin(2 * np.pi * 0.25 * np.arange(n) / SR)) * env_adsr(n, 1, 1))
add(sfx, at("seasons", .55), wind(5, 0.08, 400, 5000), pan=-0.4)

# ---------------------------------------------------------------- narration
raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(Path(__file__).parent / "vo/narration.mp3"),
                      "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True, check=True).stdout
vo_src = np.frombuffer(raw, "<f4").astype(float)
voice = np.zeros(N)
for c in TL["vo"]:
    a, b = int((c["from"] - 0.04) * SR), int((c["to"] + 0.18) * SR)
    seg = vo_src[max(0, a):b].copy()
    fade = int(0.03 * SR)
    seg[:fade] *= np.linspace(0, 1, fade)
    seg[-fade:] *= np.linspace(1, 0, fade)
    i = int((c["at"] - 0.04) * SR)
    voice[i:i + len(seg)] += seg[: N - i]
voice = spectral_filter(voice, lo=70)               # clean up rumble
voice /= np.abs(voice).max() + 1e-9

# ducking envelope: smoothed voice level, fast attack, slow release
frame = int(0.02 * SR)
lev = np.sqrt(np.convolve(voice ** 2, np.ones(frame) / frame, "same"))
lev = np.clip(lev / (np.percentile(lev[lev > 1e-4], 90) + 1e-9), 0, 1)
duck = np.empty_like(lev)
g = 0.0
att, rel = np.exp(-1 / (0.03 * SR)), np.exp(-1 / (0.5 * SR))
# a per-sample IIR is slow in Python; run it on 10 ms blocks and interpolate
blk = int(0.01 * SR)
lv = lev[::blk]
out = np.empty_like(lv)
for j, x in enumerate(lv):
    c = att if x > g else rel
    g = c * g + (1 - c) * x
    out[j] = g
duck = np.interp(np.arange(N), np.arange(len(lv)) * blk, out)

# ---------------------------------------------------------------- reverb + master
def reverb(x, seconds, wet, seed):
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = np.zeros_like(x)
    for ch in range(2):
        ir = r.standard_normal(n) * np.exp(-t / (seconds / 6.9))
        ir = spectral_filter(ir, hi=6000)
        ir[: int(0.012 * SR)] = 0   # pre-delay
        ir /= np.sqrt((ir ** 2).sum())
        L = 1 << int(np.ceil(np.log2(len(x[ch]) + n)))
        y = np.fft.irfft(np.fft.rfft(x[ch], L) * np.fft.rfft(ir, L), L)[: len(x[ch])]
        out[ch] = x[ch] * (1 - wet) + y * wet * 2.2
    return out


music = reverb(music, 4.0, 0.42, 1)
sfx = reverb(sfx, 2.0, 0.2, 2)
voice_st = reverb(np.vstack([voice, voice]), 1.2, 0.08, 3)

bed = music * (1 - 0.55 * duck) + sfx * 0.9 * (1 - 0.35 * duck)
bed /= np.percentile(np.abs(bed), 99.95) + 1e-9
mix = bed * 0.55 + voice_st * 0.95

t = np.arange(N) / SR
mix *= np.clip(t / 0.6, 0, 1) * np.clip((DUR - t) / 2.5, 0, 1)
mix /= np.percentile(np.abs(mix), 99.97) + 1e-9
mix = np.tanh(mix * 0.9) * 0.92   # soft limiter

out = sys.argv[1] if len(sys.argv) > 1 else "life.wav"
pcm = (np.clip(mix.T, -1, 1) * 32767).astype("<i2")
with wave.open(out, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("wrote", out, f"{DUR}s")
