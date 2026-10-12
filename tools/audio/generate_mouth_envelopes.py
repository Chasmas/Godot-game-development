from pathlib import Path
import array, subprocess, math, json, concurrent.futures, os, shutil

root = Path('assets/audio/voice')


def find_ffmpeg() -> str:
    """Prefer an explicit tool path, then normal PATH discovery and known local installs."""
    candidates = [
        os.environ.get('FFMPEG_PATH'),
        shutil.which('ffmpeg'),
        Path(os.environ.get('LOCALAPPDATA', '')) / 'Programs' / 'Stremio' / 'ffmpeg.exe',
    ]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(candidate)
    raise RuntimeError('ffmpeg was not found; set FFMPEG_PATH to its executable path.')


ffmpeg = find_ffmpeg()
def envelope(path):
 raw=subprocess.run([ffmpeg,'-v','error','-i',str(path),'-f','s16le','-ac','1','-ar','8000','pipe:1'],check=True,capture_output=True).stdout
 pcm=array.array('h');pcm.frombytes(raw)
 values=[math.sqrt(sum(x*x for x in pcm[i:i+160])/len(pcm[i:i+160]))/32768 for i in range(0,len(pcm),160)]
 reference=sorted(values)[int(len(values)*.95)] if values else 1
 vals=[round(min(1,max(0,(v-.006)/max(reference-.006,.01))),3) for v in values]
 return 'res://'+path.as_posix(),vals
voice_files = sorted(
	path for extension in ('*.mp3', '*.ogg', '*.wav')
	for path in root.rglob(extension)
)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
	data = dict(pool.map(envelope, voice_files))
(root/'mouth_envelopes.json').write_text(json.dumps({'step':.02,'clips':data},separators=(',',':')),encoding='utf-8')
print('Measured envelopes:',len(data),'clips')
