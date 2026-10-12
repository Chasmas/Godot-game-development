"""Inventory every runtime cast rig before requesting shared Uthana motion sets."""
import hashlib
import json
from pathlib import Path

import struct
import numpy as np

root = Path("assets/art/cast3d_rt")

def rest_signature(document: dict, binary: bytes) -> str:
    skin = document["skins"][0]
    accessor = document["accessors"][skin["inverseBindMatrices"]]
    view = document["bufferViews"][accessor["bufferView"]]
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    bind = np.frombuffer(binary, dtype="<f4", count=accessor["count"] * 16, offset=offset).copy()
    pose = []
    for index in skin["joints"]:
        node = document["nodes"][index]
        pose.append([node.get("translation", [0, 0, 0]), node.get("rotation", [0, 0, 0, 1]), node.get("scale", [1, 1, 1])])
    return hashlib.sha256(bind.tobytes() + json.dumps(pose, separators=(",", ":")).encode()).hexdigest()[:16]

records = []
for path in sorted(root.glob("*/*.glb")):
    # Read only the GLB JSON chunk; loading each mesh buffer is unnecessary
    # for a rig inventory and makes this audit needlessly slow.
    with path.open("rb") as stream:
        header = stream.read(20)
        _, _, _, json_length, json_type = struct.unpack("<4sIIII", header)
        assert json_type == 0x4E4F534A
        glb = json.loads(stream.read(json_length).decode("utf-8").rstrip(" \t\r\n\x00"))
        binary_length, binary_type = struct.unpack("<II", stream.read(8))
        assert binary_type == 0x004E4942
        binary = stream.read(binary_length)
    if not glb.get("skins"):
        records.append({"id": path.stem, "path": str(path), "rig": None, "animations": []})
        continue
    joints = [glb["nodes"][index].get("name", str(index)) for index in glb["skins"][0]["joints"]]
    records.append({
        "id": path.stem,
        "path": str(path),
        "rig": hashlib.sha256("\n".join(joints).encode()).hexdigest()[:16],
        "joint_count": len(joints),
        "rest_signature": rest_signature(glb, binary),
        "animations": [animation.get("name", "unnamed") for animation in glb.get("animations", [])],
    })
groups = {}
rest_groups = {}
for record in records:
    if record["rig"]:
        groups.setdefault(record["rig"], []).append(record["id"])
        rest_groups.setdefault(record["rest_signature"], []).append(record["id"])
output = {
    "runtime_casts": records,
    "rig_groups": groups,
    "rest_pose_groups": rest_groups,
    "policy": {
        "source_geometry": "never overwritten by generated motion studies",
        "required_motion_sets": {
            "humanoid_unarmed": ["idle", "walk", "run", "stealth", "turn", "dodge", "death"],
            "humanoid_armed": ["aim_idle", "aim_walk", "aim_run", "aim_stealth", "reload", "death_armed"],
            "quadruped": ["idle", "walk", "trot", "run", "attack", "death"],
        },
    },
}
target = Path("build/uthana/cast_animation_inventory.json")
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(json.dumps(output, indent=2), encoding="utf-8")
print(json.dumps({"casts": len(records), "rig_groups": groups}, indent=2))
