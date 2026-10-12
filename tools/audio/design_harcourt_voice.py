"""Generate private Southern-American Harcourt voice auditions, preserving runtime."""
import base64
import json
import urllib.request
from pathlib import Path
from eleven_dialogue import api_key

root = Path('build/voice_casting/harcourt_southern_v1')
root.mkdir(parents=True, exist_ok=True)
manifest = root / 'design.json'
if manifest.exists():
    raise SystemExit('Existing voice design submission; inspect before regenerating.')
body = {
    'voice_description': ('An American man in his late fifties with a convincing rural Southern '
                          'US country accent, a low gravelly baritone and weathered tobacco roughness. '
                          'Measured confident delivery, grounded and intimidating, restrained menace '
                          'and the authority of a corrupt motel boss. Natural Southern vowels and '
                          'subtle drawl, clear intelligible English. No caricature, no announcer '
                          'brightness, no friendly narrator tone. Studio-quality dry dialogue.'),
    'text': ("Well. You're definitely not housekeeping. I know that star. Aurelio sent you, "
             "didn't he? Tell him the tapes stay here. That was the arrangement. "
             "No. Of course you don't. That's the cruel part. SECURITY. FRONT DESK. Now."),
    'model_id': 'eleven_multilingual_ttv_v2',
    'guidance_scale': 5,
    'seed': 1987
}
manifest.write_text(json.dumps({'state':'submitted','request':body}, indent=2))
request = urllib.request.Request('https://api.elevenlabs.io/v1/text-to-voice/design',
    data=json.dumps(body).encode(), headers={'xi-api-key':api_key(),'Content-Type':'application/json'})
try:
    result = json.load(urllib.request.urlopen(request, timeout=180))
except Exception as error:
    manifest.write_text(json.dumps({'state':'request_error','request':body,'error_type':type(error).__name__},indent=2))
    raise SystemExit('Voice design failed: ' + type(error).__name__)
for index, preview in enumerate(result['previews']):
    (root / ('audition_%d.mp3' % (index+1))).write_bytes(base64.b64decode(preview.pop('audio_base_64')))
manifest.write_text(json.dumps({'state':'generated','request':body,'result':result,'runtime_approved':False},indent=2))
print('Harcourt auditions saved; runtime voice unchanged.',flush=True)
