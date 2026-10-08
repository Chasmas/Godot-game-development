class_name CastModel
extends CastSprite
## Real-time oblique cast: the character's GLB (tools/art/build_cast_glb.py) drawn
## into a small pixel viewport through the same fixed 50-degree camera as the baked
## oblique casts. Any facing, blended clips and exact hand positions, for a few MB
## instead of a texture atlas per clip and facing. Same interface as CastSprite, so
## CharacterVisual and Corpse drive it unchanged.

const RT_PATH := "res://assets/art/cast3d_rt/%s/%s.glb"
const GLTF_MATERIALS := preload("res://scripts/player/cast_gltf_materials.gd")
const PX := 128             ## viewport pixels: one texel of the game's character art
const METERS := 2.56        ## frame height in metres (ortho size), as the baked casts
const ELEVATION := 50.0
const LOOK_Z := 0.82        ## the camera aims this high above the ground point
const LOOPS := ["idle", "walk", "run", "sneak", "aim", "aim_dual", "aim_melee", "doze", "smoke", "drive"]
const BLEND := 0.12
# Meshy source materials have very different base exposure.  This correction
# happens after the shared 3D stage is drawn, so all looks keep identical
# camera, outlines and light direction while remaining readable in night maps.
# Values above 1 darken an over-bright source; values below 1 lift dark cloth.
const LOOK_TONE := {
	"scout": 1.24,
	"civilian": 1.24,
	"sniper": 0.60,
	"stagehand": 0.60,
	"riot": 0.60,
	# Meshy's pale boss/firefighter materials clip under the shared key; a
	# stronger exponent restores jacket/skin separation without changing lights.
	"boss": 1.22,
	"fireman": 1.12,
	"burnt": 1.10,
}

var _viewport: SubViewport
var _camera: Camera3D
var _model: Node3D
var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _hand_bones := [-1, -1]
var _hips := -1
var _head := -1
var _spine: Array = []                      ## lower to upper spine bones
var _legs: Array = [-1, -1, -1, -1]         ## left thigh, left shin, right thigh, right shin
const SPINE_SHARE := [0.3, 0.35, 0.35]      ## how the upper-body twist is spread over them
var moving := false                         ## set each frame by CharacterVisual
var move_angle := 0.0                       ## direction of travel (game 2D angle)
var move_speed := 0.0                       ## game px/s
var roll_mode := 0                          ## set by CharacterVisual: 0 forward, 1 back, 2/3 side rolls
## How fast each stride clip travels when played at 1x (game px/s, 16 px = 1 m):
## Meshy's walk ~1.4 m/s, run ~3.6 m/s, sneak ~0.9 m/s.
# Calibrated to the game's world units. The old low values made the imported
# clips run at 3–4x speed, which read as skating and made crouch movement pop.
const NATIVE_SPEED := {"walk": 92.0, "run": 168.0, "sneak": 58.0}
var _body_angle := 0.0
var _body_init := false
var _progress := 0.0
var _driven_sample := false
var _stale_frames := 0
var _origin := Vector2.ZERO
var _look_id := ""
var _procedural_rotations: Dictionary = {}

func _rotate_pose_bone(bone: int, offset: Quaternion) -> void:
	if not _procedural_rotations.has(bone):
		_procedural_rotations[bone] = _skeleton.get_bone_pose_rotation(bone)
	_skeleton.set_bone_pose_rotation(bone, _skeleton.get_bone_pose_rotation(bone) * offset)

static func available(id: String) -> bool:
	return ResourceLoader.exists(RT_PATH % [id, id]) and OS.get_environment("CAST_BAKED") != "1"

## The best cast renderer this look has: real-time model, else baked clips, else null.
static func create(id: String) -> CastSprite:
	var candidate: CastSprite = null
	if available(id):
		candidate = CastModel.new()
	elif FileAccess.file_exists("res://assets/art/cast3d/%s/meta.json" % id):
		candidate = CastSprite.new()
	if candidate and not candidate.configure(id):
		candidate.free()
		candidate = null
	return candidate

var _activity_grips: Array = []
var _drink_prop: Node3D
var _held_pistols: Array[Node3D] = []
var _held_grips: Array = []
var _magazine_parts: Array = [[], []]

