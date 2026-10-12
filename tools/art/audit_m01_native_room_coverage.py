"""Map freshly tested native M01 guest-room furniture to real map rooms.

This is a preservation check for the rebuild.  It does not treat the Blender
guest-room study as production art and it cannot approve its projection.
"""
from __future__ import annotations

import json
import os
from collections import deque
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MAP_PATH = ROOT / "levels/m01_sunset_palms.json"
OUTPUT = ROOT / "build/m01_native_room_coverage_audit.json"
USER_REPORT = (
    Path(os.environ.get("APPDATA", ""))
    / "HOTSHOT CALIFORNIA Codex Preview"
    / "m01_native_beds_runtime_review.json"
)
FALLBACK_REPORT = ROOT / "build/m01_native_beds_runtime_review.json"
BLOCKED = {"#", "W", "%", "D", "L", " "}
CARDINALS = ((1, 0), (-1, 0), (0, 1), (0, -1))


def rooms(grid: list[str]) -> list[set[tuple[int, int]]]:
    seen: set[tuple[int, int]] = set()
    result: list[set[tuple[int, int]]] = []
    for y, row in enumerate(grid):
        for x, cell in enumerate(row):
            start = (x, y)
            if start in seen or cell in BLOCKED:
                continue
            seen.add(start)
            found = {start}
            queue = deque([start])
            while queue:
                cx, cy = queue.popleft()
                for dx, dy in CARDINALS:
                    candidate = (cx + dx, cy + dy)
                    nx, ny = candidate
                    if not (0 <= ny < len(grid) and 0 <= nx < len(grid[0])):
                        continue
                    if candidate in seen or grid[ny][nx] in BLOCKED:
                        continue
                    seen.add(candidate)
                    found.add(candidate)
                    queue.append(candidate)
            result.append(found)
    return result


def component_for(point: list[float], components: list[set[tuple[int, int]]]) -> int | None:
    cell = (int(point[0] // 16), int(point[1] // 16))
    for index, component in enumerate(components):
        if cell in component:
            return index
    return None


def main() -> None:
    report_path = USER_REPORT if USER_REPORT.is_file() else FALLBACK_REPORT
    report = json.loads(report_path.read_text(encoding="utf-8"))
    if not report.get("passed"):
        raise SystemExit("M01 native furniture runtime report must pass")
    for key, expected in (("beds", 10), ("native_nightstands", 13), ("native_dressers", 7)):
        if len(report.get(key, [])) != expected:
            raise SystemExit(f"Fresh runtime review lacks {expected} {key}")

    grid = json.loads(MAP_PATH.read_text(encoding="utf-8"))["map"]
    components = rooms(grid)
    guest_components = [room for room in components if any(grid[y][x] == "b" for x, y in room)]
    if len(guest_components) != 10:
        raise SystemExit(f"Expected ten M01 guest rooms, found {len(guest_components)}")
    guest_indices = {components.index(room): number for number, room in enumerate(guest_components, start=1)}

    rows = [{"room": number, "beds": [], "nightstands": [], "dressers": []} for number in range(1, 11)]
    unassigned: dict[str, list[list[float]]] = {"beds": [], "nightstands": [], "dressers": []}
    for kind, target in (("beds", "beds"), ("native_nightstands", "nightstands"), ("native_dressers", "dressers")):
        for item in report[kind]:
            position = item["position"]
            component = component_for(position, components)
            room_no = guest_indices.get(component)
            if room_no is None:
                unassigned[target].append(position)
            else:
                rows[room_no - 1][target].append(position)
    if any(unassigned["beds"]):
        raise SystemExit("Every native bed must remain in a mapped guest room")
    if any(len(row["beds"]) != 1 for row in rows):
        raise SystemExit("Each of the ten M01 guest rooms must retain exactly one bed")
    # At least eight room-side cabinets and six room-side dressers are expected;
    # remaining review-approved furniture may serve the lobby or circulation.
    guest_nightstands = sum(len(row["nightstands"]) for row in rows)
    guest_dressers = sum(len(row["dressers"]) for row in rows)
    if guest_nightstands < 8 or guest_dressers < 6:
        raise SystemExit("Native guest-room furniture coverage dropped below reviewed minimum")

    output = {
        "passed": True,
        "runtime_approved": False,
        "source_runtime_report": str(report_path),
        "scope": "Fresh native-furniture runtime output mapped to the ten authored M01 guest rooms; staging composition remains uninstalled.",
        "rooms": rows,
        "guest_room_native_counts": {"beds": 10, "nightstands": guest_nightstands, "dressers": guest_dressers},
        "non_guest_native_positions": unassigned,
        "preservation": [
            "Keep every existing bed body, collision shape and navigation behaviour.",
            "Keep room door approaches clear; validate any future projection against actual actor, aim and occlusion behaviour.",
            "Do not install guest_room_composition_v10 until exact gameplay projection is approved.",
        ],
    }
    OUTPUT.parent.mkdir(exist_ok=True)
    OUTPUT.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(f"M01 native room coverage: PASS (10 beds, {guest_nightstands} cabinets, {guest_dressers} dressers in guest rooms)")


if __name__ == "__main__":
    main()
