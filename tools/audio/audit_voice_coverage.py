"""Report authored human-voice coverage without treating fallback as an error."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
dialogue = ROOT / "data" / "dialogue"
done = missing = spoken = 0
by_scene = []
for src in sorted(dialogue.glob("*.json")):
    data = json.loads(src.read_text(encoding="utf-8"))
    scene_done = scene_missing = 0
    for node_id, node in data.get("nodes", {}).items():
        if node.get("speaker", "narration") == "narration" or not any(c.isalnum() for c in str(node.get("text", ""))):
            continue
        spoken += 1
        base = ROOT / "assets" / "audio" / "voice" / src.stem / node_id
        candidates = [base.with_suffix(ext) for ext in (".mp3", ".ogg", ".wav")]
        if any(p.exists() for p in candidates):
            done += 1; scene_done += 1
        else:
            missing += 1; scene_missing += 1
    if scene_done or scene_missing:
        by_scene.append((src.stem, scene_done, scene_missing))
print(f"voice coverage: {done}/{spoken} spoken lines ({done / spoken * 100.0:.1f}%), fallback lines {missing}")
for name, good, left in by_scene:
    print(f"  {name}: {good} human / {left} fallback")
