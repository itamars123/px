"""Builds timeline.json for the English cut from the scene plan and the aligned narration.

Each scene keeps its original animation (`src`, in the 150 s cut's clock) but plays
it compressed into its new, shorter slot. Each narration line is placed inside its
scene, and every word carries its own timestamp for the karaoke captions.
usage: python3 build_timeline.py
"""
import json
import re
from pathlib import Path

HERE = Path(__file__).parent

# id, original span (seconds in the 150 s cut), new duration
PLAN = [
    ("void", 0, 9, 5.0), ("bigbang", 9, 19, 6.0), ("planet", 19, 29, 5.5), ("cells", 29, 39, 5.5),
    ("sprout", 39, 50, 6.0), ("heart", 50, 58, 4.5), ("childhood", 58, 68, 6.0), ("youth", 68, 78, 6.0),
    ("love", 78, 88, 6.0), ("storm", 88, 98, 5.5), ("sunrise", 98, 108, 5.5), ("seasons", 108, 120, 7.0),
    ("legacy", 120, 130, 6.0), ("rebirth", 130, 140, 6.0), ("title", 140, 150, 6.5),
]
# when each narration line starts, relative to its scene's start
VO_OFFSET = {"void": 1.0, "bigbang": 0.9, "title": 0.9}
DEFAULT_OFFSET = 0.6

lines = [l.strip() for l in (HERE / "vo/script.txt").read_text().splitlines() if l.strip()]
aligned = json.loads((HERE / "vo/words.json").read_text())
assert len(lines) == len(PLAN)

scenes, captions, vo_clips = [], [], []
t = 0.0
k = 0
for (sid, s0, s1, dur), line in zip(PLAN, lines):
    scenes.append({"id": sid, "start": round(t, 3), "end": round(t + dur, 3), "src": [s0, s1]})
    tokens = line.split()
    ws = aligned[k:k + len(tokens)]
    k += len(tokens)
    for tok, a in zip(tokens, ws):
        assert re.sub(r"[^a-z']", "", tok.lower()) == re.sub(r"\(\d\)", "", a["w"]), (tok, a)
    clip_start, clip_end = ws[0]["s"], ws[-1]["e"]
    at = t + VO_OFFSET.get(sid, DEFAULT_OFFSET)
    assert at + (clip_end - clip_start) < t + dur, sid
    vo_clips.append({"at": round(at, 3), "from": clip_start, "to": clip_end})
    captions.append({
        "start": round(at, 3), "end": round(at + clip_end - clip_start, 3),
        "words": [{"w": tok, "s": round(at + a["s"] - clip_start, 3), "e": round(at + a["e"] - clip_start, 3)}
                  for tok, a in zip(tokens, ws)],
    })
    t += dur

old = json.loads((HERE / "timeline.json").read_text())
tl = {
    "width": 1920, "height": 1080, "fps": 30, "duration": round(t, 3), "fade": 1.0,
    "scenes": scenes, "captions": captions, "vo": vo_clips,
    # visual events stay on the original clock; the scenes play them through `src`
    "events": old["events"],
}
(HERE / "timeline.json").write_text(json.dumps(tl, ensure_ascii=False, indent=1))
print("duration", t)
