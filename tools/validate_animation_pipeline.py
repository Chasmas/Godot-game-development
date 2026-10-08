"""Validate optional Blender animation drops before they are shown in-game."""
from pathlib import Path
from PIL import Image
import re, sys

ROOT = Path(__file__).resolve().parents[1]
ANIM = ROOT / "assets" / "art" / "animated"
NAME = re.compile(r"(?:frame_)?\d{1,6}\.(?:png|webp)$", re.I)
errors = []
sequences = 0
frames = 0
if ANIM.exists():
    for folder in sorted(p for p in ANIM.rglob("*") if p.is_dir()):
        files = sorted(p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in {".png", ".webp"})
        if not files:
            continue
        sequences += 1
        for f in files:
            frames += 1
            if not NAME.fullmatch(f.name):
                errors.append(f"{f.relative_to(ROOT)}: use frame_0001.png naming")
                continue
            try:
                with Image.open(f) as im:
                    w, h = im.size
                    if w < 320 or h < 180:
                        errors.append(f"{f.relative_to(ROOT)}: too small ({w}x{h})")
                    if folder.parts[-2:] and "cutscenes" in folder.parts and abs((w / h) - (16 / 9)) > 0.02:
                        errors.append(f"{f.relative_to(ROOT)}: cutscene must be 16:9 ({w}x{h})")
            except Exception as exc:
                errors.append(f"{f.relative_to(ROOT)}: unreadable ({exc})")
if errors:
    print("ANIMATION PIPELINE FAIL")
    print("\n".join(errors))
    sys.exit(1)
print(f"animation pipeline PASS: {sequences} sequences, {frames} frames; still fallbacks remain active")
