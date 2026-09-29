#!/usr/bin/env python3
"""Soundtrack masters -> game files.

  python tools/audio/prepare_music.py <source_id> <game_name> [--xfade 0.6] [--gain 0]

music/source/<source_id>.mp3 -> music/<game_name>.ogg:
- the loop seam: the last `xfade` seconds are blended into the first ones,
  so the file loops with no click and no gap (the ogg plays end -> start);
- loudness matched to the rest of the score (RMS target), peaks kept under
  -1 dBFS, nothing squashed: the track's own dynamics stay.
"""
import os, subprocess, sys, wave
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SR = 44100
TARGET_RMS = 0.16

def load(p):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", p, "-f", "s16le", "-ac", "2", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16).reshape(-1, 2).astype(np.float64) / 32767.0

def main():
    src, name = sys.argv[1], sys.argv[2]
    xf = float(sys.argv[sys.argv.index("--xfade") + 1]) if "--xfade" in sys.argv else 0.6
    gain = float(sys.argv[sys.argv.index("--gain") + 1]) if "--gain" in sys.argv else 0.0
    x = load(os.path.join(ROOT, "music", "source", src + ".mp3"))
    # trim leading silence (encoder padding) so the loop point is tight
    lead = int(np.argmax(np.abs(x).max(axis=1) > 0.002))
    x = x[lead:]
    F = int(xf * SR)
    if F > 0 and len(x) > 4 * F:
        body = x[:-F].copy()
        tail = x[-F:]
        ramp = np.linspace(0.0, 1.0, F)[:, None]
        # equal-power blend of the tail into the head
        body[:F] = body[:F] * np.sin(ramp * np.pi / 2) + tail * np.cos(ramp * np.pi / 2)
        x = body
    rms = np.sqrt((x ** 2).mean())
    x *= (TARGET_RMS / max(rms, 1e-6)) * 10 ** (gain / 20)
    peak = np.abs(x).max()
    if peak > 0.89:
        x *= 0.89 / peak
    tmp = os.path.join(ROOT, "music", name + ".tmp.wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "6", os.path.join(ROOT, "music", name + ".ogg")], check=True)
    os.remove(tmp)
    print(f"music/{name}.ogg  {len(x) / SR:.1f}s  rms {np.sqrt((x ** 2).mean()):.3f}  peak {np.abs(x).max():.2f}")

if __name__ == "__main__":
    main()
