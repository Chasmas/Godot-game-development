#!/usr/bin/env python3
"""Generate a readable high-detail kennel kit for review before integration.

Outputs go to C:/tmp_shots/kennel_kit.  They are deliberately staged first:
the game gets only the assets that retain a clear silhouette at play scale.
"""
import base64, io, json, os, sys, time, urllib.request, urllib.error
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixellab_upgrade_sprites import b64, clear_backdrop, key

OUT = "C:/tmp_shots/kennel_kit"
STYLE = ("orthographic floor-plan pixel art sprite viewed from exactly 90 degrees above, camera looking straight down, "
         "all parallel edges remain parallel, zero perspective and zero visible side faces, 1980s California neon noir, "
         "rich material texture, warm sodium rim light and cool cyan bounce, single black outline, "
         "clean readable silhouette at gameplay scale, isolated on transparent background")
ASSETS = {
    "kennel_cage": "rectangular chain-link kennel floor-plan: thin square steel perimeter fence seen only from above, clear hinged gate opening on one short side, padlock beside the gate, worn rubber floor mat visible through the empty centre; no animal, no bowl, no solid building walls",
    "kennel_dog_bed": "empty oval blue canvas dog cushion seen only from above, compressed centre, patched seam, folded blanket tucked against one edge and one small tennis ball beside it; no dog, no body parts",
    "kennel_dog_bowl": "two small round stainless-steel pet dishes seen only from above, one filled with reflective clean water and one with a modest amount of kibble; no bone, no animal, no body parts",
}

def generate(asset_id: str, description: str) -> str:
    body = {
        "description": f"{description}, {STYLE}",
        "negative_description": "isometric, three-quarter view, front view, side view, visible side faces, vanishing point, building, blurry, noisy, unreadable text, watermark, floor background, duplicate objects, dog, skeleton, bone, body parts",
        "image_size": {"width": 128, "height": 128}, "no_background": True,
        "detail": "highly detailed", "shading": "highly detailed shading",
        "outline": "single color black outline", "text_guidance_scale": 7.0,
    }
    if asset_id == "kennel_cage":
        guide_path = os.path.join(OUT, "kennel_cage_guide_imagegen.png")
        if os.path.exists(guide_path):
            guide = clear_backdrop(Image.open(guide_path).convert("RGBA"))
            bbox = guide.getbbox()
            if bbox:
                guide = guide.crop(bbox)
            guide.thumbnail((116, 116), Image.Resampling.LANCZOS)
            init = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
            init.alpha_composite(guide, ((128 - guide.width) // 2, (128 - guide.height) // 2))
            body["init_image"] = b64(init)
            body["init_image_strength"] = 650
    for attempt in range(6):
        req = urllib.request.Request("https://api.pixellab.ai/v2/create-image-pixflux", data=json.dumps(body).encode(),
            headers={"Authorization": "Bearer " + key(), "Content-Type": "application/json"})
        try:
            response = json.load(urllib.request.urlopen(req, timeout=300))
            raw = response["image"]["base64"].split(",")[-1]
            image = clear_backdrop(Image.open(io.BytesIO(base64.b64decode(raw))).convert("RGBA"))
            os.makedirs(OUT, exist_ok=True)
            image.save(os.path.join(OUT, asset_id + ".png"))
            return "ok"
        except urllib.error.HTTPError as err:
            if err.code == 429:
                time.sleep(20 * (attempt + 1)); continue
            return f"HTTP {err.code}"
    return "rate limited"

if __name__ == "__main__":
    requested = set(sys.argv[1:]) or set(ASSETS)
    for asset_id, description in ASSETS.items():
        if asset_id in requested:
            print(asset_id, generate(asset_id, description), flush=True)
