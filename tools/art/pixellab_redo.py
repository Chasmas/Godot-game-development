"""PixelLab quality-mode redraw of a chosen source painting at 2x, keeping its
silhouette (init image). Candidates land in C:/tmp_shots/redo/<name>.png; --apply
copies them to their game paths.
  python tools/art/pixellab_redo.py [--only a,b] [--apply]
"""
import base64, io, json, os, shutil, sys, time, urllib.request, urllib.error
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixellab_upgrade_sprites import ROOT, b64, clear_backdrop, key

ART = os.path.join(ROOT, "assets", "art")
HQ = os.path.join(ART, "pixellab_world", "sprites_hq")
STAGE = "C:/tmp_shots/redo"
STYLE = "highly detailed pixel art game sprite seen from above, 1980s California neon noir, rich texture, crisp pixels, clean silhouette"

# name: (source painting, game path, strength, description)
JOBS = {}
for pid, desc in {
    "bar_cart": "brass bar cart with bottles, decanters and glasses", "cigarette": "lit cigarette with a curl of smoke",
    "desk": "cluttered wooden office desk with papers, lamp, phone and typewriter", "ice_machine": "motel ice machine with a frosty scoop",
    "paper": "crumpled newspaper page", "pickup_cash": "bundle of banded cash bills", "pickup_cassette": "VHS cassette tape with a handwritten label",
    "plant": "leafy green houseplant seen from above", "plant_pot": "small potted fern in terracotta", "potted_palm": "potted palm tree seen from above, lush fronds",
    "prop_calendar": "wall calendar with a pin-up photo", "prop_room_plate": "brass motel room number plate", "security_camera": "wall mounted security camera",
    "statue": "white marble statue seen from above", "vase_flowers": "vase of pink flowers seen from above", "pallet": "wooden shipping pallet",
    "prop_trash_bag": "tied black trash bag", "tv_crt": "1980s CRT television with rabbit ears", "folding_chair": "red padded folding chair",
    "chandelier": "crystal chandelier seen from above, lit candles", "jukebox": "glowing retro jukebox",
}.items():
    JOBS[pid] = (os.path.join(ART, "sprites", pid + ".png"), os.path.join(HQ, pid + ".png"), 380, desc)
for pid, desc in {"table_dining": "dining table with white linen tablecloth, cup and saucer, sugar pot",
                  "table_office": "walnut wood table with a coffee cup, napkin holder and papers"}.items():
    JOBS[pid] = (os.path.join(ART, "sprites", pid + ".png"), os.path.join(HQ, pid + ".png"), 380, desc)
for breed, desc in {"shepherd": "german shepherd dog, black saddle and tan coat", "rottweiler": "rottweiler dog, black and rust coat, spiked collar",
                    "doberman": "doberman dog, black and rust coat, studded collar",
                    "hellhound": "demonic hellhound, charred black hide with glowing molten orange cracks"}.items():
    JOBS["dog_" + breed] = (os.path.join(ART, "cast", f"dog_{breed}.png"), os.path.join(ART, "cast", f"dog_{breed}_pl.png"), 320,
                            desc + ", seen from directly above, top-down, standing")
    JOBS[f"dog_{breed}_down"] = (os.path.join(ART, "cast", f"dog_{breed}_down.png"), os.path.join(ART, "cast", f"dog_{breed}_down_pl.png"), 320,
                                 desc + ", lying on its side")

