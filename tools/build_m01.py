#!/usr/bin/env python3
"""Authoring script for Mission 01 'Checkout Time' - Sunset Palms Motel.
Builds the ASCII map with drawing primitives and writes levels/m01_sunset_palms.json.

Legend (see scripts/levels/level_builder.gd):
 floors   . carpet  , tile  _ wood  : asphalt  = concrete  " grass  ~ pool(pit)
 solid    # wall  % weak wall  W window  D door  L locked door
 low      T table  C counter  b bed  l lounger  w washer  k desk
 props    V vending  t tv  Q arcade  I ice machine  Y plant  E propane  F fuse box  o lamp  K car  Z dumpster
 misc     * light  A alarm  $ tape  & photo  O phone  X car/exit  P player  R reinforcement spawn  @ civilian
 enemies  g guard  m gunner  h hunter  H heavy  s scout  r riot  B boss  d dobermann  y rottweiler
 power    S light switch  ^ flickering light   upgrades  U briefcase (random upgrade)
 extra    c crate  n kennel cage  j wrecked car   floors ; dirt  + steel grating
 weapons  1 pistol 2 whisper 3 revolver 4 smg 5 shotgun 6 rifle 7 knife 8 bat 9 pipe 0 machete ! bottle ? brick G hotshot
"""
import json, os
W, H = 68, 61
g = [[' '] * W for _ in range(H)]

