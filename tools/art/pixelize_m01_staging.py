from pathlib import Path
from PIL import Image, ImageEnhance
ROOT=Path(__file__).resolve().parents[2]
base=ROOT/'assets/art/prerendered/m01_sunset_palms/staging'
for src in (base/'m01_interiors_transitions_staging.png',base/'m01_reception_detail_staging.png',base/'m01_service_transition_detail_staging.png'):
 im=Image.open(src).convert('RGB'); small=im.resize((im.width//3,im.height//3),Image.Resampling.LANCZOS); small=small.quantize(colors=96,method=Image.Quantize.MEDIANCUT).convert('RGBA'); out=small.resize(im.size,Image.Resampling.NEAREST); out=ImageEnhance.Contrast(out).enhance(1.12); dst=src.with_name(src.stem.replace('_staging','_pixel_preview')+'.png'); out.save(dst); print(dst)

