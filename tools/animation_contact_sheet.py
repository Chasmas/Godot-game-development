from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1] / "assets" / "art" / "animated" / "cutscenes"
thumbs = []
for folder in sorted(root.iterdir() if root.exists() else []):
    if folder.is_dir():
        for idx, path in enumerate(sorted(folder.glob("*.png"))[::4]):
            thumbs.append((folder.name, idx * 4, Image.open(path).convert("RGB")))
w, h, cols = 320, 180, 4
out = Image.new("RGB", (w * cols, h * ((len(thumbs) + cols - 1) // cols)), (8, 8, 12))
draw = ImageDraw.Draw(out)
for i, (name, frame, im) in enumerate(thumbs):
    x, y = (i % cols) * w, (i // cols) * h
    out.paste(im.resize((w, h), Image.Resampling.NEAREST), (x, y))
    draw.text((x + 6, y + 6), f"{name}  {frame:02d}", fill="white")
out.save(Path(__file__).resolve().parents[1] / "cutscene_animation_contact.png")
print(f"contact sheet: {len(thumbs)} sampled frames")