def fill(x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = ch
def hline(x0, x1, y, ch='#'): fill(x0, y, x1, y, ch)
def vline(x, y0, y1, ch='#'): fill(x, y0, x, y1, ch)
def put(x, y, ch): g[y][x] = ch
def room(x0, y0, x1, y1, floor):
    """walls on the border, floor inside"""
    fill(x0, y0, x1, y1, '#'); fill(x0 + 1, y0 + 1, x1 - 1, y1 - 1, floor)

# ------------------------------------------------------------ outside
fill(0, 0, W - 1, H - 1, '#')
fill(1, 42, W - 2, H - 2, ':')          # parking lot
fill(1, 42, W - 2, 43, '=')             # sidewalk
fill(1, 1, 3, 41, '=')                  # west alley
# ------------------------------------------------------------ north wing (y1..10)
room(4, 1, 53, 10, '.')
for x in (15, 26, 39): vline(x, 1, 10)
for x0 in (9, 20, 31, 45): put(x0, 10, 'D'); put(x0 + 1, 10, 'D')
for x0 in (6, 12, 17, 23, 28, 35, 41, 50): put(x0, 10, 'W'); put(x0 + 1, 10, 'W')
# ------------------------------------------------------------ courtyard (y11..25)
fill(5, 11, 52, 25, '=')
fill(5, 11, 52, 12, '"'); fill(5, 24, 12, 25, '"'); fill(44, 24, 52, 25, '"')
vline(4, 11, 25); vline(53, 11, 25)
put(4, 13, '='); put(4, 14, '=')         # gate from the alley
fill(20, 15, 33, 20, '~')               # pool
# ------------------------------------------------------------ middle wing (y26..41)
room(4, 26, 53, 41, ',')
fill(5, 27, 9, 40, ',')                 # laundry
vline(10, 26, 41)
put(10, 33, 'D'); put(10, 34, 'D')      # laundry -> corridor
put(4, 37, 'D'); put(4, 38, 'D')        # service door -> alley
hline(10, 53, 31); hline(10, 53, 35)
fill(11, 32, 52, 34, ',')               # corridor
# north rooms 101 102 [passage] 103 104
fill(11, 27, 18, 30, '.'); vline(19, 26, 31)
fill(20, 27, 27, 30, '.'); vline(28, 26, 31)
fill(29, 27, 31, 30, ','); vline(32, 26, 31)
fill(33, 27, 40, 30, '.'); vline(41, 26, 31)
fill(42, 27, 52, 30, '.')
for x0 in (14, 23, 36, 46): put(x0, 31, 'D'); put(x0 + 1, 31, 'D')
fill(29, 31, 31, 31, ',')               # passage open to corridor
put(29, 26, 'D'); put(30, 26, 'D')      # passage -> courtyard
# south rooms 105 106 107(lounge) 108
fill(11, 36, 18, 40, '.'); vline(19, 35, 41)
fill(20, 36, 27, 40, '.'); vline(28, 35, 41)
fill(29, 36, 40, 40, '_'); vline(41, 35, 41)
fill(42, 36, 52, 40, '.')
for x0 in (16, 21, 33, 49): put(x0, 35, 'D'); put(x0 + 1, 35, 'D')
for x0, n in ((13, 4), (22, 4), (31, 8), (44, 4)):
    for i in range(n): put(x0 + i, 41, 'W')
# ------------------------------------------------------------ east column: suite, boiler, office, lobby
room(53, 1, 66, 10, '.')                # manager's suite (secret)
room(53, 10, 66, 18, ',')               # boiler room
room(53, 18, 66, 26, '_')               # office
room(53, 26, 66, 41, ',')               # lobby
put(53, 5, '%'); put(53, 6, '%')        # weak wall from room 204
put(53, 14, 'D'); put(53, 15, 'D')      # courtyard -> boiler
put(53, 22, 'D'); put(53, 23, 'D')      # courtyard -> office
put(53, 33, 'D'); put(53, 34, 'D')      # corridor -> lobby
put(59, 26, 'D'); put(60, 26, 'D')      # lobby -> office
put(58, 41, 'L'); put(59, 41, 'L')      # front doors (locked until the end)
for x0 in (55, 62): put(x0, 41, 'W'); put(x0 + 1, 41, 'W')
put(59, 18, '#'); put(60, 18, '#')

# ================================================================= contents
# parking lot
fill(6, 52, 7, 55, 'K')                 # Cass's car
put(8, 53, 'X'); put(9, 54, 'P')
fill(16, 47, 19, 48, 'K'); fill(28, 47, 31, 48, 'K'); fill(44, 47, 47, 48, 'K')
fill(55, 52, 56, 55, 'K'); fill(36, 54, 39, 55, 'K')
fill(2, 45, 3, 46, 'Z')                 # dumpster
for p in ((13, 50), (34, 51), (58, 49), (2, 20), (2, 33), (24, 44), (46, 44)): put(*p, '*')
put(3, 43, 'g')                         # tutorial guard, smoking by the alley
put(40, 45, 'g')                        # lot patrol
put(22, 50, '?')                        # a brick. for the window.
# laundry
for y in (28, 30): put(5, y, 'w'); put(6, y, 'w')
put(8, 38, 'T'); put(9, 38, 'T'); put(7, 36, '!'); put(8, 29, '7')
put(8, 32, 'g'); put(7, 34, '*')
# corridor
put(20, 33, 'g'); put(47, 33, 'm')
for x in (16, 30, 44): put(x, 32, '*')
# 101 guest
put(13, 28, '@'); fill(16, 28, 17, 29, 'b'); put(12, 30, 't'); put(15, 27, '*')
# 102 hunter
put(25, 28, 'h'); fill(21, 29, 22, 30, 'b'); put(21, 27, '9'); put(24, 27, '*')
# passage light
put(30, 28, '*')
# 103 card game
fill(36, 28, 37, 29, 'T'); put(35, 28, 'g'); put(38, 29, 'g'); put(34, 30, '3'); put(36, 27, '*'); put(40, 27, 'Y')
# 104 heavy
put(47, 29, 'H'); fill(50, 27, 51, 28, 'b'); put(43, 27, 't'); put(46, 27, '*'); put(52, 30, 'Y')
# 105 empty (window route)
put(12, 39, '8'); fill(16, 38, 17, 39, 'b'); put(14, 37, '*')
# 106 gunner at the window
put(24, 38, 'm'); fill(20, 36, 21, 37, 'b'); put(26, 37, '*')
# 107 lounge
put(30, 37, 'V'); put(39, 37, 'I'); put(35, 36, 'Q'); put(36, 36, 'Q')
fill(32, 39, 33, 39, 'T'); put(37, 39, 'T'); put(38, 39, 'T')
put(34, 38, 's'); put(29, 36, 'A'); put(34, 37, '*'); put(40, 40, 'Y')
# 108
put(46, 38, 'g'); put(51, 37, 'E'); put(43, 39, '!'); fill(49, 38, 50, 39, 'b'); put(47, 37, '*')
# courtyard
fill(10, 14, 11, 14, 'T'); fill(44, 21, 45, 21, 'T')
for x in (15, 17, 36, 38): put(x, 17, 'l'); put(x, 18, 'l')
put(36, 13, 'E'); put(37, 13, 'E'); put(16, 22, 'E')
put(26, 22, 'r'); put(11, 12, 's'); put(5, 12, 'A'); put(45, 14, 'h'); put(40, 23, 'g')
put(8, 20, 'Y'); put(49, 17, 'Y'); put(50, 12, 'I'); put(34, 24, '5')
for p in ((12, 17), (26, 13), (26, 22), (42, 17), (26, 18)): put(*p, '*')
# north wing
fill(7, 3, 8, 4, 'b'); put(12, 8, 't'); put(10, 6, 'g'); put(9, 5, '*'); put(13, 3, '@')
put(22, 4, 'h'); put(18, 7, 'm'); fill(23, 7, 24, 8, 'b'); put(20, 3, '*'); put(17, 3, '0')
fill(31, 5, 33, 6, 'T'); put(32, 3, 'H'); put(36, 7, 'm'); put(28, 8, 'E'); put(33, 4, '*'); put(37, 3, '4')
fill(49, 3, 50, 4, 'b'); put(48, 7, '$'); put(47, 8, 't'); put(44, 6, 'g'); put(46, 3, '*')
# suite (secret)
put(60, 5, 'G'); put(63, 3, '&'); fill(56, 3, 57, 4, 'b'); put(59, 8, 't'); put(62, 7, 'o')
# boiler
put(64, 12, 'F'); put(56, 16, 'E'); put(57, 16, 'E'); put(55, 12, '2'); put(61, 14, 'g'); put(59, 13, '*')
# office
fill(58, 21, 60, 21, 'k'); put(63, 23, 'g'); put(64, 20, 'o'); put(55, 24, 'Y'); put(59, 20, '*'); put(64, 25, 'R'); put(61, 24, '6')
# lobby
fill(55, 30, 61, 30, 'C'); put(61, 28, 'C'); put(61, 29, 'C')
put(58, 28, 'B'); put(56, 28, 'O')
put(57, 36, '#'); put(62, 36, '#')
put(55, 39, 'R'); put(65, 39, 'R'); put(65, 32, 'V'); put(55, 37, 'Y'); put(64, 40, 'Y')
for p in ((58, 33), (58, 38), (63, 29)): put(*p, '*')

# ---------------------------------------------------------------- stealth / power / dogs / upgrades
put(6, 11, 'S')                         # upstairs breaker, courtyard side
put(5, 40, 'S')                         # ground-floor lights, in the laundry
put(5, 24, 'F')                         # courtyard fuse box
put(7, 34, '^')                         # laundry tube is dying
put(13, 21, 'd')                        # dobermann asleep by the pool
put(2, 24, 'y')                         # rottweiler sniffing the alley
put(12, 37, 'U'); put(51, 8, 'U'); put(3, 48, 'U')

rows = [''.join(r) for r in g]

T = 16
def tc(x, y): return [x * T + 8, y * T + 8]
level = {
    "id": "m01_sunset_palms",
    "name": "Sunset Palms Motel",
    "ambient": [0.42, 0.38, 0.6],
    "map": rows,
    "zones": {
        "exterior": [0, 42, W, H - 42], "exterior_alley": [0, 0, 4, 42],
        "lobby": [53, 0, 15, 42],
        "north_wing": [4, 0, 50, 11], "courtyard": [4, 11, 50, 15], "ground_floor": [4, 26, 50, 16],
    },
    "power": {"6,11": "north_wing", "5,40": "ground_floor", "5,24": "courtyard"},
    "flicker_zones": ["ground_floor"],
    "parking_rows": [[46, 49], [52, 55]],
    "inside_rect": [4, 0, 200, 42],
    "time_text": "11:48 PM",
    "light_colors": {".": "ffb070", ",": "d8f0ff", "_": "ffc080", ":": "ff9a40", "=": "ff5aa0", "\"": "50e0ff", "~": "40d8ff"},
    "enemies": {
        "40,45": {"patrol": [[40, 45], [52, 45], [52, 50], [26, 51], [26, 45]]},
        "3,43": {"facing": "left"},
        "8,32": {"facing": "up"},
        "20,33": {"patrol": [[20, 33], [44, 33]]},
        "47,33": {"facing": "left"},
        "25,28": {"facing": "left"},
        "35,28": {"facing": "right"},
        "38,29": {"facing": "left"},
        "47,29": {"facing": "down"},
        "24,38": {"facing": "down"},
        "34,38": {"facing": "down"},
        "46,38": {"patrol": [[46, 38], [44, 37], [51, 39]]},
        "26,22": {"patrol": [[26, 22], [34, 22], [34, 13], [19, 13], [19, 22]]},
        "11,12": {"facing": "right"},
        "45,14": {"facing": "left"},
        "40,23": {"patrol": [[40, 23], [48, 23], [48, 14]]},
        "10,6": {"facing": "down"},
        "22,4": {"facing": "down"},
        "18,7": {"facing": "right"},
        "32,3": {"facing": "down"},
        "36,7": {"facing": "left"},
        "44,6": {"facing": "right"},
        "61,14": {"patrol": [[61, 14], [58, 12], [62, 16]]},
        "63,23": {"facing": "left"},
        "58,28": {"facing": "down", "boss": True},
        "13,21": {"sleep": True, "facing": "left"},
        "2,24": {"sniff": True},
    },
    "npcs": {
        "13,28": {"id": "earl", "palette": "civilian", "lines": ["Room's paid through Sunday. I ain't leaving.", "You with Harcourt? You don't look like you're with Harcourt.", "There's a tape playing in 204. Same tape. Every night."]},
        "13,3": {"id": "dolores", "palette": "scout", "lines": ["Housekeeping doesn't do this floor anymore, honey.", "The manager keeps a room nobody rents. East side. Walls are thin."]},
    },
    "collectibles": {
        "48,7": {"id": "tape_roll7", "kind": "tape", "title": "VHS: 'HOTSHOT' - DAILIES, ROLL 7",
                 "text": "Grainy footage. A burning Cadillac on a desert road. A stuntwoman walks out of the fire - it's you. Someone off-camera says: 'Again. From the top. Tommy, you're in the car this time.'\nThe tape cuts to static."},
        "63,3": {"id": "photo_harcourt", "kind": "photo", "title": "POLAROID: WRAP PARTY, 1987",
                 "text": "Harcourt, younger, in a HOTSHOT crew jacket. He's standing next to a man whose face has been scratched out with a key. On the back: 'Residuals - A.V.'"},
    },
    "phone": {"pos": [56, 28], "dialogue": "m01_phone"},
    "checkpoints": [
        {"rect": [5, 27, 48, 14], "name": "MOTEL - GROUND FLOOR"},
        {"rect": [5, 11, 48, 15], "name": "COURTYARD"},
        {"rect": [5, 2, 48, 8], "name": "UPSTAIRS WING"},
        {"rect": [54, 11, 12, 30], "name": "FRONT OFFICE"},
    ],
    "boss_trigger": [54, 19, 12, 22],
    "boss_cover": [[58, 28], [63, 38], [56, 35], [62, 22], [55, 38]],
    "hints": [
        {"rect": [5, 44, 12, 14], "id": "move", "text": "WASD / LEFT STICK  move    ·    MOUSE / RIGHT STICK  aim"},
        {"rect": [1, 42, 6, 6], "id": "sneak", "text": "He hasn't seen you.  Hold [CTRL] (or tilt the stick gently) to SNEAK behind him, then [F] TAKEDOWN.  Or PUNCH him down and [F] EXECUTE"},
        {"rect": [20, 44, 16, 12], "id": "lock", "text": "[V] / [R3]  LOCK-ON the nearest enemy  ·  tap again to switch target (or flick the right stick)  ·  hold to release"},
        {"rect": [4, 36, 3, 5], "id": "switch", "text": "LIGHT SWITCH: kill the lights. Unaware guards are blind in the dark — but someone may walk over to turn them back on."},
        {"rect": [1, 27, 3, 6], "id": "dog", "text": "A DOG. It smells you if you rush past. SNEAK, or take it down from behind. Dogs bark for their owners."},
        {"rect": [1, 46, 5, 4], "id": "upgrade", "text": "BRIEFCASES hold random upgrades — they last the whole mission."},
        {"rect": [11, 42, 20, 3], "id": "window", "text": "[SPACE] DASH  —  dive through windows, vault tables, dodge bullets"},
        {"rect": [1, 34, 3, 7], "id": "doors", "text": "Walk into doors to open them.  [F] near a door KICKS it into whoever is behind"},
        {"rect": [20, 45, 5, 8], "id": "brick", "text": "[E] pick up  ·  [RMB] THROW — anything you throw knocks people down"},
    ],
    "exit": [8, 53],
    "weather": {"schedule": [["drizzle", 20], ["storm", 55], ["rain", 30], ["clear", 25], ["storm", 40]]},
    "decor": [
        {"type": "neon", "pos": [59, 44], "text": "SUNSET PALMS", "color": "ff3d7f", "size": 16},
        {"type": "neon", "pos": [59, 46], "text": "VACANCY", "color": "35e0ff", "size": 10},
        {"type": "neon", "pos": [33, 12], "text": "POOL", "color": "35e0ff", "size": 9},
        {"type": "neon", "pos": [20, 44], "text": "OFFICE ->", "color": "ffd23f", "size": 8},
        {"type": "palm", "pos": [2, 47], "size": 1.1}, {"type": "palm", "pos": [14, 58], "size": 1.0},
        {"type": "palm", "pos": [42, 58], "size": 1.2}, {"type": "palm", "pos": [64, 57], "size": 1.0},
        {"type": "palm", "pos": [62, 45], "size": 0.9}, {"type": "palm", "pos": [7, 12], "size": 0.9},
        {"type": "palm", "pos": [47, 24], "size": 1.0}, {"type": "palm", "pos": [2, 26], "size": 0.8},
    ],
}
out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "levels", "m01_sunset_palms.json")
json.dump(level, open(out, "w"), indent=1)
print("\n".join(rows))
print(W, H, "enemies:", sum(r.count(c) for r in rows for c in "gmhHsrB"))

# Preserve authored flow when regenerating this data file.
from polish_layouts import apply_layout
with open(out, encoding="utf-8") as layout_source:
    polished = apply_layout(json.load(layout_source))
with open(out, "w", encoding="utf-8") as layout_target:
    json.dump(polished, layout_target, indent=1, ensure_ascii=False)
