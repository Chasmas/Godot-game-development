extends Node2D
class GripAttachment extends Node:
	var cast: CastModel
	var visual: CharacterVisual
	var weapon: Node3D
	var reported := false
	var ticks := 0
	var handle_probe := {}
	func rotate_bone_to(bone: int, direction: Vector3, wanted: Vector3) -> void:
		var skeleton := cast._skeleton
		var global_pose := skeleton.get_bone_global_pose(bone)
		var delta := Basis(Quaternion(direction.normalized(), wanted.normalized()))
		var parent := skeleton.get_bone_parent(bone)
		var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		var local := parent_basis.inverse() * delta * global_pose.basis
		skeleton.set_bone_pose_rotation(bone, local.orthonormalized().get_rotation_quaternion())
	func fit_hand(side: String, target_world: Vector3) -> void:
		var skeleton := cast._skeleton
		var upper := skeleton.find_bone(side + "Arm")
		var lower := skeleton.find_bone(side + "ForeArm")
		var hand := skeleton.find_bone(side + "Hand")
		if mini(upper, mini(lower, hand)) < 0: return
		var root := skeleton.get_bone_global_pose(upper).origin
		var elbow := skeleton.get_bone_global_pose(lower).origin
		var wrist := skeleton.get_bone_global_pose(hand).origin
		var target := skeleton.to_local(target_world)
		var length1 := root.distance_to(elbow)
		var length2 := elbow.distance_to(wrist)
		var distance := root.distance_to(target)
		if minf(length1, minf(length2, distance)) < 0.001: return
		var axis := (target-root).normalized()
		distance = clampf(distance, absf(length1-length2)+0.001, length1+length2-0.001)
		var along := (length1*length1-length2*length2+distance*distance)/(2*distance)
		var height := sqrt(maxf(0.0,length1*length1-along*along))
		# Keep elbows below and slightly outside the shoulders through animation blends.
		var outward := Vector3.RIGHT if side == "Right" else Vector3.LEFT
		var pole_world := cast._model.global_transform.basis.orthonormalized() * (Vector3.DOWN + outward * .35)
		var pole := skeleton.global_transform.basis.inverse() * pole_world
		var bend := pole-axis*pole.dot(axis)
		if bend.length_squared() < .000001: bend = axis.cross(Vector3.UP)
		var wanted_elbow := root+axis*along+bend.normalized()*height
		rotate_bone_to(upper, elbow-root, wanted_elbow-root)
		elbow = skeleton.get_bone_global_pose(lower).origin
		wrist = skeleton.get_bone_global_pose(hand).origin
		rotate_bone_to(lower,wrist-elbow,target-elbow)
	func orient_hand(side: String) -> void:
		var skeleton := cast._skeleton
		var hand := skeleton.find_bone(side+"Hand")
		var parent := skeleton.get_bone_parent(hand)
		# Hand longitudinal axis follows the tool; palm faces down onto handle.
		var finger_world := (weapon.global_transform.basis.x if side=="Left" else weapon.global_transform.basis.z).normalized()
		var palm_world := -weapon.global_transform.basis.y.normalized()
		var finger := (skeleton.global_transform.basis.inverse()*finger_world).normalized()
		var palm := (skeleton.global_transform.basis.inverse()*palm_world).normalized()
		var across := finger.cross(palm).normalized()
		var desired := Basis(across,finger,across.cross(finger)).orthonormalized()
		var local := skeleton.get_bone_global_pose(parent).basis.inverse()*desired
		skeleton.set_bone_pose_rotation(hand,local.orthonormalized().get_rotation_quaternion())
	func triangle_distance(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
		var normal := (b-a).cross(c-a).normalized()
		var projected := point-normal*(point-a).dot(normal)
		if (b-a).cross(projected-a).dot(normal)>=0 and (c-b).cross(projected-b).dot(normal)>=0 and (a-c).cross(projected-c).dot(normal)>=0:
			return point.distance_to(projected)
		return minf(point.distance_to(Geometry3D.get_closest_point_to_segment(point,a,b)),minf(point.distance_to(Geometry3D.get_closest_point_to_segment(point,b,c)),point.distance_to(Geometry3D.get_closest_point_to_segment(point,c,a))))
	func triangle_probe(point: Vector3, triangles: PackedVector3Array) -> Vector2:
		var hits: Array[float]=[]
		var nearest := INF
		var direction := Vector3(1,.271,.139).normalized()
		for i in range(0,triangles.size(),3):
			var a:=triangles[i]
			var b:=triangles[i+1]
			var c:=triangles[i+2]
			nearest=minf(nearest,triangle_distance(point,a,b,c))
			var hit=Geometry3D.ray_intersects_triangle(point,direction,a,b,c)
			if hit!=null:
				var distance:float=point.distance_to(hit)
				var duplicate:=false
				for previous in hits:
					if absf(distance-previous)<.000001:duplicate=true
				if not duplicate:hits.append(distance)
		return Vector2(hits.size()%2,nearest)
	func nearest_hand_vertex(side: String, anchor: Vector3) -> float:
		var skeleton := cast._skeleton
		var bone := skeleton.find_bone(side+"Hand")
		var rest_inverse := skeleton.get_bone_global_rest(bone).affine_inverse()
		var pose := skeleton.get_bone_global_pose(bone)
		var target := weapon.to_global(anchor)
		var nearest := INF
		var inside := 0
		var deepest := 0.0
		var crossing_edges := 0
		var reverse_crossings := 0
		var exact_inside := 0
		var exact_deepest := 0.0
		var handle: MeshInstance3D
		for candidate in weapon.find_children("*","MeshInstance3D",true,false):
			if (side=="Left" and String(candidate.name).begins_with("Front handle crossbar")) or (side=="Right" and String(candidate.name).begins_with("Rear handle top")): handle=candidate
		var bounds := handle.get_aabb() if handle else AABB()
		var triangles := handle.mesh.get_faces() if handle else PackedVector3Array()
		for mesh in cast._model.find_children("*","MeshInstance3D",true,false):
			if mesh.skin == null: continue
			var bind := -1
			for i in mesh.skin.get_bind_count():
				if mesh.skin.get_bind_bone(i)==bone or mesh.skin.get_bind_name(i)==skeleton.get_bone_name(bone): bind=i
			if bind<0: continue
			for surface in mesh.mesh.get_surface_count():
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				if arrays[Mesh.ARRAY_BONES] == null: continue
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				if bones.is_empty(): continue
				var influences := bones.size()/vertices.size()
				var posed := {}
				for i in vertices.size():
					var selected := false
					for j in influences:
						if bones[i*influences+j]==bind and weights[i*influences+j]>.99: selected=true
					if not selected: continue
					var point := skeleton.to_global(pose*mesh.skin.get_bind_pose(bind)*vertices[i])
					posed[i]=point
					nearest=minf(nearest,point.distance_to(target))
					if handle:
						var local := handle.to_local(point)
						if bounds.has_point(local):
							inside+=1
							var probe := triangle_probe(local,triangles)
							if probe.x>0:
								exact_inside+=1
								exact_deepest=maxf(exact_deepest,probe.y*handle.global_transform.basis.get_scale().x)
							var edge := bounds.end
							var depth := minf(minf(local.x-bounds.position.x,edge.x-local.x),minf(minf(local.y-bounds.position.y,edge.y-local.y),minf(local.z-bounds.position.z,edge.z-local.z)))
							deepest=maxf(deepest,depth*handle.global_transform.basis.get_scale().x)
				if handle:
					var indices=arrays[Mesh.ARRAY_INDEX]
					if indices==null or indices.is_empty(): indices=range(vertices.size())
					var checked := {}
					for triangle in range(0,indices.size(),3):
						var ids := [indices[triangle],indices[triangle+1],indices[triangle+2]]
						if not (posed.has(ids[0]) and posed.has(ids[1]) and posed.has(ids[2])): continue
						var skin_a:=handle.to_local(posed[ids[0]])
						var skin_b:=handle.to_local(posed[ids[1]])
						var skin_c:=handle.to_local(posed[ids[2]])
						for handle_face in range(0,triangles.size(),3):
							for handle_edge in 3:
								var start:=triangles[handle_face+handle_edge]
								var end:=triangles[handle_face+(handle_edge+1)%3]
								var hit=Geometry3D.segment_intersects_triangle(start,end,skin_a,skin_b,skin_c)
								if hit!=null and start.distance_to(hit)>.000001 and end.distance_to(hit)>.000001: reverse_crossings+=1
						for edge in 3:
							var a_id:int=ids[edge]
							var b_id:int=ids[(edge+1)%3]
							var key:=Vector2i(mini(a_id,b_id),maxi(a_id,b_id))
							if checked.has(key): continue
							checked[key]=true
							var a:=handle.to_local(posed[a_id])
							var b:=handle.to_local(posed[b_id])
							for face in range(0,triangles.size(),3):
								var hit=Geometry3D.segment_intersects_triangle(a,b,triangles[face],triangles[face+1],triangles[face+2])
								if hit!=null and a.distance_to(hit)>.000001 and b.distance_to(hit)>.000001:
									crossing_edges+=1
									break
		handle_probe[side]={"mesh_found":handle!=null,"hand_edges_crossing_handle":crossing_edges,"handle_edges_crossing_hand":reverse_crossings,"vertices_inside_triangles":exact_inside,"deepest_triangle_penetration_m":exact_deepest,"vertices_inside_handle_aabb":inside,"deepest_aabb_penetration_m":deepest}
		return nearest
	func palm_offset(side := "Left") -> Vector3:
		# Rest-hand palm centre: 6 cm along fingers, 3.5 cm toward curled grip centre.
		var finger := (weapon.global_transform.basis.x if side=="Left" else weapon.global_transform.basis.z).normalized()
		return finger*.06-weapon.global_transform.basis.y.normalized()*(.039 if side=="Left" else .041)
	func clamp_grip(side: String, anchor: Vector3) -> void:
		var skeleton := cast._skeleton
		var upper := skeleton.find_bone(side+"Arm")
		var lower := skeleton.find_bone(side+"ForeArm")
		var hand := skeleton.find_bone(side+"Hand")
		var root := skeleton.to_global(skeleton.get_bone_global_pose(upper).origin)
		var elbow := skeleton.to_global(skeleton.get_bone_global_pose(lower).origin)
		var wrist := skeleton.to_global(skeleton.get_bone_global_pose(hand).origin)
		var reach := root.distance_to(elbow)+elbow.distance_to(wrist)-0.0015
		var target := weapon.to_global(anchor)-palm_offset(side)
		var offset := target-root
		if offset.length()>reach:
			weapon.global_position += root+offset.normalized()*reach-target
	func _process(_delta: float) -> void:
		var a := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(cast._hand_bones[0]).origin)
		var b := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(cast._hand_bones[1]).origin)
		ticks += 1
		if not reported or ticks == 29:
			print("GRIP_SPAN metres=", a.distance_to(b), " right=", a, " left=", b)
			reported = true
		var rear := Vector3(-0.47, 0.13, 0)
		var front := Vector3(-0.09, 0.31, 0)
		var axis := front - rear
		var span := b - a
		if span.length() < 0.01: return
		var source_x := axis.normalized()
		var source_z := source_x.cross(Vector3.UP).normalized()
		var target_x := span.normalized()
		var target_z := target_x.cross(Vector3.UP).normalized()
		var source_frame := Basis(source_x, source_z.cross(source_x), source_z)
		var target_frame := Basis(target_x, target_z.cross(target_x), target_z)
		var basis := (target_frame*source_frame.transposed()).scaled(Vector3.ONE*.65)
		if visual.pose_override == "powered/chainsaw_raise" or OS.get_environment("CHAINSAW_SUPPORT_IK") == "1":
			basis = (cast._model.global_transform.basis.orthonormalized()*Basis(Vector3.UP,-PI*.5)).scaled(Vector3.ONE*.65)
		weapon.global_transform = Transform3D(basis, a - basis * rear)
		if OS.get_environment("CHAINSAW_SUPPORT_IK") == "1": weapon.global_position += palm_offset("Right")
		if OS.get_environment("CHAINSAW_SUPPORT_IK") == "1" and visual.pose_override != "powered/chainsaw_raise":
			# Old blended wrist tracks may rise above the shoulders. Keep the tool
			# below chest height before solving both arms against its grips.
			var skeleton := cast._skeleton
			var shoulder := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("RightArm")).origin)
			var rear_height := weapon.to_global(rear).y
			weapon.global_position.y -= maxf(0.0,rear_height-(shoulder.y-.24))
			for iteration in 4:
				clamp_grip("Left", front)
				clamp_grip("Right", rear)
			fit_hand("Left",weapon.to_global(front)-palm_offset())
			fit_hand("Right",weapon.to_global(rear)-palm_offset("Right"))
			orient_hand("Left")
			orient_hand("Right")
		visual.weapon_sprite.modulate.a = 0
		if ticks == 29:
			print("SUPPORT_GAP metres=", b.distance_to(weapon.to_global(front)))

