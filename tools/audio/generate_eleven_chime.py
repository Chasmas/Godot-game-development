import json, os, shutil, subprocess, urllib.request, urllib.error, wave
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
key = os.environ.get("ELEVENLABS_API_KEY")
if not key:
    raise SystemExit("ELEVENLABS_API_KEY not set")
prompt = ("PURELY INSTRUMENTAL ONLY: no voice, speech, words, singing, choir, narration or human sounds. "
          "Original 2.6 second studio signature for a dark neon VHS crime game: deep analog pulse, distinctive three-note "
          "minor synth motif answered by a glassy octave shimmer, Juno chorus, filter movement, stereo tape flutter, "
          "gated reverb, warm sub tail and a tiny tape-stop sparkle. Mysterious, elegant and memorable; no drums or guitar.")
body = {"text": prompt, "model_id": "eleven_text_to_sound_v2", "duration_seconds": 2.7, "prompt_influence": 0.85}
req = urllib.request.Request(
    "https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_192",
    data=json.dumps(body).encode(), headers={"xi-api-key": key, "Content-Type": "application/json"})
try:
    audio = urllib.request.urlopen(req, timeout=300).read()
except urllib.error.HTTPError as ex:
    raise SystemExit(f"ElevenLabs sound-generation failed: HTTP {ex.code} {ex.read()[:800]}")
src = os.path.join(ROOT, "assets", "audio", "source", "studio_chime_elevenlabs.mp3")
os.makedirs(os.path.dirname(src), exist_ok=True)
open(src, "wb").write(audio)
ffmpeg = shutil.which("ffmpeg") or r"C:\Program Files\Virtual Desktop Streamer\ffmpeg.exe"
raw = subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", src, "-f", "s16le", "-ac", "1", "-ar", "44100", "-"], capture_output=True, check=True).stdout
x = np.frombuffer(raw, np.int16).astype(np.float64) / 32767.0
nz = np.flatnonzero(np.abs(x) > 0.008)
if len(nz):
    x = x[max(0, int(nz[0]) - 88):int(nz[-1]) + 1]
# The service may trim a quiet tail. Keep the ident in the requested 2–3 s
# window by extending the final transient into a smooth analog reverb tail.
min_samples = int(2.15 * 44100)
if len(x) < min_samples:
    tail_n = min(len(x), int(0.16 * 44100))
    needed = min_samples - len(x)
    tail = np.resize(x[-tail_n:], needed).astype(np.float64)
    tail *= np.linspace(0.22, 0.0, needed)
    x = np.concatenate([x, tail])
x *= 0.82 / max(np.max(np.abs(x)), 1e-9)
fade = min(len(x) // 4, 176)
x[-fade:] *= np.linspace(1, 0, fade)
dst = os.path.join(ROOT, "assets", "audio", "sfx", "studio_chime.wav")
backup = os.path.join(ROOT, "assets", "audio", "source", "old", "studio_chime.wav")
os.makedirs(os.path.dirname(backup), exist_ok=True)
if os.path.exists(dst) and not os.path.exists(backup):
    shutil.copy2(dst, backup)
with wave.open(dst, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(44100)
    w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
print(f"generated {len(x) / 44100:.2f}s ElevenLabs chime")

