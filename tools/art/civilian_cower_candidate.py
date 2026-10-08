"""Staging civilian shelter pose; never overwrites the runtime character."""
from pathlib import Path
source=Path('tools/art/render_cast3d.py').read_text()
source=source.replace('SEATED = ("drive",','SEATED = ("cower", "drive",',1)
source=source.replace('CALM = ("idle",','CALM = ("cower", "idle",',1)
source=source.replace('seat = 1.0 if name in ("drive", "doze") else','seat = 1.0 if name in ("cower", "drive", "doze") else',1)
source=source.replace('sit_pose(arm, seat)','sit_pose(arm, seat)\n            if name == "cower":\n                for side in ("Left", "Right"):\n                    for suffix,angle in (("UpLeg",-80),("Leg",115)):\n                        pb=arm.pose.bones.get(side+suffix)\n                        if pb:\n                            orientation=(arm.matrix_world @ pb.bone.matrix_local).to_quaternion()\n                            axis=orientation.inverted() @ Vector((0,1,0))\n                            pb.rotation_quaternion=Quaternion(axis,math.radians(angle))',1)
source=source.replace('drop = -0.45*seat','drop = (-0.40 if name == "cower" else -0.45)*seat',1)
source=source.replace('            x, y = face_offset(x, y, theta)', '''            if name == "cower":
                head_bone=arm.pose.bones.get("Head")
                head_z=(arm.matrix_world @ head_bone.head).z if head_bone else hp.z+.45
                x,y,z=((arm.matrix_world @ head_bone.head).x-hp.x+.02) if head_bone else .1,(-.12 if right else .12),head_z-hp.z-.06
            x, y = face_offset(x, y, theta)''',1)
source=source.replace('        for target in [o for o in sc.objects if "grip_x" in o]:', '''        if name == "cower":
            for bone_name,degrees in (("Spine",12),("Spine01",12),("Spine02",10),("Head",12)):
                pb=arm.pose.bones.get(bone_name)
                if pb:
                    orientation=(arm.matrix_world @ pb.bone.matrix_local).to_quaternion()
                    axis=orientation.inverted() @ Vector((0,1,0))
                    pb.rotation_quaternion=Quaternion(axis,math.radians(degrees))
            bpy.context.view_layer.update()
            feet=[arm.matrix_world @ arm.pose.bones[n].head for n in ("LeftFoot","RightFoot") if n in arm.pose.bones]
            if feet and hips:
                correction=.07-min(p.z for p in feet)-.015*(1-seat)
                pose=hips.matrix.copy()
                pose.translation += arm.matrix_world.inverted().to_3x3() @ Vector((0,0,correction))
                hips.matrix=pose
                bpy.context.view_layer.update()
                hp=arm.matrix_world @ hips.head
        for target in [o for o in sc.objects if "grip_x" in o]:''',1)
# Authored one-way entry: hands protect first, then the hips settle.
source=source.replace('            sit_pose(arm, seat)', '''            if name == "cower":
                seat=combat_curve(k,[(0,0),(.12,.04),(.55,1),(1,1)])
            sit_pose(arm, seat)''',1)
source=source.replace('pb.rotation_quaternion=Quaternion(axis,math.radians(angle))','pb.rotation_quaternion=Quaternion(axis,math.radians(angle)*seat)',1)
source=source.replace('pb.rotation_quaternion=Quaternion(axis,math.radians(degrees))','pb.rotation_quaternion=Quaternion(axis,math.radians(degrees)*seat)',1)
source=source.replace('            x, y = face_offset(x, y, theta)', '''            if name == "cower":
                protection=combat_curve(k,[(0,0),(.12,.35),(.38,1),(1,1)])
                ready=Vector((.24,-.20 if right else .20,.02))
                shelter=Vector((x,y,z))
                waypoint=Vector((.28,-.18 if right else .18,.30))
                x,y,z=ready.lerp(waypoint,protection*2) if protection < .5 else waypoint.lerp(shelter,(protection-.5)*2)
            x, y = face_offset(x, y, theta)''',1)
source=source.replace('{"smoke": 4.0,','{"cower": 1.2, "smoke": 4.0,',1)
source=source.replace('if (i == 0 and d == 0) or (name == "held" and held_tucked)', 'if name == "cower" or (i == 0 and d == 0) or (name == "held" and held_tucked)',1)
source=source.replace('                    best = (float("inf"), 0)', '''                    if name == "cower":
                        goal=Vector((hp.x+.20,hp.y+(-.25 if side=="Right" else .25),hp.z+.04+.28*seat))
                    best = (float("inf"), 0)''',1)
source=source.replace('    anchor = None','    cower_poles = {}\n    anchor = None',1)
source=source.replace('                        distance = (elbow - goal).length_squared', '''                        distance = (elbow - goal).length_squared
                        if name == "cower" and side in cower_poles:
                            turn=(angle-cower_poles[side]+math.pi)%(2*math.pi)-math.pi
                            distance += .001*turn*turn''',1)
