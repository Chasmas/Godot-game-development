extends Node2D
## Staged Blender knife trail: translate only, no ill-conditioned affine stretch.
const Fit = preload("res://scripts/player/melee_texture_fit.gd")
var neighbor: Array
var fraction := 0.0
static var path_table: Dictionary = {}
static var packed_atlas: Texture2D
static var packed_table: Dictionary = {}
var driver: CharacterVisual
var serial := -1
var points: Array
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
	var heavy := OS.get_environment("KNIFE_TRAIL_HEAVY") == "1"
	var index := floori(facing) % 16 if heavy else roundi(facing) % 16
	fraction = facing - floorf(facing)
	neighbor = table.samples[(index + 1) % 16 + 16].points
	points = table.samples[index + 16].points
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
	var base := "res://build/melee_trail_review/measured_dense"
	var source := "actual_weapon_paths_16.json"
	if OS.get_environment("KNIFE_TRAIL_HEAVY") == "1":
		base += "/knife_heavy"
		source = "heavy_weapon_paths_16.json"
	elif OS.get_environment("KNIFE_TRAIL_EXTENDED") == "1":
		base += "/knife_extended"
		source = "extended_knife_paths_16.json"
	elif OS.get_environment("KNIFE_TRAIL_LONG") == "1":
		base += "/knife_long"
	packed_atlas = load(base + "/packed/knife.png")
	packed_table = JSON.parse_string(FileAccess.get_file_as_string(base + "/packed/knife.json"))
	path_table = JSON.parse_string(FileAccess.get_file_as_string("res://build/melee_trail_review/" + source))

static func supports(visual: CharacterVisual, weapon_id: StringName) -> bool:
	return visual != null and visual.cast_sprite is CastModel and visual.palette.begins_with("cass") and weapon_id == &"knife" and visual._heavy_swing == (OS.get_environment("KNIFE_TRAIL_HEAVY") == "1")

func _process(_delta: float) -> void:
	if not is_instance_valid(driver) or driver.attack_serial != serial or driver._swing_t < 0.0:
		queue_free()
		return
	var phase := clampf(driver._swing_t / driver._swing_dur, 0.0, 0.995)
	if phase < 0.22 or driver.cast_sprite.clip != ("melee" if OS.get_environment("KNIFE_TRAIL_HEAVY") == "1" else "stab"):
		visible = false
		return
	visible = true
	var pose := clampi(roundi(phase * 64.0), 0, 64)
	var tip: Array = points[pose].tip
	var head := Vector2(tip[0], tip[1])
	var basis := Transform2D.IDENTITY
	if OS.get_environment("KNIFE_TRAIL_HEAVY") == "1":
		var b: Array = neighbor[pose].tip
		var predicted := head.lerp(Vector2(b[0], b[1]), fraction)
		var source_vectors := []
		var target_vectors := []
		for sample in range(maxi(0, pose - 8), pose + 1):
			var a: Array = points[sample].tip
			var other: Array = neighbor[sample].tip
			var at := Vector2(a[0], a[1])
			source_vectors.append(at - head)
			target_vectors.append(at.lerp(Vector2(other[0], other[1]), fraction) - predicted)
		basis = Fit.fit(source_vectors, target_vectors)
	global_transform = Transform2D(basis.x * driver.global_scale, basis.y * driver.global_scale, driver.muzzle_tip_global() - basis.basis_xform(head) * driver.global_scale)
	sprite.texture = frames[pose]
	sprite.offset = frame_offsets[pose] if not frame_offsets.is_empty() else Vector2.ZERO
	modulate.a = 1.0 - clampf((phase - 0.62) / 0.38, 0.0, 1.0)
