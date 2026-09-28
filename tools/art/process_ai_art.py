#!/usr/bin/env python3
import sys
"""
Turn the generated paintings (assets/art/Artwork/ai/, see gen_ai_art.py) into
the files the game loads:

  shots/<id>     -> assets/art/painted/<id>.webp        1280x720 story frame
                    assets/art/painted/<id>_glow.png    emissive mask (neon, lamps,
                                                        screens, fire) that the
                                                        painted-shot shader pulses
  portraits/<id> -> assets/characters/portraits/<id>.png   192x192
  sprites/<id>   -> assets/art/sprites/<id>.png         top-down props, brought down
                    to the game's pixel density (2 texels per world pixel),
                    palette-reduced with a hard alpha edge and an ink outline so
                    they sit with the hand-made pixel characters
  textures/<id>  -> assets/art/floors/<id>.png          seamless floor tiles,
                    256 px = 8 tiles, same treatment

  python tools/art/process_ai_art.py
"""
import os, glob
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAW = os.path.join(ROOT, "assets", "art", "Artwork", "ai")
INK = (11, 7, 16)

# world size (in 16 px tiles, w x h, as drawn facing right) per sprite; texels = tiles * 16 * 2
SPRITE_TILES = {
    "car_red": (4, 2), "car_hero": (4.5, 2.1), "car_blue": (4, 2), "car_white": (4, 2), "car_black": (4, 2), "car_police": (4, 2),
    "wreck": (4, 2), "dumpster": (2, 2), "bed": (2, 2), "lounger": (2, 1), "washer": (1, 1), "crate": (1, 1),
    "palm": (4, 4), "plant": (1, 1), "arcade": (1, 1), "vending": (1, 1), "camera_rig": (2, 2),
    "studio_light": (2, 2), "leaf": (0.5, 0.5), "paper": (0.75, 0.75), "frond": (1, 1),
    "coffin": (2, 1), "grave": (1, 1.5), "piano": (3, 3), "candelabra": (1, 1), "chandelier": (3, 3),
    "table": (2, 1.34), "desk": (2, 1.34), "cage": (2, 2), "office_chair": (1, 1), "tv_crt": (1, 1),
    "ice_machine": (1, 1), "oil_drum": (1, 1), "pickup_truck": (3.5, 2.34), "cardboard_box": (1, 1),
    "wooden_chair": (1, 1), "jukebox": (1, 1), "pinball": (1, 1.5), "armchair": (1, 1), "tyre_stack": (1, 1),
    "pallet": (1, 1), "workbench": (2, 1.34), "pyro_charge": (1, 1),
    "sofa": (3, 2), "coffee_table": (2, 1.34), "floor_lamp": (1, 1), "potted_palm": (1.5, 1.5), "bar_cart": (1, 1),
    "speaker_stack": (1, 1), "cocktail_table": (1.5, 1.5), "pool_table": (4, 2.67), "dj_booth": (3, 2), "champagne_tower": (2, 2),
    "buffet_table": (4, 2.67), "sideboard": (2.5, 1.67), "bookshelf": (2.5, 1.67), "fireplace": (2.5, 1.67), "statue": (1.2, 1.2),
    "grandfather_clock": (1, 1), "luggage_cart": (1.5, 1.5), "dressing_table": (2.5, 1.67), "clothes_rack": (2.5, 1.67),
    "light_stand": (1.2, 1.2), "flight_case": (1.2, 1.2), "camera_dolly": (2.5, 1.67), "director_chair": (1, 1),
    "scrap_pile": (2, 2), "engine_block": (1.5, 1.5), "toolbox_chest": (1.5, 1.5), "filing_cabinet": (1, 1), "round_rug": (4, 4),
}
# existing hand-made frames reused as painted shots
EXTRA_SHOTS = {"apartment": "assets/art/cutscenes/apartment_1988.webp", "tv_news": "assets/art/cutscenes/news_1988.webp"}


# texel density over the original 2 per world pixel: sprites and floors are
# made at 2 x 2 = 4 texels per world pixel (ArtLib draws them at the old size)
DENSITY = 2


