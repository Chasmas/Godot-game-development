#!/usr/bin/env python3
"""High-quality dense prop sprites (3/4 view, highly detailed) via PixelLab pixflux.
  python tools/art/pixellab_props_hq.py <name> [<name> ...] [--out dir]
Edit PROPS below; output goes to assets/art/pixellab_world/sprites_hq/<name>.png (ArtLib shows them at 1/4 size: 160px = 40 game px).
"""
import base64, io, json, os, sys, time, urllib.request, urllib.error
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
STYLE = ("highly detailed isometric-style pixel art game asset, three-quarter view from above, 1980s California neon noir, "
         "rich material texture, dense small details, strong warm and cool rim lighting, ambient occlusion, "
         "clean silhouette, limited but rich colour ramps, crisp pixels, no background")
PROPS = {
  # --- dirt road details (yard) ---
  "dirt_ruts": (128, 64, "two parallel dark tyre ruts pressed into dry orange desert dirt seen from directly above, dust"),
  "dirt_pebbles": (96, 64, "scatter of small stones and pebbles on dry desert dirt seen from directly above, long shadows"),
  "dirt_tracks": (96, 64, "boot prints and dog paw prints pressed in dusty dirt seen from directly above"),
  "dirt_weeds": (64, 64, "dry desert weeds and a small tuft of dead grass on dirt seen from directly above"),
  "dirt_oilspill": (80, 64, "dark dried oil stain soaked into desert dirt seen from directly above, blackish brown"),
  "dirt_boards": (96, 64, "a few broken wooden planks lying on dirt seen from directly above, nails, splinters"),
  # --- villa path details ---
  "path_pavers": (96, 64, "a patch of old terracotta paving stones with moss between them seen from directly above"),
  "path_petals": (96, 64, "fallen red rose petals scattered on a stone path seen from directly above"),
  "path_leaves": (96, 64, "dry brown leaves and a few twigs on a stone path seen from directly above"),
  "path_puddle": (96, 64, "shallow puddle on a terracotta path reflecting warm lantern light seen from directly above, ripples, transparent edges"),
  "path_crack": (96, 80, "crack in an old stone paving with a tuft of grass and tiny white flowers seen from directly above"),
  "path_lantern_pool": (96, 96, "round pool of warm golden lantern light spilling on a stone path seen from directly above, soft glow"),
  # --- road decals (seen from directly above, painted on asphalt) ---
  "road_manhole": (64, 64, "round cast iron manhole cover on dark asphalt seen from directly above, rust, concentric ridges, worn"),
  "road_crosswalk": (128, 96, "zebra crosswalk white stripes painted on dark worn asphalt seen from directly above, chipped paint, tyre scuffs"),
  "road_drain": (64, 48, "street storm drain grate in a concrete gutter seen from directly above, dark water, leaves"),
  "road_arrow": (64, 96, "faded white painted road arrow on dark asphalt seen from directly above, cracked and chipped paint"),
  "road_patch": (96, 80, "rectangular repaired asphalt patch, darker fresh tar over cracked old asphalt, seen from directly above"),
  "road_pothole": (64, 56, "pothole in asphalt with broken edges and a dark puddle seen from directly above, cracks radiating"),
  "road_skid": (128, 64, "black curved tyre skid marks on asphalt seen from directly above, rubber streaks, a little smoke stain"),
  "road_oil": (80, 64, "oil and petrol stain on asphalt with rainbow sheen seen from directly above, irregular puddle"),
  "road_puddle": (96, 64, "rain puddle on asphalt reflecting neon pink and blue light seen from directly above, ripples"),
  "road_cracks": (96, 96, "network of deep cracks in dark asphalt with weeds sprouting seen from directly above"),
  "road_sand": (96, 64, "drift of desert sand and gravel blown across asphalt seen from directly above"),
  "road_stop_line": (128, 32, "painted white stop line with faded yellow double centre line on asphalt seen from directly above"),
  "grave": (128, 192, "weathered grey stone headstone with a rounded top and a carved cross, cracked, patches of moss, fresh red roses and a small candle at its foot, mound of dark soil"),
  # --- motel ---
  "hq_motel_bed": (160, 128, "1980s motel double bed, rumpled orange floral bedspread, two pillows, wooden headboard against a wall"),
  "hq_persian_rug": (192, 128, "ornate persian rug seen from above, deep red and gold geometric border, intricate medallion, worn fringe tassels"),
  "hq_motel_dresser": (128, 96, "wooden motel dresser with a CRT television, a lamp, an ice bucket, a bible and a phone on top"),
  "hq_motel_vending": (96, 128, "glowing retro soda and snack vending machine, neon label, coins slot, scratches"),
  "hq_motel_ice_machine": (96, 112, "motel ice machine, stainless steel, frost, a scoop and bucket beside it, humming"),
  "hq_neon_beer_sign": (96, 64, "neon beer sign glowing red and blue in a dark window frame"),
  "hq_motel_curtains": (128, 128, "heavy 1980s motel window with thick mustard curtains, venetian blinds, neon light leaking through"),
  "hq_pool_lounger_set": (128, 96, "two white pool loungers with towels, a small side table with cocktails and an umbrella shadow"),
  "hq_pool_cooler": (64, 64, "red and white beach cooler box with bottles and ice, open lid"),
  "hq_palm_planter": (96, 128, "large terracotta planter with a leafy palm and ferns, little pebbles"),
  # --- salvage yard ---
  "hq_workbench": (160, 96, "cluttered mechanic workbench, vise, wrenches, tool wall pegboard above, oil stains, a hanging work lamp"),
  "hq_engine_block": (128, 96, "engine block on a stand with pistons and hoses, oil dripping, hoist chain"),
  "hq_forklift": (160, 128, "old rusty yellow forklift, forks raised, hazard stripes, wooden pallet"),
  "hq_crate_stack": (128, 128, "stack of wooden shipping crates with stencilled markings, rope, tarp corner"),
  "hq_generator": (128, 96, "diesel generator with fuel cans, cables and a glowing gauge, sparks"),
  "hq_fire_barrel": (80, 112, "steel oil drum burning with orange flames and embers, soot stains, glowing rim"),
  "hq_junk_heap": (192, 128, "huge heap of scrap metal, crushed car doors, tyres, pipes, wire, rust and rim light"),
  "hq_tire_wall": (160, 112, "wall of stacked tyres with a hand-painted warning sign"),
  "hq_chainlink_gate": (160, 96, "chain-link fence section with barbed wire and a padlocked gate, shadows"),
  # --- studio ---
  "hq_directors_chairs": (128, 96, "two canvas director chairs with names stencilled, a clapperboard on a small table, coffee cups"),
  "hq_camera_dolly": (160, 112, "film camera on a dolly track with a tripod, lens, monitor and cables"),
  "hq_light_stand": (96, 144, "tall studio light stand with a big fresnel spotlight, barn doors, cables, warm beam"),
  "hq_monitor_bank": (192, 128, "wall of CRT monitors in a control room desk, mixing console, glowing buttons, coffee cup"),
  "hq_costume_rack": (160, 112, "wheeled costume rack crammed with colourful 1980s outfits, hats on top, shoes below"),
  "hq_makeup_station": (160, 112, "makeup station with big mirror ringed in light bulbs, brushes, cosmetics, a chair"),
  "hq_catering_table": (160, 96, "catering table with coffee urn, donuts, sandwiches, paper cups, a tablecloth"),
  "hq_set_flat": (160, 128, "film set flat, painted wooden fake wall with a window, braced from behind, scuffs"),
  # --- villa ---
  "hq_banquet_table": (192, 112, "long banquet table with white cloth, gold candelabras, wine glasses, plates, roses, red chairs"),
  "hq_ornate_sofa": (160, 96, "ornate burgundy velvet sofa with gold trim, tassel cushions, carved wooden feet"),
  "hq_fireplace": (160, 128, "stone fireplace with roaring orange fire, mantel with candles and a gilded mirror above"),
  "hq_gilt_mirror": (96, 128, "tall ornate gilt-framed mirror reflecting warm candlelight"),
  "hq_display_cabinet": (128, 128, "glass display cabinet with crystal glasses, porcelain, silver trophies, warm interior light"),
  "hq_bar_cabinet": (160, 112, "mansion drinks cabinet with decanters, whisky bottles, ice bucket, a lit shelf"),
  "hq_garden_bench": (128, 80, "wrought iron garden bench with moss, fallen petals, small lantern beside it"),
  "hq_hedge": (128, 64, "trimmed topiary hedge section with small white flowers and fairy lights"),
  "hq_stair_runner": (96, 128, "short ornate staircase with red carpet runner and brass rods, balustrade, candle glow"),
  "hq_grand_planter": (112, 128, "large stone urn planter with lush ferns and orchids, ivy trailing"),
  "hq_sun_loungers": (160, 96, "two teak sun loungers with striped cushions beside a pool edge, a drink on a side table"),
  "hq_chandelier_big": (192, 192, "grand crystal chandelier with many lit candles, glittering crystals, warm golden glow"),
}

