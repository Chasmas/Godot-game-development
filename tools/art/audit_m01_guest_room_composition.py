"""Validate the guest-room rebuild as a staging-only visual study."""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ROOM = ROOT / "assets/art/prerendered/m01_sunset_palms/staging/guest_room_composition_v10"
required = (ROOM / "guest_room_composition.blend", ROOM / "guest_room_composition.png", ROOM / "review.json")
missing = [str(path.relative_to(ROOT)) for path in required if not path.is_file()]
if missing:
    raise SystemExit("Guest-room composition missing: " + ", ".join(missing))
review = json.loads((ROOM / "review.json").read_text(encoding="utf-8"))
if review.get("runtime_approved"):
    raise SystemExit("Guest-room staging study must not self-approve runtime promotion")
if any("gameplay projection" in item.lower() for item in review.get("pending", [])) is False:
    raise SystemExit("Guest-room review must retain gameplay-projection validation as pending")
with Image.open(ROOM / "guest_room_composition.png") as image:
    if image.width < 1280 or image.height < 960:
        raise SystemExit(f"Guest-room render too small: {image.size}")
for root in (ROOT / "scripts", ROOT / "levels"):
    for path in root.rglob("*"):
        if path.is_file() and path.suffix not in {".png", ".blend", ".import"}:
            if "guest_room_composition_v10" in path.read_text(encoding="utf-8", errors="ignore"):
                raise SystemExit("Guest-room staging leak: " + str(path.relative_to(ROOT)))
print("M01 guest-room staging audit: PASS (v10 is review-only and runtime-isolated)")
