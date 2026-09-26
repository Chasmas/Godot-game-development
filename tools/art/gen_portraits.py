#!/usr/bin/env python3
"""
Painted dialogue portraits, same hand as the story shots: noir split light,
grime, stubble, scars. Three frames each so the portrait stays alive:
<id>.png (rest), <id>_talk.png (mouth open), <id>_blink.png.
Cass has a second set with the gold star (after she paints it on).

  python3 tools/art/gen_portraits.py   -> assets/characters/portraits/
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from paint import *
from props import *

S = 112
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "characters", "portraits")

CAST = {
    "cass": dict(skin="e6a888", hair="5a1612", jacket="7a1420", light=(1, -0.3), light_col="ffc0a0", fill_col="4030a0",
                 hair_style="long", look=(0.5, 0), brows=0.35, shirt="d8d0c8", grime=0.35, earring=True, bruise=True, bg=("1a0612", "3a0a24")),
    "tommy": dict(skin="dca080", hair="2a140c", jacket="23386a", light=(-1, -0.2), light_col="80d0ff", fill_col="ff4060",
                  hair_style="short", look=(-0.5, 0.1), brows=-0.2, mouth=0.4, stubble=True, shirt="c8c0b0", collar="lapel", cig=True, bg=("05050c", "10183a")),
    "harcourt": dict(skin="e0b090", hair="d8d0c0", jacket="e8dcc0", light=(1, -0.4), light_col="ffe0a0", fill_col="7a1030",
                     hair_style="silver", mouth=0.8, brows=0.4, shirt="f4f0e8", tie="7a1030", collar="lapel", glasses=True, jaw=0.95, bg=("1a0a10", "3a1018")),
    "earl": dict(skin="e8b090", hair="4a3020", jacket="f07ab0", light=(-1, -0.3), light_col="a0f0ff", fill_col="ff6ab0",
                 hair_style="balding", look=(0.3, 0.2), brows=-0.4, mouth=-0.3, stubble=True, shirt="f0e8a0", collar="popped", sweat=True, bg=("0c1016", "1a2a3a")),
    "anchor": dict(skin="e6b494", hair="c8a060", jacket="203060", light=(1, -0.3), light_col="ffffff", fill_col="4060c0",
                   hair_style="helmet", mouth=1.2, shirt="e8e8f0", tie="a01828", collar="lapel", bg=("101830", "1a3060")),
    "guard": dict(skin="c98f6b", hair="1b1410", jacket="1f6a68", light=(1, -0.3), light_col="a0fff0", fill_col="2a1a4a",
                  hair_style="cap", look=(0.4, 0), brows=0.5, mouth=-0.2, stubble=True, scar=True, shirt="d0d8d0", collar="lapel", bg=("06100e", "10302c")),
    "marv": dict(skin="e0b090", hair="1e1e24", jacket="7a1030", light=(1, -0.4), light_col="ffe8a0", fill_col="ff3d7f",
                 hair_style="slick", mouth=1.6, brows=0.5, shirt="f0e8e0", tie="ffd23f", collar="lapel", bg=("1a0808", "4a1020")),
}

def paint(id_, cfg, **over):
    L = Layer(S, S)
    bg0, bg1 = cfg.get("bg", ("101010", "202020"))
    L.vgrad([(0, bg0), (1, bg1)], 0, S)
    lc = cfg.get("light_col", "ffffff")
    L.radial(S * (0.85 if cfg.get("light", (1, 0))[0] > 0 else 0.15), S * 0.2, S * 0.9, lc, 1.6, 0.25)
    args = {k: v for k, v in cfg.items() if k != "bg"}
    args.update(over)
    face(L, S * 0.5, S * 0.47, S * 0.2, **args)
    vignette(L, 0.55)
    grain(L, 0.02, hash(id_) % 99)
    return L

def main():
    os.makedirs(OUT, exist_ok=True)
    for id_, cfg in CAST.items():
        sets = [("", {})]
        if id_ == "cass":
            sets.append(("_star", {"star": True, "hair_style": "ponytail"}))
        for suffix, extra in sets:
            base = dict(cfg, **extra)
            mouth_rest = base.get("mouth", 0.0)
            for frame, over in (("", {}), ("_talk", {"open_": 1.0, "mouth": mouth_rest * 0.5}), ("_blink", {"blink": True})):
                L = paint(id_, base, **over)
                save(L, os.path.join(OUT, f"{id_}{suffix}{frame}.png"), True, 24)
        print("portrait", id_)

if __name__ == "__main__":
    main()
