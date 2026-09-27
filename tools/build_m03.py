#!/usr/bin/env python3
"""Authoring script for Mission 03 'Prime Time' - KHSC Studios, Stage Nine, Burbank.
Same legend as tools/build_m01.py, plus  -  soundstage floor.
Writes levels/m03_khsc_studios.json.

The lot on a Santa Ana night: the backlot and parking in the south, the prop
warehouse (west), makeup & wardrobe (north-west), Stage Nine in the middle
with its sets (a replica of room 204, the news desk, the burning Cadillac,
the audience bleachers), and the offices down the east side (control room,
green room, security). Dutch waits by the Cadillac."""
import json, os
W, H = 70, 58
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
# ---------------------------------------------------------------- backlot (south)
fill(1, 44, W - 2, H - 2, ':')
fill(1, 42, W - 2, 43, '=')
# ---------------------------------------------------------------- buildings
room(0, 0, 20, 21, '.')          # makeup & wardrobe
room(0, 21, 20, 41, '+')         # prop warehouse
room(20, 0, 50, 41, '-')         # STAGE NINE
room(50, 0, 69, 12, '_')         # control room
room(50, 12, 69, 24, '.')        # green room
room(50, 24, 69, 29, ',')        # corridor
room(50, 29, 69, 41, '=')        # security
# makeup: three dressing rooms off a hall
vline(7, 1, 20); vline(14, 1, 12); hline(8, 19, 12)
fill(8, 13, 19, 20, '.')
put(7, 5, 'D'); put(7, 6, 'D'); put(7, 16, 'D'); put(7, 17, 'D')
put(10, 12, 'D'); put(11, 12, 'D'); put(16, 12, 'D'); put(17, 12, 'D')
fill(1, 1, 6, 20, ',')           # wardrobe racks room (tile)
# doors between buildings
put(20, 15, 'D'); put(20, 16, 'D')        # hall -> stage (wings)
put(20, 31, 'D'); put(20, 32, 'D')        # warehouse -> stage
put(10, 21, 'D'); put(11, 21, 'D')        # wardrobe -> warehouse
put(8, 41, 'D'); put(9, 41, 'D')          # warehouse -> lot (loading bay)
for x in (3, 4, 15, 16): put(x, 41, 'W')
for x0 in (33, 34, 35, 36): put(x0, 41, 'D')   # stage elephant doors
for x in (25, 26, 44, 45): put(x, 41, 'W')
put(50, 26, 'D'); put(50, 27, 'D')        # stage -> corridor
put(58, 12, 'D'); put(59, 12, 'D')        # control <-> green room
put(58, 24, 'D'); put(59, 24, 'D')        # green room -> corridor
put(58, 29, 'D'); put(59, 29, 'D')        # corridor -> security
put(62, 41, 'D'); put(63, 41, 'D')        # security -> lot
for x in (54, 55, 66, 67): put(x, 41, 'W')
put(50, 6, 'W'); put(50, 7, 'W')          # control room window onto the stage
put(50, 17, '%'); put(50, 18, '%')        # green room: flimsy flat, can be smashed through
# ---------------------------------------------------------------- stage sets
# room 204, built with three walls, open to the south
hline(23, 33, 3); vline(23, 3, 10); vline(33, 3, 10)
fill(24, 4, 32, 10, '.')
put(23, 7, 'W')
# news desk set on a wooden riser
fill(37, 3, 48, 9, '_')
# the Cadillac on its turntable, mid-stage
fill(33, 21, 37, 22, 'j')
# bleachers (low rows you can vault)
for y in (34, 36, 38):
    fill(23, y, 30, y, 'C'); fill(40, y, 48, y, 'C')