func attach_dual_pistols(path: String) -> bool:
	if _viewport == null or _skeleton == null or _hand_bones.has(-1):
		return false
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return false
	var grips: Array = []
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var shape := mesh.find_blend_shape_by_name("WeaponGrip")
		if shape >= 0: grips.append([mesh, shape])
	if grips.is_empty(): return false
	for gun in _held_pistols:
		gun.visible = false
		gun.queue_free()
	_held_pistols.clear()
	_magazine_parts = [[], []]
	_held_grips = grips
	for side in 2:
		var gun := document.generate_scene(state) as Node3D
		GLTF_MATERIALS.prepare(gun)
		_viewport.add_child(gun)
		gun.visible = false
		_held_pistols.append(gun)
		for part_name in ["Magazine body", "Magazine floorplate"]:
			var part := gun.find_child(part_name, true, false) as Node3D
			if part: _magazine_parts[side].append([part, part.position])
	return true

func update_dual_pistols(active: bool, recoil := Vector2.ZERO) -> void:
	for pair in _held_grips:
		pair[0].set_blend_shape_value(pair[1], 1.0 if active else 0.0)
	for side in _held_pistols.size():
		var hand := _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand_bones[side])
		var axes := hand.basis.orthonormalized()
		var basis := Basis(axes.y, axes.x, -axes.z) if side == 0 else Basis(axes.y, -axes.x, axes.z)
		_held_pistols[side].global_transform = Transform3D(basis, hand.origin + axes.y * (0.06 - recoil[side] / 16.0) + axes.z * 0.039)
		_held_pistols[side].visible = active
		var extraction := 0.0
		if active and clip == "reload_dual":
			var start := 0.08 if side == 0 else 0.48
			var end := 0.45 if side == 0 else 0.9
			var phase := clampf((_progress - start) / (end - start), 0.0, 1.0)
			extraction = 0.11 * smoothstep(0.0, 0.33, phase) * (1.0 - smoothstep(0.66, 1.0, phase))
		for pair in _magazine_parts[side]:
			pair[0].position = pair[1] - Vector3.UP * extraction

func native_pistol_points(left := false) -> PackedVector2Array:
	var side := 1 if left else 0
	if _held_pistols.size() <= side or not _held_pistols[side].visible:
		return PackedVector2Array()
	var tip := _held_pistols[side].to_global(Vector3(0.169, 0.055, 0))
	var floor := Vector3(tip.x, 0, tip.z)
	return PackedVector2Array([
		((_camera.unproject_position(tip) - _origin) * world_scale).rotated(-_facing_angle),
		((_camera.unproject_position(floor) - _origin) * world_scale).rotated(-_facing_angle)])

func attach_drink_prop(path: String) -> bool:
	if _viewport == null or _activity_grips.is_empty() or not clips.has("drink"):
		return false
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return false
	clear_drink_prop()
	_drink_prop = document.generate_scene(state) as Node3D
	GLTF_MATERIALS.prepare(_drink_prop)
	_viewport.add_child(_drink_prop)
	_update_drink_prop()
	return true

func clear_drink_prop() -> void:
	if is_instance_valid(_drink_prop):
		_drink_prop.visible = false
		_drink_prop.queue_free()
	_drink_prop = null
	for pair in _activity_grips:
		if is_instance_valid(pair[0]):
			pair[0].set_blend_shape_value(pair[1], 0.0)

func drink_drop_points() -> PackedVector2Array:
	if not is_instance_valid(_drink_prop) or _camera == null:
		return PackedVector2Array()
	var center := _drink_prop.to_global(Vector3(0, .0575, 0))
	var floor := Vector3(center.x, 0, center.z)
	return PackedVector2Array([
		((_camera.unproject_position(center) - _origin) * world_scale).rotated(-_facing_angle),
		((_camera.unproject_position(floor) - _origin) * world_scale).rotated(-_facing_angle)])

func _update_drink_prop() -> void:
	if not is_instance_valid(_drink_prop):
		return
	_drink_prop.visible = clip == "drink"
	var hand := _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand_bones[0])
	var axes := hand.basis.orthonormalized()
	_drink_prop.global_transform = Transform3D(Basis(axes.y, axes.x, -axes.z), hand.origin - axes.x * .0575 + axes.y * .09 - axes.z * .041)

func _cache_activity_morphs() -> void:
	_activity_grips.clear()
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		var index: int = mesh.find_blend_shape_by_name("CanGrip")
		if index >= 0:
			_activity_grips.append([mesh, index])