source=source.replace('                    ik.pole_angle = best[1]', '''                    if name == "cower" and side in cower_poles:
                        previous=cower_poles[side]
                        turn=(best[1]-previous+math.pi)%(2*math.pi)-math.pi
                        best=(best[0],previous+max(-math.radians(20),min(math.radians(20),turn)))
                    if name == "cower": cower_poles[side]=best[1]
                    ik.pole_angle = best[1]''',1)
source=source.replace('        if bake_out:\n            # the visual pose', '''        if name == "cower":
            for target in [o for o in sc.objects if "grip_x" in o]:
                side="Right" if target.name.startswith("Right") else "Left"
                hand=arm.pose.bones.get(side+"Hand")
                if hand:
                    actual=arm.matrix_world @ hand.head
                    print("COWER_WRIST",i,side,round((actual-target.location).length,5),tuple(actual),tuple(target.location))
        if bake_out:
            # the visual pose''',1)
source=source.replace('            bpy.context.view_layer.update()\n            feet=[', '''            for side,sign in (("Left",1),("Right",-1)):
                thigh=arm.pose.bones.get(side+"UpLeg")
                if thigh:
                    orientation=(arm.matrix_world @ thigh.bone.matrix_local).to_quaternion()
                    lateral=orientation.inverted() @ Vector((1,0,0))
                    thigh.rotation_quaternion = thigh.rotation_quaternion @ Quaternion(lateral,sign*math.radians(14)*seat)
            bpy.context.view_layer.update()
            feet=[''',1)
source=source.replace('        if name == "cower":\n            for target in [o for o in sc.objects if "grip_x" in o]:', '''        if name == "cower":
            for bone_name in ("Hips","LeftFoot","RightFoot"):
                pb=arm.pose.bones.get(bone_name)
                if pb:
                    at=arm.matrix_world @ pb.head
                    print("COWER_SUPPORT",i,bone_name,*[round(v,6) for v in at])
        if name == "cower":
            for target in [o for o in sc.objects if "grip_x" in o]:''',1)
source=source.replace('or (name == "doze" and seat_world):','or (name in ("doze","cower") and seat_world):',1)
source=source.replace('            if name == "doze" and seat_world:', '            if name in ("doze","cower") and seat_world:',1)
source=source.replace('        if name == "cower":\n            for bone_name in ("Hips","LeftFoot","RightFoot"):', '''        if name == "cower" and foot_support:
            for foot,target,ik,floor_z in foot_support:
                planted=close_feet[foot.name]
                target.location=(planted.x,planted.y,.07)
                ik.influence=1.0
                side=-1 if foot.name.startswith("Right") else 1
                ik.pole_target.location=(hp.x+.5,hp.y+.2*side,hp.z-.15)
                knee=arm.pose.bones["RightLeg" if side==-1 else "LeftLeg"]
                goal=Vector((hp.x+.28,hp.y+.14*side,hp.z-.18))
                ik.pole_angle=-math.pi*.5
                print("COWER_KNEE",i,side,round(ik.pole_angle,6))
            bpy.context.view_layer.update()
        if name == "cower":
            for bone_name in ("Hips","LeftFoot","RightFoot"):''',1)
source=source.replace('        if name == "cower":\n            for bone_name in ("Hips","LeftFoot","RightFoot"):', '''        if name == "cower" and foot_support:
            for foot,target,ik,floor_z in foot_support:
                pose=foot.matrix.copy()
                foot.matrix=Matrix.LocRotScale(pose.translation,foot.bone.matrix_local.to_quaternion(),pose.to_scale())
            bpy.context.view_layer.update()
        if name == "cower":
            for bone_name in ("Hips","LeftFoot","RightFoot"):''',1)
source=source.replace('def setup_scene(path):', '''def repair_cower_leg_rest(arm):
    bpy.context.view_layer.objects.active=arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for side in ("Left","Right"):
        for parent,child in (("UpLeg","Leg"),("Leg","Foot")):
            a=arm.data.edit_bones.get(side+parent)
            b=arm.data.edit_bones.get(side+child)
            if a and b: a.tail=b.head
    bpy.ops.object.mode_set(mode="OBJECT")

def setup_scene(path):''',1)
source=source.replace('        repair_arms(arm)\n    cam_data', '        repair_arms(arm)\n        repair_cower_leg_rest(arm)\n    cam_data',1)
source=source.replace('    repair_arms(arm)\n    if arm.animation_data', '    repair_arms(arm)\n    repair_cower_leg_rest(arm)\n    if arm.animation_data',1)
source=source.replace('                pose.translation += arm.matrix_world.inverted().to_3x3() @ Vector((0,0,drop))','                pose.translation += arm.matrix_world.inverted().to_3x3() @ Vector((-.18*seat if name=="cower" else 0,0,drop))',1)
exec(compile(source,'tools/art/render_cast3d.py','exec'))