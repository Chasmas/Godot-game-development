from PIL import Image,ImageDraw
from pathlib import Path
root=Path('build/civilian_cower_review')
files=sorted((root/'motion').glob('*.png'))
frames=[Image.open(p).convert('RGB') for p in files]
frames[0].save(root/'cower_motion.gif',save_all=True,append_images=frames[1:],duration=33,loop=0)
sheet=Image.new('RGB',(640,6*240),(30,25,35))
for row,index in enumerate([0,5,10,15,20,36]):
 sheet.paste(frames[index],(0,row*240))
 ImageDraw.Draw(sheet).text((5,row*240+220),f'frame {index}/36',(230,230,230))
sheet.save(root/'motion_contact.png')
print(len(frames),'frames assembled')