func configure(id: String, source_path := "") -> bool:
	_look_id = id
	# the stage (viewport, camera, lights) needs the tree: built in _ready
	if source_path != "" and source_path.ends_with(".glb"):
		# Review candidates can live outside Godot's imported asset directories.
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(source_path, state) != OK:
			return false
		_model = document.generate_scene(state)
		GLTF_MATERIALS.prepare(_model)
	else:
		var scene := load(source_path if source_path != "" else RT_PATH % [id, id]) as PackedScene
		if scene == null:
			return false
		_model = scene.instantiate()
	# Cass's imported body carries an emissive texture that washes out the red
	# coat and hand detail under the actor boost. Keep her skin and cloth lit
	# by the stage, with per-instance overrides so the imported asset stays intact.
	if id == "cass":
		for skin_mesh in _model.find_children("*", "MeshInstance3D", true, false):
			for skin_surface in skin_mesh.mesh.get_surface_count():
				var skin_material := skin_mesh.get_active_material(skin_surface) as StandardMaterial3D
				if skin_material != null and skin_material.emission_enabled:
					var lit_skin := skin_material.duplicate() as StandardMaterial3D
					lit_skin.emission_enabled = false
					skin_mesh.set_surface_override_material(skin_surface, lit_skin)
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skeletons.is_empty():
		return false
	_player = players[0]
	_skeleton = skeletons[0]
	_hand_bones = [_bone(["RightHand", "hand_r"]), _bone(["LeftHand", "hand_l"])]
	_hips = _bone(["Hips", "pelvis"])
	_head = _bone(["Head", "head"])
	_spine = []
	for n in ["Spine02", "Spine01", "Spine"]:
		var b := _bone([n])
		if b >= 0:
			_spine.append(b)
	_legs = [_bone(["LeftUpLeg"]), _bone(["LeftLeg"]), _bone(["RightUpLeg"]), _bone(["RightLeg"])]
	# the clip is advanced by hand each frame, so the spine twist can go on top
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	clips.clear()
	var anims := {}
	for n in _player.get_animation_list():
		if n == "RESET":
			continue
		clips[n] = true
		anims[n] = {"fps": 12.0}
		# Armed locomotion variants must loop too; otherwise they reach their
		# last frame and slide indefinitely while the body keeps travelling.
		var base_clip := n.trim_prefix("armed_").trim_prefix("dual_").trim_prefix("melee_")
		_player.get_animation(n).loop_mode = Animation.LOOP_LINEAR if base_clip in LOOPS else Animation.LOOP_NONE
	# CastSprite reads facings and fps from here; is_oblique() keys on "directions"
	metadata = {"px": PX, "meters": METERS, "fps": 12.0, "directions": 0, "anims": anims}
	directions = 0
	world_scale = METERS * 16.0 / PX
	scale = Vector2.ONE * world_scale
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	light_mask = 2
	material = _outline_material(float(LOOK_TONE.get(id, 0.88)))
	_cache_activity_morphs()
	return clips.has("idle") and clips.has("aim")

func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(PX, PX)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_build_stage()
	_viewport.add_child(_model)
	texture = _viewport.get_texture()
	_origin = _camera.unproject_position(Vector3.ZERO)
	offset = Vector2(PX * 0.5, PX * 0.5) - _origin

func _notification(what: int) -> void:
	# a model never staged (configure failed, or freed before _ready) is orphaned
	if what == NOTIFICATION_PREDELETE and _model and is_instance_valid(_model) and _model.get_parent() == null:
		_model.free()

func _build_stage() -> void:
	# The boss GLB has a pale, high-albedo costume; lower the shared stage
	# energy for it so the black vest and skin planes retain separation.
	var stage_energy: float = {"boss": 0.48, "fireman": 0.72, "scout": 0.24}.get(_look_id, 1.0)
	_camera = dress_stage(_viewport, METERS, LOOK_Z, stage_energy)

