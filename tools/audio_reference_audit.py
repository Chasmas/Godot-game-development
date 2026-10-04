import json
from pathlib import Path

def main():
    data = json.loads(Path('data/music.json').read_text(encoding='utf-8'))
    refs = set()
    def walk(v):
        if isinstance(v, dict):
            for x in v.values(): walk(x)
        elif isinstance(v, list):
            for x in v: walk(x)
        elif isinstance(v, str) and v.startswith('res://'):
            refs.add(v.removeprefix('res://'))
    walk(data)
    missing = sorted(r for r in refs if not Path(r).exists())
    print(f'audio_refs={len(refs)} missing={len(missing)}')
    if missing: print('\n'.join(missing))
    return 1 if missing else 0

if __name__ == '__main__': raise SystemExit(main())
