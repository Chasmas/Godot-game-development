from PIL import Image,ImageDraw
from pathlib import Path
root=Path('build/civilian_cower_review/motel_motion')
files=sorted(root.glob('[0-9][0-9][0-9].png'))
frames=[Image.open(p).convert('RGB') for p in files]
frames[0].save(root/'native_motion.gif',save_all=True,append_images=frames[1:],duration=33,loop=0)
sheet=Image.new('RGB',(160*6,170),(20,18,26))
for i,index in enumerate([0,5,10,15,20,36]):
 sheet.paste(frames[index],(i*160,0))
 ImageDraw.Draw(sheet).text((i*160+5,153),str(index),(240,240,240))
sheet.save(root/'contact.png')
print(len(frames),'native scale frames')