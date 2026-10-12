"""Blender audit of existing Meshy NPC sources; never edits production assets."""
import bpy, json, sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
rows=[]
for cast in ('guard','gunner','hunter','heavy','scout','bellhop','security','boss'):
 for clip in ('idle','walk','run','aim','melee','death'):
  path=root/'assets/art/Artwork/3d'/cast/f'anim_{clip}.glb'
  bpy.ops.wm.read_factory_settings(use_empty=True)
  try:
   bpy.ops.import_scene.gltf(filepath=str(path))
   arms=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']
   meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
   images=[{'name':i.name,'size':list(i.size),'pixels_available':i.has_data} for i in bpy.data.images]
   names=[b.name for a in arms for b in a.data.bones]
   hands={s:[n for n in names if s.lower() in n.lower() and 'hand' in n.lower()] for s in ('Left','Right')}
   rows.append({'cast':cast,'clip':clip,'armatures':len(arms),'bones':len(names),'hand_bones':hands,'vertices':sum(len(o.data.vertices) for o in meshes),'images':images,'actions':[{'name':a.name,'frames':list(a.frame_range)} for a in bpy.data.actions], 'missing_images':[i.name for i in bpy.data.images if not i.has_data]})
  except Exception as e: rows.append({'cast':cast,'clip':clip,'error':str(e)})
out=root/'build/meshy_npc_source_audit.json'
out.write_text(json.dumps({'scope':'Import integrity only; not visual motion or weapon grip approval','rows':rows},indent=2))
print('NPC_MESHY_AUDIT',len(rows),'imports; errors',sum('error' in r for r in rows),'report',out)