## The shared look of everything drawn in 3D (cast, hero car, ...): the fixed
## 50-degree ortho camera at PX / METERS pixels per metre, the same lights.
## `meters` is the frame height; the camera aims `look_z` above the ground point.
static func dress_stage(viewport: SubViewport, meters: float, look_z: float, energy := 1.0) -> Camera3D:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.72, 0.74, 0.9)
	env.environment.ambient_light_energy = 0.7 * energy
	viewport.add_child(env)
	# Characters are lit brighter than the night around them (the level's
	# CanvasModulate darkens everything again): warm key from the upper left,
	# a strong cool rim from behind that keeps dark clothes off the dark floor.
	for spec in [[Vector3(-2, 4, 1.5), 2.3, Color(1.0, 0.9, 0.78)], [Vector3(2, 2, -2.5), 1.5, Color(0.45, 0.85, 1.0)], [Vector3(2.5, 1, 1), 0.45, Color(1.0, 0.45, 0.75)]]:
		var light := DirectionalLight3D.new()
		light.light_energy = spec[1] * energy
		light.light_color = spec[2]
		viewport.add_child(light)
		light.look_at_from_position(spec[0], Vector3.ZERO)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = meters
	camera.near = 0.1
	camera.far = 100.0
	viewport.add_child(camera)
	var e := deg_to_rad(ELEVATION)
	var target := Vector3(0, look_z, 0)
	# screen down is world +Z (toward the camera), screen right is world +X
	camera.look_at_from_position(target + Vector3(0, sin(e), cos(e)) * 30.0, target)
	return camera

func _bone(names: Array) -> int:
	for n in names:
		var i := _skeleton.find_bone(n)
		if i >= 0:
			return i
	return -1

func play_sample(name: String, delta: float, progress := -1.0) -> void:
	name = _available(name)
	# Grip shapes belong to the resolved activity, never to the actor's next
	# combat pose. Existing models without these shapes are unaffected.
	for pair in _activity_grips:
		var mesh: MeshInstance3D = pair[0]
		if is_instance_valid(mesh):
			mesh.set_blend_shape_value(pair[1], 1.0 if name == "drink" else 0.0)
	if _camera == null:
		return   # not in the tree yet
	# Constant/untracked animation channels need not be rewritten by advance().
	# Remove last frame's procedural twist/tuck before sampling the next pose.
	for bone in _procedural_rotations:
		_skeleton.set_bone_pose_rotation(bone, _procedural_rotations[bone])
	_procedural_rotations.clear()
	var parent_2d := get_parent() as Node2D
	_facing_angle = parent_2d.global_rotation if parent_2d else 0.0
	global_rotation = 0.0
	# Hotline Miami style: legs and hips go where she moves, the upper body turns
	# to the aim. Past ~100 degrees apart she backpedals instead (legs face the
	# other way, the stride plays backwards) so the spine never twists too far.
	var body := _facing_angle
	var backwards := false
	if moving and progress < 0.0:
		body = move_angle
		if absf(angle_difference(move_angle, _facing_angle)) > deg_to_rad(100.0):
			body = move_angle + PI
			backwards = true
	_body_angle = lerp_angle(_body_angle, body, 1.0 - exp(-maxf(delta, 0.0) * 14.0)) if _body_init else body
	_body_init = true
	if OS.get_environment("CAST_DEBUG") == "1":
		print("cast ", clip, " moving=", moving, " move=", snappedf(move_angle, 0.01), " aim=", snappedf(_facing_angle, 0.01), " body=", snappedf(_body_angle, 0.01), " spine=", _spine)
	# the model faces +Z; game angle 0 is screen right (+X), PI/2 screen down (+Z)
	_model.rotation.y = PI * 0.5 - _body_angle
	if clip != name:
		clip = name
		clock = 0.0
		# Driven attacks seek directly to their pose; advancing only 1 ms below
		# would otherwise stretch the blend across most of the whole attack.
		_player.play(name, 0.0 if progress >= 0.0 else BLEND)
	else:
		clock += delta
		if progress >= 0.0 and not _driven_sample:
			# Activities can first arrive before their phase is initialized.
			# Cancel the old locomotion blend when they become pose-driven;
			# 1 ms sampling advances would otherwise stretch it over seconds.
			_player.play(name, 0.0)
	_driven_sample = progress >= 0.0
	var length := _player.get_animation(name).length
	# a driven clip never seeks to exactly its end: that wraps to frame 0
	_progress = clampf(progress, 0.0, 0.995) if progress >= 0.0 else fposmod(clock, maxf(length, 0.01)) / maxf(length, 0.01)
	if progress >= 0.0:
		# manual process mode: a seek alone doesn't pose the skeleton, and a zero
		# advance is skipped - land a hair early and advance onto the frame
		var at_t := _progress * length
		_player.seek(maxf(at_t - 0.001, 0.0), true)
		_player.advance(minf(0.001, at_t))
	else:
		# feet planted: a stride clip plays at the speed she actually travels
		# (its own pace, in game px/s, from NATIVE_SPEED). Slow collision
		# slides must slow the feet too; a minimum rate causes skating.
		var rate := 1.0
		var base := name.trim_prefix("armed_").trim_prefix("dual_").trim_prefix("melee_")
		if moving and NATIVE_SPEED.has(base):
			rate = clampf(move_speed / float(NATIVE_SPEED[base]), 0.0, 2.0)
		_player.advance((-delta if backwards else delta) * rate)
	# the twist, spread up the spine (after the clip has posed it this frame)
	var twist := -angle_difference(_body_angle, _facing_angle)
	if twist != 0.0:
		for i in _spine.size():
			var b: int = _spine[i]
			_rotate_pose_bone(b, Quaternion(Vector3.UP, twist * SPINE_SHARE[i]))
	# off screen nobody sees the model: stop rendering its viewport
	var at := get_global_transform_with_canvas().origin
	var onscreen := get_viewport_rect().grow(96.0).has_point(at)
	# hidden but on screen (in a car, a cutscene) keeps rendering: when it is shown
	# again its picture must already be the current pose, not one from seconds ago
	var live := onscreen
	if not live:
		# while it isn't drawing, its texture goes stale (seconds old, another
		# pose): stay transparent, so the first frame shown again isn't that
		_stale_frames = 2
	elif _viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED:
		_stale_frames = maxi(_stale_frames, 2)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
	if _stale_frames > 0:
		_stale_frames -= 1
		self_modulate.a = 0.0
	elif self_modulate.a == 0.0:
		self_modulate.a = 1.0
	# the roll: a real forward roll, the whole body going head over heels round
	# the waist (Meshy's "roll" is only a stumble), tucked low through the middle
	_model.rotation.x = 0.0
	_model.rotation.z = 0.0
	_model.position.y = 0.0
	if clip == "roll" and progress >= 0.0:
		var e := _progress * _progress * (3.0 - 2.0 * _progress)
		match roll_mode:
			0: _model.rotation.x = TAU * e
			1: _model.rotation.x = -TAU * e
			2: _model.rotation.z = TAU * e      # over to her right
			3: _model.rotation.z = -TAU * e
		var tuck := sin(_progress * PI)
		var pivot := Vector3(0.0, 0.55 - 0.15 * tuck, 0.0)
		var spun := Basis.from_euler(_model.rotation) * pivot
		_model.position.y = pivot.y - spun.y - 0.35 * tuck
		# tucked into a ball: knees to the chest, back rounded
		var t2 := clampf(tuck * 1.6, 0.0, 1.0)
		for pair in [[_legs[0], -1.75], [_legs[1], 2.1], [_legs[2], -1.75], [_legs[3], 2.1]]:
			if pair[0] >= 0:
				_rotate_pose_bone(pair[0], Quaternion(Vector3.RIGHT, float(pair[1]) * t2))
		for b in _spine:
			_rotate_pose_bone(b, Quaternion(Vector3.RIGHT, 0.45 * t2))
	# keep the hips over the ground point, as the baked renders follow them
	if _hips >= 0:
		var hips := _skeleton.to_global(_skeleton.get_bone_global_pose(_hips).origin)
		_model.position -= Vector3(hips.x, 0.0, hips.z)
	_update_drink_prop()

