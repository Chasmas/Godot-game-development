"""Check encounter source parity without overwriting playable level files."""
import builtins, contextlib, io, json, runpy, sys, tempfile
from pathlib import Path
from unittest.mock import patch
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
real_open = builtins.open
failures = []
with tempfile.TemporaryDirectory(prefix="encounter_review_") as temporary:
    for name in ("m01_sunset_palms", "m02_yermo_salvage", "m03_khsc_studios", "m04_villa_estrella"):
        target = ROOT / "levels" / (name + ".json")
        output = Path(temporary) / target.name
        def redirected_open(file, *args, **kwargs):
            if isinstance(file, (str, bytes, Path)) and Path(file).resolve() == target.resolve():
                file = output
            return real_open(file, *args, **kwargs)
        with patch("builtins.open", redirected_open), contextlib.redirect_stdout(io.StringIO()):
            runpy.run_path(str(ROOT / "tools" / ("build_" + name[:3] + ".py")), run_name="__main__")
        authored = json.loads(target.read_text(encoding="utf-8"))
        generated = json.loads(output.read_text(encoding="utf-8"))
        for cell, enemy in authored.get("enemies", {}).items():
            for field in ("patrol", "idle_action"):
                if enemy.get(field) != generated.get("enemies", {}).get(cell, {}).get(field):
                    failures.append(f"{name} {cell} {field}: source differs from playable data")
        authored_lock = next((h for h in authored.get("hints", []) if h.get("id") == "lock"), None)
        generated_lock = next((h for h in generated.get("hints", []) if h.get("id") == "lock"), None)
        if authored_lock != generated_lock:
            failures.append(f"{name}: lock-on tutorial source differs from playable data")
        if authored.get("cameras") != generated.get("cameras"):
            failures.append(f"{name}: camera source differs from playable data")
        print(f"Checked {name}: patrols, idle actions, cameras")
for failure in failures:
    print("FAIL", failure)
print(f"ENCOUNTER GENERATOR REVIEW: {len(failures)} failures")
raise SystemExit(bool(failures))
