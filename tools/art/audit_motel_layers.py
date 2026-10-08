"""Validate the preview layer contract for Sunset Palms."""

from pathlib import Path
import re
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
LAYER_DIR = ROOT / "assets/art/prerendered/m01_sunset_palms/layers"
EXPECTED = ("ground.png", "architecture.png", "props_vegetation.png", "foreground_occlusion.png")
STAGING = ("ground_no_emissive_review.png", "ground_no_pool_review.png", "ground_no_pool_neutral_review.png")
GALLERY = ROOT / "tools/level_gallery.gd"


def audit_gallery_mapping(errors):
    text = GALLERY.read_text(encoding="utf-8")
    neutral = re.search(
        r'"res://assets/art/prerendered/m01_sunset_palms/layers/ground_no_pool_neutral_review\.png"\s*\]\s*if ground_only and ground_neutral',
        text,
    )
    no_pool = re.search(
        r'"res://assets/art/prerendered/m01_sunset_palms/layers/ground_no_pool_review\.png"\s*\]\s*if ground_only and ground_no_pool',
        text,
    )
    if not neutral:
        errors.append("gallery neutral flag does not select ground_no_pool_neutral_review.png")
    if not no_pool:
        errors.append("gallery no-pool flag does not select ground_no_pool_review.png")


def audit_runtime_isolation(errors):
    """Ensure prerender plates stay opt-in and gallery-only."""
    for base in (ROOT / "scripts", ROOT / "levels", ROOT / "scenes"):
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if path.suffix not in {".gd", ".tscn", ".json"}:
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            if "assets/art/prerendered" in text:
                relative = path.relative_to(ROOT).as_posix()
                if relative != "scripts/levels/level.gd" or "APPROVED_M01_GROUND_PLATE" not in text:
                    errors.append(f"runtime prerender reference: {relative}")

def main() -> int:
    errors = []
    sizes = set()
    audit_gallery_mapping(errors)
    audit_runtime_isolation(errors)
    for name in EXPECTED + STAGING:
        path = LAYER_DIR / name
        if not path.exists():
            errors.append(f"missing: {name}")
            continue
        with Image.open(path) as image:
            sizes.add(image.size)
            if image.mode != "RGBA":
                errors.append(f"no alpha: {name} ({image.mode})")
            if image.getbbox() is None:
                errors.append(f"empty: {name}")
    if len(sizes) > 1:
        errors.append(f"inconsistent sizes: {sorted(sizes)}")
    if errors:
        print("M01 layer audit: FAIL")
        print("\n".join(f"- {item}" for item in errors))
        return 1
    print(f"M01 layer audit: PASS ({len(EXPECTED)} runtime-contract + {len(STAGING)} staging RGBA layers, {next(iter(sizes))})")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
