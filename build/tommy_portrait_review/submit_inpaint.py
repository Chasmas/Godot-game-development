from pathlib import Path
from PIL import Image,ImageDraw
import base64,json,urllib.request,os,io
out=Path('build/tommy_portrait_review'); src=Path('assets/art/pixellab_ui_v3_approved/portraits/tommy.png'); size=Image.open(src).size
mask=Image.new('RGB',size,'black');ImageDraw.Draw(mask).rectangle((53,64,74,76),fill='white');mask.save(out/'mouth_mask.png')
key=os.environ.get('PIXELLAB_API_KEY','').strip() or (Path.home()/'.pixellab_key').read_text(encoding='utf-8-sig').strip()
def packed(path): return {'image':{'base64':base64.b64encode(path.read_bytes()).decode()},'size':{'width':size[0],'height':size[1]}}
body={'description':'Same tired man speaking softly. Only slightly open his lips, dark mouth interior and tiny upper tooth edge. Match existing pixel clusters, palette, stubble and face. No smile. Natural understated speech mouth, not a scream.','inpainting_image':packed(src),'mask_image':packed(out/'mouth_mask.png'),'crop_to_mask':True,'seed':43,'no_background':False}
(out/'request_provenance.json').write_text(json.dumps({'source':str(src),'mask_box':[53,64,74,76],'description':body['description'],'endpoint':'/v2/inpaint-v3','seed':43},indent=2))
r=urllib.request.Request('https://api.pixellab.ai/v2/inpaint-v3',data=json.dumps(body).encode(),headers={'Authorization':'Bearer '+key,'Content-Type':'application/json'})
try:
 data=json.load(urllib.request.urlopen(r,timeout=60));(out/'job.json').write_text(json.dumps(data));print(json.dumps(data))
except urllib.error.HTTPError as e: print('HTTP',e.code,e.read().decode()[:500]);raise SystemExit(1)
