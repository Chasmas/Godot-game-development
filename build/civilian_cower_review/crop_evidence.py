from PIL import Image
from pathlib import Path
root=Path('build/civilian_cower_review')
im=Image.open(root/'motel_staging.png')
im.crop((880,260,1040,400)).save(root/'motel_shelter_detail.png')