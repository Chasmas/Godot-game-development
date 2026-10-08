#!/usr/bin/env python3
"""Stage overhead PixelLab mask sprites for gameplay review; never applies them.

Run with one or more ids, or no ids for the full collection. Results are kept
in C:/tmp_shots/masks_world until visual review approves every silhouette.
"""
import base64, io, json, os, sys, time, urllib.request, urllib.error
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixellab_upgrade_sprites import b64, clear_backdrop, key

OUT = "C:/tmp_shots/masks_world"
STYLE = ("flat wearable face-mask prop lying face-up on a surface, viewed from directly overhead with no portrait head, "
         "pixel art game sprite, 1980s California neon noir, highly detailed shading, crisp readable silhouette at small gameplay scale, "
         "single black outline, transparent background, no character, no text, no watermark")
MASKS = {
    "star": "white theatrical mask with a cracked gold five-point star over one eye",
    "soldier": "weathered olive combat half-mask, canvas straps and scratched metal cheek plates",
    "dog": "black and tan Doberman-inspired leather mask, pointed ears and brass collar studs",
    "cowboy": "sun-faded leather outlaw mask with a red bandana knot and small sheriff-star scar",
    "angel": "porcelain angel mask with a thin gold halo ring and hairline cracks",
    "saint": "ivory hockey goalie mask with round ventilation holes, dark eye sockets, red forehead mark, a thin broken metal halo above it and a white cloth knot below it; preserve this exact holy-hockey-mask silhouette",
    "ghost": "off-white ghost sheet mask with sewn eye holes and frayed hem",
    "fool": "neon carnival jester mask with asymmetric bells and cracked painted smile",
    "king": "ornate gold king mask with a small crooked crown and emerald insets",
    "devil": "charcoal devil mask with short red horns, ember cracks and dark leather straps",
    "king_hidden": "damaged obsidian king mask, broken crown, violet neon crack and hidden royal insignia",
}

def make(mask_id: str) -> str:
    if mask_id not in MASKS:
        return "unknown mask"
    body = {"description": f"{MASKS[mask_id]}, {STYLE}",
        "negative_description": "front portrait, side view, human face, full body, blurry, noisy, isometric, background, duplicate masks",
        "image_size": {"width": 128, "height": 128}, "no_background": True,
        "detail": "highly detailed", "shading": "highly detailed shading", "outline": "single color black outline", "text_guidance_scale": 7.0}
    # Saint has a distinctive halo and cloth knot. Keep the existing menu art
    # as an image reference so the new gameplay sprite does not lose them.
    if mask_id == "saint":
        source = Image.open(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "assets", "art", "masks", "saint.png")).convert("RGBA")
        body["init_image"] = b64(source.resize((128, 128), Image.Resampling.NEAREST))
        body["init_image_strength"] = 260
    for attempt in range(6):
        req = urllib.request.Request("https://api.pixellab.ai/v2/create-image-pixflux", data=json.dumps(body).encode(),
            headers={"Authorization": "Bearer " + key(), "Content-Type": "application/json"})
        try:
            response = json.load(urllib.request.urlopen(req, timeout=300))
            raw = response["image"]["base64"].split(",")[-1]
            im = clear_backdrop(Image.open(io.BytesIO(base64.b64decode(raw))).convert("RGBA"))
            os.makedirs(OUT, exist_ok=True); im.save(os.path.join(OUT, mask_id + ".png"))
            return "ok"
        except urllib.error.HTTPError as error:
            if error.code == 429:
                time.sleep(20 * (attempt + 1)); continue
            return f"HTTP {error.code}"
    return "rate limited"

if __name__ == "__main__":
    ids = sys.argv[1:] or list(MASKS)
    for mask_id in ids:
        print(mask_id, make(mask_id), flush=True)
