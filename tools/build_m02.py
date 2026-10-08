#!/usr/bin/env python3
"""Authoring script for Mission 02 'Dog Days' - Yermo Salvage & K-9.
Same legend as tools/build_m01.py. Writes levels/m02_yermo_salvage.json."""
import json, os
W, H = 66, 50
g = [[' '] * W for _ in range(H)]
def fill(x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = ch
def hline(x0, x1, y, ch='#'): fill(x0, y, x1, y, ch)
def vline(x, y0, y1, ch='#'): fill(x, y0, x, y1, ch)
def put(x, y, ch): g[y][x] = ch

fill(0, 0, W - 1, H - 1, '#')
fill(1, 44, W - 2, H - 2, ':')          # desert road
fill(1, 20, W - 2, 42, ';')             # the yard
hline(1, W - 2, 43)                     # chain-link fence
fill(8, 43, 11, 43, ';')                # the gate
put(58, 43, '%')                        # rotten fence panel (secret)
# ---------------------------------------------------------------- warehouse
fill(1, 1, 30, 18, '+')
vline(31, 1, 19)
hline(1, 30, 19)
put(13, 19, 'D'); put(14, 19, 'D')
for x in (5, 6, 22, 23): put(x, 19, 'W')
for (x0, y0) in ((4, 4), (4, 9), (14, 4), (14, 9)):
    fill(x0, y0, x0 + 5, y0 + 1, 'c')
fill(24, 3, 28, 4, 'c')
vline(22, 12, 18); hline(22, 30, 12)    # foreman's room
put(22, 15, 'D'); put(22, 16, 'D')
fill(23, 13, 30, 18, '_')
fill(26, 14, 28, 14, 'k')
for p in ((6, 7), (16, 7), (26, 7), (6, 15), (16, 15), (26, 16)): put(*p, '*')
put(11, 2, '^')
put(12, 18, 'S')
# ---------------------------------------------------------------- kennels
fill(32, 1, 47, 18, ',')
vline(48, 1, 19)
hline(32, 47, 19)
put(31, 8, 'D'); put(31, 9, 'D')        # warehouse <-> kennels
put(39, 19, 'D'); put(40, 19, 'D')      # kennels -> yard
for x0 in (33, 37, 41, 45):
    fill(x0, 2, x0 + 2, 4, 'n')
fill(33, 14, 35, 17, 'n'); fill(43, 14, 46, 17, 'n')
fill(39, 9, 41, 9, 'T')
for p in ((36, 7), (44, 7), (36, 12), (44, 12)): put(*p, '*')
put(32, 12, 'S')
# ---------------------------------------------------------------- office trailer + generator shed
fill(49, 1, 64, 10, '.')
hline(49, 64, 11)
fill(49, 12, 64, 18, '+')
hline(49, 64, 19)
put(54, 11, 'D'); put(55, 11, 'D')      # office <-> shed
put(58, 19, 'D'); put(59, 19, 'D')      # shed -> yard
fill(55, 3, 57, 3, 'k'); fill(61, 2, 62, 4, 'b'); put(60, 8, 't'); put(50, 2, 'A')
for p in ((52, 4), (60, 5), (56, 15)): put(*p, '*')
put(50, 9, 'S')
put(50, 13, 'F'); put(51, 13, 'F'); put(53, 13, 'F')
put(62, 14, 'E'); put(62, 15, 'E')
# ---------------------------------------------------------------- the yard
for (x0, y0, x1, y1) in ((4, 23, 7, 24), (15, 27, 16, 30), (24, 23, 27, 24), (34, 30, 37, 31), (46, 24, 47, 27),
                         (55, 28, 58, 29), (20, 35, 23, 36), (42, 37, 45, 38), (52, 35, 53, 38), (8, 33, 9, 36)):
    fill(x0, y0, x1, y1, 'j')
fill(28, 40, 29, 41, 'Z')
fill(38, 24, 39, 25, 'c'); fill(12, 38, 13, 38, 'c'); fill(60, 24, 61, 25, 'c')
for p in ((10, 26), (30, 27), (50, 31), (18, 40), (40, 41), (60, 40), (33, 21), (5, 40)): put(*p, '*')
# ---------------------------------------------------------------- road
fill(3, 45, 6, 46, 'K'); put(7, 45, 'X'); put(8, 47, 'P')
for p in ((15, 46), (35, 46), (55, 46)): put(*p, '*')
put(2, 46, 'R'); put(63, 46, 'R')
# ---------------------------------------------------------------- people, dogs, things
put(20, 31, 'g'); put(21, 32, 'd'); put(6, 26, 'y'); put(48, 33, 'm'); put(58, 33, 'g'); put(41, 21, 'g')
put(16, 12, 'H'); put(8, 7, 'g'); put(26, 15, 'm'); put(12, 2, 'h')
put(40, 11, 'h'); put(34, 8, 'g'); put(36, 10, 'd'); put(44, 10, 'd')
put(56, 5, 's'); put(52, 8, 'd'); put(57, 16, 'g')
put(9, 41, '7'); put(27, 21, '9'); put(60, 17, '2'); put(29, 13, '5'); put(44, 34, '8'); put(46, 6, '0'); put(3, 38, '!')
put(3, 41, 'U'); put(63, 9, 'U'); put(29, 2, 'U')
put(29, 17, '$'); put(58, 2, '&')

rows = [''.join(r) for r in g]
level = {
    "id": "m02_yermo_salvage",
    "name": "Yermo Salvage & K-9",
    "ambient": [0.36, 0.34, 0.54],
    "map": rows,
    "zones": {
        "warehouse": [0, 0, 31, 19], "kennels": [31, 0, 18, 19], "office": [49, 0, 17, 11], "shed": [49, 11, 17, 8],
        "exterior": [0, 19, W, H - 19],
    },
    "power": {"12,18": "warehouse", "32,12": "kennels", "50,9": "office", "50,13": "warehouse", "51,13": "kennels", "53,13": "exterior"},
    "flicker_zones": ["kennels"],
    "wall_colors": {
        "warehouse": ["8a93a0", "3e4654", "ffb030"], "shed": ["8a93a0", "3e4654", "ffd23f"],
        "kennels": ["d8cfa0", "7a6a40", "ff5aa0"], "office": ["a07850", "5a3a22", "35e0ff"],
        "default": ["b0a898", "5a5048", "ff5aa0"],
    },
    "light_colors": {"+": "c8e0ff", ",": "d8f0ff", ".": "ffb070", "_": "ffc080", ";": "ffa040", ":": "ff9a40"},
    "inside_rect": [0, 0, W, 43],
    "time_text": "2:15 AM",
    "objectives": {"infiltrate": "GET INTO THE SALVAGE YARD", "clear": "CLEAR THE YARD", "escape": "GET BACK TO THE CAR",
                   "cleared": "YARD CLEARED", "escape_hint": "NOBODY LEFT TO FEED THE DOGS. BACK TO THE CAR."},
    "enemies": {
        "20,31": {"patrol": [[20, 31], [40, 33], [40, 26], [20, 26]]},
        "21,32": {"patrol": [[21, 32], [41, 34], [41, 27], [21, 27]]},
        "6,26": {"sleep": True, "facing": "right"},
        "48,33": {"facing": "left"}, "58,33": {"idle_action": "watch", "facing": "left"}, "41,21": {"idle_action": "watch", "facing": "down"},
        "16,12": {"facing": "down"}, "8,7": {"patrol": [[8, 7], [8, 12], [20, 12], [20, 7]]},
        "26,15": {"facing": "left"}, "12,2": {"facing": "right"},
        "40,11": {"facing": "down"}, "34,8": {"facing": "right"},
        "36,10": {"sniff": True}, "44,10": {"patrol": [[44, 10], [34, 11], [34, 6], [44, 6]]},
        "56,5": {"facing": "down"}, "52,8": {"sleep": True, "facing": "up"},
        "57,16": {"patrol": [[57, 16], [51, 15], [61, 13]]},
    },
    "collectibles": {
        "29,17": {"id": "tape_vance", "kind": "tape", "title": "VHS: 'HOTSHOT' - STUNT REHEARSAL",
                  "text": "Arlo Vance walks a young man to the edge of a rooftop. 'Don't think about the ground, Tommy.' Tommy laughs. Off-camera, a voice you know: 'Keep rolling. He doesn't need to know the pad's not there.'"},
        "58,2": {"id": "photo_kennel", "kind": "photo", "title": "POLAROID: 'EMPLOYEE OF THE MONTH'",
                 "text": "A rottweiler in a HOTSHOT crew jacket. Someone has written on the back: 'Better loyalty than the cast. - A.V.'"},
    },
    "checkpoints": [
        {"rect": [1, 20, 64, 22], "name": "THE YARD"},
        {"rect": [1, 1, 30, 18], "name": "WAREHOUSE"},
        {"rect": [32, 1, 16, 18], "name": "KENNELS"},
        {"rect": [49, 1, 16, 18], "name": "THE OFFICE"},
    ],
    "hints": [
        {"rect": [6, 38, 8, 5], "id": "m02_dogs", "text": "Yermo Salvage & K-9. Listen for barking. Dogs SMELL you if you run - sneak, or put them down before they wake the whole yard."},
        {"rect": [49, 12, 7, 4], "id": "m02_fuse", "text": "FUSE BOXES: cut the warehouse, the kennels or the yard floodlights. Smashed boxes stay dead - nobody can switch them back on."},
        {"rect": [30, 5, 3, 7], "id": "m02_kennel", "text": "The kennel lights are on their last legs. When they die, so do the handlers' eyes."},
    ],
    "exit": [7, 45],
    "weather": {"preset": "desert_wind"},
    "cameras": [{"cell": [1, 1], "angle": 45}, {"cell": [30, 20], "angle": 90}, {"cell": [47, 1], "angle": 130}],
    "decor": [
        {"type": "neon", "pos": [33, 45], "text": "YERMO SALVAGE & K-9", "color": "ffd23f", "size": 14},
        {"type": "neon", "pos": [10, 42], "text": "BEWARE OF DOG", "color": "ff3d7f", "size": 9},
        {"type": "neon", "pos": [40, 20], "text": "K-9", "color": "35e0ff", "size": 10},
        {"type": "palm", "pos": [62, 48], "size": 1.0}, {"type": "palm", "pos": [26, 48], "size": 0.9}, {"type": "palm", "pos": [1, 48], "size": 1.1},
    ],
}
out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "levels", "m02_yermo_salvage.json")
json.dump(level, open(out, "w"), indent=1)
print("\n".join(rows))
print(W, H, "humans:", sum(r.count(c) for r in rows for c in "gmhHsr"), "dogs:", sum(r.count(c) for r in rows for c in "dy"))

# Preserve authored flow when regenerating this data file.
from polish_layouts import apply_layout
with open(out, encoding="utf-8") as layout_source:
    polished = apply_layout(json.load(layout_source))
with open(out, "w", encoding="utf-8") as layout_target:
    json.dump(polished, layout_target, indent=1, ensure_ascii=False)
