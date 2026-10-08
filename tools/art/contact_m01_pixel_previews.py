from pathlib import Path
from PIL import Image,ImageOps,ImageDraw
root=Path('assets/art/prerendered/m01_sunset_palms/staging')
paths=[root/'m01_interiors_transitions_pixel_preview.png',root/'m01_reception_detail_pixel_preview.png',root/'m01_service_transition_detail_pixel_preview.png']
thumbs=[]
for p in paths:
 im=Image.open(p).convert('RGB'); im.thumbnail((640,360)); canvas=Image.new('RGB',(640,400),(18,20,28)); canvas.paste(im,((640-im.width)//2,20)); ImageDraw.Draw(canvas).text((18,375),p.stem,fill=(240,220,180)); thumbs.append(canvas)
out=Image.new('RGB',(1280,800),(8,10,16))
for i,im in enumerate(thumbs): out.paste(im,((i%2)*640,(i//2)*400))
out.save(root/'m01_pixel_previews_contact.png')
print(root/'m01_pixel_previews_contact.png')
