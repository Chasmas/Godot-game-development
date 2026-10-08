extends Node2D
## Blender-rendered heavy knife trail following the authored Cass weapon path.
const Fit = preload("res://scripts/player/melee_texture_fit.gd")
static var path_table: Dictionary = {}
static var packed_atlas: Texture2D
static var packed_table: Dictionary = {}
var driver: CharacterVisual
var serial := -1
var points: Array
var neighbor: Array
var fraction := 0.0
var frames: Array[Texture2D] = []
var sprite: Sprite2D
var frame_offsets: Array[Vector2] = []
var prewarm_ms := 0.0
func configure(visual: CharacterVisual, facing_angle := INF) -> void:
	driver = visual
	serial = driver.attack_serial
	process_priority = 100
	z_index = 25
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	prewarm()
	var table := path_table
	var facing := fposmod(facing_angle if is_finite(facing_angle) else driver._attack_angle, TAU) * 16.0 / TAU
	var index := floori(facing) % 16
	fraction = facing - floorf(facing)
	points = table.samples[index].points
	neighbor = table.samples[(index + 1) % 16].points
	var started := Time.get_ticks_usec()
	var heading: Dictionary = packed_table.frames[str(index * 22.5).trim_suffix(".0")]
	for frame in 65:
		var entry: Dictionary = heading["%03d" % frame]
		var region: Array = entry.region
		var texture := AtlasTexture.new()
		texture.atlas = packed_atlas
		texture.region = Rect2(region[0], region[1], region[2], region[3])
		texture.filter_clip = true
		frames.append(texture)
		frame_offsets.append(Vector2(entry.offset[0], entry.offset[1]))
	prewarm_ms = (Time.get_ticks_usec() - started) / 1000.0
	sprite = Sprite2D.new()
	sprite.scale = Vector2.ONE * 80.0 / 256.0
	add_child(sprite)
	visible = false
static func prewarm() -> void:
	if packed_atlas != null:
		return
	packed_atlas = load("res://assets/art/blender_fx/melee/knife_heavy.png")
	packed_table = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/blender_fx/melee/knife_heavy.json"))
	path_table = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/blender_fx/melee/knife_heavy_paths.json"))

static func supports(visual: CharacterVisual, weapon_id: StringName) -> bool:
	return visual != null and visual.cast_sprite is CastModel and visual.palette.begins_with("cass") and weapon_id == &"knife" and visual._heavy_swing and visual.cast_sprite.clips.has("melee")

func _process(_delta: float) -> void:
	if not is_instance_valid(driver) or driver.attack_serial != serial or driver._swing_t < 0.0:
		queue_free()
		return
	var phase := clampf(driver._swing_t / driver._swing_dur, 0.0, 0.995)
	if phase < 0.22 or driver.cast_sprite.clip != "melee":
		visible = false
		return
	visible = true
	var pose := clampi(roundi(phase * 64.0), 0, 64)
	var tip: Array = points[pose].tip
	var second_tip: Array = neighbor[pose].tip
	var head := Vector2(tip[0], tip[1])
	var predicted_head := head.lerp(Vector2(second_tip[0], second_tip[1]), fraction)
	var source_vectors := []
	var target_vectors := []
	for sample in range(maxi(0, pose - 8), pose + 1):
		var a: Array = points[sample].tip
		var b: Array = neighbor[sample].tip
		var at := Vector2(a[0], a[1])
		source_vectors.append(at - head)
		target_vectors.append(at.lerp(Vector2(b[0], b[1]), fraction) - predicted_head)
	var basis: Transform2D = Fit.fit(source_vectors, target_vectors)
	global_transform = Transform2D(basis.x * driver.global_scale, basis.y * driver.global_scale, driver.muzzle_tip_global() - basis.basis_xform(head) * driver.global_scale)
	sprite.texture = frames[pose]
	sprite.offset = frame_offsets[pose] if not frame_offsets.is_empty() else Vector2.ZERO
	modulate.a = 1.0 - clampf((phase - 0.62) / 0.38, 0.0, 1.0)
