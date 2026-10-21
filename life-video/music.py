"""Original score + sound design for "החיים", synthesized from scratch with numpy.

Reads timeline.json so every boom, heartbeat, firework and thunderclap lands on
the frame where it happens on screen.  usage: python3 music.py out.wav
"""
import json
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


# ---------------------------------------------------------------- harmony
# D major / B minor.  (start, end, midi notes)
D, A, Bm, G, Em, Fsm = [50, 57, 62, 66], [45, 57, 61, 64], [47, 54, 62, 66], [43, 55, 59, 62], [40, 55, 59, 64], [42, 54, 57, 61]
Dadd9 = [38, 50, 57, 64, 66]
chords = [
    (0, 9.4, [38, 45]),                    # drone in the void
    (9.4, 14, D), (14, 19, A),
    (19, 24, Bm), (24, 29, G),
    (29, 34, D), (34, 39, A),
    (39, 44.5, Bm), (44.5, 50, G),
    (50, 58, [38, 45, 50]),                # heartbeat: open fifth, nearly silent
    (58, 61.3, D), (61.3, 64.6, A), (64.6, 68, G),
    (68, 70.5, Bm), (70.5, 73, G), (73, 75.5, D), (75.5, 78, A),
    (78, 81.3, G), (81.3, 84.6, D), (84.6, 88, A),
    (88, 91.3, Bm), (91.3, 94.6, Em), (94.6, 98, Fsm),
    (98, 101.3, G), (101.3, 104.6, A), (104.6, 108, D),
    (108, 111, D), (111, 114, Bm), (114, 117, G), (117, 120, A),
    (120, 125, Bm), (125, 130, G),
    (130, 135, D), (135, 140, A),
    (140, 150, Dadd9),
]

# pad level per section (dynamic arc of the film)
def pad_gain(t):
    pts = [(0, .35), (9, .5), (19, .55), (29, .5), (50, .25), (58, .55), (68, .6), (78, .6), (88, .7),
           (98, 1.0), (108, .65), (120, .5), (130, .6), (140, .75), (150, .5)]
    xs, ys = zip(*pts)
    return float(np.interp(t, xs, ys))


for s, e, notes in chords:
    bright = 3 if e <= 9.4 or 50 <= s < 58 else (8 if 98 <= s < 108 else 5)
    freqs = [midi(m) for m in notes] + ([midi(notes[-1] + 12)] if 98 <= s < 108 or s >= 140 else [])
    sig = pad(freqs, (e - s) + 2.2, attack=1.8 if s else 4, release=2.5, bright=bright)
    add(music, s - 0.4, sig, pan=0, gain=0.55 * pad_gain(s))

# sub bass under the chords from the bang on
for s, e, notes in chords:
    if s < 9.4 or 50 <= s < 58:
        continue
    n = int((e - s + 1) * SR)
    t = np.arange(n) / SR
    b = np.sin(2 * np.pi * midi(notes[0] - 12 if notes[0] > 40 else notes[0]) * t) * env_adsr(n, 0.8, 1.2)
    add(music, s - 0.2, b, gain=0.22 * pad_gain(s))


def chord_at(t):
    for s, e, notes in chords:
        if s <= t < e:
            return notes
    return chords[-1][2]


# ---------------------------------------------------------------- piano arpeggios
def arpeggio(t0, t1, step, pattern, octave=12, vel=0.6, swing=0.0, dur=3.0):
    t = t0
    k = 0
    while t < t1:
        notes = chord_at(t)
        upper = sorted(set([m + octave for m in notes[1:]] + [notes[1] + octave + 12]))
        m = upper[pattern[k % len(pattern)] % len(upper)]
        v = vel * (1.0 if k % len(pattern) == 0 else 0.7) * (0.9 + 0.2 * rng.random())
        add(music, t + (swing * step if k % 2 else 0) + rng.normal(0, 0.006), piano(midi(m), v, dur),
            pan=np.clip((m - 66) / 18, -0.7, 0.7))
        t += step
        k += 1


arpeggio(29.5, 49.6, 0.62, [0, 1, 2, 3, 2, 1], vel=0.45)          # life begins: slow, curious
arpeggio(58.2, 67.8, 0.31, [0, 2, 1, 3, 2, 4, 3, 1], vel=0.5)     # childhood: playful
arpeggio(68.0, 77.8, 0.27, [0, 1, 2, 3, 4, 3, 2, 1], vel=0.55, octave=0)  # youth: driving
arpeggio(78.0, 87.8, 0.42, [0, 2, 3, 2], vel=0.45)                # love
arpeggio(98.0, 107.8, 0.30, [0, 1, 2, 3, 4, 3, 2, 1], vel=0.55)   # sunrise
arpeggio(108.0, 119.8, 0.36, [0, 1, 2, 3, 2, 1], vel=0.45)        # seasons
arpeggio(120.0, 129.6, 0.85, [3, 2, 1, 0], vel=0.32, octave=24)   # legacy: sparse, high
arpeggio(130.0, 139.6, 0.48, [0, 1, 2, 3], vel=0.4)               # rebirth

