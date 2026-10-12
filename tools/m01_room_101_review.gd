extends Node3D

func _ready() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file("res://assets/art/prerendered/m01_sunset_palms/staging/room_101_shared_3d_v21/room.glb",state)==OK)
	var room := document.generate_scene(state)
	add_child(room)
	var preparation: Dictionary = preload("res://scripts/player/cast_gltf_materials.gd").prepare(room,BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC)
	assert(preparation.generated_mipmaps>0)
	var cutaway_surfaces: int = preload("res://tools/m01_room_101_cutaway.gd").apply(room)
	assert(cutaway_surfaces>0)
	var camera := room.find_children("*","Camera3D",true,false)[0] as Camera3D
	camera.current=true
	var world := WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color(.025,.025,.04)
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color(.65,.73,1)
	world.environment.ambient_light_energy=.55
	add_child(world)
	for light in room.find_children("*","Light3D",true,false):
		light.light_energy=.6
		if light is OmniLight3D:light.omni_range=3
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-60,-20,0)
	fill.light_energy=.5
	fill.light_color=Color(1,.78,.6)
	add_child(fill)
	PostFX.rect.hide()
	var laser := preload("res://scripts/systems/projected_laser_visual.gd").new()
	add_child(laser)
	laser.position=Vector3(2,0,1)
	laser.rotation.y=.4
	var barrel := Vector3(4,.9,2)
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		laser.update_from_beam({"floor_from":Vector2(248,464),"floor_to":Vector2(248,464)+direction*32},barrel)
		assert(laser.endpoints[0].distance_to(barrel)<.001)
		assert(absf(laser.endpoints[1].distance_to(barrel)-2)<.001)
		assert(laser.mesh.get_surface_count()==1)
	laser.update_from_beam({},barrel)
	assert(not laser.visible and laser.mesh==null and laser.endpoints.is_empty())
	laser.queue_free()
	var weapon_document := GLTFDocument.new()
	var weapon_state := GLTFState.new()
	assert(weapon_document.append_from_file("res://assets/art/weapons3d/staging/service_pistol_v1/service_pistol.glb",weapon_state)==OK)
	var weapon := weapon_document.generate_scene(weapon_state)
	add_child(weapon)
	weapon.position=Vector3(4,.9,2)
	weapon.rotation.y=.6
	var muzzle_nodes := weapon.find_children("Muzzle","Node3D",true,false)
	var grip_nodes := weapon.find_children("GripAnchor","Node3D",true,false)
	assert(muzzle_nodes.size()==1 and grip_nodes.size()==1)
	var muzzle := muzzle_nodes[0] as Node3D
	var grip_marker := grip_nodes[0] as Node3D
	var weapon_laser := preload("res://scripts/systems/projected_laser_visual.gd").new()
	add_child(weapon_laser)
	weapon_laser.update_from_beam({"floor_from":Vector2(248,464),"floor_to":Vector2(280,464)},muzzle.global_position)
	assert(weapon_laser.endpoints[0].distance_to(muzzle.global_position)<.00001)
	var weapon_report := FileAccess.open("res://build/m01_pistol_anchor_review.json",FileAccess.WRITE)
	weapon_report.store_string(JSON.stringify({"runtime_promoted":false,"scope":"Exported weapon anchors and laser source under rotated transform; not hand pose or barrel heading approval","anchors":2,"laser_origin_error_metres":weapon_laser.endpoints[0].distance_to(muzzle.global_position),"grip_to_muzzle_metres":grip_marker.global_position.distance_to(muzzle.global_position)},"\t"))
	weapon_laser.queue_free();weapon.queue_free()
	var projection := preload("res://scripts/systems/locked_floor_projection.gd")
	var origin_map := Vector2(176,432)
	var projection_checks := 0
	for y in 11:
		for x in 11:
			var map_point := origin_map+Vector2(x*.8,y*.4)*16
			var screen_point := camera.unproject_position(projection.to_world(map_point,origin_map))
			var restored: Variant=projection.screen_to_map(camera,screen_point,origin_map)
			assert(restored!=null and restored.distance_to(map_point)<.02)
			projection_checks+=1
	for direction in [Vector2.ZERO,Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		var position_map := Vector2(248,464)
		var movement := projection.screen_direction_to_map(camera,position_map,direction,origin_map)
		if direction==Vector2.ZERO:
			assert(movement==Vector2.ZERO)
			continue
		var start := camera.unproject_position(projection.to_world(position_map,origin_map))
		var end := camera.unproject_position(projection.to_world(position_map+movement*8,origin_map))
		assert((end-start).normalized().dot(direction.normalized())>.999)
	var projection_report := FileAccess.open("res://build/m01_room101_input_projection.json",FileAccess.WRITE)
	projection_report.store_string(JSON.stringify({"runtime_integrated":false,"scope":"Camera-ground roundtrips and screen-relative direction conversion, not actual Player input integration","roundtrips":projection_checks,"directions":8,"zero_input":true},"\t"))
	var actor := (load("res://assets/art/cast3d_rt/cass/cass.glb") as PackedScene).instantiate() as Node3D
	add_child(actor)
	var skeleton := actor.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var hand_bones: Array=[]
	for bone in skeleton.get_bone_count():
		var label := str(skeleton.get_bone_name(bone))
		if label.to_lower().contains("hand") or label.to_lower().contains("wrist"):
			hand_bones.append({"name":label,"index":bone,"rest_origin":str(skeleton.get_bone_global_rest(bone).origin)})
	var rig_report := FileAccess.open("res://build/m01_cass_weapon_rig.json",FileAccess.WRITE)
	rig_report.store_string(JSON.stringify({"scope":"Existing skeleton attachment candidates, not grip alignment approval","hand_bones":hand_bones,"animations":Array((actor.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer).get_animation_list())},"\t"))
	(actor.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer).play("idle")
	var occlusion = preload("res://scripts/systems/visual_occlusion_fade.gd").new()
	occlusion.setup(room)
	var samples: Array=[]
	for sample in [{"label":"entry","position":Vector3(4,0,3.5)}, {"label":"bedside","position":Vector3(4.5,0,2)}, {"label":"window","position":Vector3(.5,0,3.2)}]:
		actor.position=sample.position
		var screen := camera.unproject_position(actor.position)
		var origin := camera.project_ray_origin(screen)
		var ray := camera.project_ray_normal(screen)
		assert((origin+ray*(-origin.y/ray.y)).distance_to(actor.position)<.001)
		var blockers: Array=[]
		for frame in 12:
			blockers=occlusion.update(camera,actor.position,1.0/60)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var capture := "res://build/m01_room101_%s.png" % sample.label
		get_viewport().get_texture().get_image().save_png(capture)
		samples.append({"label":sample.label,"occluders":blockers,"capture":capture})
	actor.position=Vector3(4.5,0,2)
	var screen_surfaces := 0
	var curtain: MeshInstance3D
	for mesh in room.find_children("*","MeshInstance3D",true,false):
		var label := str(mesh.name).to_lower().replace("_"," ")
		if label.begins_with("101 right gathered curtain"):curtain=mesh
		if not label.begins_with("convex dark crt"):continue
		for surface in mesh.mesh.get_surface_count():
			var lit := mesh.get_active_material(surface).duplicate() as StandardMaterial3D
			lit.emission_enabled=true
			lit.emission=Color(.10,.40,.45)
			lit.emission_energy_multiplier=.8
			mesh.set_surface_override_material(surface,lit)
			screen_surfaces+=1
	assert(screen_surfaces>0 and curtain!=null)
	for comparison in ["lit_screen","lit_screen_without_right_curtain"]:
		curtain.visible=comparison=="lit_screen"
		for frame in 8:await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var comparison_path := "res://build/m01_room101_%s.png"%comparison
		get_viewport().get_texture().get_image().save_png(comparison_path)
		samples.append({"label":comparison,"screen_surfaces":screen_surfaces,"capture":comparison_path,"scope":"Diagnostic emission/occluder comparison only"})
	curtain.show()
	var foreground_count: int = preload("res://tools/m01_room_101_cutaway.gd").fade_front_window(room)
	assert(foreground_count>0)
	actor.position=Vector3(4.5,0,2)
	for frame in 8:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/m01_room101_foreground_window.png")
	samples.append({"label":"foreground_window_comparison","opacity":.35,"surfaces":foreground_count,"capture":"res://build/m01_room101_foreground_window.png","scope":"Static visual trial, not dynamic fade or production approval"})
	var report := FileAccess.open("res://build/m01_room101_godot_review.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"runtime_approved":false,"scope":"Room101 material/actor/projection review; no full mission collision or input approval","materials":preparation,"cutaway_surfaces":cutaway_surfaces,"samples":samples},"\t"))
	print("M01 ROOM101 REVIEW PASSED")
	Game.request_quit(0)
