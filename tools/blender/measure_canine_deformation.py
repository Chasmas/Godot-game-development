"""Measure the actual skinned surface, separately from IK target metadata."""
import bpy
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
out = ROOT / "build/canine_review/shepherd"
clip = "idle" if "--idle" in sys.argv else ("walk" if "--walk" in sys.argv else "trot")
contact = json.loads((out / (clip + "_contact_audit.json")).read_text(encoding="utf-8"))
stance = contact.get("stance_fraction", 0.6)
def phase_offset(name):
    fallback = 0 if name.startswith("Front") == name.endswith(".L") else 0.5
    return contact.get("paw_phase_offsets", {}).get(name.replace("Paw", "Contact"), fallback)
bpy.ops.wm.open_mainfile(filepath=str(out / (clip + "_candidate.blend")))
mesh = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.name != "WeightProxy")
arm = bpy.data.objects["CanineRig"]
torso = [vertex.index for vertex in mesh.data.vertices
         if (mesh.matrix_world @ vertex.co).z > 0.22
         and -0.38 < (mesh.matrix_world @ vertex.co).y < 0.55]
samples = []
paw_vertices = {}
sole_vertices = {}
for group in mesh.vertex_groups:
    if "Paw." in group.name:
        paw_vertices[group.name] = [vertex.index for vertex in mesh.data.vertices
            if any(weight.group == group.index and weight.weight > 0.35 for weight in vertex.groups)]
        sole_vertices[group.name] = [index for index in paw_vertices[group.name]
            if (mesh.matrix_world @ mesh.data.vertices[index].co).z < -0.62]
for frame in range(1, 26):
    bpy.context.scene.frame_set(frame)
    graph = bpy.context.evaluated_depsgraph_get()
    evaluated = mesh.evaluated_get(graph)
    surface = evaluated.to_mesh()
    torso_displacement = max(((evaluated.matrix_world @ surface.vertices[index].co) -
                              (mesh.matrix_world @ mesh.data.vertices[index].co)).length
                             for index in torso)
    errors = {}
    for limb in ["Front", "Hind"]:
        for side in ["L", "R"]:
            name = limb + "Contact." + side
            target = bpy.data.objects[name]
            endpoint = arm.matrix_world @ arm.pose.bones[limb + "Lower." + side].tail
            errors[name] = (endpoint - target.location).length
    soles = {}
    sole_centers_y = {}
    for name, indices in paw_vertices.items():
        if indices:
            soles[name] = min((evaluated.matrix_world @ surface.vertices[index].co).z for index in indices)
        if sole_vertices[name]:
            sole_centers_y[name] = sum((evaluated.matrix_world @ surface.vertices[index].co).y
                                      for index in sole_vertices[name]) / len(sole_vertices[name])
    samples.append({"frame": frame, "paw_surface_minimum_z_m": soles,
                    "sole_center_y_m": sole_centers_y,
                    "maximum_torso_displacement_m": torso_displacement,
                    "ankle_target_errors_m": errors})
    evaluated.to_mesh_clear()
report = {"candidate_only": True, "runtime_approved": False,
          "maximum_torso_displacement_m": max(row["maximum_torso_displacement_m"] for row in samples),
          "maximum_ankle_target_error_m": max(max(row["ankle_target_errors_m"].values()) for row in samples),
          "samples": samples,
          "limitation": "Ankle endpoint error does not prove paw sole contact; visual deformation review is still required."}
stance_variation = {}
for name in paw_vertices:
    diagonal = phase_offset(name)
    heights = [row["paw_surface_minimum_z_m"][name] for row in samples
               if name in row["paw_surface_minimum_z_m"]
               and (((row["frame"] - 1) / 24 + diagonal) % 1) < stance]
    if heights:
        stance_variation[name] = max(heights) - min(heights)
report["stance_sole_height_variation_m"] = stance_variation
duration = contact["duration_seconds"]
speed = contact["native_forward_speed_mps"]
slip = {}
for name in sole_vertices:
    diagonal = phase_offset(name)
    segments, active = [], []
    previous_phase = -1
    for row in samples:
        phase = (((row["frame"] - 1) / 24 + diagonal) % 1)
        if phase < previous_phase or phase >= stance:
            if active:
                segments.append(active)
                active = []
        if phase < stance and name in row["sole_center_y_m"]:
            seconds = (row["frame"] - 1) / 24 * duration
            active.append(row["sole_center_y_m"][name] - seconds * speed)
        previous_phase = phase
    if active:
        segments.append(active)
    slip[name] = max((max(segment) - min(segment) for segment in segments), default=0)
report["stance_world_slip_m"] = slip
report["native_forward_speed_mps"] = speed
report["limitation"] = "Measurements cover this candidate at native stride speed; gameplay scale, turning, acceleration and other gaits still require review."
(out / (clip + "_deformation_audit.json" if clip != "trot" else "deformation_audit.json")).write_text(json.dumps(report, indent=2), encoding="utf-8")
print({key: value for key, value in report.items() if key != "samples"})
