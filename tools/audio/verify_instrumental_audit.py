#!/usr/bin/env python3
"""Validate that the saved no-vocals audit covers the complete music library.

This is the fast, offline companion to ``audit_instrumental_content.py``.
The transcription audit remains the authority for detecting vocals; this tool
makes its report enforceable in local review and automated checks by rejecting
missing, extra, or non-passing entries.
"""
from __future__ import annotations

import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
MUSIC = ROOT / "music"
REPORT = ROOT / "build" / "music_instrumental_content_audit.json"
AUDIO_SUFFIXES = {".mp3", ".ogg", ".wav"}


def library_tracks() -> set[str]:
    return {
        path.relative_to(ROOT).as_posix()
        for path in MUSIC.rglob("*")
        if path.is_file() and path.suffix.lower() in AUDIO_SUFFIXES
    }


def main() -> int:
    if not REPORT.is_file():
        print("Instrumental audit is missing. Run tools/audio/audit_instrumental_content.py.")
        return 1
    try:
        report = json.loads(REPORT.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        print(f"Instrumental audit is invalid JSON: {error}")
        return 1

    records = report.get("tracks")
    if not isinstance(records, list):
        print("Instrumental audit has no track records.")
        return 1
    audited: dict[str, dict] = {}
    duplicate: set[str] = set()
    for record in records:
        if not isinstance(record, dict) or not isinstance(record.get("file"), str):
            print("Instrumental audit contains an invalid record.")
            return 1
        key = record["file"].replace("\\", "/")
        if key in audited:
            duplicate.add(key)
        audited[key] = record

    expected = library_tracks()
    actual = set(audited)
    missing = sorted(expected - actual)
    unexpected = sorted(actual - expected)
    failed = sorted(path for path, record in audited.items() if record.get("status") != "instrumental_pass")
    if missing or unexpected or duplicate or failed:
        for label, paths in (("missing", missing), ("unexpected", unexpected), ("duplicate", sorted(duplicate)), ("not instrumental", failed)):
            for path in paths:
                print(f"{label}: {path}")
        print("Instrumental audit verification failed. Re-run tools/audio/audit_instrumental_content.py.")
        return 1

    print(f"Instrumental audit verified: {len(expected)}/{len(expected)} music tracks pass with no discernible vocals.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