def out(*p):
    path = os.path.join(ROOT, *p)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def crop_169(im):
    w, h = im.size
    if w / h > 16 / 9:
        nw = int(h * 16 / 9)
        x = (w - nw) // 2
        return im.crop((x, 0, x + nw, h))
    nh = int(w * 9 / 16)
    y = (h - nh) // 2
    return im.crop((0, y, w, y + nh))


def glow_mask(im):
    """Bright, saturated pixels (neon, screens, lamps, fire) -> soft mask."""
    hsv = np.asarray(im.convert("HSV")).astype(np.float32) / 255.0
    s, v = hsv[..., 1], hsv[..., 2]
    rgb = np.asarray(im).astype(np.float32) / 255.0
    lum = rgb.max(axis=2)
    m = np.clip((v - 0.62) * 3.2, 0, 1) * np.clip((s - 0.25) * 2.5, 0, 1)
    m = np.maximum(m, np.clip((lum - 0.9) * 8.0, 0, 1) * 0.7)     # near-white hot spots
    mi = Image.fromarray((m * 255).astype(np.uint8), "L").resize((320, 180), Image.LANCZOS)
    return mi.filter(ImageFilter.GaussianBlur(1.6))


def shots():
    srcs = {os.path.basename(f)[:-5]: f for f in glob.glob(os.path.join(RAW, "shots", "*.webp"))}
    for k, v in EXTRA_SHOTS.items():
        srcs.setdefault(k, os.path.join(ROOT, v))
    for sid, f in sorted(srcs.items()):
        im = crop_169(Image.open(f).convert("RGB")).resize((1280, 720), Image.LANCZOS)
        im.save(out("assets", "art", "painted", sid + ".webp"), "WEBP", quality=80, method=6)
        glow_mask(im).save(out("assets", "art", "painted", sid + "_glow.png"), optimize=True)
    print("shots:", len(srcs))


def portraits():
    n = 0
    for f in glob.glob(os.path.join(RAW, "portraits", "*.webp")):
        pid = os.path.basename(f)[:-5]
        im = Image.open(f).convert("RGB")
        w, h = im.size
        # a little tighter on the face, like the painted sheet
        m = int(w * 0.08)
        im = im.crop((m, int(h * 0.02), w - m, h - int(h * 0.14))).resize((192, 192), Image.LANCZOS)
        im.save(out("assets", "characters", "portraits", pid + ".png"))
        n += 1
    print("portraits:", n)