func _ready() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(1200, 1300)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var actors: Array = []
	var clips := ["powered/chainsaw_aim", "powered/chainsaw_walk", "powered/chainsaw_run", "powered/chainsaw_sneak"]
	for i in 32:
		var visual := CharacterVisual.new()
		stage.add_child(visual)
		visual.setup("cass")
		var model := visual.cast_sprite as CastModel
		if OS.get_environment("CHAINSAW_GRIP_MESH") == "1":
			var donor: Node3D = load(OS.get_environment("CHAINSAW_HAND_MODEL") if not OS.get_environment("CHAINSAW_HAND_MODEL").is_empty() else "res://build/chainsaw_pose_candidate/cass_grip_mesh.glb").instantiate()
			var donor_skeleton: Skeleton3D = donor.find_children("*","Skeleton3D",true,false)[0]
			assert(donor_skeleton.get_bone_count()==model._skeleton.get_bone_count())
			for bone in donor_skeleton.get_bone_count():
				assert(donor_skeleton.get_bone_name(bone)==model._skeleton.get_bone_name(bone))
			var replaced := 0
			for mesh in model._model.find_children("*","MeshInstance3D",true,false):
				for replacement in donor.find_children("*","MeshInstance3D",true,false):
					if mesh.name==replacement.name:
						mesh.mesh=replacement.mesh
						replaced += 1
			print("GRIP_MESH replacements=",replaced)
			assert(replaced > 0)
			donor.free()
		var library := load("res://build/chainsaw_pose_candidate/chainsaw_clips.res") as AnimationLibrary
		model._player.add_animation_library("powered", library)
		for clip in library.get_animation_list(): model.clips["powered/" + clip] = true
		visual.set_weapon(DB.weapon(&"chainsaw"))
		visual.idle_fidgets = false
		visual.position = Vector2(75 + (i % 8) * 150, 230 + (i / 8) * 320)
		visual.scale = Vector2.ONE * 4.0
		visual.set_aim((i % 8) * PI * 0.25)
		visual.set_powered_cutting(true)
		visual.pose_override = clips[i / 8]
		visual._face_angle = (i % 8) * PI * 0.25
		var attachment := GripAttachment.new()
		attachment.cast = visual.cast_sprite as CastModel
		attachment.visual = visual
		attachment.weapon = load("res://build/chainsaw_review/chainsaw.glb").instantiate()
		var bounds := AABB()
		var first := true
		for mesh in attachment.weapon.find_children("*", "MeshInstance3D", true, false):
			var transformed: AABB = mesh.transform * mesh.get_aabb()
			bounds = transformed if first else bounds.merge(transformed)
			first = false
		print("WEAPON BOUNDS ", bounds, " root=", attachment.weapon.transform)
		attachment.cast._model.add_child(attachment.weapon)
		add_child(attachment)
		var label := Label.new()
		label.text = clips[i / 8] + " " + str((i % 8) * 45)
		label.position = Vector2(12 + (i % 8) * 150, 280 + (i / 8) * 320)
		stage.add_child(label)
		visual.set_process(false)
		attachment.set_process(false)
		actors.append([visual, attachment])
	var measurements: Array = []
	var failures := 0
	for actor in actors:
		var visual: CharacterVisual = actor[0]
		var cast := visual.cast_sprite as CastModel
		visual.pose_progress = -1.0
		measurements.append({"clip":visual.pose_override,"heading":rad_to_deg(visual.aim_angle),"max_steady_gap_m":0.0,"max_entry_gap_m":0.0,"duration_s":cast._player.get_animation(visual.pose_override).length})
	for frame in 540:
		for index in actors.size():
			var visual: CharacterVisual = actors[index][0]
			var cast := visual.cast_sprite as CastModel
			visual._process_cast(1.0 / 60.0)
			actors[index][1]._process(0.0)
			var left := cast._skeleton.to_global(cast._skeleton.get_bone_global_pose(cast._hand_bones[1]).origin)
			var front: Vector3 = actors[index][1].weapon.to_global(Vector3(-0.09, 0.31, 0))
			var key := "max_entry_gap_m" if frame < 20 else "max_steady_gap_m"
			measurements[index][key] = maxf(measurements[index][key], (left+actors[index][1].palm_offset()).distance_to(front))
		await get_tree().process_frame
	for index in actors.size():
		measurements[index]["left_nearest_vertex_m"] = actors[index][1].nearest_hand_vertex("Left",Vector3(-.09,.31,0))
		measurements[index]["right_nearest_vertex_m"] = actors[index][1].nearest_hand_vertex("Right",Vector3(-.47,.13,0))
		measurements[index]["handle_aabb_probe"] = actors[index][1].handle_probe.duplicate(true)
	for row in measurements:
		if row.max_steady_gap_m > 0.005: failures += 1
		for side in ["Left","Right"]:
			if not row.handle_aabb_probe[side].mesh_found or row.handle_aabb_probe[side].deepest_triangle_penetration_m > .001 or row.handle_aabb_probe[side].hand_edges_crossing_handle>0 or row.handle_aabb_probe[side].handle_edges_crossing_hand>0: failures += 1
	for frame in 5: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png("res://build/chainsaw_pose_candidate/remodeled_continuous.png")
	var file := FileAccess.open("res://build/chainsaw_pose_candidate/remodeled_continuous_alignment.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"scope":"Remodeled hand candidate with powered AnimationLibrary and contact IK, 540 real process frames, animation advanced at 60Hz through at least two loops per clip. Entry gaps recorded separately; no input or physical locomotion.","rows":measurements}, "  "))
	print("CHAINSAW CONTINUOUS REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