func grip(left := false) -> Vector2:
	var bone: int = _hand_bones[1 if left else 0]
	if bone < 0 or _camera == null:
		return Vector2.ZERO
	var at := _skeleton.to_global(_skeleton.get_bone_global_pose(bone).origin)
	var screen := (_camera.unproject_position(at) - _origin) * world_scale
	return screen.rotated(-_facing_angle)

func pelvis_point() -> Vector2:
	if _hips < 0 or _camera == null:
		return Vector2.ZERO
	var at := _skeleton.to_global(_skeleton.get_bone_global_pose(_hips).origin)
	return ((_camera.unproject_position(at) - _origin) * world_scale).rotated(-_facing_angle)

func seat_point() -> Vector2:
	# The root pelvis bone sits above the seat; thigh origins track the support.
	if _camera == null or _legs[0] < 0 or _legs[2] < 0:
		return pelvis_point()
	var left := _skeleton.to_global(_skeleton.get_bone_global_pose(_legs[0]).origin)
	var right := _skeleton.to_global(_skeleton.get_bone_global_pose(_legs[2]).origin)
	var at := (left + right) * 0.5
	return ((_camera.unproject_position(at) - _origin) * world_scale).rotated(-_facing_angle)

func face_point() -> Vector2:
	if _head < 0 or _camera == null:
		return grip()
	var at := _skeleton.to_global(_skeleton.get_bone_global_pose(_head).origin)
	return ((_camera.unproject_position(at) - _origin) * world_scale).rotated(-_facing_angle)

