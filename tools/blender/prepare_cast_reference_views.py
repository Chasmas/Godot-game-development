"""Run inside Blender: separate reviewed turnaround views without altering originals."""
import bpy
import hashlib
import json
import math
import sys
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/art/reference/cast_redesign_v1/cass_turnaround.png'
OUT = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/cass/references'
BOXES = {'front': (0, 0, 575, 1024), 'side': (575, 0, 965, 1024), 'back': (965, 0, 1536, 1024)}

def main(character='cass'):
    global SOURCE, OUT, BOXES
    config = json.loads((ROOT / 'tools/art/cast_reference_crops.json').read_text(encoding='utf-8'))[character]
    SOURCE = ROOT / ('assets/art/reference/cast_redesign_v1/' + config.get('source_file', character + '_turnaround.png'))
    OUT = ROOT / ('assets/art/Artwork/3d/cast_redesign_v1/' + character + '/references')
    BOXES = config['views']
    height_m = config['height_m']
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    source = bpy.data.images.load(str(SOURCE), check_existing=False)
    width, height = source.size
    expected_size = tuple(config.get('source_size', [1536, 1024]))
    if (width, height) != expected_size:
        raise RuntimeError('Source dimensions do not match reviewed crop configuration')
    for box in BOXES.values():
        left, top, right, bottom = box
        if not (0 <= left < right <= width and 0 <= top < bottom <= height):
            raise RuntimeError('Reference crop lies outside original image')
    buffer = np.empty(width * height * 4, dtype=np.float32)
    source.pixels.foreach_get(buffer)
    pixels = buffer.reshape((height, width, 4))
    report = {'character': character, 'height_m': height_m, 'source': str(SOURCE.relative_to(ROOT)),
              'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              'operation': 'Blender image buffers; separate existing front/profile/back views',
              'model_generated': False, 'approved_for_api': False, 'views': []}
    for index, (name, box) in enumerate(BOXES.items()):
        left, top, right, bottom = box
        crop = np.ascontiguousarray(pixels[height-bottom:height-top, left:right, :])
        image = bpy.data.images.new(character + ' reference ' + name, width=right-left, height=bottom-top, alpha=True)
        image.colorspace_settings.name = source.colorspace_settings.name
        image.pixels.foreach_set(crop.ravel())
        image.filepath_raw = str(OUT / (name + '.png'))
        image.file_format = 'PNG'
        image.save()
        image.pack()
        empty = bpy.data.objects.new('REFERENCE_ONLY_' + name, None)
        empty.empty_display_type = 'IMAGE'
        empty.data = image
        empty.empty_display_size = height_m
        empty.location = (index * 1.15, 0, height_m / 2)
        empty.rotation_euler = (math.pi / 2, 0, 0)
        empty['purpose'] = 'Modeling reference only; this is not a character mesh'
        bpy.context.scene.collection.objects.link(empty)
        report['views'].append({'name': name, 'box_top_left_pixels': box,
                                'width': right-left, 'height': bottom-top,
                                'file': str((OUT / (name + '.png')).relative_to(ROOT)),
                                'sha256': hashlib.sha256((OUT / (name + '.png')).read_bytes()).hexdigest()})
    bpy.context.scene['purpose'] = character + ' turnaround reference board. No character geometry generated.'
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / (character + '_reference_board.blend')))
    (OUT / 'reference_audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({'reference_board': str(OUT / (character + '_reference_board.blend')), 'views': len(report['views'])}))

if __name__ == '__main__':
    characters = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else ['cass']
    for character in characters:
        main(character)
