from PIL import Image,ImageDraw
from pathlib import Path
root=Path('build/civilian_exposure_review')
files=sorted(root.glob('*.png'))
sheet=Image.new('RGB',(640,180*4),(18,16,24))
for i,p in enumerate(files):
 x=(i%4)*160;y=(i//4)*180
 sheet.paste(Image.open(p),(x,y))
 ImageDraw.Draw(sheet).text((x+3,y+151),p.stem.replace('m01_checkout_','').replace('m03_prime_time_',''),(230,230,230))
sheet.save(root/'comparison_contact.png')
print(len(files),'captures')