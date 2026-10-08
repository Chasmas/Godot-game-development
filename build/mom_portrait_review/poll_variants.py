import json,urllib.request,os,base64
from pathlib import Path
out=Path('build/mom_portrait_review');key=os.environ.get('PIXELLAB_API_KEY','').strip() or (Path.home()/'.pixellab_key').read_text(encoding='utf-8-sig').strip()
for name in ['blink','talk_wide','talk']:
 job=json.load(open(out/('job.json' if name=='talk' else name+'_job.json')))['background_job_id'];req=urllib.request.Request('https://api.pixellab.ai/v2/background-jobs/'+job,headers={'Authorization':'Bearer '+key})
 data=json.load(urllib.request.urlopen(req,timeout=30));(out/(name+'_status.json')).write_text(json.dumps(data));print(name,data['status'])
 if data['status']=='completed':
  im=data['last_response']['image'];(out/(name+'_native.png')).write_bytes(base64.b64decode(im['base64'].split(',')[-1]))
