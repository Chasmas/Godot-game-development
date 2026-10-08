"""Fast visual-pipeline audit for the four playable levels."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets/art/pixellab_world/sprites"
PIXELLAB_PAINTED = ROOT / "assets/art/pixellab_ui_v3_approved/painted"
PLAN = ROOT / "tools/layout_plans.json"

def main() -> int:
    pngs = sorted(SPRITES.glob("*.png"))
    missing_imports = [p.name for p in pngs if not p.with_name(p.name + ".import").exists()]
    bad_alpha = []
    bad_size = []
    for p in pngs:
        try:
            im = Image.open(p).convert("RGBA")
            if im.getchannel("A").getextrema()[1] == 0:
                bad_alpha.append(p.name)
            if im.width > 400 or im.height > 400:
                bad_size.append(p.name)
        except Exception as exc:
            bad_alpha.append(f"{p.name}: {exc}")
    plans = json.loads(PLAN.read_text(encoding="utf-8"))
    decor = sum(len(v.get("decor", [])) for v in plans.values())
    dialogue_text = "\n".join(p.read_text(encoding="utf-8", errors="ignore") for p in (ROOT / "data/dialogue").glob("*.json"))
    import re
    used_shots = set(re.findall(r'"shot"\s*:\s*"([^"]+)"', dialogue_text))
    intro_text = (ROOT / "scripts/ui/intro.gd").read_text(encoding="utf-8", errors="ignore")
    used_shots.update(re.findall(r'\["(t_[^"]+)"\s*,', intro_text))
    shot_dirs = {p.name for p in (ROOT / "assets/art/shots").iterdir() if p.is_dir()}
    painted = {p.stem for p in (ROOT / "assets/art/painted").glob("*.webp")}
    pixellab_painted = {p.stem for p in PIXELLAB_PAINTED.glob("*.png")}
    known_special = {"static", "fireman", "fireman_down", "news_studio_fire", "harcourt_office", "burning_tommy"}
    missing_shots = sorted(used_shots - shot_dirs - painted - known_special)
    missing_pixellab_shots = sorted(used_shots - pixellab_painted - {"static"})
    print(f"sprites={len(pngs)} decor_entries={decor}")
    print(f"pixel_shots={len(used_shots - {'static'})} missing_pixel_shots={len(missing_pixellab_shots)}")
    print(f"missing_imports={len(missing_imports)} empty_alpha={len(bad_alpha)} oversized={len(bad_size)} missing_shots={len(missing_shots)}")
    if missing_imports: print("missing:", ", ".join(missing_imports))
    if bad_alpha: print("bad_alpha:", ", ".join(bad_alpha))
    if bad_size: print("oversized:", ", ".join(bad_size))
    if missing_shots: print("missing_shots:", ", ".join(missing_shots))
    if missing_pixellab_shots: print("missing_pixel_shots:", ", ".join(missing_pixellab_shots))
    return 1 if (missing_imports or bad_alpha or bad_size or missing_shots or missing_pixellab_shots) else 0

if __name__ == "__main__":
    raise SystemExit(main())
