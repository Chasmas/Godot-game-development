"""Validate live M01 composition captures at gameplay scale."""
from __future__ import annotations
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / 'build'
OUT = BUILD / 'm01_runtime_composition_audit.json'
CAPTURES = [
    'm01_courtyard_runtime_capture.png', 'm01_lounge_runtime_capture.png',
    'm01_reception_runtime_capture.png', 'm01_office_runtime_capture.png',
    'm01_service_runtime_capture.png', 'm01_guest_room_accents_runtime.png',
]

def percentile(values: list[float], fraction: float) -> float:
    return values[min(len(values) - 1, int((len(values) - 1) * fraction))]

def main() -> None:
    failures: list[str] = []
    zones: list[dict] = []
    for name in CAPTURES:
        path = BUILD / name
        if not path.exists():
            failures.append(f'missing capture: {name}')
            continue
        image = Image.open(path).convert('RGB')
        if image.size != (800, 600):
            failures.append(f'{name}: expected 800x600, got {image.size}')
        luminance: list[float] = []
        white = 0
        for r, g, b in image.get_flattened_data():
            luminance.append(r * .2126 + g * .7152 + b * .0722)
            white += int(r >= 250 and g >= 250 and b >= 250)
        luminance.sort()
        clipped_pct = white * 100.0 / max(1, len(luminance))
        # White tile and active lights are intentional in reception; this cap
        # catches a global washout while allowing its concentrated lit area.
        if clipped_pct > 3.0:
            failures.append(f'{name}: clipped-white area {clipped_pct:.3f}% exceeds 3%')
        zones.append({'capture': name, 'resolution': list(image.size), 'median_luminance': round(percentile(luminance,.5), 3), 'p95_luminance': round(percentile(luminance,.95), 3), 'p99_luminance': round(percentile(luminance,.99), 3), 'clipped_white_percent': round(clipped_pct, 3)})
    report = {'passed': not failures, 'zones': zones, 'failures': failures, 'scope': 'Live M01 camera captures. Checks expected output dimensions and guards against global clipped-white lighting while allowing the established concentrated reception tile lighting.'}
    OUT.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(f'M01 runtime composition audit: {len(zones)} captures, {len(failures)} failures')
    if failures: raise SystemExit(1)
if __name__ == '__main__': main()
