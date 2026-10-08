"""Repaint plain top-down rig guides into PixelLab torso layers.

Guides come from tools/art/topdown_pose_guides.gd (64 px, rig hand coordinates).
Outputs review-only candidates under C:/tmp_shots/topdown_pose_pixellab.
There is intentionally no apply mode: copy a candidate into
assets/art/pixellab_cast_v4/ only after it passes a runtime review at
aim 0/90/180/270 degrees.

Usage: python tools/art/pixellab_topdown_poses.py guard [pose ...] [--strength N]
"""

from __future__ import annotations

import argparse
import base64
import colorsys
import io
import json
import time
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image

from pixellab_upgrade_sprites import b64, clear_backdrop, key


GUIDES = Path("C:/tmp_shots/topdown_pose_guides")
OUT = Path("C:/tmp_shots/topdown_pose_pixellab")
ENDPOINT = "https://api.pixellab.ai/v2/create-image-pixflux"
POSES = ["unarmed", "aim_one", "aim_two", "melee"]

IDENTITIES = {
    "guard": "motel security guard, navy patrol cap with small brass badge on the crown, navy short sleeve uniform shirt, black shoulder radio",
}

# Guide shirt hue range -> (target hue, saturation scale, value scale). The rig
# palette and the approved identity can disagree; recolouring the guide is far
# more reliable than asking the prompt to override the init image's colours.
RECOLOR = {
    "guard": ((0.42, 0.56), 0.61, 0.55, 0.82),
}

ACTIONS = {
    "unarmed": "both arms bent forward, fists in front of the chest",
    "aim_one": "one arm reaching straight forward, the other hand near the near shoulder",
    "aim_two": "both arms reaching forward together, hands close at the front",
    "melee": "one arm forward, the other drawn back beside the body",
}

NEGATIVE = (
    "face, front view, side view, portrait, isometric, standing figure, legs, "
    "feet, arm over head, hand on head, extra limbs, background, floor, shadow, "
    "text, watermark, blurry, smooth vector art"
)


def prompt(look: str, pose: str) -> str:
    return (
        f"strict top-down view from directly above of a {IDENTITIES[look]}, "
        "seen from overhead like a 1980s top-down shooter, facing right, "
        "round head at the center showing the top of the cap, shoulders above "
        f"and below the head, {ACTIONS[pose]}, arms pointing to the right and "
        "never crossing the head, neon-noir pixel art, crisp pixels, single dark "
        "outline, transparent background"
    )


def recolor(look: str, guide: Image.Image) -> Image.Image:
    if look not in RECOLOR:
        return guide
    (low, high), hue, sat_k, val_k = RECOLOR[look]
    out = guide.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if low < h < high and s > 0.25:
                r2, g2, b2 = colorsys.hsv_to_rgb(hue, min(1.0, s * sat_k), v * val_k)
                px[x, y] = (round(r2 * 255), round(g2 * 255), round(b2 * 255), a)
    return out


def generate(look: str, pose: str, strength: int) -> Path:
    guide = recolor(look, Image.open(GUIDES / f"{look}_{pose}.png").convert("RGBA"))
    guide.save(OUT / f"{look}_{pose}_guide.png")
    body = {
        "description": prompt(look, pose),
        "negative_description": NEGATIVE,
        "image_size": {"width": guide.width, "height": guide.height},
        "no_background": True,
        "init_image": b64(guide),
        "init_image_strength": strength,
        "view": "high top-down",
        "detail": "highly detailed",
        "shading": "detailed shading",
        "outline": "single color black outline",
        "text_guidance_scale": 8.0,
    }
    encoded = json.dumps(body).encode("utf-8")
    for attempt in range(8):
        request = urllib.request.Request(
            ENDPOINT,
            data=encoded,
            headers={"Authorization": "Bearer " + key(), "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=300) as response:
                result = json.load(response)
            data = base64.b64decode(result["image"]["base64"].split(",")[-1])
            image = clear_backdrop(Image.open(io.BytesIO(data)).convert("RGBA"))
            destination = OUT / f"{look}_{pose}_s{strength}.png"
            image.save(destination)
            return destination
        except urllib.error.HTTPError as exc:
            if exc.code != 429:
                raise RuntimeError(f"PixelLab HTTP {exc.code}: {exc.read(400).decode('utf-8', 'replace')}") from exc
            time.sleep(20 * (attempt + 1))
    raise RuntimeError("PixelLab remained rate-limited after eight attempts")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("look")
    parser.add_argument("poses", nargs="*", default=POSES)
    parser.add_argument("--strength", type=int, default=700)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    for pose in args.poses:
        print(generate(args.look, pose, args.strength), flush=True)
    (OUT / "REVIEW_ONLY.txt").write_text(
        "Not approved. Review each candidate in runtime at aim 0/90/180/270 before integration.\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