func grip_lift(left := false) -> Vector2:
	var bone: int = _hand_bones[1 if left else 0]
	if bone < 0 or _camera == null:
		return Vector2.ZERO
	var at := _skeleton.to_global(_skeleton.get_bone_global_pose(bone).origin)
	var floor := Vector3(at.x, 0.0, at.z)
	return (_camera.unproject_position(at) - _camera.unproject_position(floor)) * world_scale * global_scale.x / maxf(scale.x, 0.0001)

func weapon_angle() -> float:
	if clip != "melee":
		return 0.0
	if not clips.has("grab"):
		return -0.9 + 2.0 * sin(_progress * PI * 0.5)
	# Same preparation/contact/recovery landmarks as Blender's hand arc.
	var keys := [Vector2(0, 0.59), Vector2(0.22, -1.2), Vector2(0.58, 1.05), Vector2(1, 0.59)]
	for i in keys.size() - 1:
		if _progress <= keys[i + 1].x:
			var k := smoothstep(keys[i].x, keys[i + 1].x, _progress)
			return lerpf(keys[i].y, keys[i + 1].y, k) - 0.59
	return 0.0

static func _outline_material(lift := 0.88) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
// one dark texel round the silhouette, like the packed sprites
uniform float lift = 0.88;   // < 1 lifts dark clothes off a dark floor
varying vec4 tint;   // the node's modulate: the level's actor boost, hit flashes, fades
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.45) {
		float a = 0.0;
		a = max(a, texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a);
		a = max(a, texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a);
		COLOR = a > 0.45 ? vec4(0.055, 0.03, 0.08, tint.a) : vec4(0.0);
	} else {
		// lift the darks so navy reads as navy, not black, under the night grade
		COLOR = vec4(pow(c.rgb, vec3(lift)), 1.0) * tint;
	}
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("lift", lift)
	return mat

## Keep the animated, textured body while removing the actual severed region.
## Each instance receives its own mesh; shared imported resources stay intact.
func sever_part(part: String, retain_part := false) -> int:
	if not retain_part:
		var authored: int = preload("res://scripts/player/sever_meshes.gd").apply(self,part)
		if authored > 0: return authored
	var roots: Array = {"head":["Head", "Head1"],"arm":["RightArm"],"leg":["RightUpLeg"],"legs":["RightUpLeg","LeftUpLeg"]}.get(part,[])
	if part == "head" and _look_id == "heavy": roots.append("neck")
	if roots.is_empty(): return 0
	var selected: Array[int]=[]
	for index in _skeleton.get_bone_count():
		var ancestor:=index
		while ancestor>=0:
			if _skeleton.get_bone_name(ancestor) in roots:
				selected.append(index)
				break
			ancestor=_skeleton.get_bone_parent(ancestor)
	var removed:=0
	for object in _model.find_children("*","MeshInstance3D",true,false):
		var instance:=object as MeshInstance3D
		if not instance.mesh is ArrayMesh or instance.skin==null: continue
		var replacement:=ArrayMesh.new()
		for surface in instance.mesh.get_surface_count():
			var arrays:=instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for index in vertices.size(): indices.append(index)
			var keep:=PackedInt32Array()
			var influences: int=bones.size()/maxi(vertices.size(),1)
			for triangle in range(0,indices.size(),3):
				var cut:=false
				for corner in 3:
					var vertex:=indices[triangle+corner]
					var amount:=0.0
					for slot in influences:
						var bind:=bones[vertex*influences+slot]
						var bone:=instance.skin.get_bind_bone(bind)
						if bone<0: bone=_skeleton.find_bone(instance.skin.get_bind_name(bind))
						if bone in selected: amount+=weights[vertex*influences+slot]
					if amount>.45: cut=true
				if cut != retain_part: removed+=1
				else:
					for corner in 3: keep.append(indices[triangle+corner])
			if keep.is_empty(): continue
			arrays[Mesh.ARRAY_INDEX]=keep
			replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			replacement.surface_set_material(replacement.get_surface_count()-1,instance.mesh.surface_get_material(surface))
		instance.mesh=replacement
	return removed



