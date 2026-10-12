"""Thirty-five-second stage reveal edit from current Godot gameplay captures."""
from pathlib import Path
import subprocess, shutil, json
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'build/awards_trailer'
FF = shutil.which('ffmpeg')
W,H = 1920,1080

def run(args):
    subprocess.run([FF,'-hide_banner','-loglevel','error','-y',*map(str,args)],check=True)

def card(name, headline, sub=''):
    im=Image.new('RGB',(W,H),(5,5,14)); d=ImageDraw.Draw(im)
    for y in range(0,H,4): d.line((0,y,W,y),fill=(9,9,21))
    font=ImageFont.truetype(str(ROOT/'assets/fonts/Poppins-BoldItalic.ttf'),92)
    small=ImageFont.truetype(str(ROOT/'assets/fonts/DejaVuSansMono-Bold.ttf'),28)
    d.line((500,365,1420,365), fill='#ff397f',width=4)
    d.text((W/2,510),headline,font=font,anchor='mm',fill='#eee8db')
    d.text((W/2,635),sub,font=small,anchor='mm',fill='#35e0ff')
    path=WORK/(name+'.png'); im.save(path); return path

def still(name,path,duration,zoom=True):
    fitted=ImageOps.fit(Image.open(path).convert('RGB'),(W,H),method=Image.Resampling.LANCZOS)
    png=WORK/(name+'_source.png'); fitted.save(png)
    frames=round(duration*30)
    motion=f"zoompan=z='1+0.000055*on':x='iw/2-iw/zoom/2':y='ih/2-ih/zoom/2':d={frames}:s={W}x{H}:fps=30," if zoom else ''
    out=WORK/(name+'.mp4')
    run(['-loop','1','-i',png,'-f','lavfi','-i','anullsrc=r=48000:cl=stereo','-t',duration,'-vf',motion+f'fade=t=in:d=0.18,fade=t=out:st={duration-.22}:d=0.22',
         '-r','30','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-c:a','aac','-ar','48000',out])
    return out

def clip(name,source,start,duration):
    out=WORK/(name+'.mp4')
    run(['-ss',start,'-i',WORK/source,'-t',duration,'-vf',f'scale={W}:{H}:flags=neighbor,setsar=1,fps=30',
         '-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-c:a','aac','-ar','48000','-ac','2',out])
    return out

def main():
    parts=[still('01_studio',card('studio','INVERTED INDEX','A GAME BY GILBERTO LOPES'),2,False),
           still('02_motel',ROOT/'assets/art/painted/motel_night.webp',3),
           still('03_tape',ROOT/'assets/art/painted/t_tape.webp',2),
           still('04_revenge',card('revenge','EVERY NIGHT HAS A PRICE.'),2,False),
           clip('05_motel','m01.avi',12,5),
           clip('06_studio','m03.avi',12,4),
           still('07_cass',ROOT/'assets/art/painted/cass_close.webp',1.5),
           clip('08_action','m01.avi',23,3),
           clip('09_action','m03.avi',23,3),
           clip('10_action','m01.avi',32,2),
           clip('11_action','m03.avi',32,2),
           still('12_title',ROOT/'assets/art/title/hotshot_title.webp',5.5)]
    concat=WORK/'edit.txt'; concat.write_text(''.join("file '"+p.as_posix()+"'\n" for p in parts))
    picture=WORK/'picture.mp4'
    run(['-f','concat','-safe','0','-i',concat,'-c','copy',picture])
    out=Path.home()/'Desktop/Hotshot California — Reveal Trailer.mp4'
    # A restrained opening rises into the gameplay montage, then releases into
    # the final logo. No storefront or release-date claims are added.
    run(['-i',picture,'-i',ROOT/'music/source/trailer_synthwave.mp3','-t','35',
         '-filter_complex',"[1:a]volume='if(lt(t,7),0.45,0.85)':eval=frame,afade=t=in:d=1,afade=t=out:st=33:d=2[m];[0:a]volume=0.65[s];[m][s]amix=inputs=2:duration=longest:normalize=0,alimiter=limit=0.95[a]",
         '-map','0:v','-map','[a]',
         '-c:v','copy','-c:a','aac','-b:a','256k','-movflags','+faststart',out])
    print(out)

if __name__=='__main__': main()
