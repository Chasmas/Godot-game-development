class_name PropModel
extends Sprite2D
## A static 3D prop (a Meshy GLB from assets/art/Artwork/3d/<id>/model.glb copied
## to assets/art/props3d/<id>.glb) drawn through the cast's own camera and lights
## (CastModel.dress_stage), so props match the characters. The node's position is
## the prop's foot on the floor; `height_m` sizes the model in metres.

const DIR := "res://assets/art/props3d/%s.glb"
const PX := 96

var id := ""
var height_m := 0.6
var yaw := 0.0                 ## turned about its own vertical axis (radians)
var source_path := ""          ## Review candidate override; normal props use DIR.
var _animation_player: AnimationPlayer
var _viewport: SubViewport
var _camera: Camera3D

static func available(prop_id: String) -> bool:
	return ResourceLoader.exists(DIR % prop_id)

func _ready() -> void:
	var meters := float(PX) / (float(CastModel.PX) / CastModel.METERS)   # same px per metre as the cast
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(PX, PX)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE   # static: draw once
	add_child(_viewport)
	_camera = CastModel.dress_stage(_viewport, meters, meters * 0.3)
	var model: Node3D
	if source_path != "" and source_path.ends_with(".glb"):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(source_path, state) != OK:
			return
		model = document.generate_scene(state) as Node3D
	else:
		model = (load(source_path if source_path != "" else DIR % id) as PackedScene).instantiate() as Node3D
	_viewport.add_child(model)
	# stand it on the floor at the origin, scaled to height_m
	var aabb := _aabb(model)
	var k := height_m / maxf(aabb.size.y, 0.001)
	model.scale = Vector3.ONE * k
	model.position = Vector3(-aabb.get_center().x * k, -aabb.position.y * k, -aabb.get_center().z * k)
	model.rotation.y = yaw
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_animation_player = players[0]
		_animation_player.animation_finished.connect(func(_clip): _viewport.render_target_update_mode = SubViewport.UPDATE_ONCE)
	texture = _viewport.get_texture()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE * 16.0 / (float(CastModel.PX) / CastModel.METERS)
	offset = Vector2(PX * 0.5, PX * 0.5) - _camera.unproject_position(Vector3.ZERO)
	material = CastModel._outline_material()
	light_mask = 2

func play_animation(clip: StringName) -> bool:
	if _animation_player == null or not _animation_player.has_animation(clip):
		return false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_animation_player.play(clip)
	return true

func _aabb(n: Node) -> AABB:
	var bounds: Array[AABB] = []
	_collect_bounds(n, Transform3D.IDENTITY, bounds)
	var box := AABB()
	var first := true
	for b in bounds:
		box = b if first else box.merge(b)
		first = false
	return box

func _collect_bounds(n: Node, relative: Transform3D, bounds: Array[AABB]) -> void:
	# Measure in the imported root's local space. Imported Blender groups
	# may carry translation, rotation and scale above each mesh instance.
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		bounds.append(relative * (n as MeshInstance3D).get_aabb())
	for child in n.get_children():
		var child_relative := relative
		if child is Node3D:
			child_relative *= (child as Node3D).transform
		_collect_bounds(child, child_relative, bounds)