# ================================================================= contents
fill(4, 50, 5, 53, 'K'); put(6, 51, 'X'); put(8, 52, 'P')        # Cass's car
fill(14, 47, 17, 48, 'K'); fill(26, 47, 29, 48, 'K'); fill(46, 52, 49, 53, 'K'); fill(58, 47, 61, 48, 'K')
fill(38, 53, 41, 54, 'K')
fill(1, 45, 2, 46, 'Z'); fill(66, 50, 67, 51, 'Z')
for p in ((12, 50), (30, 51), (44, 45), (56, 51), (22, 45), (64, 45)): put(*p, '*')
put(20, 46, 'g'); put(40, 49, 'g'); put(55, 44, 'h')
put(12, 45, '?'); put(33, 47, '1')
put(3, 55, 'U')
# prop warehouse
for (x0, y0) in ((3, 24), (3, 28), (12, 24), (12, 28)): fill(x0, y0, x0 + 3, y0 + 1, 'c')
fill(3, 34, 6, 35, 'j'); fill(12, 35, 15, 36, 'j')
put(17, 24, 'E'); put(18, 24, 'E'); put(9, 38, 'E')
put(8, 31, 'h'); put(16, 33, 'H'); put(5, 38, 'g'); put(17, 39, 'm')
put(10, 26, '8'); put(18, 30, '5'); put(2, 33, '0')
for p in ((5, 26), (14, 26), (10, 33), (4, 39), (16, 39)): put(*p, '*')
put(1, 36, 'S')
# makeup & wardrobe
fill(2, 3, 2, 8, 'c'); fill(5, 3, 5, 8, 'c'); fill(2, 12, 2, 17, 'c'); fill(5, 12, 5, 17, 'c')   # garment racks
put(3, 19, 'g'); put(4, 2, '@')
fill(9, 2, 12, 2, 'T'); put(10, 5, 'h'); put(12, 9, 'o'); put(9, 9, 'Y')
fill(16, 2, 18, 2, 'T'); put(17, 7, 'm'); put(15, 10, '4'); put(18, 10, 'Y')
fill(9, 19, 12, 19, 'T'); put(15, 16, 'g'); put(18, 14, 'V'); put(9, 14, '!')
for p in ((3, 5), (3, 15), (10, 4), (17, 4), (13, 16)): put(*p, '*')
put(19, 18, 'U')
# Stage Nine
put(28, 6, 'b'); put(29, 6, 'b'); put(28, 7, 'b'); put(29, 7, 'b')
put(31, 4, 't'); put(25, 9, 'o'); put(26, 5, '$')
fill(39, 5, 46, 5, 'C'); put(40, 4, 't'); put(45, 4, 't'); put(42, 7, 'g'); put(47, 8, '2')
put(35, 19, 'B')
for p in ((31, 20), (39, 20), (30, 24), (40, 24), (35, 26)): put(*p, 'E')
put(24, 18, 'h'); put(46, 17, 'h'); put(27, 28, 'g'); put(44, 29, 'm')
put(22, 12, 's'); put(21, 2, 'A'); put(49, 38, 'r'); put(25, 40, 'g')
put(31, 14, 'H'); put(42, 13, 'g')
put(22, 30, '6'); put(48, 25, '3')
for p in ((28, 13), (42, 12), (27, 20), (43, 20), (35, 16), (35, 30), (28, 32), (42, 32), (26, 39), (44, 39), (35, 5)): put(*p, '*')
put(24, 26, '^'); put(46, 26, '^')
put(21, 36, 'S'); put(49, 2, 'F')
put(49, 14, 'U')
# control room
fill(53, 3, 60, 3, 'k'); fill(53, 7, 60, 7, 'k')
for x in (53, 55, 57, 59): put(x, 2, 't')
put(63, 5, 'g'); put(66, 9, 'm'); put(64, 2, '&'); put(67, 3, 'o')
put(56, 5, '*'); put(64, 8, '*')
# green room
fill(53, 15, 55, 16, 'T'); put(60, 14, 'V'); put(61, 14, 'Q'); put(67, 14, 'Y')
fill(62, 19, 64, 20, 'T'); put(57, 20, '@'); put(66, 22, 'h'); put(53, 21, 'g')
put(55, 18, '*'); put(64, 17, '*'); put(68, 22, '7')
# corridor
put(55, 26, 'g'); put(65, 27, 's'); put(52, 25, 'A')
put(56, 26, '*'); put(64, 26, '*')
# security
fill(53, 32, 57, 32, 'k'); put(60, 31, 't'); put(61, 31, 't')
put(55, 35, 'H'); put(64, 34, 'r'); put(58, 38, 'm'); put(66, 38, 'g')
put(67, 31, 'F'); put(52, 39, 'R'); put(66, 36, 'R'); put(54, 30, '5')
put(56, 34, '*'); put(64, 37, '*')
put(1, 22, 'R'); put(68, 1, 'R')

