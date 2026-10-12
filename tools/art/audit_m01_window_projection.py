"""Keep the M01 window reconstruction honest about the live map it must fit."""
from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
INVENTORY = ROOT / "build/m01_window_runtime_inventory.json"
STAGING = ROOT / "assets/art/prerendered/m01_sunset_palms/staging/window_v1"
STRIP_FAMILY = ROOT / "assets/art/prerendered/m01_sunset_palms/staging/window_strip_family_v1"
OUTPUT = ROOT / "build/m01_window_projection_audit.json"


def main() -> None:
    if not INVENTORY.is_file():
        raise SystemExit("Run m01_window_runtime_inventory before auditing window projection")
    required = [STAGING / "window.blend", STAGING / "window_review.png", STAGING / "REVIEW.md"]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.is_file()]
    if missing:
        raise SystemExit("M01 window staging is incomplete: " + ", ".join(missing))
    contract_path = STRIP_FAMILY / "contract.json"
    if not contract_path.is_file():
        raise SystemExit("M01 span-aware window family is missing its staging contract")
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    if contract.get("runtime_approved"):
        raise SystemExit("M01 window strip family must remain unapproved until map projection review")
    frames = contract.get("frames", [])
    expected = {("horizontal", 32), ("horizontal", 48), ("horizontal", 64), ("horizontal", 128), ("vertical", 32)}
    found = {(frame.get("orientation"), frame.get("span_px")) for frame in frames}
    if found != expected or any(not (STRIP_FAMILY / str(frame.get("file", ""))).is_file() for frame in frames):
        raise SystemExit("M01 window strip family does not cover the live span/orientation set")
    inventory = json.loads(INVENTORY.read_text(encoding="utf-8"))
    rows = inventory.get("windows", [])
    if not inventory.get("passed") or len(rows) != 20:
        raise SystemExit("Expected a fresh, passing inventory of twenty live M01 GlassWindow bodies")
    horizontal = [row for row in rows if row["orientation"] == "horizontal"]
    vertical = [row for row in rows if row["orientation"] == "vertical"]
    if len(horizontal) != 18 or len(vertical) != 2:
        raise SystemExit("Unexpected M01 window orientation distribution")
    spans = sorted({int(row["size_px"][0]) for row in horizontal})
    if spans != [32, 48, 64, 128]:
        raise SystemExit("M01 horizontal window spans changed; regenerate the projection family")
    report = {
        "passed": True,
        "runtime_approved": False,
        "scope": "Maps the uninstalled Blender window reconstruction to live M01 GlassWindow bodies; it does not replace their art.",
        "live_window_inventory": {"total": len(rows), "horizontal": len(horizontal), "vertical": len(vertical), "horizontal_spans_px": spans},
        "staging_status": "window_v1 remains reconstruction-only; its full-height architecture cannot be placed directly over 4-pixel gameplay collision strips. window_strip_family_v1 provides an uninstalled, span-aware visual candidate.",
        "required_before_promotion": [
            "Bake a dedicated 2D frame/sill/curtain sprite family anchored to 4-pixel horizontal and vertical GlassWindow spans.",
            "Keep each GlassWindow body, collision layer, hit point and breakable state intact.",
            "Hide the intact override when GlassWindow.broken so the existing damaged frame, shards and dive-through collision remain visible.",
            "Validate all 20 placements under the actual Camera2D projection, including actor occlusion and light masks.",
        ],
    }
    OUTPUT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("M01 window projection audit: PASS (20 live strips; staging remains unapproved)")


if __name__ == "__main__":
    main()