def pixelize(im, size, colors=48):
    """Downscale an RGBA painting to game density: palette-reduced colour,
    hard alpha, 1 px ink outline."""
    im = im.convert("RGBA")
    bbox = im.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
    if bbox:
        im = im.crop(bbox)
    tw, th = size
    # fit inside, keep aspect, pad to the exact size
    k = min((tw - 2) / im.width, (th - 2) / im.height)
    nw, nh = max(1, round(im.width * k)), max(1, round(im.height * k))
    small = im.resize((nw, nh), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
    a = np.asarray(small.getchannel("A"))
    rgb = small.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    arr = np.dstack([np.asarray(rgb), np.where(a > 110, 255, 0).astype(np.uint8)])
    canvas = np.zeros((th, tw, 4), np.uint8)
    ox, oy = (tw - nw) // 2, (th - nh) // 2
    canvas[oy:oy + nh, ox:ox + nw] = arr
    # ink outline around the silhouette
    solid = canvas[..., 3] > 0
    grow = np.zeros_like(solid)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        grow |= np.roll(np.roll(solid, dx, 1), dy, 0)
    if DENSITY > 1:
        # the outline keeps its weight at the higher density: two texels
        g2 = grow.copy()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            g2 |= np.roll(np.roll(grow, dx, 1), dy, 0)
        grow = g2
    edge = grow & ~solid
    canvas[edge] = (*INK, 255)
    return Image.fromarray(canvas, "RGBA")


def sprites():
    n = 0
    for f in glob.glob(os.path.join(RAW, "sprites", "*.webp")):
        sid = os.path.basename(f)[:-5]
        tiles = SPRITE_TILES.get(sid, (1, 1))
        size = (max(16, int(tiles[0] * 32 * DENSITY)), max(16, int(tiles[1] * 32 * DENSITY)))
        im = Image.open(f)
        if im.mode != "RGBA":
            # no transparency came back: key out the flat background colour
            im = im.convert("RGBA")
            arr = np.asarray(im).astype(np.int16)
            bg = arr[0, 0, :3]
            d = np.abs(arr[..., :3] - bg).sum(axis=2)
            arr[..., 3] = np.where(d < 40, 0, 255)
            im = Image.fromarray(arr.astype(np.uint8), "RGBA")
        pixelize(im, size, 128 if tiles[0] * tiles[1] >= 4 else 96).save(out("assets", "art", "sprites", sid + ".png"))
        n += 1
    print("sprites:", n)


def seamless(im):
    """Blend the image with a half-offset copy across its seams so it tiles."""
    a = np.asarray(im).astype(np.float32)
    h, w = a.shape[:2]
    b = np.roll(np.roll(a, h // 2, 0), w // 2, 1)
    yy = np.abs(np.linspace(-1, 1, h))[:, None]
    xx = np.abs(np.linspace(-1, 1, w))[None, :]
    # weight of the rolled copy: 1 at the original edges, 0 in the middle
    wgt = np.clip(np.maximum(yy, xx) * 1.6 - 0.6, 0, 1)[..., None]
    return Image.fromarray((a * (1 - wgt) + b * wgt).astype(np.uint8))


def textures():
    n = 0
    for f in glob.glob(os.path.join(RAW, "textures", "*.webp")):
        tid = os.path.basename(f)[:-5]
        im = seamless(Image.open(f).convert("RGB")).resize((256 * DENSITY, 256 * DENSITY), Image.LANCZOS)
        im = im.filter(ImageFilter.UnsharpMask(radius=1.4, percent=70, threshold=2))
        im.save(out("assets", "art", "floors", tid + ".png"))
        n += 1
    print("textures:", n)


def posters():
    """Vertical movie posters -> 16:9 frames for the inspect view: the poster
    centred on a blurred, darkened wash of itself (painted/poster_<id>)."""
    n = 0
    for f in glob.glob(os.path.join(RAW, "posters", "*.webp")):
        pid = os.path.basename(f)[:-5]
        im = Image.open(f).convert("RGB")
        bg = im.resize((1280, int(1280 * im.height / im.width)), Image.LANCZOS)
        top = (bg.height - 720) // 2
        bg = bg.crop((0, top, 1280, top + 720)).filter(ImageFilter.GaussianBlur(18))
        bg = Image.eval(bg, lambda v: int(v * 0.35))
        ph = 680
        pw = int(im.width * ph / im.height)
        bg.paste(im.resize((pw, ph), Image.LANCZOS), ((1280 - pw) // 2, 20))
        bg.save(out("assets", "art", "painted", "poster_" + pid + ".webp"), "WEBP", quality=82, method=6)
        glow_mask(bg).save(out("assets", "art", "painted", "poster_" + pid + "_glow.png"), optimize=True)
        n += 1
    print("posters:", n)


def weapons():
    """HUD weapon icons: trimmed to the object, fitted into 256x128
    (art/weapons/<id>.png, transparent)."""
    n = 0
    for f in glob.glob(os.path.join(RAW, "weapons", "*.webp")):
        wid = os.path.basename(f)[:-5].replace("weapon_", "")
        im = Image.open(f).convert("RGBA")
        a = np.asarray(im)[:, :, 3]
        ys, xs = np.nonzero(a > 24)
        if len(xs) == 0:
            continue
        im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
        k = min(248 / im.width, 120 / im.height)
        im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)
        c = Image.new("RGBA", (256, 128), (0, 0, 0, 0))
        c.paste(im, ((256 - im.width) // 2, (128 - im.height) // 2), im)
        c.save(out("assets", "art", "weapons", wid + ".png"), optimize=True)
        n += 1
    print("weapons:", n)


def masks():
    """mask cards: trimmed, centred in 256x256, transparent (art/masks/<id>.png)"""
    n = 0
    for f in glob.glob(os.path.join(RAW, "masks", "*.webp")):
        mid = os.path.basename(f)[:-5]
        im = Image.open(f).convert("RGBA")
        a = np.asarray(im)[:, :, 3]
        ys, xs = np.nonzero(a > 24)
        if len(xs):
            im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
        k = 236 / max(im.width, im.height)
        im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)
        c = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        c.paste(im, ((256 - im.width) // 2, (256 - im.height) // 2), im)
        c.save(out("assets", "art", "masks", mid + ".png"), optimize=True)
        n += 1
    print("masks:", n)


def covers():
    """VHS box covers: 2:3, 360x540 webp (art/covers/<id>.webp)"""
    n = 0
    for f in glob.glob(os.path.join(RAW, "covers", "*.webp")):
        cid = os.path.basename(f)[:-5]
        im = Image.open(f).convert("RGB").resize((360, 540), Image.LANCZOS)
        im.save(out("assets", "art", "covers", cid + ".webp"), "WEBP", quality=86, method=6)
        n += 1
    print("covers:", n)


def _trimmed(f):
    im = Image.open(f).convert("RGBA")
    a = im.getchannel("A").point(lambda v: 255 if v > 24 else 0)
    bb = a.getbbox()
    return im.crop(bb) if bb else im


def _fit(im, w, h, colors=160):
    """Into a w x h canvas (4 texels per world pixel), centred, outlined."""
    return pixelize(im, (w, h), colors)


def cast():
    """Painted cast for the game world (assets/art/cast): corpses in the
    corpse canvas (48x32 at 2x -> 96x64), boss bodies in the torso canvas
    (32x32 -> 64x64), dogs as a free-size sprite (drawn to length)."""
    n = 0
    for f in glob.glob(os.path.join(RAW, "corpses", "*.webp")):
        cid = os.path.basename(f)[:-5]
        _fit(_trimmed(f), 96, 64).save(out("assets", "art", "cast", "corpse_" + cid + ".png"))
        n += 1
    for f in glob.glob(os.path.join(RAW, "topdown", "*.webp")):
        tid = os.path.basename(f)[:-5]
        if tid.startswith("boss_"):
            _fit(_trimmed(f), 64, 64).save(out("assets", "art", "cast", tid + ".png"))
        else:
            im = _trimmed(f)
            k = 128 / im.width
            pixelize(im, (128, max(16, round(im.height * k))), 160).save(out("assets", "art", "cast", tid.replace("dog_", "dog_") + ".png"))
        n += 1
    for f in glob.glob(os.path.join(RAW, "bodies", "*.webp")):
        bid = os.path.basename(f)[:-5]
        im = _trimmed(f)
        k = 112 / max(im.width, im.height)
        pixelize(im, (max(16, round(im.width * k)) + 4, max(16, round(im.height * k)) + 4), 160).save(out("assets", "art", "cast", "body_" + bid + ".png"))
        n += 1
    print("cast:", n)


def materials():
    """Cloth materials for the character painter (assets/art/materials):
    seamless, greyscale, contrast normalised around mid-grey, 96 px."""
    n = 0
    for f in glob.glob(os.path.join(RAW, "materials", "*.webp")):
        mid = os.path.basename(f)[:-5]
        im = seamless(Image.open(f).convert("RGB")).resize((96, 96), Image.LANCZOS).convert("L")
        a = np.asarray(im).astype(np.float32)
        a = (a - a.mean()) / (a.std() + 1e-6) * 0.18 + 0.5
        Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L").convert("RGB").save(out("assets", "art", "materials", mid + ".png"))
        n += 1
    print("materials:", n)


if __name__ == "__main__":
    only = sys.argv[1:]
    for fn in (shots, portraits, sprites, textures, posters, weapons, masks, covers, cast, materials):
        if not only or fn.__name__ in only:
            fn()
