#!/usr/bin/env python3
"""Audit every game-referenced music file for spoken or sung vocal content.

The OpenAI transcription request is deliberately prompted to return only
discernible words.  An empty transcript is recorded as an instrumental pass;
non-empty output needs human review before that cue can ship.
"""
from __future__ import annotations

import json
import mimetypes
import os
from pathlib import Path
import sys
import time
import uuid
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor

ROOT = Path(__file__).resolve().parents[2]
MUSIC = ROOT / "music"
OUTPUT = ROOT / "build" / "music_instrumental_content_audit.json"
API = "https://api.openai.com/v1/audio/transcriptions"


def api_key() -> str:
    key = os.environ.get("OPENAI_API_KEY", "")
    if key:
        return key
    if os.name == "nt":
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as registry:
            return str(winreg.QueryValueEx(registry, "OPENAI_API_KEY")[0]).strip()
    raise RuntimeError("OPENAI_API_KEY is unavailable")


def music_tracks() -> list[Path]:
    # Audit every music master and source variant.  Dialogue and SFX live
    # elsewhere, while *.import files are Godot metadata rather than audio.
    return sorted(path for path in MUSIC.rglob("*") if path.suffix.lower() in {".mp3", ".ogg", ".wav"})


def game_tracks() -> list[Path]:
    cues = json.loads((ROOT / "data" / "music.json").read_text(encoding="utf-8"))
    return sorted({ROOT / Path(layer.removeprefix("res://")) for cue in cues.values() for layer in cue["layers"]})


def transcribe(path: Path, key: str) -> str:
    boundary = "----HotshotInstrumental" + uuid.uuid4().hex
    chunks: list[bytes] = []
    def field(name: str, value: str) -> None:
        chunks.extend((f"--{boundary}\r\n".encode(),
                       f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode(),
                       value.encode(), b"\r\n"))
    field("model", "gpt-4o-mini-transcribe")
    field("prompt", "Return only exact words that are audibly spoken or sung. If this is instrumental music with no intelligible human voice, return an empty transcript. Do not describe instruments or music.")
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    chunks.extend((f"--{boundary}\r\n".encode(),
                   f'Content-Disposition: form-data; name="file"; filename="{path.name}"\r\n'.encode(),
                   f"Content-Type: {mime}\r\n\r\n".encode(), path.read_bytes(), b"\r\n",
                   f"--{boundary}--\r\n".encode()))
    request = urllib.request.Request(API, data=b"".join(chunks), headers={
        "Authorization": f"Bearer {key}", "Content-Type": f"multipart/form-data; boundary={boundary}"
    })
    for attempt in range(4):
        try:
            response = json.load(urllib.request.urlopen(request, timeout=180))
            return str(response.get("text", "")).strip()
        except (urllib.error.URLError, TimeoutError, ConnectionError) as error:
            if attempt == 3:
                raise RuntimeError(f"transcription unavailable: {error.reason if hasattr(error, 'reason') else error}") from error
            time.sleep(2 ** attempt)
    raise AssertionError("unreachable")


def main() -> int:
    key = api_key()
    arguments = sys.argv[1:]
    output = OUTPUT
    output_value = ""
    if "--output" in arguments:
        output_index = arguments.index("--output")
        if output_index + 1 >= len(arguments):
            raise SystemExit("--output needs a project-relative report path")
        output_value = arguments[output_index + 1]
        output = ROOT / output_value.removeprefix("res://")
    requested = [
        ROOT / argument.removeprefix("res://")
        for argument in arguments
        if not argument.startswith("--") and argument != output_value
    ]
    tracks = game_tracks() if "--game-referenced" in arguments else (requested if requested else music_tracks())
    def inspect(path: Path) -> dict[str, str]:
        if not path.is_file():
            return {"file": str(path.relative_to(ROOT)), "status": "missing", "transcript": ""}
        try:
            transcript = transcribe(path, key)
        except RuntimeError as error:
            return {"file": str(path.relative_to(ROOT)), "status": "audit_error", "transcript": str(error)}
        status = "needs_replacement" if transcript else "instrumental_pass"
        return {"file": str(path.relative_to(ROOT)), "status": status, "transcript": transcript}

    # Requests are independent.  A modest pool keeps a full source-library
    # verification practical without turning it into a single long-running
    # serial request, while preserving one result per source file.
    with ThreadPoolExecutor(max_workers=3) as pool:
        records = list(pool.map(inspect, tracks))
    for record in records:
        path = ROOT / record["file"]
        status = record["status"]
        transcript = record["transcript"]
        print(f"{status}: {path.name}" + (f" — {transcript}" if transcript else ""))
    scope = "Every game-referenced music master; dialogue, SFX and unshipped source variants excluded" if "--game-referenced" in arguments else "Every audio track under music/, including game masters and source variants; dialogue and SFX excluded"
    report = {"scope": scope, "tracks": records}
    output.parent.mkdir(exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    blocked = [record for record in records if record["status"] != "instrumental_pass"]
    print(f"Instrumental content audit: {len(records) - len(blocked)}/{len(records)} passed")
    return 1 if blocked else 0


if __name__ == "__main__":
    sys.exit(main())
