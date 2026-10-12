"""Non-promotion audit for a Uthana locomotion study on a preserved source rig."""
import json
import math
import sys
from pathlib import Path

import numpy as np
from pygltflib import GLTF2

def array(gltf: GLTF2, index: int) -> np.ndarray:
    accessor = gltf.accessors[index]
    view = gltf.bufferViews[accessor.bufferView]
    types = {5126: "<f4", 5125: "<u4", 5123: "<u2", 5121: "u1"}
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[accessor.type]
    dtype = np.dtype(types[accessor.componentType])
    stride = view.byteStride or dtype.itemsize * width
    offset = (view.byteOffset or 0) + (accessor.byteOffset or 0)
    return np.ndarray((accessor.count, width), dtype=dtype, buffer=gltf.binary_blob(), offset=offset, strides=(stride, dtype.itemsize)).copy()

if len(sys.argv) < 2:
    raise SystemExit("Usage: audit_uthana_locomotion_study.py <cast_id> [conditioned]")
cast_id = sys.argv[1]
source = GLTF2().load("assets/art/cast3d_rt/%s/%s.glb" % (cast_id, cast_id))
root = Path("build/uthana/cast_roster/motions") / cast_id
if len(sys.argv) > 2 and sys.argv[2] == "conditioned":
    root = root / "conditioned"
records = []
for path in sorted(root.glob("*.glb")):
    candidate = GLTF2().load(str(path))
    animation = candidate.animations[0]
    names_source = [source.nodes[i].name for i in source.skins[0].joints]
    names_candidate = [candidate.nodes[i].name for i in candidate.skins[0].joints]
    position_source = array(source, source.meshes[0].primitives[0].attributes.POSITION)
    position_candidate = array(candidate, candidate.meshes[0].primitives[0].attributes.POSITION)
    max_rotation = 0.0
    max_translation = 0.0
    duration = 0.0
    for channel in animation.channels:
        sampler = animation.samplers[channel.sampler]
        values = array(candidate, sampler.output)
        times = array(candidate, sampler.input)
        duration = max(duration, float(times[-1, 0]))
        if channel.target.path == "rotation":
            dot = min(1.0, abs(float(np.dot(values[0], values[-1]))))
            max_rotation = max(max_rotation, math.degrees(2.0 * math.acos(dot)))
        elif channel.target.path == "translation":
            max_translation = max(max_translation, float(np.linalg.norm(values[0] - values[-1])))
    records.append({
        "clip": path.stem,
        "duration_seconds": duration,
        "same_joint_names_and_order": names_source == names_candidate,
        "max_mesh_vertex_delta": float(np.max(np.abs(position_source - position_candidate))),
        "max_loop_rotation_degrees": max_rotation,
        "max_loop_translation_native_units": max_translation,
        "runtime_approved": False,
    })
(root / "integrity_loop_audit.json").write_text(json.dumps(records, indent=2), encoding="utf-8")
print(json.dumps(records, indent=2))
