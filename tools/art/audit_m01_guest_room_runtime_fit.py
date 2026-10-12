"""Audit the M01 guest-room staging study against the production room layout.

This does not approve or install the Blender composition.  It records the
existing functional furniture layout that a future gameplay-projection pass
must preserve before the visual study can become a runtime asset.
"""
from __future__ import annotations

import json
import hashlib
from collections import deque
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LEVEL_PATH = ROOT / "levels/m01_sunset_palms.json"
FURNITURE_REVIEW = ROOT / "build/m01_native_furniture_runtime_review_v2.json"
CHAIR_REVIEW = ROOT / "build/m01_native_armchair_review.json"
ACCENT_REVIEW = ROOT / "build/m01_guest_room_accents_runtime_review.json"
ACCENT_CONTRACT = ROOT / "assets/art/prerendered/m01_sunset_palms/runtime/guest_room_props_v1/contract.json"
CURTAIN_REVIEW = ROOT / "build/m01_guest_curtains_runtime_review.json"
CURTAIN_CONTRACT = ROOT / "assets/art/prerendered/m01_sunset_palms/runtime/guest_curtain_v1/contract.json"
ROOM_REVIEW = ROOT / "assets/art/prerendered/m01_sunset_palms/staging/guest_room_composition_v10/review.json"
CAMERA_REVIEW = ROOT / "assets/art/prerendered/m01_sunset_palms/staging/guest_room_camera_review_v4/projection_review.json"
OUTPUT = ROOT / "build/m01_guest_room_runtime_fit_audit.json"

# Mirrors Dressing._passable.  Door cells deliberately remain closed here,
# which keeps each motel room distinct from the exterior circulation routes.
BLOCKED = {"#", "W", "%", "D", "L", " "}
CARDINALS = ((1, 0), (-1, 0), (0, 1), (0, -1))


def components(grid: list[str]) -> list[set[tuple[int, int]]]:
    height, width = len(grid), len(grid[0])
    seen: set[tuple[int, int]] = set()
    found: list[set[tuple[int, int]]] = []
    for y, row in enumerate(grid):
        for x, cell in enumerate(row):
            start = (x, y)
            if start in seen or cell in BLOCKED:
                continue
            seen.add(start)
            room = {start}
            queue = deque([start])
            while queue:
                cx, cy = queue.popleft()
                for dx, dy in CARDINALS:
                    nx, ny = cx + dx, cy + dy
                    if not (0 <= nx < width and 0 <= ny < height):
                        continue
                    neighbour = (nx, ny)
                    if neighbour in seen or grid[ny][nx] in BLOCKED:
                        continue
                    seen.add(neighbour)
                    room.add(neighbour)
                    queue.append(neighbour)
            found.append(room)
    return found


def rect(cells: set[tuple[int, int]]) -> list[int]:
    xs, ys = zip(*cells)
    return [min(xs), min(ys), max(xs), max(ys)]


