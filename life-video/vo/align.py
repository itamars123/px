import json, re, sys
from pocketsphinx import Decoder
text = open(sys.argv[1]).read()
words = re.findall(r"[a-z']+", text.lower())
d = Decoder(samprate=16000, bestpath=False)
d.set_align_text(" ".join(words))
d.start_utt(); d.process_raw(open(sys.argv[2], 'rb').read(), full_utt=True); d.end_utt()
d.set_alignment(); d.start_utt(); d.process_raw(open(sys.argv[2], 'rb').read(), full_utt=True); d.end_utt()
al = d.get_alignment()
out = []
for w in al:
    if w.name in ('<sil>', '<s>', '</s>') or w.name.startswith('+'): continue
    out.append({"w": w.name, "s": w.start / 100, "e": (w.start + w.duration) / 100})
print(len(words), len(out))
json.dump(out, open(sys.argv[3], 'w'), indent=0)
for o in out: print(o)
