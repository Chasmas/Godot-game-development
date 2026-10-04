"""Thin out small floor clutter so it reads as placed, not sprinkled: a piece
stays only when it is anchored (by a wall or a big prop), apart from other
small pieces, and under a per-kind cap.
  python tools/art/declutter.py [--dry]
"""
import json, math, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LEVELS = ["m01_sunset_palms", "m02_yermo_salvage", "m03_khsc_studios", "m04_villa_estrella"]
SMALL = {
    "studio_script_trail": 2, "studio_gaffer_scraps": 3, "studio_makeup_spill": 2, "studio_moth": 2,
    "studio_tape_marks": 3, "paper": 2, "studio_reel": 2,
    "villa_rose_petals": 4, "villa_candle_ring": 4, "villa_seating_card": 3, "villa_tea_service": 3,
    "villa_wax_and_petals": 3, "villa_orange_peel": 1,
}
BIG_HINTS = ("table", "sofa", "piano", "cabinet", "station", "rack", "bench", "bed", "desk", "planter", "coffin",
             "monitor", "teleprompter", "screen", "fountain", "statue", "lounger", "rig", "crate", "chairs", "bar", "rug", "mirror")
WALLS = set("#W%")
DROP = {"motel_exit_arrow"}   # reads as a road marking on a pool deck

def main(dry):
    for name in LEVELS:
        path = os.path.join(ROOT, "levels", name + ".json")
        d = json.load(open(path, encoding="utf-8"))
        mp = d["map"]
        def wall_near(x, y, r=1):
            for yy in range(int(y) - r, int(y) + r + 1):
                for xx in range(int(x) - r, int(x) + r + 1):
                    if 0 <= yy < len(mp) and 0 <= xx < len(mp[yy]) and mp[yy][xx] in WALLS:
                        return True
            return False
        bigs = [e["pos"] for e in d["decor"] if e.get("type") == "sprite" and any(h in str(e.get("id", "")) for h in BIG_HINTS)]
        # the same sprite placed twice on the same spot draws twice: keep one
        seen, uniq = set(), []
        for e in d["decor"]:
            k = (e.get("type"), e.get("id"), tuple(e.get("pos", [])))
            if e.get("type") == "sprite" and k in seen:
                continue
            seen.add(k); uniq.append(e)
        dupes = len(d["decor"]) - len(uniq)
        d["decor"] = [e for e in uniq if e.get("id") not in DROP]
        kept, smalls, count, dropped = [], [], {}, dupes
        # visit anchored pieces first so the cap keeps the best-placed ones
        def score(e):
            x, y = e["pos"]
            nb = min((math.dist((x, y), b) for b in bigs), default=99)
            return nb if not wall_near(x, y) else min(nb, 1.0)
        order = sorted(d["decor"], key=lambda e: score(e) if e.get("id") in SMALL else -1)
        for e in order:
            sid = e.get("id")
            if e.get("type") != "sprite" or sid not in SMALL:
                kept.append(e); continue
            x, y = e["pos"]
            anchored = wall_near(x, y) or any(math.dist((x, y), b) <= 2.5 for b in bigs)
            apart = all(math.dist((x, y), s) >= 4.0 for s in smalls)
            if anchored and apart and count.get(sid, 0) < SMALL[sid]:
                kept.append(e); smalls.append((x, y)); count[sid] = count.get(sid, 0) + 1
            else:
                dropped += 1
        # keep the original order for everything that stayed
        ids = {id(e) for e in kept}
        d["decor"] = [e for e in d["decor"] if id(e) in ids]
        print(f"{name}: dropped {dropped}, kept small {sum(count.values())} {count}")
        if not dry:
            json.dump(d, open(path, "w", encoding="utf-8"), indent=2, ensure_ascii=False)

if __name__ == "__main__":
    main("--dry" in sys.argv)
