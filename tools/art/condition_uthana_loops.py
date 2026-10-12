"""Close study loop seams with a short tail blend; preserve source downloads."""
import json
from pathlib import Path
import numpy as np
from pygltflib import GLTF2
from audit_uthana_cass import array

root = Path('build/uthana/cass')
destination = root / 'conditioned'
destination.mkdir(exist_ok=True)
reports = []
for name in ('walk', 'run', 'pistol_walk'):
    model = GLTF2().load(str(root / (name + '.glb')))
    blob = bytearray(model.binary_blob())
    channels = []
    for channel in model.animations[0].channels:
        sampler = model.animations[0].samplers[channel.sampler]
        values = array(model, sampler.output)
        times = array(model, sampler.input)[:, 0]
        if channel.target.path not in ('rotation', 'translation'):
            continue
        original = values.copy()
        window = min(.12, float(times[-1]) * .1)
        weights = np.clip((times - (times[-1] - window)) / window, 0, 1)
        weights = weights * weights * (3 - 2 * weights)
        endpoint = values[0].copy()
        if channel.target.path == 'rotation' and np.dot(endpoint, values[-1]) < 0:
            endpoint *= -1
        values += weights[:, None] * (endpoint - values[-1])
        if channel.target.path == 'rotation':
            values /= np.linalg.norm(values, axis=1)[:, None]
        values[-1] = endpoint
        accessor = model.accessors[sampler.output]
        view = model.bufferViews[accessor.bufferView]
        stride = view.byteStride or values.shape[1] * 4
        offset = (view.byteOffset or 0) + (accessor.byteOffset or 0)
        for index, value in enumerate(values):
            begin = offset + index * stride
            blob[begin:begin + value.nbytes] = value.tobytes()
        accessor.min = values.min(axis=0).tolist()
        accessor.max = values.max(axis=0).tolist()
        channels.append({'bone': model.nodes[channel.target.node].name,
                         'path': channel.target.path,
                         'maximum_component_adjustment': float(np.max(np.abs(values - original))),
                         'endpoint_difference': float(np.max(np.abs(values[-1] - endpoint)))})
    model.set_binary_blob(bytes(blob))
    model.save_binary(str(destination / (name + '.glb')))
    reports.append({'clip': name, 'tail_blend_seconds': window,
                    'channels': channels, 'runtime_approved': False,
                    'remaining_review': 'Foot contacts and temporal visual review; endpoint equality alone is insufficient.'})
(destination / 'loop_conditioning_review.json').write_text(json.dumps(reports, indent=2))
print('Prepared three staged loops; runtime approval remains pending.')