# REJECTED LEGACY CHARACTER JOBS.
# These descriptions deliberately remain below only as an audit trail for the
# rejected 2026-10-05 batch.  They combine a strict vertical camera with
# torso-only crops and must never be generated or applied again.  Use
# pixellab_character_proof.py for the isolated oblique-camera proof.
JOBS["body_guard"] = (
    os.path.join(STAGE, "body_guard_torso_guide_imagegen.png"),
    os.path.join(ART, "pixellab_cast_v3_approved", "body_guard.png"),
    450,
    "modular head shoulders and torso of a California motel security guard in navy uniform and cap, strict direct overhead top-down view, compact square silhouette ending cleanly at the belt, no hands and no legs",
)
JOBS["corpse_guard"] = (
    os.path.join(STAGE, "corpse_guard_guide_imagegen.png"),
    os.path.join(ART, "pixellab_cast_v3_approved", "corpse_guard.png"),
    450,
    "same California motel security guard lying motionless on one side, strict direct overhead top-down view, uniform and body intact, restrained dark blood stain, no exposed skeleton and no detached bones",
)
JOBS["body_security"] = (
    os.path.join(STAGE, "body_security_torso_guide_imagegen.png"),
    os.path.join(ART, "pixellab_cast_v3_approved", "body_security.png"),
    450,
    "modular head shoulders and torso of an 1980s film studio private security officer, strict direct overhead top-down view, deep burgundy blazer cream shirt black tie gold badge and shoulder radio, compact square silhouette ending cleanly at the belt, no hands and no legs",
)
JOBS["corpse_security"] = (
    os.path.join(STAGE, "corpse_security_guide_imagegen.png"),
    os.path.join(ART, "pixellab_cast_v3_approved", "corpse_security.png"),
    450,
    "same burgundy film studio private security officer lying motionless on one side, strict direct overhead top-down view, blazer tie badge radio and body intact, restrained dark blood stain, no exposed skeleton and no detached bones",
)
JOBS["body_civilian"] = (
    os.path.join(STAGE, "body_civilian_torso_guide_imagegen.png"),
    os.path.join(ART, "pixellab_cast_v3_approved", "body_civilian.png"),
    450,
    "modular head shoulders and torso of an adult 1980s civilian woman, strict direct overhead top-down view, voluminous curly golden blonde hair gold hoop earrings and vivid hot pink patterned blouse, compact square silhouette ending cleanly at the belt, no hands and no legs",
)
JOBS["corpse_civilian"] = (
    os.path.join(STAGE, "corpse_civilian_guide_imagegen.png"),
    os.path.join(ART, "pixellab_cast_v3_approved", "corpse_civilian.png"),
    450,
    "same 1980s civilian woman lying motionless curled on one side, strict direct overhead top-down view, curly golden blonde hair pink patterned blouse black trousers and complete body intact, restrained dark blood stain, no exposed skeleton and no detached bones",
)
JOBS["body_gunner"] = (
    os.path.join(STAGE, "body_gunner_torso_guide_imagegen.png"),
    os.path.join(ART, "pixellab_cast_v3_approved", "body_gunner.png"),
    450,
    "modular head shoulders and torso of an adult 1980s gunman, strict direct overhead top-down view, slick black hair black sunglasses vivid royal purple suit dark patterned shirt and thin gold chain, compact square silhouette ending cleanly at the belt, no hands and no legs",
)
JOBS["corpse_gunner"] = (
    os.path.join(STAGE, "corpse_gunner_guide_imagegen.png"),
    os.path.join(ART, "pixellab_cast_v3_approved", "corpse_gunner.png"),
    450,
    "same adult 1980s gunman lying motionless on one side, strict direct overhead top-down view, slick black hair sunglasses royal purple suit dark patterned shirt gold chain and body intact, restrained dark blood stain, no exposed skeleton and no detached bones",
)
JOBS["body_heavy"] = (
    os.path.join(STAGE, "body_heavy_torso_guide_imagegen.png"),
    os.path.join(ART, "pixellab_cast_v3_approved", "body_heavy.png"),
    450,
    "modular head shoulders and torso of a massive adult enforcer, strict direct overhead top-down view, bald scarred head thick beard very broad shoulders sleeveless distressed dark brown leather vest metal buckles and chain, wide readable silhouette ending cleanly at the belt, no hands and no legs",
)
JOBS["corpse_heavy"] = (
    os.path.join(STAGE, "corpse_heavy_guide_imagegen.png"),
    os.path.join(ART, "pixellab_cast_v3_approved", "corpse_heavy.png"),
    450,
    "same massive adult enforcer lying motionless on one side, strict direct overhead top-down view, bald scarred head thick beard muscular arms distressed leather vest dark work trousers heavy boots and intact body, restrained dark blood stain, no exposed skeleton and no detached bones",
)
JOBS["body_hunter"] = (
    os.path.join(STAGE, "body_hunter_torso_guide_imagegen.png"),
    os.path.join(ART, "pixellab_cast_v3_approved", "body_hunter.png"),
    450,
    "modular head shoulders and torso of a lean athletic adult hunter, strict direct overhead top-down view, shaggy dark hair bright red tied bandana tattooed bare shoulders dirty off white tank top and silver dog tags, lean readable silhouette ending cleanly at the belt, no hands and no legs",
)
JOBS["corpse_hunter"] = (
    os.path.join(STAGE, "corpse_hunter_guide_imagegen.png"),
    os.path.join(ART, "pixellab_cast_v3_approved", "corpse_hunter.png"),
    450,
    "same lean athletic adult hunter lying motionless on one side, strict direct overhead top-down view, shaggy dark hair red bandana tattooed bare arms dirty off white tank dog tags dark jeans boots and intact body, restrained dark blood stain, no exposed skeleton and no detached bones",
)
JOBS["body_riot"] = (
    os.path.join(STAGE, "body_riot_torso_guide_imagegen.png"),
    os.path.join(ART, "pixellab_cast_v3_approved", "body_riot.png"),
    450,
    "modular helmet shoulders and torso of an armored adult riot officer, strict direct overhead top-down view, deep navy ballistic helmet smoky visor edge segmented blue armor reinforced shoulder plates utility straps and tactical belt, broad readable silhouette ending cleanly at the belt, no hands shield or legs",
)
JOBS["corpse_riot"] = (
    os.path.join(STAGE, "corpse_riot_guide_imagegen.png"),
    os.path.join(ART, "pixellab_cast_v3_approved", "corpse_riot.png"),
    450,
    "same armored adult riot officer lying motionless on one side, strict direct overhead top-down view, navy helmet smoky visor segmented blue armor shoulder plates knee pads tactical boots and intact body, restrained dark blood stain, no exposed skeleton and no detached bones",
)

