from pathlib import Path
import array,subprocess,math,json,concurrent.futures
import imageio_ffmpeg
root=Path('assets/audio/voice'); ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
def envelope(path):
 raw=subprocess.run([ffmpeg,'-v','error','-i',str(path),'-f','s16le','-ac','1','-ar','8000','pipe:1'],check=True,capture_output=True).stdout
 pcm=array.array('h');pcm.frombytes(raw)
 values=[math.sqrt(sum(x*x for x in pcm[i:i+160])/len(pcm[i:i+160]))/32768 for i in range(0,len(pcm),160)]
 reference=sorted(values)[int(len(values)*.95)] if values else 1
 vals=[round(min(1,max(0,(v-.006)/max(reference-.006,.01))),3) for v in values]
 return 'res://'+path.as_posix(),vals
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool: data=dict(pool.map(envelope,sorted(root.rglob('*.mp3'))))
(root/'mouth_envelopes.json').write_text(json.dumps({'step':.02,'clips':data},separators=(',',':')),encoding='utf-8')
print('Measured envelopes:',len(data),'clips')
