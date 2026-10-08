"""Ensure M01 staging Blender renders are not accidentally promoted."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
scan=[ROOT/'scripts',ROOT/'levels',ROOT/'project.godot']
forbidden=('m01_interiors_transitions_staging','m01_reception_detail_staging','m01_interiors_transitions_pixel_preview','m01_reception_detail_pixel_preview')
hits=[]
for base in scan:
 files=[base] if base.is_file() else list(base.rglob('*'))
 for p in files:
  if p.is_file() and p.suffix not in ('.import','.png','.blend'):
   try: txt=p.read_text(encoding='utf-8',errors='ignore')
   except: continue
   for token in forbidden:
    if token in txt: hits.append((p.relative_to(ROOT),token))
if hits: raise SystemExit('runtime staging leak: '+str(hits))
print('M01 runtime isolation audit: PASS')
