import base64, json, os, sys, urllib.request
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / 'tools' / 'art' / 'pixellab_context_clutter_manifest.json'

def main():
    manifest_path = Path(sys.argv[1]) if len(sys.argv) > 1 else MANIFEST
    out = ROOT / 'assets' / 'art' / 'Artwork' / manifest_path.stem.replace('_manifest', '')
    token = os.environ.get('PIXELLAB_API_KEY', '').strip()
    if not token:
        token = Path.home().joinpath('.pixellab_key').read_text(encoding='utf-8-sig').strip()
    out.mkdir(parents=True, exist_ok=True)
    for asset in json.loads(manifest_path.read_text(encoding='utf-8'))['assets']:
        w, h = [int(v) for v in asset['size'].split('x')]
        body = json.dumps({
            'description': asset['prompt'],
            'image_size': {'width': w, 'height': h},
            'no_background': True,
        }).encode()
        req = urllib.request.Request(
            'https://api.pixellab.ai/v2/create-image-pixflux', data=body,
            headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=300) as resp:
            result = json.load(resp)
        raw = result['image']['base64'].split(',')[-1]
        path = out / (asset['name'] + '.png')
        path.write_bytes(base64.b64decode(raw))
        im = Image.open(path).convert('RGBA')
        im.save(path)
        print(f"{asset['name']}: {im.size}, alpha={im.getchannel('A').getextrema()}")

if __name__ == '__main__':
    main()
