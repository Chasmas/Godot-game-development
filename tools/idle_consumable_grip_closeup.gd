extends Node
var contact_rows: Array = []

func _ready() -> void:
	var look := OS.get_environment("IDLE_REVIEW_LOOK")
	if look == "":
		look = "guard"
	var consumables := true
	var directions := true
	var columns := 8 if directions else 6
	var stage := SubViewport.new()
	stage.size = Vector2i(columns * 280, 640)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var background := ColorRect.new()
	background.color = Color("191622")
	background.z_index = -100
	background.size = Vector2(stage.size)
	stage.add_child(background)
	var pairs: Array = []
	for row in 2:
		for col in columns:
			var cell := Node2D.new()
			cell.position = Vector2(140 + col * 280, 140 + row * 320)
			cell.scale = Vector2.ONE * 6.0
			stage.add_child(cell)
			var visual := CharacterVisual.new()
			cell.add_child(visual)
			visual.setup(look)
			var source := OS.get_environment("CONSUMABLE_CONTACT_MODEL")
			if source == "": source = "res://build/guard_consumables_isolated/guard.glb"
			if source != "":
				visual.cast_sprite.free()
				var candidate := CastModel.new()
				if not candidate.configure(look, source):
					get_tree().quit(1)
					return
				visual.cast_sprite = candidate
				visual.rig.add_child(candidate)
			var facing := float(col) * TAU / columns if directions else 0.0
			visual._face_angle = facing
			visual.set_aim(facing)
			if visual.cast_sprite is CastModel:
				# Frozen samples must initialize the hips to this facing too.
				(visual.cast_sprite as CastModel)._body_init = false
			visual.set_weapon(DB.weapon(&"pistol"))
			var activity := IdleActivity.new()
			visual.rig.add_child(activity)
			var kind := (IdleActivity.Kind.DRINK if row == 0 else IdleActivity.Kind.EAT) if consumables else (IdleActivity.Kind.SMOKE if row == 0 else IdleActivity.Kind.SNOOZE)
			activity.setup(visual, kind, "review")
			if col == 0: print("ACTIVITY_REVIEW ", kind, " pose=",visual.idle_activity_pose," clips=",visual.cast_sprite.clips.keys())
			visual.set_process(false)
			activity.set_process(false)
			var phase := (0.33 if row == 0 else 0.5) if directions else float(col) / 6.0
			activity.visible = false
			var document := GLTFDocument.new()
			var gltf := GLTFState.new()
			var prop_name := "can" if row == 0 else "donut"
			if document.append_from_file("res://build/idle_consumables_candidate/" + prop_name + ".glb", gltf) != OK:
				get_tree().quit(1)
				return
			var prop := document.generate_scene(gltf) as Node3D
			(visual.cast_sprite as CastModel)._viewport.add_child(prop)
			var markers: Array[MeshInstance3D] = []
			if OS.get_environment("CONSUMABLE_CONTACT_MARKERS") == "1":
				for colour in [Color.WHITE,Color.RED,Color.CYAN]:
					var marker := MeshInstance3D.new()
					var sphere := SphereMesh.new()
					sphere.radius = .016
					sphere.height = .032
					marker.mesh = sphere
					var material := StandardMaterial3D.new()
					material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					material.albedo_color = colour
					marker.material_override = material
					(visual.cast_sprite as CastModel)._viewport.add_child(marker)
					markers.append(marker)
			pairs.append([visual, activity, phase, prop, row, markers])
			var label := Label.new()
			label.text = "%s  %s" % [("Drink" if row == 0 else "Eat") if consumables else ("Smoke" if row == 0 else "Doze"), "%d°" % int(rad_to_deg(facing)) if directions else "%.2f" % phase]
			label.position = Vector2(20 + col * 280, 285 + row * 320)
			stage.add_child(label)
	var capture_dir := OS.get_environment("CONSUMABLE_CAPTURE_DIR")
	if capture_dir == "": capture_dir = "res://build/idle_consumables_motion"
	DirAccess.make_dir_recursive_absolute(capture_dir)
	for frame in 24:
		for pair in pairs:
			var visual: CharacterVisual = pair[0]
			var activity: IdleActivity = pair[1]
			activity._t = float(frame) / 24.0 * activity._cycle
			activity._process(0.0)
			visual._process_cast(0.0)
			var cast := visual.cast_sprite as CastModel
			var skeleton := cast._skeleton
			var hand := skeleton.global_transform * skeleton.get_bone_global_pose(cast._hand_bones[0])
			var axes := hand.basis.orthonormalized()
			if frame == 0 and pair == pairs[0]: print("HAND_GEOMETRY ", hand.origin, " scale=",hand.basis.get_scale())
			var head_world := skeleton.to_global(skeleton.get_bone_global_pose(cast._head).origin)
			cast._camera.size = .42
			var look_at := head_world + Vector3.UP * .01
			var view_direction := Vector3(0,sin(deg_to_rad(50)),cos(deg_to_rad(50)))
			cast._camera.look_at_from_position(look_at+view_direction*30,look_at)
			cast.offset = Vector2.ZERO
			var prop: Node3D = pair[3]
			if int(pair[4]) == 0:
				prop.global_transform = Transform3D(axes, hand.origin + axes.z * -0.055 + axes.y * (0.03 - 0.0575))
			else:
				var up := -axes.z
				var right := axes.x
				prop.global_transform = Transform3D(Basis(right, up, right.cross(up)), hand.origin + up * (0.065 - 0.014) + axes.y * 0.075)
			if frame >= 6 and frame <= 11:
				var head := skeleton.to_global(skeleton.get_bone_global_pose(cast._head).origin)
				# Anatomical proxy for review only; does not prove mesh lip contact.
				var landmark: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/consumable_head_landmarks/lip_surface.json"))
				var local_point: Array = landmark.head_local_gltf
				var mouth := (skeleton.global_transform * skeleton.get_bone_global_pose(cast._head)) * Vector3(local_point[0],local_point[1],local_point[2])
				var markers: Array = pair[5]
				if markers.size() == 3:
					markers[0].global_position = head
					markers[1].global_position = mouth
					markers[2].visible = false
				var nearest := INF
				var nearest_edge := Vector3.ZERO
				for sample in 64:
					var angle := TAU * sample / 64.0
					var radius := .030 if int(pair[4]) == 0 else .042
					var height := .111 if int(pair[4]) == 0 else .014
					var edge := prop.to_global(Vector3(cos(angle)*radius,height,sin(angle)*radius))
					if edge.distance_to(mouth) < nearest:
						nearest = edge.distance_to(mouth)
						nearest_edge = edge
				contact_rows.append({"action":"drink" if int(pair[4])==0 else "eat","heading":rad_to_deg(cast._facing_angle),"phase":float(frame)/24,"mouth_proxy_gap_m":nearest,"edge_to_lip_model":[ (cast._model.global_basis.orthonormalized().inverse() * (mouth-nearest_edge)).x,(cast._model.global_basis.orthonormalized().inverse() * (mouth-nearest_edge)).y,(cast._model.global_basis.orthonormalized().inverse() * (mouth-nearest_edge)).z]})
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		stage.get_texture().get_image().save_png(capture_dir + "/frame_%02d.png" % frame)
	await RenderingServer.frame_post_draw
	var err := stage.get_texture().get_image().save_png("res://build/%s_consumable_grip_closeup%s.png" % [look, ("_consumables" if consumables else "") + ("_directions" if directions else "")])
	var report := FileAccess.open(capture_dir + "/contact_proxy.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"approved":false,"scope":"Surface-raycast lip landmark follows Head bone; prop edge samples do not prove full mesh nonintersection","rows":contact_rows},"  "))
	stage.queue_free()
	await get_tree().process_frame
	get_tree().quit(err)
