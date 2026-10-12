"""Replace voice-risk source variants with verified instrumental equivalents.

The source directory is not shipped by Godot, but it remains part of the
music library.  Keeping it instrumental prevents an older working file from
being accidentally promoted later.
"""
from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MUSIC = ROOT / "music"
MANIFEST = MUSIC / "source" / "instrumental_replacements.json"

# destination relative to music/ -> previously audited instrumental master.
REPLACEMENTS = {
    "source/combat_arcade1.mp3": "st_arcade1.ogg",
    "source/combat_motel.mp3": "st_motel_combat.ogg",
    "source/combat_yard.mp3": "st_yard_combat.ogg",
    "source/main_theme_v2.mp3": "st_main_theme.ogg",
    "source/stealth_motel.mp3": "st_motel_stealth.ogg",
    "source/stealth_yard.mp3": "st_yard_stealth.ogg",
    "source/trailer_synthwave.mp3": "intro_teaser_v2.mp3",
    "st_motel_combat.mp3": "st_motel_combat.ogg",
}


def main() -> None:
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise SystemExit("ffmpeg is required to create replacement MP3 sources")
    manifest = []
    for destination_rel, source_rel in REPLACEMENTS.items():
        source = MUSIC / source_rel
        destination = MUSIC / destination_rel
        if not source.is_file():
            raise SystemExit(f"Verified source master missing: {source.relative_to(ROOT)}")
        subprocess.run(
            [ffmpeg, "-y", "-loglevel", "error", "-i", str(source), "-map_metadata", "-1", "-c:a", "libmp3lame", "-q:a", "2", str(destination)],
            check=True,
        )
        manifest.append(
            {
                "file": str(Path("music") / destination_rel).replace("\\", "/"),
                "replacement_master": str(Path("music") / source_rel).replace("\\", "/"),
                "reason": "Voice-risk transcription response; replaced with a same-role verified instrumental master.",
            }
        )
    MANIFEST.write_text(json.dumps({"scope": "All source and legacy music files flagged by the instrumental content audit", "replacements": manifest}, indent=2) + "\n", encoding="utf-8")
    print(f"Replaced {len(manifest)} voice-risk music source files with verified instrumental masters.")


if __name__ == "__main__":
    main()