# bass notes on the downbeat of each chord, from the first sprout onward
for s, e, notes in chords:
    if s >= 29 and not (50 <= s < 58) and not (120 <= s < 130):
        add(music, s, piano(midi(notes[0]), 0.55, 5), pan=-0.2)

# ---------------------------------------------------------------- melodies
# (time, midi, length)  D major
melody = [
    # love — a simple question and answer
    (79.0, 74, 1.2), (80.2, 73, .6), (80.8, 71, 1.6), (82.6, 69, 1.0), (83.6, 71, .6), (84.2, 74, 1.8), (86.2, 78, 2.0),
    # sunrise — the theme opens up
    (98.4, 74, 1.0), (99.4, 76, .5), (99.9, 78, 1.5), (101.4, 81, 1.0), (102.4, 79, .5), (102.9, 78, 1.6),
    (104.6, 76, .8), (105.4, 78, .8), (106.2, 81, 2.4),
    # rebirth — the theme returns, quieter
    (131.0, 69, 1.4), (132.4, 71, .7), (133.1, 74, 2.0), (135.2, 73, 1.0), (136.2, 71, .7), (136.9, 69, 2.4),
    # title — last statement
    (141.0, 74, 1.4), (142.4, 76, .7), (143.1, 78, 2.2), (145.4, 74, 4.5),
]
for t, m, l in melody:
    v = 0.75 if 98 <= t < 108 else 0.6
    add(music, t, piano(midi(m), v, max(3.5, l + 2.5)), pan=0.1)
    add(music, t, piano(midi(m + 12), v * 0.25, 3), pan=0.15)

# bells / sparkles
for t in np.arange(60, 67.5, 0.93):
    add(music, t, bell(midi(rng.choice([86, 88, 90, 93]))), pan=rng.uniform(-.8, .8), gain=0.6)
for t in np.arange(122, 129.5, 1.27):
    add(music, t, bell(midi(rng.choice([81, 83, 86, 90])), 5), pan=rng.uniform(-.8, .8), gain=0.7)
add(music, EV["seedDrop"] + 1.8, bell(midi(86), 6, 1.2), gain=1.0)        # the seed lands
add(music, EV["sproutStart"] + 0.3, bell(midi(93), 6, 0.9), pan=0.3)
add(music, 141.0, bell(midi(86), 8, 1.0), pan=-0.2)
add(music, 141.05, bell(midi(90), 8, 0.7), pan=0.2)

# ---------------------------------------------------------------- sound design
def wind(t0, t1, gain, lo=60, hi=500):
    n = int((t1 - t0) * SR)
    t = np.arange(n) / SR
    w = spectral_filter(noise(n), lo=lo, hi=hi)
    w /= np.abs(w).max() + 1e-9
    mod = 0.6 + 0.4 * np.sin(2 * np.pi * 0.11 * t) * np.sin(2 * np.pi * 0.047 * t + 1)
    return w * mod * env_adsr(n, 2.5, 2.5) * gain


add(sfx, 0, wind(0, 10, 0.08, 40, 300))
add(sfx, 19, wind(19, 29.5, 0.06, 80, 900), pan=-0.3)

# riser into the big bang
n = int(2.6 * SR); t = np.arange(n) / SR
riser = spectral_filter(noise(n), lo=300, hi=7000) * (t / t[-1]) ** 3
riser += np.sin(2 * np.pi * (60 * t + 140 * t ** 2)) * (t / t[-1]) ** 2 * 0.5
add(sfx, EV["bang"] - 2.6, riser / np.abs(riser).max(), gain=0.35)

# the bang: sub drop + roar
n = int(7 * SR); t = np.arange(n) / SR
boom = np.sin(2 * np.pi * np.cumsum(30 + 70 * np.exp(-t * 2)) / SR) * np.exp(-t / 2.0)
roar = spectral_filter(noise(n), hi=900) * np.exp(-t / 1.4)
roar /= np.abs(roar).max()
add(sfx, EV["bang"], boom * 0.9 + roar * 0.5, gain=1.8)

# underwater: bubbles rising during the cells
for _ in range(70):
    t0 = rng.uniform(29.5, 38.5)
    n = int(0.09 * SR); t = np.arange(n) / SR
    f0 = rng.uniform(500, 1400)
    b = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 3 * t / t[-1])) / SR) * np.exp(-t / 0.03)
    add(sfx, t0, b, pan=rng.uniform(-.8, .8), gain=0.05)