def cell_for(position: list[float]) -> tuple[int, int]:
    return int(position[0] // 16), int(position[1] // 16)


def main() -> None:
    level = json.loads(LEVEL_PATH.read_text(encoding="utf-8"))
    grid = level["map"]
    if not grid or len({len(row) for row in grid}) != 1:
        raise SystemExit("M01 map must be a non-empty rectangular grid")
    furniture = json.loads(FURNITURE_REVIEW.read_text(encoding="utf-8"))
    chairs = json.loads(CHAIR_REVIEW.read_text(encoding="utf-8"))
    accents = json.loads(ACCENT_REVIEW.read_text(encoding="utf-8"))
    accent_contract = json.loads(ACCENT_CONTRACT.read_text(encoding="utf-8"))
    curtains = json.loads(CURTAIN_REVIEW.read_text(encoding="utf-8"))
    curtain_contract = json.loads(CURTAIN_CONTRACT.read_text(encoding="utf-8"))
    staging = json.loads(ROOM_REVIEW.read_text(encoding="utf-8"))
    camera = json.loads(CAMERA_REVIEW.read_text(encoding="utf-8"))

    guest_rooms = [room for room in components(grid) if any(grid[y][x] == "b" for x, y in room)]
    if staging.get("runtime_approved"):
        raise SystemExit("The guest-room staging study must never self-approve runtime use")
    if camera.get("source_composition") != "guest_room_composition_v10":
        raise SystemExit("Camera review must be regenerated from the current v10 staging composition")
    if camera.get("runtime_approved"):
        raise SystemExit("A camera comparison cannot approve gameplay projection")
    if len(guest_rooms) != 10:
        raise SystemExit(f"Expected 10 distinct M01 guest rooms, found {len(guest_rooms)}")
    if not furniture.get("passed") or len(furniture.get("beds", [])) != 10:
        raise SystemExit("Native furniture collision review must pass for all ten M01 beds")
    rugs = furniture.get("native_rugs", [])
    if len(rugs) != 10:
        raise SystemExit("Native furniture review must prove all ten guest-room woven rugs")
    if chairs.get("native_chairs") != 11 or chairs.get("player_sweep_failures") != 0:
        raise SystemExit("Native armchair collision review must pass before room-fit audit")
    if not accents.get("passed") or not accents.get("runtime_approved"):
        raise SystemExit("Live runtime accent review must pass before room-fit audit")
    if not accent_contract.get("runtime_approved") or accent_contract.get("source_level_sha256") != hashlib.sha256(LEVEL_PATH.read_bytes()).hexdigest():
        raise SystemExit("Guest-room accent runtime contract must match the current M01 map")
    if len(accents.get("accents", [])) != int(accent_contract.get("expected_placements", -1)):
        raise SystemExit("Guest-room accent review count must match its runtime contract")
    if any(int(row.get("alpha_pixels_outside_room", -1)) != 0 for row in accents["accents"]):
        raise SystemExit("Guest-room accent review found a visual boundary spill")
    if len(accents.get("botanical_wall_art", [])) != 10:
        raise SystemExit("Every guest room must retain exactly one botanical wall lithograph")
    if int(accents.get("expected_guest_entry_trims", -1)) != 19 or len(accents.get("guest_entry_trims", [])) != 19:
        raise SystemExit("Live runtime accent review must retain all nineteen guest-door transition trims")
    if not curtains.get("passed") or not curtains.get("runtime_approved") or not curtains.get("shatter_hides_dressing"):
        raise SystemExit("Live runtime curtain review must prove intact and shattered window behavior")
    if not curtain_contract.get("runtime_approved") or curtain_contract.get("source_level_sha256") != hashlib.sha256(LEVEL_PATH.read_bytes()).hexdigest():
        raise SystemExit("Guest curtain runtime contract must match the current M01 map")
    if len(curtains.get("curtained_windows", [])) != int(curtain_contract.get("expected_windows", -1)):
        raise SystemExit("Guest curtain review count must match its runtime contract")
    if any(int(row.get("alpha_pixels_outside_room", -1)) != 0 for row in curtains["curtained_windows"]):
        raise SystemExit("Guest curtain review found a visual boundary spill")

    room_entries: list[dict[str, object]] = []
    uncovered_beds: list[list[float]] = []
    for index, room in enumerate(guest_rooms, start=1):
        room_beds = [bed for bed in furniture["beds"] if cell_for(bed["position"]) in room]
        room_chairs = [chair for chair in chairs["placements"] if cell_for(chair["position"]) in room]
        if len(room_beds) != 1:
            uncovered_beds.extend(bed["position"] for bed in room_beds)
        room_entries.append(
            {
                "room": index,
                "bounds_cells": rect(room),
                "floor_cells": len(room),
                "bed_positions_px": [bed["position"] for bed in room_beds],
                "native_chair_positions_px": [chair["position"] for chair in room_chairs],
                "bed_body_count": len(room_beds),
                "chair_count": len(room_chairs),
            }
        )
    mapped_beds = {tuple(bed["position"]) for entry in room_entries for bed in furniture["beds"] if bed["position"] in entry["bed_positions_px"]}
    all_beds = {tuple(bed["position"]) for bed in furniture["beds"]}
    if uncovered_beds or mapped_beds != all_beds:
        raise SystemExit("Every production bed must map to exactly one distinct guest room")
    uncovered_rugs = [rug for rug in rugs if not any(cell_for(rug["position"]) in room for room in guest_rooms)]
    alpha_spills = [rug for rug in rugs if int(rug.get("projected_alpha_pixels_outside_room", -1)) != 0]
    if uncovered_rugs or alpha_spills:
        raise SystemExit("Every native rug must remain fully inside a distinct authored guest room")

    report = {
        "passed": True,
        "runtime_approved": False,
        "scope": "Maps existing M01 bed and armchair review positions to the authored motel rooms. It validates preservation targets only; it does not install guest_room_composition_v10.",
        "guest_rooms": room_entries,
        "preservation_contract": {
            "bed_bodies": "Keep all ten existing Furniture bodies, collision shapes and navigation behaviour.",
            "woven_rugs": "Keep all ten native woven rugs as walkable in-room dressing; rerun alpha-projection validation after map or placement changes.",
            "armchairs": "Keep the eleven reviewed native armchair placements or re-run physical, door-arc and steering reviews.",
            "projection": "Adapt staging art to the exact gameplay camera; do not rotate or squash a background independently.",
        },
        "promotion_blockers": sorted(set(staging.get("pending", [])) | set(camera.get("requirements", []))),
        "native_rug_validation": {"count": len(rugs), "projected_alpha_pixels_outside_rooms": sum(int(rug.get("projected_alpha_pixels_outside_room", 0)) for rug in rugs)},
        "runtime_visual_coverage": {
            "beds": len(furniture["beds"]),
            "native_armchairs": chairs["native_chairs"],
            "native_rugs": len(rugs),
            "native_nightstands": len(furniture.get("native_nightstands", [])),
            "native_dressers": len(furniture.get("native_dressers", [])),
            "room_story_accents": len(accents["accents"]),
            "botanical_wall_lithographs": len(accents["botanical_wall_art"]),
            "guest_door_transition_trims": len(accents["guest_entry_trims"]),
            "guest_facing_curtained_windows": len(curtains["curtained_windows"]),
        },
    }
    OUTPUT.parent.mkdir(exist_ok=True)
    OUTPUT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("M01 guest-room runtime-fit audit: PASS (10 rooms, 10 beds; staging remains unapproved)")


if __name__ == "__main__":
    main()
