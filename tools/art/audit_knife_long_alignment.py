"""Review nearest-heading, tip-anchored 16-sample knife history on measured stride data."""
from pathlib import Path
import json, math
root = Path("build/melee_trail_review")
base = [sample for sample in json.loads((root / "actual_weapon_paths_16.json").read_text())["samples"] if sample["weapon"] == "knife"]
results = []
for filename in ["moving_weapon_paths.json", "moving_weapon_paths_32_midpoints.json"]:
    for sample in json.loads((root / filename).read_text())["samples"]:
        if sample["weapon"] != "knife":
            continue
        index = int((sample["angle"] % math.tau) * 16 / math.tau + 0.5) % 16
        baked = base[index]
        errors = []
        for i, point in enumerate(sample["points"]):
            if not .30 <= point["phase"] <= .78:
                continue
            head = min(baked["points"], key=lambda p: abs(p["phase"] - point["phase"]))
            offset = [point["tip"][axis] - head["tip"][axis] for axis in range(2)]
            for past in sample["points"][max(0, i - 16):i + 1]:
                texture_point = min(baked["points"], key=lambda p: abs(p["phase"] - past["phase"]))
                errors.append(math.dist(past["tip"], [texture_point["tip"][axis] + offset[axis] for axis in range(2)]))
        results.append({"source": filename, "angle": sample["angle"], "max_error_px": max(errors)})
report = {"approved": False, "scope": "Lateral stride and 32 headings, phase .30-.78, 16 recent poses, nearest heading translation only; does not prove all actions or level visual quality.", "results": results}
(root / "knife_long_alignment_audit.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("Knife long measured shape error max px:", max(row["max_error_px"] for row in results))
