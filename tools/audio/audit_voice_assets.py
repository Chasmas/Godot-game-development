"""Check generated human dialogue assets before Godot integration."""
from pathlib import Path
import struct, sys

ROOT = Path(__file__).resolve().parents[2]
VOICE = ROOT / "assets" / "audio" / "voice"
bad = []
files = list(VOICE.rglob("*.mp3")) if VOICE.exists() else []
for p in files:
    b = p.read_bytes()
    # MP3 files begin with ID3 or an MPEG frame sync. Reject placeholders.
    if len(b) < 256 or not (b[:3] == b"ID3" or b[0] == 0xFF):
        bad.append(f"{p.relative_to(ROOT)} ({len(b)} bytes)")
if bad:
    print("VOICE ASSET FAIL")
    print("\n".join(bad))
    sys.exit(1)
print(f"voice asset PASS: {len(files)} ElevenLabs files readable")