add(sfx, 29, spectral_filter(noise(int(10 * SR)), lo=40, hi=250) * 0.04 * env_adsr(int(10 * SR), 1.5, 1.5))

# heartbeat (lub-dub) on the ECG spikes
for hb in EV["heartbeats"]:
    for dt, f, g in [(0.0, 55, 1.0), (0.2, 48, 0.7)]:
        n = int(0.35 * SR); t = np.arange(n) / SR
        thump = np.sin(2 * np.pi * np.cumsum(f * (1 + 1.5 * np.exp(-t * 40))) / SR) * np.exp(-t / 0.08) * np.minimum(1, t / 0.004)
        add(sfx, hb - 0.012 + dt, thump, gain=0.85 * g)

# children laughing would be uncanny from a synth — birdsong chirps instead
for _ in range(26):
    t0 = rng.uniform(58.5, 67)
    for j in range(rng.integers(2, 5)):
        n = int(0.07 * SR); t = np.arange(n) / SR
        f0 = rng.uniform(2800, 4200)
        c = np.sin(2 * np.pi * np.cumsum(f0 + 1500 * np.sin(np.pi * t / t[-1])) / SR) * np.sin(np.pi * t / t[-1]) ** 2
        add(sfx, t0 + j * 0.09, c, pan=rng.uniform(-.9, .9), gain=0.025)

# fireworks: launch whistle, burst, crackle
for i, ft in enumerate(EV["fireworks"]):
    pan = rng.uniform(-.7, .7)
    n = int(0.85 * SR); t = np.arange(n) / SR
    whistle = np.sin(2 * np.pi * np.cumsum(900 + 1400 * t / t[-1]) / SR) * (t / t[-1]) * 0.15
    add(sfx, ft - 0.88, whistle, pan=pan, gain=0.25)
    n = int(2.5 * SR); t = np.arange(n) / SR
    burst = spectral_filter(noise(n), hi=2500) * np.exp(-t / 0.35)
    burst += np.sin(2 * np.pi * np.cumsum(70 * np.exp(-t * 3) + 30) / SR) * np.exp(-t / 0.4)
    add(sfx, ft, burst / np.abs(burst).max(), pan=pan, gain=0.45)
    for _ in range(40):
        cn = 180
        click = noise(cn) * np.exp(-np.arange(cn) / 25)
        add(sfx, ft + 0.25 + rng.exponential(0.5), click, pan=pan + rng.uniform(-.3, .3), gain=0.12)

# storm: rain bed, wind, thunder
n = int(11.5 * SR)
rain = spectral_filter(noise(n), lo=900, hi=9000) * env_adsr(n, 1.5, 2.0)
rain /= np.abs(rain).max()
add(sfx, 87.5, rain, gain=0.16)
add(sfx, 87.5, wind(87.5, 99, 0.18, 50, 700), pan=0.4)
for lt in EV["lightning"]:
    n = int(5 * SR); t = np.arange(n) / SR
    crack = spectral_filter(noise(n), lo=200, hi=5000) * np.exp(-t / 0.12)
    rumble = spectral_filter(noise(n), hi=160) * np.exp(-t / 1.6) * (1 + 0.5 * np.sin(2 * np.pi * 3 * t))
    rumble /= np.abs(rumble).max() + 1e-9
    crack /= np.abs(crack).max() + 1e-9
    add(sfx, lt, crack * 0.4, pan=rng.uniform(-.6, .6), gain=0.8)
    add(sfx, lt + 0.15, rumble, gain=1.2)

# sunrise: gentle waves and gulls
add(sfx, 97.5, spectral_filter(noise(int(11 * SR)), lo=100, hi=1200) * 0.05 *
    (0.6 + 0.4 * np.sin(2 * np.pi * 0.15 * np.arange(int(11 * SR)) / SR)) * env_adsr(int(11 * SR), 2, 2))
# seasons: wind through leaves in autumn
add(sfx, 113, wind(113, 121, 0.08, 400, 5000), pan=-0.4)

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


music = reverb(music, 4.5, 0.42, 1)
sfx = reverb(sfx, 2.0, 0.2, 2)
mix = music + sfx * 0.9

t = np.arange(N) / SR
mix *= np.clip(t / 1.0, 0, 1) * np.clip((DUR - t) / 3.5, 0, 1)
mix /= np.percentile(np.abs(mix), 99.95) + 1e-9
mix = np.tanh(mix * 0.9) * 0.92   # soft limiter

out = sys.argv[1] if len(sys.argv) > 1 else "life.wav"
pcm = (np.clip(mix.T, -1, 1) * 32767).astype("<i2")
with wave.open(out, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print("wrote", out, f"{DUR}s")
