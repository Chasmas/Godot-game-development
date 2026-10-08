"""Run with Blender --background --python this_file -- path/to/source.blend."""
from pathlib import Path
import sys,json
import bpy
root=Path(__file__).resolve().parents[1]
source=Path(sys.argv[sys.argv.index('--')+1]).resolve()
assert source.is_relative_to(root), 'Only repair source files inside the migrated project'
bpy.ops.wm.open_mainfile(filepath=str(source))
changed=[];missing=[]
marker='Godot-game-development-codex/'
for image in bpy.data.images:
    if image.packed_file or not image.filepath:continue
    old=image.filepath.replace('\\','/')
    if marker in old:
        candidate=root/old.split(marker,1)[1]
        if candidate.is_file():image.filepath=str(candidate);changed.append(image.name)
        else:missing.append({'image':image.name,'source':old})
    elif not Path(bpy.path.abspath(image.filepath)).is_file():missing.append({'image':image.name,'source':old})
if missing:
    print(json.dumps({'unresolved_images':missing},indent=2));raise RuntimeError('Resolve missing source images before saving this Blender file')
bpy.ops.file.make_paths_relative()
bpy.ops.wm.save_as_mainfile(filepath=str(source))
print('Relinked images:',len(changed))