def run(name):
    src, _, strength, desc = JOBS[name]
    im = Image.open(src).convert("RGBA")
    if (name.startswith("body_") or name.startswith("corpse_")) and src.startswith(STAGE):
        im = clear_backdrop(im)
        # Preview capture uses magenta chroma. Remove antialiased/postprocess
        # fringe too, then crop tightly so PixelLab sees the complete pose at
        # useful scale instead of treating it as a tiny icon.
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = px[x, y]
                if a and r > 120 and b > 120 and g < min(r, b) * 0.62:
                    px[x, y] = (0, 0, 0, 0)
        bbox = im.getbbox()
        if bbox:
            im = im.crop(bbox)
            framed = Image.new("RGBA", (im.width + 24, im.height + 24), (0, 0, 0, 0))
            framed.alpha_composite(im, (12, 12))
            im = framed
        if max(im.size) > 192:
            im.thumbnail((192, 192), Image.Resampling.LANCZOS)
    w, h = im.size
    k = 2 if max(w, h) * 2 <= 400 else 1
    content_w, content_h = w * k, h * k
    W, H = (content_w + 7) // 8 * 8, (content_h + 7) // 8 * 8
    init = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    left, top = (W - content_w) // 2, (H - content_h) // 2
    init.alpha_composite(im.resize((content_w, content_h), Image.NEAREST), (left, top))
    body = {"description": f"{desc}, {STYLE}", "negative_description": "blurry, flat, noisy, text, watermark, background, floor, frontal portrait, side view, isometric, extra limbs, detached limbs, exposed skeleton, loose bones",
            "image_size": {"width": W, "height": H}, "no_background": True, "init_image": b64(init), "init_image_strength": strength,
            "detail": "highly detailed", "shading": "highly detailed shading", "outline": "single color black outline", "text_guidance_scale": 7.0}
    for a in range(8):
        req = urllib.request.Request("https://api.pixellab.ai/v2/create-image-pixflux", data=json.dumps(body).encode(),
                                     headers={"Authorization": "Bearer " + key(), "Content-Type": "application/json"})
        try:
            r = json.load(urllib.request.urlopen(req, timeout=300)); break
        except urllib.error.HTTPError as e:
            if e.code == 429: time.sleep(20 * (a + 1)); continue
            return f"HTTP {e.code} {e.read()[:160]}"
    else:
        return "rate limited"
    out = clear_backdrop(Image.open(io.BytesIO(base64.b64decode(r["image"]["base64"].split(",")[-1]))).convert("RGBA"))
    if W != content_w or H != content_h:   # drop padding without scaling
        out = out.crop((left, top, left + content_w, top + content_h))
    os.makedirs(STAGE, exist_ok=True)
    out.save(f"{STAGE}/{name}.png")
    return "ok"

