"""Fail-fast audit for the music contract: every cue is instrumental."""
import json

d = json.load(open('tools/audio/soundtrack.json', encoding='utf-8'))
for tid, track in d['tracks'].items():
    assert track.get('instrumental', True), f'{tid}: instrumental=false'
print(f'instrumental contract PASS: {len(d["tracks"])} tracks, no vocal directions')