def key():
    k = os.environ.get("PIXELLAB_API_KEY", "")
    return k or open(os.path.join(os.path.expanduser("~"), ".pixellab_key"), encoding="utf-8-sig").read().strip()

def clear_backdrop(im):
    px = im.load(); w, h = im.size
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    if all(c[3] < 10 for c in corners): return im
    bg = corners[0]
    if any(abs(c[i] - bg[i]) > 10 for c in corners for i in range(3)): return im
    near = lambda c: c[3] > 0 and all(abs(c[i] - bg[i]) <= 14 for i in range(3))
    stack = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    seen = set()
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h) or not near(px[x, y]): continue
        seen.add((x, y)); px[x, y] = (0, 0, 0, 0)
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return im

def gen(name, out):
    w, h, desc = PROPS[name]
    body = {"description": desc + ", " + (STYLE if not name.startswith(("road_", "dirt_", "path_")) else STYLE.replace("three-quarter view from above","view straight down from directly above, flat top-down")), "negative_description": "blurry, flat, noisy, text, watermark, low detail, front view, side view",
            "image_size": {"width": w, "height": h}, "no_background": True,
            "detail": "highly detailed", "shading": "highly detailed shading", "outline": "single color black outline",
            "text_guidance_scale": 8.0}
    for attempt in range(6):
        req = urllib.request.Request("https://api.pixellab.ai/v2/create-image-pixflux", data=json.dumps(body).encode(),
                                     headers={"Authorization": "Bearer " + key(), "Content-Type": "application/json"})
        try:
            r = json.load(urllib.request.urlopen(req, timeout=300)); break
        except urllib.error.HTTPError as e:
            if e.code == 429: time.sleep(20 * (attempt + 1)); continue
            print("  !", name, e.code, e.read()[:200]); return False
    else:
        return False
    im = Image.open(io.BytesIO(base64.b64decode(r["image"]["base64"].split(",")[-1]))).convert("RGBA")
    os.makedirs(out, exist_ok=True)
    im = clear_backdrop(im)
    im.save(os.path.join(out, name + ".png"))
    return True

if __name__ == "__main__":
    a = sys.argv[1:]
    out = a[a.index("--out") + 1] if "--out" in a else os.path.join(ROOT, "assets", "art", "pixellab_world", "sprites_hq")
    names = list(PROPS) if "--all" in a else [x for x in a if x in PROPS]
    for n in names:
        if os.path.exists(os.path.join(out, n + ".png")): continue
        print(n, "ok" if gen(n, out) else "FAILED", flush=True)
