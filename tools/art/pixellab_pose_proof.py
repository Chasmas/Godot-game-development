"""Repaint one existing v4 character pose without changing its camera.

Outputs review-only candidates under C:/tmp_shots/character_pose_proof.
There is intentionally no apply mode.
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


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/art/pixellab_cast_v4"
OUT = Path("C:/tmp_shots/character_pose_proof")
ENDPOINT = "https://api.pixellab.ai/v2/create-image-pixflux"

IDENTITIES = {
    "guard": (
        "adult male California roadside motel security guard, weathered face "
        "with short dark moustache, navy patrol cap with a small brass badge, "
        "navy short sleeve uniform, shoulder radio and black duty belt"
    ),
}


def prompt(look: str, pose: str) -> str:
    action = {
        "unarmed": "compact alert stance with arms relaxed close to the body",
        "aim_one": "one arm extended and one supporting arm, aiming a pistol",
        "aim_two": "both arms extended together, aiming a pistol",
        "melee": "balanced close-combat stance with both arms readable",
    }[pose]
    return (
        f"{IDENTITIES[look]}, {action}, upper body game-animation layer facing "
        "right, three-quarter top-down oblique camera about 60 degrees above "
        "the horizon, crown of head visible while brow eyes nose moustache and "
        "jaw remain partly readable, head face shoulders torso and arms at one "
        "consistent angle, preserve the exact supplied silhouette and limb "
        "placement, premium detailed 1980s California neon-noir pixel art, "
        "crisp intentional pixels, transparent background, single dark outline"
    )


NEGATIVE = (
    "strict vertical ceiling view, face completely hidden, faceless, front "
    "portrait, eye-level camera, side view, isometric room, full body, legs, "
    "cropped head, missing arms, fused arms, detached hands, extra limbs, giant "
    "head, floating bust, background, floor, shadow, text, logo, watermark, "
    "photorealistic, smooth vector art, blurry pixels"
)


def square_guide(source: Image.Image) -> Image.Image:
    """Fit a full-body guide without cropping its head, hands, or feet."""
    source = source.convert("RGBA")
    bounds = source.getbbox()
    if bounds:
        source = source.crop(bounds)
    source.thumbnail((112, 112), Image.Resampling.LANCZOS)
    guide = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    guide.alpha_composite(source, ((128 - source.width) // 2, (128 - source.height) // 2))
    return guide


def generate(
    look: str,
    pose: str,
    strength: int = 620,
    suffix: str = "",
    guide_path: Path | None = None,
) -> Path:
    source_path = guide_path or (SOURCE / f"{look}_{pose}.png")
    source = Image.open(source_path).convert("RGBA")
    init = square_guide(source) if guide_path else source.resize((128, 128), Image.Resampling.NEAREST)
    body = {
        "description": prompt(look, pose),
        "negative_description": NEGATIVE,
        "image_size": {"width": 128, "height": 128},
        "no_background": True,
        "init_image": b64(init),
        "init_image_strength": strength,
        "detail": "highly detailed",
        "shading": "highly detailed shading",
        "outline": "single color black outline",
        "text_guidance_scale": 8.5,
    }
    encoded = json.dumps(body).encode("utf-8")
    for attempt in range(8):
        request = urllib.request.Request(
            ENDPOINT,
            data=encoded,
            headers={
                "Authorization": "Bearer " + key(),
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=300) as response:
                result = json.load(response)
            image_data = base64.b64decode(result["image"]["base64"].split(",")[-1])
            output = clear_backdrop(Image.open(io.BytesIO(image_data)).convert("RGBA"))
            destination = OUT / f"{look}_{pose}{suffix}.png"
            output.save(destination)
            return destination
        except urllib.error.HTTPError as exc:
            if exc.code != 429:
                message = exc.read(256).decode("utf-8", errors="replace")
                raise RuntimeError(f"PixelLab HTTP {exc.code}: {message}") from exc
            time.sleep(20 * (attempt + 1))
    raise RuntimeError("PixelLab remained rate-limited after eight attempts")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    anatomy_guide = OUT / "guard_unarmed_arms_clear_guide.png"
    if anatomy_guide.exists():
        print(generate("guard", "unarmed", 700, "_arms_clear", anatomy_guide), flush=True)
    else:
        print(generate("guard", "unarmed", 480, "_detail"), flush=True)
    (OUT / "REVIEW_ONLY.txt").write_text(
        "Not approved and not integrated. Compare camera, face, hands and pose "
        "continuity before generating the remaining actions.\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
