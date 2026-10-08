"""Region-aware skin-weight pilot; must pass deformation review before use."""
import bpy
import json
import heapq
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman'
OUT = BASE / 'skin_candidate_v6'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE / 'rig_candidate_v2/dog_doberman_skeleton_candidate.blend'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
segments = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in rig.data.bones if b.use_deform}
def distance(point, name):
    a, b = segments[name]
    delta = b-a
    t = max(0., min(1., (point-a).dot(delta)/delta.length_squared))
    return (point-(a+delta*t)).length
def weights(point, names):
    scores = sorted([(name, 1/(distance(point, name)+.012)**3) for name in names],
                    key=lambda row: row[1], reverse=True)[:3]
    total = sum(score for _, score in scores)
    return {name: score/total for name, score in scores}
reports = []
for obj in [o for o in bpy.context.scene.objects if o.type == 'MESH']:
    # UV seams duplicate vertices in GLB. Build adjacency by coincident
    # positions so the tail seed follows the whole surface across those seams.
    keys = {v.index: tuple(round(float(c), 6) for c in v.co) for v in obj.data.vertices}
    positions = {keys[v.index]: v.co.copy() for v in obj.data.vertices}
    adjacency = {key: set() for key in positions}
    for edge in obj.data.edges:
        a, b = (keys[i] for i in edge.vertices)
        adjacency[a].add(b); adjacency[b].add(a)
    def geodesic(seeds):
        distances = {key:float('inf') for key in positions}
        queue = []
        for key in seeds:
            distances[key] = 0.; heapq.heappush(queue,(0.,key))
        while queue:
            cost,key = heapq.heappop(queue)
            if cost != distances[key]:
                continue
            for neighbor in adjacency[key]:
                trial = cost+(positions[key]-positions[neighbor]).length
                if trial < distances[neighbor]:
                    distances[neighbor]=trial; heapq.heappush(queue,(trial,neighbor))
        return distances
    tail_seeds = {key for key,p in positions.items() if p.y > .47 and abs(p.x) < .065 and p.z > .20}
    body_seeds = {key for key,p in positions.items() if p.y < .30 or abs(p.x) > .085 or p.z < .13}
    if not tail_seeds or not body_seeds:
        raise RuntimeError('Missing geodesic partition seeds')
    tail_distance = geodesic(tail_seeds)
    body_distance = geodesic(body_seeds)
    tail_blends = {}
    for key,p in positions.items():
        if p.y <= .30 or not math.isfinite(tail_distance[key]) or not math.isfinite(body_distance[key]):
            tail_blends[key]=0.; continue
        blend=max(0.,min(1.,.5+(body_distance[key]-tail_distance[key])/.08))
        tail_blends[key]=blend*blend*(3-2*blend)
    root_keys = {key for key,p in positions.items() if .30 < p.y < .47 and p.z > .20
                 and abs(p.x) < .08 and key not in body_seeds}
    for _ in range(24):
        next_blends = dict(tail_blends)
        for key in root_keys:
            neighbors = adjacency[key]
            if neighbors:
                mean = sum(tail_blends[n] for n in neighbors)/len(neighbors)
                next_blends[key] = .5*tail_blends[key]+.5*mean
        tail_blends = next_blends
    tail_keys = {key for key,blend in tail_blends.items() if blend > .0001}
    obj.vertex_groups.clear()
    groups = {n: obj.vertex_groups.new(name=n) for n in segments}
    counts = {}
    for vertex in obj.data.vertices:
        p = vertex.co
        side = 'negative_x' if p.x < 0 else 'positive_x'
        pair = 'front' if p.y < 0 else 'rear'
        torso = weights(p, ['pelvis', 'spine', 'chest'])
        if keys[vertex.index] in tail_keys:
            tail = weights(p, ['tail_1', 'tail_2', 'tail_3'])
            blend = tail_blends[keys[vertex.index]]
            # Blend against local limb/torso influence instead of a rigid
            # pelvis assignment at every tail boundary.
            prefix = pair + '_' + side
            local = weights(p,[prefix+'_upper',prefix+'_lower',prefix+'_paw','pelvis'])
            result={n:w*(1-blend) for n,w in local.items()}
            for n,w in tail.items():
                result[n]=result.get(n,0.)+w*blend
            region = 'tail'
        elif p.y < -.29 and p.z > .56:
            result = weights(p, ['neck', 'head'])
            region = 'head_neck'
            # Closed muzzle remains head-weighted until jaw topology is authored.
        elif abs(p.x) > .025 and abs(p.y) > .13 and p.z < .54:
            prefix = pair + '_' + side
            leg = weights(p, [prefix+'_upper', prefix+'_lower', prefix+'_paw'])
            blend = max(0., min(1., (.54-p.z)/.14))
            result = {n:w*(1-blend) for n,w in torso.items()}
            for n,w in leg.items():
                result[n] = result.get(n, 0.) + w*blend
            region = prefix
        else:
            # Head influence must not reach unrelated chest/shoulder vertices.
            result = weights(p, ['pelvis', 'spine', 'chest'])
            neck_blend = max(0., min(1., (p.z-.50)/.12)) * max(0., min(1., (-p.y-.15)/.14))
            if neck_blend:
                result = {n:w*(1-neck_blend) for n,w in result.items()}
                result['neck'] = neck_blend
            region = 'torso'
        counts[region] = counts.get(region, 0) + 1
        for name, weight in result.items():
            if weight > .00001:
                groups[name].add([vertex.index], weight, 'REPLACE')
    obj.parent = rig
    modifier = obj.modifiers.new('Quadruped region weights candidate', 'ARMATURE')
    modifier.object = rig
    modifier.use_deform_preserve_volume = True
    sums = [sum(g.weight for g in v.groups) for v in obj.data.vertices]
    reports.append({'mesh':obj.name, 'region_vertices':counts,
        'tail_connected_positions':len(tail_keys),
        'tail_root_diffusion_iterations':24,
        'unweighted_vertices':sum(w < .001 for w in sums),
        'minimum_weight_sum':min(sums), 'maximum_weight_sum':max(sums)})
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'dog_doberman_skin_candidate.blend'))
report = {'runtime_approved':False, 'rig_approved':False, 'meshes':reports,
    'scope':'Authored spatial region skin-weight pilot; no motion or deformation approval',
    'jaw_animation_ready':False,
    'limitations':['Closed muzzle requires authored jaw topology before mouth animation',
                   'Shoulder/hip transitions and torso regions require pose-probe visual checks'],
    'next':'Render independent limb bends, head turns and tail bends; inspect cross-limb displacement'}
(OUT / 'skin_audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report), flush=True)
