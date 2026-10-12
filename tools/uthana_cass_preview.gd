extends Node
func _ready() -> void:
	Engine.set_meta("skip_tasks",true)
	var motions: Array = ["walk","run","pistol_walk","stealth","run_arm_clearance_v2"]
	var selected := OS.get_environment("UTHANA_PREVIEW_MOTION")
	var cast_id := OS.get_environment("UTHANA_PREVIEW_CAST")
	if cast_id.is_empty(): cast_id = "cass"
	if not selected.is_empty(): motions = [selected]
	for motion in motions:
		var path: String = "res://build/uthana/cass/"+motion+".glb" if cast_id == "cass" else "res://build/uthana/cast_roster/motions/"+cast_id+"/"+motion+".glb"
		if cast_id != "cass" and OS.get_environment("UTHANA_PREVIEW_CONDITIONED") == "1":
			path = "res://build/uthana/cast_roster/motions/"+cast_id+"/conditioned/"+motion+".glb"
		var merged_review := OS.get_environment("UTHANA_PREVIEW_MERGED") == "1"
		if merged_review:
			path = CastModel.RT_PATH % [cast_id, cast_id]
		if OS.get_environment("UTHANA_PREVIEW_HAND_CANDIDATE")=="1":
			path="res://build/uthana/cast_roster/motions/"+cast_id+"/hand_preserved/guard.glb"
		if OS.get_environment("UTHANA_PREVIEW_FOREEND_HAND")=="1":
			path="res://build/uthana/cast_roster/motions/"+cast_id+"/hand_foreend_preserved/guard.glb"
		if not FileAccess.file_exists(path): continue
		var viewport := SubViewport.new()
		viewport.size = Vector2i(320,320)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(path,state) == OK)
		var model := document.generate_scene(state)
		viewport.add_child(model)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 2.5
		viewport.add_child(camera)
		camera.position = Vector3(3,1.8,3)
		var camera_angle:=OS.get_environment("UTHANA_PREVIEW_CAMERA_ANGLE")
		if not camera_angle.is_empty():
			var azimuth:=deg_to_rad(float(camera_angle))
			camera.position=Vector3(sin(azimuth)*4.24,1.8,cos(azimuth)*4.24)
		camera.look_at(Vector3(0,0.85,0))
		if OS.get_environment("UTHANA_PREVIEW_CLOSEUP") == "1":
			camera.size = 1.0
			camera.look_at(Vector3(-.08,1.25,.16))
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color("20222b")
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = 0.6
		viewport.add_child(env)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-45,-30,0)
		light.light_energy = 1.4
		viewport.add_child(light)
		var player: AnimationPlayer = model.find_children("*","AnimationPlayer",true,false)[0]
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var clip: String = player.get_animation_list()[0]
		if clip == "RESET": clip = player.get_animation_list()[1]
		if merged_review:
			var library_name := "contact_corrected_library.res" if OS.get_environment("UTHANA_PREVIEW_CORRECTED")=="1" else "contact_library.res"
			var merged := load("res://build/uthana/cast_roster/motions/"+cast_id+"/merged/"+library_name) as AnimationLibrary
			assert(merged != null)
			player.add_animation_library("uthana_review", merged)
			clip = "uthana_review/armed_" + ("sneak" if motion == "stealth" else motion)
		var duration := player.get_animation(clip).length
		var weapon: Node3D
		var grip: Node3D
		var skeleton: Skeleton3D
		var hand_index := -1
		var long_id:=OS.get_environment("UTHANA_PREVIEW_LONG_WEAPON")
		if OS.get_environment("UTHANA_PREVIEW_WEAPON") == "1":
			var weapon_document := GLTFDocument.new()
			var weapon_state := GLTFState.new()
			var weapon_path: String="res://assets/art/weapons3d/staging/service_pistol_v3/service_pistol.glb" if long_id.is_empty() else "res://assets/art/weapons3d/staging/"+long_id+"_fit_v1/"+long_id+".glb"
			assert(weapon_document.append_from_file(weapon_path, weapon_state) == OK)
			weapon = weapon_document.generate_scene(weapon_state)
			viewport.add_child(weapon)
			grip = weapon.find_child("GripAnchor", true, false) as Node3D
			skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			for bone in skeleton.get_bone_count():
				if skeleton.get_bone_name(bone).ends_with("RightHand"):
					hand_index = bone
			assert(grip != null and hand_index >= 0)
			for mesh_node in model.find_children("*","MeshInstance3D",true,false):
				var mesh := mesh_node as MeshInstance3D
				var shape := mesh.find_blend_shape_by_name("WeaponGrip")
				if shape >= 0:
					mesh.set_blend_shape_value(shape,1.0)
					print("PISTOL existing WeaponGrip morph enabled: ",mesh.name)
			print("PISTOL root basis scale=",weapon.global_basis.get_scale()," meshes=",weapon.find_children("*","MeshInstance3D",true,false).size()," grip=",grip.position)
		var directory: String = "res://build/uthana/cass/"+motion+"_frames" if cast_id == "cass" else "res://build/uthana/cast_roster/motions/"+cast_id+"/"+motion+"_frames"
		if merged_review:
			directory = "res://build/uthana/cast_roster/motions/"+cast_id+"/merged/"+motion+"_frames"
		if weapon:
			directory = "res://build/uthana/cast_roster/motions/"+cast_id+"/merged/"+motion+"_weapon_frames" if merged_review else ("res://build/uthana/cass/"+motion+"_weapon_frames" if cast_id == "cass" else "res://build/uthana/cast_roster/motions/"+cast_id+"/"+motion+"_weapon_frames")
		if OS.get_environment("UTHANA_PREVIEW_CLOSEUP") == "1": directory += "_closeup"
		if OS.get_environment("UTHANA_PREVIEW_CORRECTED") == "1": directory += "_contact_corrected"
		if OS.get_environment("UTHANA_PREVIEW_AIM_CANDIDATE") == "1": directory += "_aim_candidate"
		if OS.get_environment("UTHANA_PREVIEW_HAND_CANDIDATE") == "1": directory += "_hand_candidate"
		if not long_id.is_empty(): directory+="_"+long_id
		if not camera_angle.is_empty(): directory+="_camera_"+camera_angle
		if OS.get_environment("UTHANA_PREVIEW_FOREEND_HAND")=="1": directory+="_foreend"
		if not OS.get_environment("UTHANA_PREVIEW_ELBOW_ORBIT").is_empty(): directory+="_elbow_"+OS.get_environment("UTHANA_PREVIEW_ELBOW_ORBIT").replace(",","_")
		if not OS.get_environment("UTHANA_PREVIEW_ARM_TWIST").is_empty(): directory+="_twist_"+OS.get_environment("UTHANA_PREVIEW_ARM_TWIST")
		# Image.save_png and DirAccess absolute APIs require an OS path.  `res://`
		# is valid for ResourceLoader/FileAccess but silently failed to create the
		# review-frame directory for newly named Uthana studies.
		var output_directory := ProjectSettings.globalize_path(directory)
		assert(DirAccess.make_dir_recursive_absolute(output_directory) == OK)
		player.play(clip)
		var worst_hand_error:=0.0
		var reviewed_poses: Array=[]
		for frame in 48:
			player.seek(duration*frame/48.0,true)
			player.advance(0.000001)
			if weapon:
				skeleton.force_update_all_bone_transforms()
				if not long_id.is_empty():
					var error:=preload("res://tools/uthana_shouldered_pose_candidate.gd").apply(skeleton,weapon)
					worst_hand_error=maxf(worst_hand_error,error)
					assert(error<.002,"Shouldered hand target unreachable: "+str(error))
				elif OS.get_environment("UTHANA_PREVIEW_AIM_CANDIDATE") == "1":
					var error := preload("res://tools/uthana_aim_pose_candidate.gd").apply(skeleton)
					assert(error<.002,"Review grip target unreachable: "+str(error))
				var hand := skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
				var axes := hand.basis.orthonormalized()
				# The Blender pistol's +Z barrel follows the aim, while its grip
				# stays on the animated hand. Wrist-axis inference had pointed the
				# barrel back into the arm on this preserved combat pose.
				var mount := Transform3D(Basis.IDENTITY, hand.origin + axes.y * .03)
				if OS.get_environment("UTHANA_PREVIEW_HAND_CANDIDATE")=="1":
					mount.origin=hand.origin+axes.y*.06+axes.z*.039
				var local_grip := weapon.global_transform.affine_inverse() * grip.global_transform
				if long_id.is_empty():
					weapon.global_transform = mount * local_grip.affine_inverse()
					assert(grip.global_position.distance_to(mount.origin) < .00001)
				var barrel := weapon.find_child("Muzzle",true,false) as Node3D
				assert(barrel != null)
				assert(barrel.global_basis.orthonormalized().z.dot(Vector3.BACK) > .9999, "Blender barrel must point along the review aim")
				if long_id.is_empty(): assert(grip.global_position.distance_to(barrel.global_position) > .17 and grip.global_position.distance_to(barrel.global_position) < .19, "Service pistol must keep physical scale")
				if frame == 12:
					var bone_poses: Dictionary={}
					for bone in skeleton.get_bone_count():
						var pose:=skeleton.global_transform*skeleton.get_bone_global_pose(bone)
						bone_poses[skeleton.get_bone_name(bone)]=[[pose.basis.x.x,pose.basis.y.x,pose.basis.z.x,pose.origin.x],[pose.basis.x.y,pose.basis.y.y,pose.basis.z.y,pose.origin.y],[pose.basis.x.z,pose.basis.y.z,pose.basis.z.z,pose.origin.z],[0,0,0,1]]
					var pose_file:=FileAccess.open(directory+"/pose_012.json",FileAccess.WRITE)
					pose_file.store_string(JSON.stringify(bone_poses))
					for bone_name in ["Spine02","RightArm","RightForeArm","RightHand","LeftHand"]:
						var bone_index:=skeleton.find_bone(bone_name)
						print("POSE DIAG ",bone_name," ",skeleton.to_global(skeleton.get_bone_global_pose(bone_index).origin))
					var muzzle := weapon.find_child("Muzzle",true,false) as Node3D
					print("PISTOL hand=",hand.origin," grip=",grip.global_position," muzzle=",muzzle.global_position," grip_to_muzzle_m=",grip.global_position.distance_to(muzzle.global_position))
				var frame_pose: Dictionary={}
				for bone in skeleton.get_bone_count():
					var pose:=skeleton.global_transform*skeleton.get_bone_global_pose(bone)
					frame_pose[skeleton.get_bone_name(bone)]=[[pose.basis.x.x,pose.basis.y.x,pose.basis.z.x,pose.origin.x],[pose.basis.x.y,pose.basis.y.y,pose.basis.z.y,pose.origin.y],[pose.basis.x.z,pose.basis.y.z,pose.basis.z.z,pose.origin.z],[0,0,0,1]]
				reviewed_poses.append(frame_pose)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			assert(viewport.get_texture().get_image().save_png(output_directory+"/%03d.png"%frame) == OK)
		var review:=FileAccess.open(directory+"/review.json",FileAccess.WRITE)
		review.store_string(JSON.stringify({"runtime_approved":false,"cast":cast_id,"motion":motion,"weapon":long_id if not long_id.is_empty() else "pistol","frames":48,"duration_seconds":duration,"worst_shouldered_hand_target_error_m":worst_hand_error,"pending":"Finger contact, anatomical clearance, other aim angles and actual gameplay"},"\t"))
		var all_poses:=FileAccess.open(directory+"/poses.json",FileAccess.WRITE)
		all_poses.store_string(JSON.stringify(reviewed_poses))
		print("UTHANA preview frames: ",motion," seconds=",duration)
		viewport.queue_free()
		await get_tree().process_frame
	Game.request_quit(0)

