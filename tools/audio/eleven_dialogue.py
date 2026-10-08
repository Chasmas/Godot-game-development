#!/usr/bin/env python3
"""Opt-in ElevenLabs dialogue renderer for authored character lines.

This never runs as part of the build and never touches music. Generate only
selected lines after listening to a voice test, e.g.:
  python tools/audio/eleven_dialogue.py --speaker cass --text "Keep rolling." --out cass_keep_rolling.mp3
"""
import argparse, json, os, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
API = "https://api.elevenlabs.io/v1"
VOICE = {
    "buck": "N2lVS1w4EtoT3dr4eOWO", # Callum: husky American character voice
    "dutch": "CwhRBWXzGAHq8TQ4Fs17", # Roger: mature, resonant American
    "pa": "nPczCjzI2devNBz1zQrb", # Brian: clear, deep American announcement
    "tommy_burnt": "TxGEqnHWrfWFTfGW9XjX", # Preserve Tommy's identity
    "mom": "g12yXXabMWeFoLMzxPrF", # Julie: older, warm American mother
    "harcourt": "pqHfZKP75CvOlQylNhV4",
    "cass": "21m00Tcm4TlvDq8ikWAM", "arlo": "ErXwobaYiN019PkySvjV", "tommy": "TxGEqnHWrfWFTfGW9XjX",
    "anchor": "VR6AewLTigWG4xSOukaG", "marv": "pNInz6obpgDQGcFmaJgB", "earl": "yoZ06aMxZJJ28mfd3POQ",
    "voice": "ErXwobaYiN019PkySvjV", "machine": "VR6AewLTigWG4xSOukaG", "rudy": "TxGEqnHWrfWFTfGW9XjX", "dead": "pNInz6obpgDQGcFmaJgB",
}
VOICE_STYLE = {
    "buck": {"stability": 0.52, "similarity_boost": 0.85, "style": 0.38},
    "dutch": {"stability": 0.66, "similarity_boost": 0.85, "style": 0.30},
    "pa": {"stability": 0.86, "similarity_boost": 0.85, "style": 0.12},
    "tommy_burnt": {"stability": 0.42, "similarity_boost": 0.85, "style": 0.40},
    "mom": {"stability": 0.58, "similarity_boost": 0.85, "style": 0.25},
    "harcourt": {"stability": 0.62, "similarity_boost": 0.85, "style": 0.25},
    "cass": {"stability": 0.58, "similarity_boost": 0.86, "style": 0.28},
    "arlo": {"stability": 0.68, "similarity_boost": 0.84, "style": 0.14},
    "tommy": {"stability": 0.48, "similarity_boost": 0.80, "style": 0.34},
    "anchor": {"stability": 0.76, "similarity_boost": 0.84, "style": 0.10},
    "marv": {"stability": 0.55, "similarity_boost": 0.83, "style": 0.30},
    "earl": {"stability": 0.50, "similarity_boost": 0.81, "style": 0.26},
    "voice": {"stability": 0.82, "similarity_boost": 0.86, "style": 0.06},
    "machine": {"stability": 0.90, "similarity_boost": 0.80, "style": 0.02},
    "rudy": {"stability": 0.60, "similarity_boost": 0.82, "style": 0.22},
    "dead": {"stability": 0.88, "similarity_boost": 0.78, "style": 0.04},
}

def api_key():
    k = os.environ.get("ELEVENLABS_API_KEY", "")
    if not k:
        p = Path.home() / ".elevenlabs_key"
        if p.exists(): k = p.read_text(encoding="utf-8-sig").strip()
    if not k: raise SystemExit("no ElevenLabs key")
    return k

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--speaker", choices=sorted(VOICE))
    p.add_argument("--text")
    p.add_argument("--out")
    p.add_argument("--dialogue", help="Generate every spoken node in data/dialogue/<id>.json")
    a = p.parse_args()
    if a.dialogue:
        data = json.loads((ROOT / "data" / "dialogue" / (a.dialogue + ".json")).read_text(encoding="utf-8"))
        made = 0
        for node_id, node in data.get("nodes", {}).items():
            speaker = node.get("speaker", "")
            if speaker not in VOICE or not any(c.isalnum() for c in str(node.get("text", ""))):
                continue
            target = ROOT / "assets" / "audio" / "voice" / a.dialogue / (node_id + ".mp3")
            if target.exists():
                continue
            # Reuse this same function through a small local request.
            settings = dict(VOICE_STYLE[speaker]); settings["use_speaker_boost"] = True
            if speaker == "harcourt" and a.dialogue == "m01_boss_down":
                settings.update(stability=0.48, style=0.40)
            if speaker in ("buck", "dutch") and a.dialogue.endswith("boss_down"):
                settings.update(stability=0.44, style=0.42)
            body = {"text": node["text"], "model_id": "eleven_multilingual_v2", "voice_settings": settings}
            req = urllib.request.Request(f"{API}/text-to-speech/{VOICE[speaker]}?output_format=mp3_44100_128", data=json.dumps(body).encode(), headers={"xi-api-key": api_key(), "Content-Type": "application/json"})
            target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(urllib.request.urlopen(req, timeout=180).read()); made += 1
            print(f"wrote {target}")
        print(f"generated {made} voice lines for {a.dialogue}")
        return
    if not a.speaker or not a.text or not a.out:
        p.error("--speaker, --text and --out are required unless --dialogue is used")
    settings = dict(VOICE_STYLE[a.speaker]); settings["use_speaker_boost"] = True
    body = {"text": a.text, "model_id": "eleven_multilingual_v2", "voice_settings": settings}
    req = urllib.request.Request(f"{API}/text-to-speech/{VOICE[a.speaker]}?output_format=mp3_44100_128", data=json.dumps(body).encode(), headers={"xi-api-key": api_key(), "Content-Type": "application/json"})
    audio = urllib.request.urlopen(req, timeout=180).read()
    out = Path(a.out); out.parent.mkdir(parents=True, exist_ok=True); out.write_bytes(audio)
    print(f"wrote {out} ({len(audio)} bytes)")

if __name__ == "__main__": main()
