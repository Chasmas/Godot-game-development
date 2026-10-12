"""Refresh M01 runtime-art contract hashes after approved level metadata edits.

The contracts deliberately pin their art to the authored M01 map.  This tool
updates only existing ``source_level_sha256`` fields; it never changes a
runtime-approval flag, asset list, placement or gameplay contract.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LEVEL = ROOT / "levels" / "m01_sunset_palms.json"
RUNTIME = ROOT / "assets" / "art" / "prerendered" / "m01_sunset_palms" / "runtime"


def main() -> None:
    digest = hashlib.sha256(LEVEL.read_bytes()).hexdigest()
    changed = []
    for path in sorted(RUNTIME.rglob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue
        if not isinstance(data, dict) or "source_level_sha256" not in data:
            continue
        if data["source_level_sha256"] == digest:
            continue
        data["source_level_sha256"] = digest
        path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        changed.append(path.relative_to(ROOT).as_posix())
    print("M01_RUNTIME_CONTRACT_HASHES:", len(changed), "contracts", digest)
    for path in changed:
        print(path)


if __name__ == "__main__":
    main()