def guard_pose_guide():
    """Generate an open, readable top-down anatomy guide before stylized redraw."""
    body = {
        "description": (
            "Pixel art game sprite, complete full-body adult security guard viewed from directly overhead, "
            "navy motel uniform and cap, holding a pistol in two hands pointed upward, head torso both arms "
            "and two separated legs all clearly visible, wide stable stance, anatomically coherent, crisp silhouette"
        ),
        "negative_description": (
            "portrait, bust, close-up, cropped body, isometric, side view, front view, sitting, kneeling, "
            "extra limbs, detached limbs, merged legs, oversized weapon, background, floor, text, watermark, blood"
        ),
        "image_size": {"width": 128, "height": 192},
        "no_background": True,
        "detail": "highly detailed",
        "shading": "basic shading",
        "outline": "single color black outline",
        "text_guidance_scale": 9.0,
    }
    for attempt in range(8):
        req = urllib.request.Request("https://api.pixellab.ai/v2/create-image-pixflux", data=json.dumps(body).encode(),
                                     headers={"Authorization": "Bearer " + key(), "Content-Type": "application/json"})
        try:
            result = json.load(urllib.request.urlopen(req, timeout=300)); break
        except urllib.error.HTTPError as exc:
            if exc.code == 429: time.sleep(20 * (attempt + 1)); continue
            return f"HTTP {exc.code} {exc.read()[:160]}"
    else:
        return "rate limited"
    out = clear_backdrop(Image.open(io.BytesIO(base64.b64decode(result["image"]["base64"].split(",")[-1]))).convert("RGBA"))
    os.makedirs(STAGE, exist_ok=True)
    out.save(os.path.join(STAGE, "guard_pose_guide.png"))
    return "ok"

if __name__ == "__main__":
    a = sys.argv[1:]
    if any(n.startswith(("body_", "corpse_")) for n in JOBS) and (
        "--apply" in a or any(x.startswith("--only=") and any(
            p.startswith(("body_", "corpse_"))
            for p in x.split("=", 1)[1].split(",")
        ) for x in a)
    ):
        raise SystemExit(
            "Rejected overhead human jobs are locked. "
            "Use tools/art/pixellab_character_proof.py and review its staging output."
        )
    if "--guard-guide" in a:
        print("guard_pose_guide", guard_pose_guide(), flush=True)
        raise SystemExit(0)
    only = next((x.split("=", 1)[1] for x in a if x.startswith("--only=")), "")
    names = [n for n in JOBS if not only or n in only.split(",")]
    if "--apply" in a:
        for n in names:
            p = f"{STAGE}/{n}.png"
            if os.path.exists(p):
                if n.startswith("corpse_"):
                    # Runtime corpse textures face right on a 96x64 canvas.
                    src = Image.open(p).convert("RGBA").transpose(Image.Transpose.ROTATE_270)
                    src.thumbnail((92, 60), Image.Resampling.LANCZOS)
                    out = Image.new("RGBA", (96, 64), (0, 0, 0, 0))
                    out.alpha_composite(src, ((96 - src.width) // 2, (64 - src.height) // 2))
                    os.makedirs(os.path.dirname(JOBS[n][1]), exist_ok=True)
                    out.save(JOBS[n][1])
                else:
                    shutil.copy(p, JOBS[n][1])
                print("applied", n)
    else:
        for n in names:
            print(n, run(n), flush=True)
