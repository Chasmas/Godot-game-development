#!/usr/bin/env python3
"""
80s poster dialogue portraits, same hand as the story shots: flat cel
colour, ink outline, neon rims (the cast lives in retro.py). Three frames each so the portrait stays alive:
<id>.png (rest), <id>_talk.png (mouth open), <id>_blink.png.
Cass has a second set with the gold star (after she paints it on).

  python3 tools/art/gen_portraits.py   -> assets/characters/portraits/
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from paint import *
from props import *
from retro import *

S = 112
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "characters", "portraits")

BG = {
    "cass": ("1a0630", "a0206a"), "tommy": ("05051a", "1a3a7a"), "harcourt": ("1a0a14", "6a1a3a"),
    "earl": ("0a1a24", "1a6a7a"), "anchor": ("0a1030", "2a4aa0"), "guard": ("061410", "1a5a50"),
    "marv": ("1a0616", "8a1a4a"),
}

def paint(id_, **over):
    """80s poster portrait (see retro.py): gradient backdrop with a sun
    glow, the bust in flat cel colour with neon rims."""
    L = Layer(S, S)
    b0, b1 = BG[id_]
    L.vgrad([(0, b0), (1, b1)], 0, S)
    L.radial(S * 0.78, S * 0.28, S * 0.7, "ff3d7f", 1.8, 0.25)
    L.radial(S * 0.15, S * 0.9, S * 0.6, "35e0ff", 1.8, 0.15)
    for i in range(5):
        L.add(line(L, [(0, S * (0.8 + i * 0.045)), (S, S * (0.8 + i * 0.045))], 1), col("ff3d7f"), 0.08)
    kw = dict(over)
    bust(L, S * 0.5, S * 0.44, 24, CAST[id_], **kw)
    vignette(L, 0.45)
    grain(L, 0.015, hash(id_) % 99)
    return L

def main():
    os.makedirs(OUT, exist_ok=True)
    for id_ in BG:
        sets = [("", {"aviators_up": True} if id_ == "cass" else {})]
        if id_ == "cass":
            sets.append(("_star", {"star": True, "hair_style": "ponytail"}))
        for suffix, extra in sets:
            for frame, over in (("", {}), ("_talk", {"talk": True}), ("_blink", {"blink": True})):
                L = paint(id_, **extra, **over)
                save(L, os.path.join(OUT, f"{id_}{suffix}{frame}.png"), True, 24)
        print("portrait", id_)

if __name__ == "__main__":
    main()
