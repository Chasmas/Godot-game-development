"""Stage a loop-safe copy of Uthana locomotion; never alters a source download.

This only aligns the last pose with the first over a short tail window.  It is
not a promotion step: contact, anatomy and the eventual upper-body merge still
need Godot review before a cast can use the result at runtime.
"""
import sys
from pathlib import Path

import numpy as np
from pygltflib import GLTF2

def array(model: GLTF2, index: int) -> np.ndarray:
    accessor = model.accessors[index]
    view = model.bufferViews[accessor.bufferView]
    types = {5126: "<f4", 5125: "<u4", 5123: "<u2", 5121: "u1"}
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[accessor.type]
    dtype = np.dtype(types[accessor.componentType])
    stride = view.byteStride or dtype.itemsize * width
    offset = (view.byteOffset or 0) + (accessor.byteOffset or 0)
    return np.ndarray((accessor.count, width), dtype=dtype, buffer=model.binary_blob(), offset=offset, strides=(stride, dtype.itemsize)).copy()


def write_values(model: GLTF2, accessor_index: int, values: np.ndarray) -> None:
    accessor = model.accessors[accessor_index]
    view = model.bufferViews[accessor.bufferView]
    blob = bytearray(model.binary_blob())
    stride = view.byteStride or values.shape[1] * 4
    offset = (view.byteOffset or 0) + (accessor.byteOffset or 0)
    for index, value in enumerate(values):
        begin = offset + index * stride
        blob[begin:begin + value.nbytes] = value.astype("<f4").tobytes()
    accessor.min = values.min(axis=0).tolist()
    accessor.max = values.max(axis=0).tolist()
    model.set_binary_blob(bytes(blob))


def condition(path: Path, destination: Path) -> None:
    model = GLTF2().load(str(path))
    animation = model.animations[0]
    for channel in animation.channels:
        sampler = animation.samplers[channel.sampler]
        if channel.target.path not in ("rotation", "translation"):
            continue
        values = array(model, sampler.output)
        times = array(model, sampler.input)[:, 0]
        duration = float(times[-1])
        window = min(0.12, duration * 0.10)
        weights = np.clip((times - (duration - window)) / window, 0.0, 1.0)
        weights = weights * weights * (3.0 - 2.0 * weights)
        first = values[0].copy()
        if channel.target.path == "rotation" and np.dot(first, values[-1]) < 0.0:
            first *= -1.0
        adjusted = values + weights[:, None] * (first - values[-1])
        if channel.target.path == "rotation":
            adjusted /= np.linalg.norm(adjusted, axis=1)[:, None]
        adjusted[-1] = first
        write_values(model, sampler.output, adjusted)
    destination.parent.mkdir(parents=True, exist_ok=True)
    model.save_binary(str(destination))


if len(sys.argv) != 2:
    raise SystemExit("Usage: condition_uthana_cast_loops.py <cast_id>")

cast = sys.argv[1]
root = Path("build/uthana/cast_roster/motions") / cast
for gait in ("walk", "run", "stealth"):
    source = root / f"{gait}.glb"
    if not source.exists():
        raise FileNotFoundError(source)
    condition(source, root / "conditioned" / f"{gait}.glb")
print(f"Conditioned staged Uthana loops for {cast}; runtime approval remains false.")
