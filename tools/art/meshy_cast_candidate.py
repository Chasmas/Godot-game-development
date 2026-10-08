"""Persisted, single-task Meshy cast pilot. No automatic paid retries."""
import argparse
import base64
import hashlib
import json
import re
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/cass'
CHARACTER = 'cass'
STATE = OUT / 'meshy_task.json'
API = 'https://api.meshy.ai/openapi'
ENDPOINT = '/v1/multi-image-to-3d'

def save(value):
    OUT.mkdir(parents=True, exist_ok=True)
    temporary = STATE.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(value, indent=2), encoding='utf-8')
    temporary.replace(STATE)

def read():
    return json.loads(STATE.read_text(encoding='utf-8')) if STATE.exists() else {}

def call(method, path, body=None):
    secret = (Path.home() / '.meshy_key').read_text(encoding='utf-8-sig').strip()
    request = urllib.request.Request(API + path, method=method,
        data=json.dumps(body).encode('utf-8') if body is not None else None,
        headers={'Authorization': 'Bearer ' + secret, 'Content-Type': 'application/json'})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)

def preflight():
    """Validate reviewed source and derived views without contacting the service."""
    audit = json.loads((OUT / 'references/reference_audit.json').read_text(encoding='utf-8'))
    if audit.get('character') != CHARACTER:
        raise RuntimeError('Reference audit belongs to another character')
    if not audit.get('approved_for_api'):
        raise RuntimeError('Reference views must be visually checked before upload')
    source = ROOT / audit['source']
    if hashlib.sha256(source.read_bytes()).hexdigest() != audit.get('source_sha256'):
        raise RuntimeError('Original reference changed since visual review')
    files = [OUT / 'references' / (name + '.png') for name in ('front', 'side', 'back')]
    audited = {view['name']: view['sha256'] for view in audit['views']}
    hashes = {file.stem: hashlib.sha256(file.read_bytes()).hexdigest() for file in files}
    if hashes != audited:
        raise RuntimeError('Reference files changed since their visual review')
    return files, hashes


def create():
    state = read()
    if state.get('task_id'):
        print(json.dumps({'task_id': state['task_id'], 'action': 'reuse_existing_task'}))
        return
    if state.get('submission_started'):
        raise RuntimeError('Earlier submission outcome is unknown; reconcile service state before another paid request')
    files, hashes = preflight()
    params = {'ai_model': 'meshy-7.1', 'geometry_resolution': '2k', 'should_texture': True,
              'enable_pbr': True, 'texture_resolution': '4k', 'pose_mode': 'a-pose',
              'image_enhancement': False, 'remove_lighting': True, 'should_remesh': True,
              'topology': 'quad', 'target_polycount': 60000, 'save_pre_remeshed_model': True,
              'target_formats': ['glb'], 'multi_view_thumbnails': True}
    config = json.loads((ROOT / 'tools/art/cast_reference_crops.json').read_text(encoding='utf-8'))[CHARACTER]
    if CHARACTER == 'cass_head_detail' or config.get('anatomy_type') == 'quadruped':
        # Busts and quadrupeds must preserve their source pose, not a human A-pose.
        params.pop('pose_mode')
    state = {'character': CHARACTER, 'submission_started': True, 'endpoint': ENDPOINT,
             'source_hashes': hashes, 'parameters': params, 'runtime_approved': False}
    save(state)
    body = dict(params)
    body['image_urls'] = ['data:image/png;base64,' + base64.b64encode(file.read_bytes()).decode('ascii') for file in files]
    result = call('POST', ENDPOINT, body)
    state['task_id'] = result['result']
    state['submission_outcome'] = 'task_id_received'
    save(state)
    print(json.dumps({'task_id': state['task_id'], 'status': 'submitted', 'runtime_approved': False}))

def status():
    state = read()
    if not state.get('task_id'):
        raise RuntimeError('No known task ID to poll')
    task = call('GET', ENDPOINT + '/' + state['task_id'])
    state['last_task_response'] = task
    save(state)
    print(json.dumps({key: task.get(key) for key in ('id', 'status', 'progress', 'consumed_credits', 'task_error')}))
    return task

def download():
    task = status()
    if task.get('status') != 'SUCCEEDED':
        raise RuntimeError('Task is not successful; preserve it and poll later')
    raw = OUT / 'raw'
    raw.mkdir(exist_ok=True)
    outputs = []
    urls = {'model.glb': task['model_urls']['glb']}
    if task['model_urls'].get('pre_remeshed_glb'):
        urls['pre_remeshed.glb'] = task['model_urls']['pre_remeshed_glb']
    for index, maps in enumerate(task.get('texture_urls', [])):
        for name, url in maps.items():
            if url:
                urls['texture_%d_%s.png' % (index, name)] = url
    for filename, url in urls.items():
        file = raw / filename
        if not file.exists():
            with urllib.request.urlopen(url, timeout=60) as response:
                content = response.read()
            if filename.endswith('.glb') and content[:4] != b'glTF':
                raise RuntimeError('Downloaded file is not a binary glTF: ' + filename)
            temporary = file.with_suffix(file.suffix + '.tmp')
            temporary.write_bytes(content)
            temporary.replace(file)
        outputs.append({'file': str(file.relative_to(ROOT)), 'bytes': file.stat().st_size,
                        'sha256': hashlib.sha256(file.read_bytes()).hexdigest()})
    (OUT / 'download_audit.json').write_text(json.dumps({'task_id': task['id'], 'outputs': outputs,
                                                       'runtime_approved': False}, indent=2), encoding='utf-8')
    print(json.dumps({'downloaded_files': len(outputs), 'folder': str(raw), 'runtime_approved': False}))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=('create', 'status', 'download', 'preflight'))
    parser.add_argument('--character', default='cass')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z][a-z0-9_]*', args.character):
        parser.error('Character must be a simple asset identifier')
    CHARACTER = args.character
    OUT = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1' / CHARACTER
    STATE = OUT / 'meshy_task.json'
    command = args.command
    if command == 'preflight':
        _, hashes = preflight()
        print(json.dumps({'character': CHARACTER, 'validated_views': len(hashes),
                          'service_contacted': False, 'runtime_approved': False}))
    else:
        {'create': create, 'status': status, 'download': download}[command]()
