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
  ("motel_bedside_lamp", 5, "north_wing", ".", dict(size=0.5, near="b")),
  ("motel_bedside_lamp", 3, "ground_floor", ".", dict(size=0.5, near="b")),
  ("motel_tv_crt", 3, "north_wing", ".", dict(size=0.7, wall=True)),
  ("motel_telephone", 3, "north_wing", ".", dict(size=0.5, floor=True, near="b")),
  ("motel_suitcase_open", 3, "north_wing", ".", dict(size=0.7, floor=True, rot=True)),
  ("motel_ice_bucket_full", 2, "lobby", ",", dict(size=0.5, floor=True)),
 ],
 "m02_yermo_salvage": [
  ("yard_car_stack", 3, "exterior", ";", dict(size=1.0, clear=2)),
  ("yard_oil_barrel_cluster", 4, "exterior", ";+", dict(size=0.8)),
  ("yard_tire_stack", 4, "exterior", ";", dict(size=0.7)),
  ("yard_scrap_pile", 4, "exterior", ";", dict(size=0.9, clear=2)),
  ("yard_storage_container", 2, "exterior", ";", dict(size=1.0, clear=2)),
  ("yard_welder_sparks", 2, "warehouse", "+:", dict(size=0.7, floor=True)),
  ("yard_oil_barrel_cluster", 2, "warehouse", "+:", dict(size=0.8, wall=True)),
 ],
 "m03_khsc_studios": [
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

def tidy(name, d):
    """Drop older decor that sits somewhere it makes no sense (found by a close-up audit)."""
    m = d["map"]; H, W = len(m), len(m[0])
    ch = lambda x, y: m[y][x] if 0 <= y < H and 0 <= x < W else "#"
    zones = d["zones"]
    def zone_of(x, y):
        for z, (zx, zy, zw, zh) in zones.items():
            if zx <= x < zx + zw and zy <= y < zy + zh: return z
        return ""
    out = []
    for it in d["decor"]:
        sid = it.get("id", ""); x, y = (int(round(v)) for v in it.get("pos", [0, 0])); c = ch(x, y)
        drop = False
        if it.get("type") == "sprite" and not it.get("auto"):
            if name == "m01_sunset_palms":
                if sid == "motel_water_ring" and not any(ch(x + dx, y + dy) == "~" for dx in range(-6, 7) for dy in range(-6, 7)): drop = True
                if sid == "motel_neon_vacancy_sign" and not zone_of(x, y).startswith("exterior"): drop = True
            if name == "m02_yermo_salvage" and sid.startswith("yard_") and c in ".,": drop = True
            if name == "m03_khsc_studios" and sid == "studio_acoustic_wall_panel": drop = True
            if name == "m04_villa_estrella":
                if sid == "villa_orange_peel" and c == "~": drop = True
                if sid == "villa_ivy_wall_cluster" and not any(ch(x + dx, y + dy) == "#" for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))): drop = True
        if drop: print("  tidy:", name, sid, [x, y])
        else: out.append(it)
    d["decor"] = out

def build(name):
    path = os.path.join(ROOT, "levels", name + ".json")
    d = json.load(open(path, encoding="utf-8"))
    d["decor"] = [it for it in d["decor"] if not it.get("auto")]
    tidy(name, d)
    m = d["map"]; H, W = len(m), len(m[0])
    ch = lambda x, y: m[y][x] if 0 <= y < H and 0 <= x < W else "#"
    taken = [tuple(it["pos"]) for it in d["decor"] if "pos" in it]
    taken += [tuple(e["pos"]) for e in d.get("enemies", []) if "pos" in e]
    rng = random.Random(name)
    hc = d.get("hero_car") or {}
    keep_clear = []
    for key in ("route_in", "route_out"):
        r = hc.get(key, [])
        for (ax, ay), (bx, by) in zip(r, r[1:]):
            n = max(1, int(max(abs(bx - ax), abs(by - ay)) * 2))
            keep_clear += [(ax + (bx - ax) * k / n, ay + (by - ay) * k / n) for k in range(n + 1)]
    if hc.get("pos"): keep_clear.append(tuple(hc["pos"]))
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
            okc = (FLOORS if ("~" in chars or ex.get("edge_of")) else FLOORS - {"~"}) | ({"#"} if ex.get("wall") else set()) | ({ex["near"]} if ex.get("near") else set())
            if not all(ch(a, b) in okc for a, b in ring if (a, b) != (x, y)): continue
            if ex.get("near"):
                if not any(ch(x + dx, y + dy) == ex["near"] for dx in range(-2, 3) for dy in range(-2, 3)): continue
                if any(ch(x + dx, y + dy) == "#" for dx in (-1, 0, 1) for dy in (-1, 0, 1)): continue
            near_wall = any(ch(a, b) == "#" for a, b in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)])
            if ex.get("wall") and not near_wall: continue
            if not ex.get("wall") and near_wall and clear > 1: continue
            if any(abs(x - tx) + abs(y - ty) < 4 for tx, ty in taken): continue
            if any(abs(x - kx) < 4 and abs(y - ky) < 4 for kx, ky in keep_clear): continue
            it = {"type": "sprite", "id": sid, "pos": [x, y], "size": ex.get("size", 1.0), "auto": True}
            if ex.get("floor"): it["floor"] = True
            if ex.get("rot"): it["rot"] = rng.choice([0, 25, 45, 90, 135])
            d["decor"].append(it); taken.append((x, y)); placed += 1; added += 1
        if placed < count: print(f"  {name}: {sid} placed {placed}/{count}")
    json.dump(d, open(path, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    print(name, "auto items:", added, "total decor:", len(d["decor"]))

if __name__ == "__main__":
    for n in RULES: build(n)
