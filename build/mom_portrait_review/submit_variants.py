from pathlib import Path
from PIL import Image,ImageDraw
import base64,json,urllib.request,os
out=Path('build/mom_portrait_review');src=Path('assets/art/pixellab_ui_v3_approved/portraits/mom.png');size=Image.open(src).size
key=os.environ.get('PIXELLAB_API_KEY','').strip() or (Path.home()/'.pixellab_key').read_text(encoding='utf-8-sig').strip()
variants={'blink':([(41,60,60,71),(74,52,87,61)],'Same older mother briefly blinking. Both eyes fully closed with natural thin eyelid lines. Preserve eyebrows and expression. Match exact native pixel clusters and palette. No new detail.'),'talk_wide':([(64,85,83,97)],'Same older mother speaking an emphatic vowel. Mouth naturally slightly wider open than soft speech, dark interior, tiny understated upper tooth edge. No scream or smile. Match native pixel clusters, wrinkles and palette.')}
for name,(boxes,prompt) in variants.items():
 mask=Image.new('RGB',size,'black');draw=ImageDraw.Draw(mask)
 for box in boxes:draw.rectangle(box,fill='white')
 mask_path=out/(name+'_mask.png');mask.save(mask_path)
 def packed(path):return {'image':{'base64':base64.b64encode(path.read_bytes()).decode()},'size':{'width':size[0],'height':size[1]}}
 body={'description':prompt,'inpainting_image':packed(src),'mask_image':packed(mask_path),'crop_to_mask':True,'seed':44 if name=='blink' else 45,'no_background':False}
 (out/(name+'_request.json')).write_text(json.dumps({'source':str(src),'boxes':boxes,'prompt':prompt,'seed':body['seed']}))
 req=urllib.request.Request('https://api.pixellab.ai/v2/inpaint-v3',data=json.dumps(body).encode(),headers={'Authorization':'Bearer '+key,'Content-Type':'application/json'})
 response=json.load(urllib.request.urlopen(req,timeout=60));(out/(name+'_job.json')).write_text(json.dumps(response));print(name,response['background_job_id'],response['status'])
