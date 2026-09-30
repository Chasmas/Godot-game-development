#!/usr/bin/env python3
"""Authoring script for Mission 04 'Sweet Dreams' - Villa Estrella (the nightmare).
Same legend as tools/build_m01.py, plus enemies  z zombie  u ghoul  M demon
q cultist (usher)  v hellhound, and weapons  ( boomstick  ) flamethrower.
Writes levels/m04_villa_estrella.json.

The wrap party she dreams after Stage Nine: a graveyard lawn of fresh graves
with gold stars on them, and the mansion on the hill - foyer, ballroom
(where Tommy waits), library and dining room to the west, the nursery, the
mirror bathroom and a chapel crypt to the east. The level is generous with
guns; the dead are generous with numbers."""
import json, os
W, H = 72, 60
g = [[' '] * W for _ in range(H)]

def fill(x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = ch
def hline(x0, x1, y, ch='#'): fill(x0, y, x1, y, ch)
def vline(x, y0, y1, ch='#'): fill(x, y0, x, y1, ch)
def put(x, y, ch): g[y][x] = ch
def room(x0, y0, x1, y1, floor):
    fill(x0, y0, x1, y1, '#'); fill(x0 + 1, y0 + 1, x1 - 1, y1 - 1, floor)

fill(0, 0, W - 1, H - 1, '#')
# ---------------------------------------------------------------- the lawn
fill(1, 37, W - 2, H - 2, '"')
fill(1, 35, W - 2, 36, '=')                  # terrace
fill(34, 37, 37, H - 2, ';')                 # the drive up to the door
fill(1, 50, W - 2, 51, ';')                  # the path across the graves
fill(32, 43, 39, 47, '~')                    # the fountain (dry? no: dark water)
fill(33, 44, 38, 46, '~')
for (x0, y0, x1) in ((6, 41, 14), (20, 41, 28), (44, 41, 52), (58, 41, 66)):
    hline(x0, x1, y0)                        # hedges
# ---------------------------------------------------------------- the house
room(4, 0, 67, 34, '_')
# ballroom (north middle) and foyer (south middle)
vline(22, 1, 33); vline(50, 1, 33)
hline(23, 49, 21)
fill(23, 1, 49, 20, '_')
fill(23, 22, 49, 33, ',')
put(35, 21, 'D'); put(36, 21, 'D')           # foyer -> ballroom
put(35, 34, 'D'); put(36, 34, 'D')           # front doors
for x in (27, 28, 31, 32, 39, 40, 43, 44): put(x, 34, 'W')
# west wing: library over dining room
hline(5, 21, 15)
fill(5, 1, 21, 14, '.')
fill(5, 16, 21, 33, '_')
put(12, 15, 'D'); put(13, 15, 'D')
put(22, 7, 'D'); put(22, 8, 'D')             # library -> ballroom
put(22, 27, 'D'); put(22, 28, 'D')           # dining -> foyer
put(10, 34, 'D'); put(11, 34, 'D')           # dining -> lawn (servants' door)
for x in (6, 7, 16, 17): put(x, 34, 'W')
put(22, 12, '%'); put(22, 13, '%')           # a thin panel behind the shelves
# east wing: nursery, mirror bath, chapel
hline(51, 66, 11); hline(51, 66, 20)
fill(51, 1, 66, 10, '.')
fill(51, 12, 66, 19, ',')
fill(51, 21, 66, 33, '=')
put(50, 5, 'D'); put(50, 6, 'D')             # ballroom -> nursery
put(50, 27, 'D'); put(50, 28, 'D')           # foyer -> chapel
put(58, 11, 'D'); put(59, 11, 'D')
put(58, 20, 'D'); put(59, 20, 'D')
put(60, 34, 'D'); put(61, 34, 'D')           # chapel -> lawn
for x in (54, 55, 64, 65): put(x, 34, 'W')

# ================================================================= contents
fill(4, 52, 5, 55, 'K'); put(6, 53, 'X'); put(9, 55, 'P')      # the Cadillac, unburnt, for now
put(12, 53, '('); put(20, 49, '5'); put(8, 47, '0'); put(30, 39, '4'); put(47, 55, '1'); put(48, 55, '1')
for p in ((10, 45), (16, 47), (24, 45), (28, 53), (44, 47), (52, 45), (60, 48), (64, 54), (18, 56), (54, 56)): put(*p, 'z')
for p in ((40, 56), (26, 38), (62, 39)): put(*p, 'u')
put(66, 44, 'v'); put(3, 39, 'v')
for p in ((12, 48), (30, 48), (42, 49), (57, 52), (22, 54), (46, 38)): put(*p, '*')
put(66, 57, 'U')
put(2, 44, 'R'); put(69, 44, 'R'); put(36, 57, 'R')
# foyer: the demon on the stairs, candles, a rifle on the coat check
put(36, 26, 'M'); put(28, 24, 'z'); put(44, 24, 'z'); put(30, 31, 'u'); put(42, 31, 'q')
put(25, 32, '6'); put(47, 23, '5')
for p in ((30, 25), (42, 25), (36, 30), (26, 29), (46, 29)): put(*p, '*')
put(24, 23, 'Y'); put(48, 23, 'Y')
# library
for (x0, y0) in ((7, 3), (7, 7), (7, 11), (16, 3), (16, 7), (16, 11)): fill(x0, y0, x0 + 3, y0, 'c')   # bookshelves
fill(11, 5, 14, 6, 'T')
put(9, 5, 'u'); put(18, 9, 'q'); put(13, 12, 'z'); put(6, 13, 'G')
put(12, 2, 'o'); put(19, 13, '*'); put(9, 9, '*')
# dining room: the long table and its guests
fill(8, 22, 18, 23, 'T')
for p in ((8, 21), (11, 21), (14, 21), (17, 21), (9, 24), (12, 24), (15, 24)): put(*p, 'z')
put(19, 30, 'q'); put(6, 31, 'M'); put(20, 18, '4')
for p in ((10, 19), (16, 19), (13, 28), (7, 26), (19, 26)): put(*p, '*')
put(6, 17, 'U')
# ballroom: Tommy and the crowd
put(36, 8, 'B')
for p in ((28, 5), (44, 5), (27, 14), (45, 14), (32, 17), (40, 17), (36, 3)): put(*p, 'z')
put(24, 3, 'u'); put(48, 3, 'u'); put(48, 18, 'q'); put(24, 18, 'q')
for p in ((29, 10), (43, 10), (36, 14), (30, 3), (42, 3), (36, 19)): put(*p, '*')
for p in ((31, 6), (41, 6), (36, 12)): put(*p, 'E')
put(24, 10, '^'); put(48, 10, '^')
put(23, 20, 'S')
# nursery
put(53, 3, 'b'); put(54, 3, 'b'); put(63, 8, 't'); put(56, 7, 'u'); put(62, 4, 'u'); put(60, 2, 'o')
put(65, 2, '5'); put(58, 5, '*')
# mirror bathroom
put(52, 16, 'q'); put(64, 13, 'z'); put(57, 17, '*'); put(62, 17, '*'); put(66, 18, '3')
# chapel crypt
for p in ((54, 24), (54, 29), (63, 24), (63, 29)): put(*p, 'z')
put(58, 31, 'M'); put(60, 23, 'v'); put(65, 32, 'q')
put(52, 32, ')'); put(66, 22, '(')
for p in ((56, 22), (61, 26), (56, 31), (64, 27)): put(*p, '*')
put(52, 22, 'F'); put(65, 25, 'R')
put(59, 33, 'U')

rows = [''.join(r) for r in g]

graves = [(8, 44), (12, 44), (16, 44), (22, 44), (26, 44), (46, 44), (50, 44), (60, 44), (64, 44),
          (8, 53), (14, 57), (26, 56), (44, 53), (52, 54), (58, 56), (64, 51), (18, 38), (54, 38)]
level = {
    "id": "m04_villa_estrella",
    "name": "Villa Estrella",
    "nightmare": True,
    "floor_textures": {",": "marble", ".": "rug"},
    "ambient": [0.34, 0.22, 0.36],
    "map": rows,
    "zones": {
        "exterior": [0, 35, W, H - 35],
        "west_wing": [4, 0, 19, 35], "ballroom": [22, 0, 29, 22], "foyer": [22, 21, 29, 14], "east_wing": [50, 0, 18, 35],
    },
    "power": {"23,20": "ballroom", "52,22": "east_wing"},
    "flicker_zones": ["west_wing", "east_wing"],
    "inside_rect": [4, 0, 64, 35],
    "time_text": "THE HOUR THAT ISN'T",
    "wall_colors": {
        "ballroom": ["7a4a5a", "2e1420", "ff3d7f"], "foyer": ["8a6a5a", "3a2418", "ffd23f"],
        "west_wing": ["5a3a2a", "241208", "ffb030"], "east_wing": ["6a6a78", "24242e", "c21f2f"],
        "default": ["3a4a3a", "141c14", "ff3d7f"],
    },
    "light_colors": {".": "ff9a70", ",": "d8c8ff", "_": "ffb070", "=": "ff5a5a", "\"": "c03a4a", ";": "ff7a50", "~": "ff3050"},
    "objectives": {
        "infiltrate": "GET INTO THE HOUSE", "clear": "PUT THEM BACK IN THE GROUND", "find_boss": "FIND TOMMY",
        "boss": "TOP BILLING", "escape": "WAKE UP. GET TO THE CAR.", "cleared": "THE PARTY'S OVER",
        "escape_hint": "The car's still out front. It isn't burning. Yet.",
    },
    "intro_call": {"dialogue": "call_m04", "caller": "tommy", "device": "phone"},
    "boss": {"intro": "m04_boss_intro", "down": "m04_boss_down"},
    "reinforcement_kinds": ["zombie", "ghoul", "zombie", "hellhound"],
    "arcade_roster": [[1, "zombie", 5.0], [1, "ghoul", 2.0], [2, "hellhound", 1.5], [3, "cultist", 2.0], [4, "demon", 1.0], [6, "ghoul", 2.0]],
    "enemies": {
        "36,8": {"kind": "burning_man", "facing": "down"},
        "8,21": {"facing": "down"}, "11,21": {"facing": "down"}, "14,21": {"facing": "down"}, "17,21": {"facing": "down"},
        "9,24": {"facing": "up"}, "12,24": {"facing": "up"}, "15,24": {"facing": "up"},
    },
    "collectibles": {
        "6,13": {"id": "tape_dream", "kind": "tape", "title": "VHS: 'WRAP PARTY - 1987'",
                 "text": "The crew party the night after the fire. Everyone is drinking. Somebody plays the stunt footage on a TV in the corner and the room cheers when the car goes up. The camera finds the Director in the crowd for half a second. He is clapping with his whole body. The tape was never made. You are dreaming it."},
        "63,8": {"id": "photo_nursery", "kind": "photo", "title": "POLAROID: TWO KIDS ON A CAR HOOD",
                 "text": "You and Tommy, maybe eight and ten, on the hood of your father's Cadillac, both wearing paper gold stars. On the back, in your mother's handwriting: 'My two stars.' You don't remember this photo. You remember this day."},
    },
    "checkpoints": [
        {"rect": [1, 37, 70, 21], "name": "THE LAWN"},
        {"rect": [23, 22, 27, 12], "name": "THE FOYER"},
        {"rect": [5, 1, 17, 33], "name": "WEST WING"},
        {"rect": [51, 1, 16, 33], "name": "EAST WING"},
    ],
    "boss_trigger": [26, 4, 20, 13],
    "boss_cover": [[36, 8], [28, 8], [44, 8], [36, 16], [28, 16], [44, 16]],
    "fire_points": [[24, 2], [48, 2], [24, 19], [48, 19], [30, 1], [42, 1], [23, 10], [49, 10], [36, 20]],
    "scares": [
        {"rect": [1, 42, 70, 3], "type": "spawn", "at": [[8, 44], [16, 44], [26, 44], [46, 44], [60, 44]], "kinds": ["zombie", "zombie", "ghoul"]},
        {"rect": [30, 36, 12, 2], "type": "whisper", "text": "Checkout was midnight, Lyle."},
        {"rect": [33, 30, 6, 4], "type": "apparition", "who": "harcourt"},
        {"rect": [5, 1, 16, 5], "type": "slam"},
        {"rect": [5, 6, 16, 3], "type": "whisper", "text": "You didn't even ask my name."},
        {"rect": [5, 16, 16, 4], "type": "lights", "zone": "west_wing", "time": 4.0},
        {"rect": [5, 25, 16, 3], "type": "whisper", "text": "Room service! ...no? Nobody?"},
        {"rect": [51, 1, 15, 4], "type": "whisper", "text": "I had a kid, you know. Had."},
        {"rect": [51, 12, 15, 7], "type": "apparition", "who": "cass"},
        {"rect": [51, 21, 15, 3], "type": "spawn", "at": [[54, 26], [63, 26], [58, 29]], "kinds": ["zombie", "ghoul", "zombie"]},
        {"rect": [51, 27, 15, 3], "type": "whisper", "text": "I was just the fire watch."},
        {"rect": [26, 16, 20, 4], "type": "chandelier", "at": [36, 11]},
        {"rect": [26, 12, 20, 3], "type": "apparition", "who": "tommy"},
        {"rect": [60, 33, 3, 3], "type": "whisper", "text": "Is this still the take?"},
    ],
    "hints": [
        {"rect": [5, 50, 10, 8], "id": "m04_dream", "text": "It's a dream. The dead don't stay down unless you burn them, blow them up or finish them. Keep moving. Keep shooting."},
        {"rect": [10, 51, 5, 4], "id": "m04_boom", "text": "BOOMSTICK: two barrels, sawn short. Reload after every pair."},
        {"rect": [51, 30, 3, 3], "id": "m04_flame", "text": "PYRO SPECIAL: hold FIRE. Everything burns here. Everything but him."},
    ],
    "exit": [6, 53],
    "weather": {"preset": "nightmare"},
    "decor": [{"type": "sprite", "id": "grave", "pos": [x, y], "rot": 0} for (x, y) in graves] + [
        {"type": "sprite", "id": "coffin", "pos": [54, 26], "rot": 0}, {"type": "sprite", "id": "coffin", "pos": [63, 26], "rot": 180},
        {"type": "sprite", "id": "coffin", "pos": [58, 29], "rot": 90},
        {"type": "sprite", "id": "piano", "pos": [45, 16], "rot": 20}, {"type": "sprite", "id": "candelabra", "pos": [27, 26]},
        {"type": "sprite", "id": "candelabra", "pos": [45, 26]}, {"type": "sprite", "id": "candelabra", "pos": [13, 22]},
        {"type": "neon", "pos": [36, 36], "text": "WRAP PARTY", "color": "ff3d7f", "size": 12},
        {"type": "neon", "pos": [36, 58], "text": "VILLA ESTRELLA", "color": "ffd23f", "size": 12},
        {"type": "palm", "pos": [2, 38], "size": 1.1}, {"type": "palm", "pos": [69, 38], "size": 1.0},
        {"type": "palm", "pos": [30, 57], "size": 1.2}, {"type": "palm", "pos": [42, 57], "size": 1.1},
    ],
    "film_cameras": [{"cell": [26, 2], "angle": 45}, {"cell": [46, 2], "angle": 135}, {"cell": [36, 33], "angle": 270}],
}
out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "levels", "m04_villa_estrella.json")
json.dump(level, open(out, "w"), indent=1)
print("\n".join(rows))
print(W, H, "enemies:", sum(r.count(c) for r in rows for c in "gmhHsrBzuMqv"))

# Preserve authored flow when regenerating this data file.
from polish_layouts import apply_layout
with open(out, encoding="utf-8") as layout_source:
    polished = apply_layout(json.load(layout_source))
with open(out, "w", encoding="utf-8") as layout_target:
    json.dump(polished, layout_target, indent=1, ensure_ascii=False)
