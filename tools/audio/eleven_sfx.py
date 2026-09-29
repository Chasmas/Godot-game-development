#!/usr/bin/env python3
"""Sound effects through the ElevenLabs Sound Effects API.

  python tools/audio/eleven_sfx.py <name> [<name> ...]     (names from sfx_manifest.json)
  python tools/audio/eleven_sfx.py --all [--group guns]
  python tools/audio/eleven_sfx.py --list

Raw results are kept in assets/audio/source/<name>.mp3 (excluded from the
export); the game file assets/audio/sfx/<name>.wav is replaced by it,
trimmed of leading silence and matched in loudness to the sound it
replaces, so every volume the game already sets still fits. The old file
is kept once as assets/audio/source/old/<name>.wav.
Credits are read before and after; nothing is regenerated unless --again.
"""
import json, os, shutil, subprocess, sys, urllib.request, urllib.error, wave
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eleven_music import key, credits

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MAN = os.path.join(ROOT, "tools", "audio", "sfx_manifest.json")
SRC = os.path.join(ROOT, "assets", "audio", "source")
SFX = os.path.join(ROOT, "assets", "audio", "sfx")
SR = 44100
STYLE = " Recorded for a 1980s-set top-down action game: punchy, clean, close-miked, no music, no voices unless asked."

def gen(name, e):
    body = {"text": e["prompt"] + STYLE, "model_id": "eleven_text_to_sound_v2", "prompt_influence": e.get("influence", 0.45)}
    if e.get("sec"):
        body["duration_seconds"] = e["sec"]
    if e.get("loop"):
        body["loop"] = True
    req = urllib.request.Request("https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_192", data=json.dumps(body).encode(),
                                 headers={"xi-api-key": key(), "Content-Type": "application/json"})
    try:
        audio = urllib.request.urlopen(req, timeout=300).read()
    except urllib.error.HTTPError as ex:
        print(f"  ! {name}: HTTP {ex.code} {ex.read()[:400]}")
        return None
    os.makedirs(SRC, exist_ok=True)
    p = os.path.join(SRC, name + ".mp3")
    open(p, "wb").write(audio)
    return p

def load(p):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", p, "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16).astype(np.float64) / 32767.0

def old_level(name):
    p = os.path.join(SRC, "old", name + ".wav")
    if not os.path.exists(p):
        p = os.path.join(SFX, name + ".wav")
    if not os.path.exists(p):
        return None
    with wave.open(p) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float64) / 32767.0
        if w.getnchannels() == 2:
            x = x.reshape(-1, 2).mean(axis=1)
    loud = np.abs(x) > 0.02
    return np.sqrt((x[loud] ** 2).mean()) if loud.any() else None

def install(name, mp3, e):
    x = load(mp3)
    # tight start: a gunshot must fire on the frame the trigger is pulled
    if not e.get("loop"):
        start = int(np.argmax(np.abs(x) > 0.01))
        x = x[max(0, start - int(0.002 * SR)):]
        end = len(x) - int(np.argmax(np.abs(x[::-1]) > 0.0012))
        x = x[:max(end, int(0.05 * SR))]
    ref = old_level(name)
    loud = np.abs(x) > 0.02
    cur = np.sqrt((x[loud] ** 2).mean()) if loud.any() else 0.1
    x *= (ref if ref else 0.2) / max(cur, 1e-6) * 10 ** (e.get("gain", 0.0) / 20)
    pk = np.abs(x).max()
    if pk > 0.95:
        x *= 0.95 / pk
    f = min(len(x) // 4, int(0.004 * SR))
    if f > 1 and not e.get("loop"):
        x[-f:] *= np.linspace(1, 0, f)
    os.makedirs(os.path.join(SRC, "old"), exist_ok=True)
    dst = os.path.join(SFX, name + ".wav")
    keep = os.path.join(SRC, "old", name + ".wav")
    if os.path.exists(dst) and not os.path.exists(keep):
        shutil.copy(dst, keep)
    with wave.open(dst, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    print(f"  {name}: {len(x) / SR:.2f}s")

def main():
    man = json.load(open(MAN, encoding="utf-8"))
    if "--list" in sys.argv:
        for n, e in man.items():
            print(f"  {'x' if os.path.exists(os.path.join(SRC, n + '.mp3')) else ' '} {n:18s} {e.get('group', ''):8s} {e['prompt'][:70]}")
        return
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--all" in sys.argv:
        g = sys.argv[sys.argv.index("--group") + 1] if "--group" in sys.argv else None
        names = [n for n, e in man.items() if g is None or e.get("group") == g]
    u0, lim = credits()
    print(f"{len(names)} sounds; {lim - u0} credits left")
    for n in names:
        e = man[n]
        mp3 = os.path.join(SRC, n + ".mp3")
        if not os.path.exists(mp3) or "--again" in sys.argv:
            mp3 = gen(n, e)
            if mp3 is None:
                continue
        install(n, mp3, e)
    u1, _ = credits()
    print(f"spent {u1 - u0} credits ({(u1 - u0) / max(1, len(names)):.0f} per sound); {lim - u1} left")

if __name__ == "__main__":
    main()