rows = [''.join(r) for r in g]

level = {
    "id": "m03_khsc_studios",
    "name": "KHSC Studios - Stage Nine",
    "ambient": [0.44, 0.34, 0.5],
    "map": rows,
    "zones": {
        "exterior": [0, 42, W, H - 42],
        "wardrobe": [0, 0, 21, 21], "warehouse": [0, 21, 21, 21],
        "stage": [20, 0, 31, 42],
        "offices": [50, 0, 20, 42],
    },
    "power": {"1,36": "warehouse", "21,36": "stage", "49,2": "stage", "67,31": "offices"},
    "flicker_zones": ["warehouse"],
    "parking_rows": [[46, 49], [51, 55]],
    "inside_rect": [0, 0, 70, 42],
    "time_text": "10:58 PM",
    "wall_colors": {
        "stage": ["3a3448", "1c1826", "ff3d7f"], "warehouse": ["8a93a0", "3e4654", "ffb030"],
        "wardrobe": ["d8a0b8", "7a4058", "ffd23f"], "offices": ["b0a898", "5a5048", "35e0ff"],
        "default": ["c89880", "6a4838", "ff5aa0"],
    },
    "light_colors": {".": "ffb070", ",": "d8f0ff", "_": "ffc080", ":": "ff9a40", "=": "ff5aa0", "-": "fff0d8", "+": "c8e0ff"},
    "objectives": {
        "infiltrate": "GET ONTO THE LOT", "clear": "CLEAR STAGE NINE", "find_boss": "FIND THE FIREMAN",
        "boss": "PUT OUT THE FIREMAN", "escape": "GET OUT BEFORE THE ROOF COMES DOWN",
        "cleared": "STAGE NINE IS DARK", "escape_hint": "THE STAGE IS BURNING. BACK TO THE CAR.",
    },
    "boss": {"intro": "m03_boss_intro", "down": "m03_boss_down"},
    "enemies": {
        "20,46": {"kind": "security", "patrol": [[20, 46], [34, 46], [34, 51], [20, 51]]},
        "40,49": {"kind": "security", "patrol": [[40, 49], [54, 49], [54, 45], [40, 45]]},
        "55,44": {"kind": "stagehand", "facing": "left"},
        "8,31": {"kind": "stagehand", "patrol": [[8, 31], [8, 37], [17, 37], [17, 31]]},
        "16,33": {"facing": "left"},
        "5,38": {"kind": "security", "facing": "up"},
        "17,39": {"facing": "left"},
        "3,19": {"kind": "security", "facing": "up"},
        "10,5": {"kind": "stagehand", "facing": "down"},
        "17,7": {"facing": "left"},
        "15,16": {"kind": "security", "patrol": [[15, 16], [9, 16], [9, 19], [18, 19]]},
        "24,18": {"kind": "stagehand", "facing": "right"},
        "46,17": {"kind": "stagehand", "facing": "left"},
        "27,28": {"kind": "security", "patrol": [[27, 28], [27, 31], [43, 31], [43, 28]]},
        "44,29": {"facing": "up"},
        "22,12": {"facing": "right"},
        "49,38": {"facing": "left"},
        "25,40": {"kind": "security", "facing": "up"},
        "31,14": {"facing": "down"},
        "42,13": {"kind": "security", "facing": "down"},
        "42,7": {"kind": "security", "facing": "down"},
        "35,19": {"kind": "fireman", "facing": "down"},
        "63,5": {"kind": "security", "facing": "left"},
        "66,9": {"facing": "left"},
        "66,22": {"kind": "stagehand", "facing": "left"},
        "53,21": {"kind": "security", "facing": "right"},
        "55,26": {"kind": "security", "patrol": [[55, 26], [66, 26]]},
        "65,27": {"facing": "left"},
        "55,35": {"facing": "up"},
        "64,34": {"facing": "left"},
        "58,38": {"facing": "up"},
        "66,38": {"kind": "security", "facing": "left"},
    },
    "npcs": {
        "57,20": {"id": "rudy", "palette": "civilian", "lines": ["I'm not here. I'm a coat rack. Coat racks don't testify.", "Mr. Kowalski's on the Cadillac. He's been talking to it.", "The booth said you'd come in through the elephant doors. They had a whole shot planned."]},
        "4,2": {"id": "bev", "palette": "scout", "lines": ["Hold still, your star's smudged. ...Sorry. Habit.", "They made me paint twenty of those stars tonight. For the extras. The extras didn't come back."]},
    },
    "collectibles": {
        "26,5": {"id": "tape_pilot", "kind": "tape", "title": "VHS: 'HOTSHOT CALIFORNIA' - PILOT, ROUGH CUT",
                 "text": "The motel, from four angles. Your face in a doorway. A laugh track where the gunshots are. A title card: 'NEXT WEEK - THE DOGS.' Dated a week before you went to Yermo."},
        "64,2": {"id": "photo_casting", "kind": "photo", "title": "POLAROIDS: 'CASTING - 1990 / 91'",
                 "text": "A clipped stack of Polaroids. A girl in a jester's collar at an arcade machine: 'THE FOOL.' A tired policewoman at a desk: 'D. PRUITT - STAR?' On the last one, a gold star over a face that has been cut out."},
    },
    "checkpoints": [
        {"rect": [1, 44, 67, 12], "name": "THE BACKLOT"},
        {"rect": [1, 22, 19, 19], "name": "PROP WAREHOUSE"},
        {"rect": [1, 1, 19, 20], "name": "WARDROBE"},
        {"rect": [21, 1, 29, 40], "name": "STAGE NINE"},
        {"rect": [51, 1, 18, 40], "name": "THE OFFICES"},
    ],
    "boss_trigger": [26, 14, 20, 16],
    "boss_cover": [[35, 19], [28, 22], [42, 22], [35, 28], [26, 16], [44, 16]],
    "fire_points": [[24, 5], [32, 9], [38, 6], [47, 6], [24, 34], [29, 38], [41, 36], [47, 38], [22, 22], [48, 22], [33, 23], [37, 20]],
    "hints": [
        {"rect": [3, 48, 10, 8], "id": "m03_wind", "text": "Santa Ana winds. The whole lot is loud tonight - gunfire carries less far outside."},
        {"rect": [30, 40, 10, 3], "id": "m03_cameras", "text": "The show's cameras are rolling. Shoot them out, or give them something to film."},
        {"rect": [26, 14, 20, 3], "id": "m03_fire", "text": "FIRE kills. Don't stand in it - DASH through a flame to get past it. Propane tanks hurt him."},
    ],
    "exit": [6, 51],
    "weather": {"preset": "santa_ana"},
    "decor": [
        {"type": "neon", "pos": [35, 43], "text": "STAGE 9", "color": "ff3d7f", "size": 14},
        {"type": "neon", "pos": [58, 43], "text": "KHSC  CHANNEL 9", "color": "35e0ff", "size": 10},
        {"type": "neon", "pos": [35, 1], "text": "ON AIR", "color": "ff3030", "size": 10},
        {"type": "neon", "pos": [42, 10], "text": "EYEWITNESS 9", "color": "35e0ff", "size": 8},
        {"type": "neon", "pos": [10, 43], "text": "LOADING", "color": "ffd23f", "size": 8},
        {"type": "palm", "pos": [2, 56], "size": 1.1}, {"type": "palm", "pos": [24, 56], "size": 1.0},
        {"type": "palm", "pos": [52, 56], "size": 1.2}, {"type": "palm", "pos": [67, 55], "size": 1.0},
        {"type": "palm", "pos": [34, 50], "size": 0.9}, {"type": "palm", "pos": [62, 44], "size": 0.9},
    ],
    "cameras": [{"cell": [21, 1], "angle": 45}, {"cell": [68, 25], "angle": 180}, {"cell": [1, 22], "angle": 45}],
    "film_cameras": [{"cell": [27, 13], "angle": 270}, {"cell": [43, 16], "angle": 200}, {"cell": [35, 31], "angle": 270}, {"cell": [30, 11], "angle": 90}, {"cell": [45, 11], "angle": 270}],
}
out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "levels", "m03_khsc_studios.json")
json.dump(level, open(out, "w"), indent=1)
print("\n".join(rows))
print(W, H, "enemies:", sum(r.count(c) for r in rows for c in "gmhHsrB"))
