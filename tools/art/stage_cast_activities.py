"""Bake candidates with Blender, preserving runtime files until rendered review."""
import argparse, hashlib, json, struct, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BLENDER = Path(r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe")

def animation_names(path):
    data = path.read_bytes()
    if data[:4] != b"glTF":
        raise ValueError(f"Invalid GLB: {path}")
    size = struct.unpack_from("<I", data, 12)[0]
    document = json.loads(data[20:20 + size])
    return {clip["name"] for clip in document.get("animations", [])}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("looks", nargs="+")
    args = parser.parse_args()
    stage = ROOT / "build/cast_activity_candidates"
    stage.mkdir(parents=True, exist_ok=True)
    audit_path = stage / "audit.json"
    previous = json.loads(audit_path.read_text(encoding="utf-8")) if audit_path.exists() else []
    report = {row["look"]: row for row in previous}
    generated = []
    for look in args.looks:
        source = ROOT / "assets/art/Artwork/3d" / look
        runtime = ROOT / "assets/art/cast3d_rt" / look / f"{look}.glb"
        candidate = stage / f"{look}.glb"
        command = [str(BLENDER), "-b", "--python", str(ROOT / "tools/art/render_cast3d.py"), "--",
                   str(source), str(stage / look), "--fps", "24", "--bake", str(candidate)]
        mesh = source / "rig_newhair.glb"
        if mesh.exists():
            command += ["--mesh", str(mesh)]
        with (stage / f"{look}.log").open("w", encoding="utf-8") as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
        entry = {"look": look, "exit_code": result.returncode, "candidate": str(candidate), "reviewed": False}
        if result.returncode == 0 and candidate.exists():
            entry["candidate_sha256"] = hashlib.sha256(candidate.read_bytes()).hexdigest()
            names = animation_names(candidate)
            entry["missing_previous_clips"] = sorted(animation_names(runtime) - names)
            entry["missing_required_clips"] = sorted({"idle", "smoke", "doze", "grab", "held"} - names)
            entry["clips"] = sorted(names)
            entry["valid"] = not entry["missing_previous_clips"] and not entry["missing_required_clips"]
        else:
            entry["valid"] = False
        generated.append(entry)
        report[look] = entry
        temporary = stage / "audit.json.tmp"
        temporary.write_text(json.dumps(list(report.values()), indent=2), encoding="utf-8")
        temporary.replace(audit_path)
        print(look, "candidate ready for review" if entry["valid"] else "FAILED audit", flush=True)
    raise SystemExit(0 if all(row["valid"] for row in generated) else 1)

if __name__ == "__main__":
    main()
