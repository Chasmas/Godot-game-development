#!/usr/bin/env python3
"""Place themed decor on free floor cells, read from each level's own map.
Idempotent: items it placed carry "auto": true and are rebuilt on every run.
  python tools/art/place_decor.py
"""
import json, os, random

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FLOORS = set(".,_:=\"~;+-")
SOLID_NEAR = set("DW")           # keep doorways and windows clear

# (sprite id, count, zone, floor chars, extra)  extra: wall=True hugs a wall, size, clear=cells of free floor around
RULES = {
 "m01_sunset_palms": [
  ("motel_pool_lounger", 6, "courtyard", "=", dict(size=0.9, edge_of="~")),
  ("motel_pool_umbrella", 3, "courtyard", "=", dict(size=0.9, edge_of="~")),
  ("motel_pool_float_flamingo", 1, "courtyard", "~", dict(size=0.7, floor=True)),
  ("motel_bedside_lamp", 5, "north_wing", ".", dict(size=0.5, wall=True)),
  ("motel_bedside_lamp", 3, "ground_floor", ".", dict(size=0.5, wall=True)),
  ("motel_tv_crt", 3, "north_wing", ".", dict(size=0.7, wall=True)),
  ("motel_telephone", 3, "north_wing", ".", dict(size=0.5, floor=True)),
  ("motel_suitcase_open", 3, "north_wing", ".", dict(size=0.7, floor=True, rot=True)),
  ("motel_ice_bucket_full", 2, "lobby", ",", dict(size=0.5, floor=True)),
  ("motel_bedside_lamp", 2, "lobby", ",", dict(size=0.55, wall=True)),
 ],
 "m02_yermo_salvage": [
  ("yard_car_stack", 3, "exterior", ";", dict(size=1.0, clear=2)),
  ("yard_oil_barrel_cluster", 4, "exterior", ";+", dict(size=0.8)),
  ("yard_tire_stack", 4, "exterior", ";", dict(size=0.9)),
  ("yard_scrap_pile", 4, "exterior", ";", dict(size=0.9, clear=2)),
  ("yard_storage_container", 2, "exterior", ";", dict(size=1.0, clear=2)),
  ("yard_welder_sparks", 2, "warehouse", "+:", dict(size=0.7, floor=True)),
  ("yard_oil_barrel_cluster", 2, "warehouse", "+:", dict(size=0.8, wall=True)),
 ],
 "m03_khsc_studios": [
  ("studio_camera_crane", 2, "stage", "-:", dict(size=0.9, clear=2)),
  ("studio_green_screen", 1, "stage", "-", dict(size=1.0, wall=True)),
  ("studio_clapperboard", 3, "stage", "-:", dict(size=0.5, floor=True)),
  ("studio_teleprompter", 2, "stage", "-", dict(size=0.7)),
  ("studio_spotlight_beam", 3, "stage", "-", dict(size=0.8, floor=True)),
  ("studio_film_reel_pair", 3, "offices", ".,", dict(size=0.6, floor=True)),
  ("studio_film_reel_pair", 1, "warehouse", "_.", dict(size=0.6, floor=True)),
 ],
 "m04_villa_estrella": [
  ("villa_fountain", 1, "exterior", "\"", dict(size=1.0, clear=3)),
  ("villa_garden_statue", 4, "exterior", "\"", dict(size=0.8, clear=1)),
  ("villa_flower_bed", 4, "exterior", "\"", dict(size=0.9, clear=1)),
  ("villa_wine_glasses", 3, "ballroom", "_.,", dict(size=0.6, floor=True)),
  ("candelabra", 5, "ballroom", "_.,", dict(size=0.6, wall=True)),
  ("candelabra", 3, "foyer", "_.,", dict(size=0.6, wall=True)),
  ("villa_candle_ring", 2, "foyer", "_.,", dict(size=0.7, floor=True, clear=1)),
  ("piano", 1, "west_wing", "_.,", dict(size=0.9, wall=True, clear=1)),
 ],
}

def build(name):
    path = os.path.join(ROOT, "levels", name + ".json")
    d = json.load(open(path, encoding="utf-8"))
    d["decor"] = [it for it in d["decor"] if not it.get("auto")]
    m = d["map"]; H, W = len(m), len(m[0])
    ch = lambda x, y: m[y][x] if 0 <= y < H and 0 <= x < W else "#"
    taken = [tuple(it["pos"]) for it in d["decor"] if "pos" in it]
    taken += [tuple(e["pos"]) for e in d.get("enemies", []) if "pos" in e]
    rng = random.Random(name)
    added = 0
    for sid, count, zone, chars, ex in RULES[name]:
        zx, zy, zw, zh = d["zones"][zone]
        cells = [(x, y) for y in range(zy, min(zy + zh, H)) for x in range(zx, min(zx + zw, W)) if ch(x, y) in chars]
        rng.shuffle(cells)
        clear = ex.get("clear", 1)
        placed = 0
        for x, y in cells:
            if placed >= count: break
            ring = [(x + dx, y + dy) for dy in range(-clear, clear + 1) for dx in range(-clear, clear + 1)]
            if any(ch(a, b) in SOLID_NEAR for a, b in ring): continue
            if ex.get("edge_of"):
                if not any(ch(a, b) == ex["edge_of"] for a, b in ring): continue
                ring = [(a, b) for a, b in ring if ch(a, b) != ex["edge_of"]]
            okc = FLOORS | ({"#"} if ex.get("wall") else set())
            if not all(ch(a, b) in okc for a, b in ring if (a, b) != (x, y)): continue
            near_wall = any(ch(a, b) == "#" for a, b in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)])
            if ex.get("wall") and not near_wall: continue
            if not ex.get("wall") and near_wall and clear > 1: continue
            if any(abs(x - tx) + abs(y - ty) < 4 for tx, ty in taken): continue
            it = {"type": "sprite", "id": sid, "pos": [x, y], "size": ex.get("size", 1.0), "auto": True}
            if ex.get("floor"): it["floor"] = True
            if ex.get("rot"): it["rot"] = rng.choice([0, 25, 45, 90, 135])
            d["decor"].append(it); taken.append((x, y)); placed += 1; added += 1
        if placed < count: print(f"  {name}: {sid} placed {placed}/{count}")
    json.dump(d, open(path, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    print(name, "auto items:", added, "total decor:", len(d["decor"]))

if __name__ == "__main__":
    for n in RULES: build(n)
