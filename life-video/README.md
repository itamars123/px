# Life: a short film

An 87-second film (1920×1080, 30 fps) about the journey of a life: from the silence
before the Big Bang, through the first cell, childhood, youth, love, storms and sunrise,
to the turning seasons and the seed that starts everything again.

Every frame is drawn in code (Canvas 2D). The score and sound design are synthesized
from scratch with numpy, and every boom, heartbeat, firework and thunderclap lands
on its frame. The narration is a male storyteller voice ("George", ElevenLabs, generated
through vidIQ). It is aligned word by word with PocketSphinx and drives karaoke captions
on a frosted-glass bar. The music ducks under the voice.

**Final film:** [`life.mp4`](life.mp4) · the earlier 2:30 Hebrew cut: [`life-he.mp4`](life-he.mp4)

## Scenes

| Time | Scene | Narration |
|---|---|---|
| 0:00 | The void, one spark | In the beginning... there was only silence. |
| 0:05 | Big Bang → spiral galaxy | And then... light. |
| 0:11 | A planet forms | From dust and fire, a world was born. |
| 0:16 | Ocean, a cell divides | Life began small. Impossibly small. |
| 0:22 | A seed becomes a tree | And slowly... it learned to grow. |
| 0:28 | ECG heartbeat | A first heartbeat. |
| 0:32 | Balloons, kite, meadow | Childhood. Everything is new. Everything is possible. |
| 0:38 | City at night, fireworks | Youth. To run. To dream. To dare. |
| 0:44 | Two lights meet | Then someone arrives... and the whole world changes. |
| 0:50 | Storm at sea | There are storms. There are falls. |
| 0:56 | Sunrise, calm sea | But we always rise again. |
| 1:01 | Spring → winter | Time moves on. The seasons turn. |
| 1:08 | Lanterns become stars | And what remains... is the light we leave in others. |
| 1:14 | A seed falls, a new sprout | Because every ending... is a new beginning. |
| 1:20 | Title: LIFE | This is life. Live it. All the way. |

## Rebuild

```bash
python3 build_timeline.py                     # scene slots + word-timed captions → timeline.json
node render.mjs out 4                         # frames → video (Playwright + Chromium + ffmpeg)
ffmpeg -f concat -safe 0 -i out/segments.txt -c copy out/video.mp4
python3 music.py out/life.wav                 # score + sound design + narration
ffmpeg -i out/video.mp4 -i out/life.wav -c:v libx264 -crf 23 -tune grain -c:a aac -b:a 224k -shortest life.mp4
```

To re-align a new narration: `python3 vo/align.py vo/script.txt <16 kHz mono s16le raw> vo/words.json`
(needs `pip install pocketsphinx`).

To watch it live in a browser, serve the folder (e.g. `npx serve`) and open `render.html?play`.
The live preview plays the picture only, with no sound.

- `timeline.json`: scenes, word-timed captions, narration placement, event timing
- `scenes.js`: all scenes; each frame is a pure function of time
- `music.py`: score, sound design, narration mix and ducking
- `vo/`: narration script, audio and word alignment
- `fonts/`: Montserrat and Playfair Display (OFL)
