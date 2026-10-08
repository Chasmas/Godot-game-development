"""Contact sheet assembly only, no game artwork modification."""
from pathlib import Path
from PIL import Image,ImageDraw
out=Image.new('RGB',(1400,800),'#191622')
draw=ImageDraw.Draw(out)
for index,angle in enumerate(range(0,360,45)):
    source=Image.open(Path('build')/f'guard_dual_asset_comparison_side_angle_{angle}.png')
    # Preserve pixels; crop each candidate's rendered region and tile it.
    cell=source.crop((730,210,1080,520))
    x=(index%4)*350;y=(index//4)*400
    out.paste(cell,(x,y+80))
    draw.text((x+20,y+30),f'{angle} degrees',fill='white')
out.save('build/guard_dual_eight_heading_review.png')
