"""Derive map scope from current data; references do not prove finished assets."""
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / 'assets/art/materials/m01/batch_v1'
level = json.loads((ROOT / 'levels/m01_sunset_palms.json').read_text(encoding='utf-8'))
glyphs = Counter(''.join(level['map']))
furniture = {'T': 'table', 'C': 'counter', 'b': 'bed', 'l': 'lounger', 'w': 'washer', 'k': 'desk', 'K': 'car', 'Z': 'dumpster'}
props = {'V': 'vending', 't': 'tv', 'Q': 'arcade', 'I': 'ice', 'Y': 'plant', 'F': 'fuse', 'o': 'lamp'}
actors = {'g': 'guard', 'm': 'gunner', 'h': 'hunter', 'H': 'heavy', 's': 'scout', 'r': 'riot', 'B': 'night_manager', 'd': 'dog', 'y': 'dog_rott'}
weapon_glyphs = {'2':'whisper','3':'revolver','4':'smg','5':'shotgun','6':'rifle','7':'knife','8':'bat','9':'pipe','0':'machete','!':'bottle','?':'brick','G':'hotshot'}
def entries(mapping):
    return [{'glyph': glyph, 'kind': kind, 'occupied_map_cells': glyphs[glyph]} for glyph, kind in mapping.items() if glyphs[glyph]]
report = {
    'source': 'levels/m01_sunset_palms.json',
    'note': 'Multi-cell furniture counts are occupied cells, not distinct objects. Image presence does not prove quality, identity fidelity, Blender production or runtime integration.',
    'furniture': entries(furniture), 'interactive_props': entries(props),
    'actors': entries(actors), 'authored_enemy_overrides': level['enemies'],
    'civilians': level['npcs'], 'weapon_pickups': entries(weapon_glyphs),
    'decor_ids': sorted({item.get('id', item.get('type','')) for item in level['decor']}),
    'zones': level.get('zones'), 'camera_placements': level.get('cameras'),
    'visual_sources_present': sorted(path.name for path in BATCH.glob('*.png')),
    'full_map_imagegen_coverage': 'incomplete',
    'blender_batch_started': False
}
(BATCH / 'map_inventory.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
print(f'M01 inventory: {len(report["decor_ids"])} decor identifiers, {len(report["actors"])} actor kinds. Coverage still incomplete.')
