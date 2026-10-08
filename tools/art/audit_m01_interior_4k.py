"""Validate optional M01 interior review renders without touching runtime assets."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RENDER_DIR = ROOT / "assets" / "art" / "prerendered" / "m01_sunset_palms" / "staging" / "4k"
EXPECTED = (
    "m01_interiors_transitions_staging.png",
    "m01_reception_detail_staging.png",
    "m01_service_transition_detail_staging.png",
)

def main() -> None:
    for name in EXPECTED:
        path = RENDER_DIR / name
        if not path.exists():
            raise SystemExit(f"FAIL: missing {path}")
        with Image.open(path) as image:
            if image.size != (3840, 2160):
                raise SystemExit(f"FAIL: {name} is {image.size}, expected (3840, 2160)")
            if image.mode not in ("RGB", "RGBA"):
                raise SystemExit(f"FAIL: {name} mode {image.mode}")
    print(f"M01 interior 4K audit: PASS ({len(EXPECTED)} RGBA/RGB renders at 3840x2160)")

if __name__ == "__main__":
    main()
