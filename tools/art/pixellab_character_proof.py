"""Generate one isolated character-perspective proof for visual review.

Nothing produced here is copied into the Godot runtime.  This tool exists to
prove the camera, anatomy, silhouette and identity on one guard before any
batch generation resumes.

    python tools/art/pixellab_character_proof.py

Output:
    C:/tmp_shots/character_oblique_proof/guard_alive.png
    C:/tmp_shots/character_oblique_proof/guard_dead.png
"""

from __future__ import annotations

import base64
import io
import json
import time
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image

from pixellab_upgrade_sprites import b64, clear_backdrop, key


OUT = Path("C:/tmp_shots/character_oblique_proof")
ENDPOINT = "https://api.pixellab.ai/v2/create-image-pixflux"

STYLE = (
    "premium highly detailed pixel art action-game sprite, 1980s California "
    "neon-noir, transparent background, crisp intentional pixels, coherent "
    "anatomy, clean readable silhouette, restrained single dark outline"
)

IDENTITY = (
    "adult male California roadside motel security guard, weathered face, "
    "short dark moustache, navy patrol cap with small brass badge, navy short "
    "sleeve uniform shirt, brass name plate, shoulder radio, black duty belt, "
    "navy trousers and black patrol shoes"
)

ALIVE = (
    f"{IDENTITY}, complete full body standing in a compact alert stance, "
    "both arms and both separated legs fully visible, holding a pistol low in "
    "both hands, three-quarter top-down oblique camera about 55 degrees above "
    "the horizon like a classic top-down action game, crown of head visible "
    "but also the brow eyes nose moustache and lower face partly readable, "
    "head torso pelvis limbs gear and weapon all share the exact same camera "
    f"angle, {STYLE}"
)

DEAD = (
    f"the exact same {IDENTITY}, complete full body lying motionless on his "
    "right side, both arms and both legs fully present and readable, cap still "
    "on, pistol beside one hand, same three-quarter top-down oblique camera "
    "about 55 degrees above the horizon, side of face with brow nose moustache "
    "and jaw partly readable, head torso pelvis limbs gear and weapon all share "
    "the exact same camera angle, small restrained dark blood stain under the "
    f"shoulder, {STYLE}"
)

NEGATIVE = (
    "strict vertical 90 degree overhead camera, ceiling view, frontal portrait, "
    "eye-level camera, side-scroller view, isometric room, bust, torso only, "
    "cropped body, missing face, face hidden entirely by hair or cap, faceless, "
    "head down, chin touching chest, missing arms, missing legs, fused legs, "
    "detached limbs, extra limbs, giant head, floating torso, mannequin, skeleton, "
    "exposed bones, excessive gore, background, floor, text, logo, watermark, "
    "smooth vector art, painting, blurry pixels"
)


def prepare_runtime_guide(path: Path, width: int, height: int) -> Image.Image:
    image = clear_backdrop(Image.open(path).convert("RGBA"))
    # Remove chroma-key fringe left by viewport filtering.
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha and red > 105 and blue > 105 and green < min(red, blue) * 0.72:
                pixels[x, y] = (0, 0, 0, 0)
    box = image.getbbox()
    if box:
        image = image.crop(box)
    image.thumbnail((width - 24, height - 24), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    canvas.alpha_composite(
        image,
        ((width - image.width) // 2, (height - image.height) // 2),
    )
    return canvas


def generate(
    description: str,
    width: int,
    height: int,
    guide_path: Path | None = None,
) -> Image.Image:
    body = {
        "description": description,
        "negative_description": NEGATIVE,
        "image_size": {"width": width, "height": height},
        "no_background": True,
        "detail": "highly detailed",
        "shading": "highly detailed shading",
        "outline": "single color black outline",
        "text_guidance_scale": 9.0,
    }
    if guide_path is not None:
        body["init_image"] = b64(prepare_runtime_guide(guide_path, width, height))
        body["init_image_strength"] = 680
    data = json.dumps(body).encode("utf-8")
    for attempt in range(8):
        request = urllib.request.Request(
            ENDPOINT,
            data=data,
            headers={
                "Authorization": "Bearer " + key(),
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=300) as response:
                result = json.load(response)
            encoded = result["image"]["base64"].split(",")[-1]
            image = Image.open(io.BytesIO(base64.b64decode(encoded))).convert("RGBA")
            return clear_backdrop(image)
        except urllib.error.HTTPError as exc:
            if exc.code != 429:
                message = exc.read(256).decode("utf-8", errors="replace")
                raise RuntimeError(f"PixelLab HTTP {exc.code}: {message}") from exc
            time.sleep(20 * (attempt + 1))
    raise RuntimeError("PixelLab remained rate-limited after eight attempts")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = (
        (
            "guard_alive_imagegen_guided.png",
            ALIVE,
            192,
            256,
            OUT / "guard_anatomy_guide_imagegen.png",
        ),
    )
    for filename, prompt, width, height, guide_path in jobs:
        destination = OUT / filename
        generate(prompt, width, height, guide_path).save(destination)
        print(destination)
    (OUT / "REVIEW_ONLY.txt").write_text(
        "Not approved and not integrated. Inspect both images and a gameplay-scale "
        "mockup before copying anything into assets/art.\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
