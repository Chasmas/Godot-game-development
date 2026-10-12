from pathlib import Path
from PIL import Image
root=Path('build/uthana/cass')
for name,seconds in [('walk',1.9333334),('run',1.23333335),('pistol_walk',1.4666667)]:
    files=sorted((root/(name+'_frames')).glob('*.png'))
    frames=[Image.open(p).convert('RGB') for p in files]
    assert len(frames)==48
    frames[0].save(root/(name+'.gif'),save_all=True,append_images=frames[1:],duration=round(seconds*1000/48),loop=0,optimize=False)
    print(name+'.gif:',len(frames),'frames')
