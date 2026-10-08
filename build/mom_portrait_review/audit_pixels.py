from pathlib import Path
from PIL import Image
import json
out=Path('build/mom_portrait_review')
base=Image.open('assets/art/pixellab_ui_v3_approved/portraits/mom.png').convert('RGBA')
result={}
for name,boxes in {'blink':[(41,60,60,71),(74,52,87,61)],'talk':[(64,85,83,97)],'talk_wide':[(64,85,83,97)]}.items():
 image=Image.open(out/(name+'_native.png')).convert('RGBA')
 inside=outside=0
 for y in range(base.height):
  for x in range(base.width):
   if base.getpixel((x,y))!=image.getpixel((x,y)):
    if any(a<=x<=c and b<=y<=d for a,b,c,d in boxes):inside+=1
    else:outside+=1
 result[name]={'size':image.size,'changed_inside_mask':inside,'changed_outside_mask':outside,'visual_decision':'blink candidate accepted; mouth variants rejected as exaggerated' }
(out/'pixel_audit.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result))