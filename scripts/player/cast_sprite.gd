class_name CastSprite
extends Sprite2D
## Blender-rendered full-body clips. Gameplay movement remains in Player.
## Top-down clips turn with the rig. Oblique clips (meta "directions") are
## rendered from a fixed camera in N facings: the sprite stays upright, picks the
## facing nearest the rig's angle and stands its ground point on the character.
static var _cache: Dictionary = {}
var clips: Dictionary = {}
var metadata: Dictionary = {}
var clip := ""
var clock := 0.0
var frame_index := 0
var world_scale := 0.5
var directions := 1
var facing := 0              ## oblique only: the rendered facing in use
var _facing_angle := 0.0     ## the rig angle that facing was picked for
var _frame_fraction := 0.0
var _next_frame := 0
var _transition := 1.0
var _previous: Sprite2D
var _last_grips := [Vector2.ZERO, Vector2.ZERO]

func configure(id: String) -> bool:
	var path := "res://assets/art/cast3d/%s/meta.json" % id
	if not FileAccess.file_exists(path):
		return false
	if not _cache.has(id):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary or not parsed.has("anims"):
			return false
		var loaded: Dictionary = {}
		for name in parsed.anims:
			var source := load("res://assets/art/cast3d/%s/%s.png" % [id, name]) as Texture2D
			if source == null:
				continue
			var info: Dictionary = parsed.anims[name]
			var columns := int(info.get("columns", info.frames))
			var rows_per_dir := int(info.get("rows_per_dir", 0))
			var per_facing: Array = []
			for d in int(parsed.get("directions", 1)):
				var frames: Array[AtlasTexture] = []
				for i in int(info.frames):
					var frame := AtlasTexture.new()
					frame.atlas = source
					frame.region = Rect2((i % columns) * int(parsed.px), (d * rows_per_dir + i / columns) * int(parsed.px), int(parsed.px), int(parsed.px))
					frames.append(frame)
				per_facing.append(frames)
			# top-down clips keep their flat frame list
			loaded[name] = per_facing if parsed.has("directions") else per_facing[0]
		_cache[id] = {"meta": parsed, "clips": loaded}
	metadata = _cache[id].meta
	clips = _cache[id].clips
	world_scale = float(metadata.meters) * 16.0 / float(metadata.px)
	scale = Vector2.ONE * world_scale
	directions = int(metadata.get("directions", 1))
	if is_oblique():
		var origin: Array = metadata.origin
		offset = Vector2(float(metadata.px) * 0.5 - float(origin[0]), float(metadata.px) * 0.5 - float(origin[1]))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	light_mask = 2
	return clips.has("idle") and clips.has("aim")

func is_oblique() -> bool:
	return metadata.has("directions")

## A clip this character lacks falls back to its closest relative before idle:
## "armed_dual_walk" -> "armed_walk" -> "walk", "aim_melee" -> "aim".
func _available(name: String) -> String:
	var base := name.trim_prefix("armed_").trim_prefix("dual_").trim_prefix("melee_")
	var tries := [name, name.replace("dual_", "").replace("melee_", ""), base]
	# Missing crouch/run variants must keep a real stride, rather than sliding
	# in idle. Retain the armed posture where an armed walk exists.
	if base in ["walk", "run", "sneak"]:
		tries.append(name.trim_suffix(base) + "walk")
		tries.append("armed_walk" if name.begins_with("armed_") else "walk")
		tries.append("walk")
		tries.append("run")
	tries.append("aim" if name.begins_with("aim") or name.begins_with("reload") else "idle")
	for n in tries:
		if clips.has(n):
			return n
	return "idle"

func play_sample(name: String, delta: float, progress := -1.0) -> void:
	name = _available(name)
	if is_oblique():
		# stay upright; pick the facing nearest the rig's angle
		var parent_2d := get_parent() as Node2D
		var rig_angle: float = parent_2d.global_rotation if parent_2d else 0.0
		facing = posmod(roundi(rig_angle / TAU * directions), directions)
		_facing_angle = rig_angle
		global_rotation = 0.0
	if clip != name:
		if texture != null:
			_last_grips = [grip(), grip(true)]
			if _previous == null:
				_previous = Sprite2D.new()
				_previous.texture_filter = texture_filter
				_previous.light_mask = light_mask
				_previous.offset = offset
				add_child(_previous)
			_previous.texture = texture
			_transition = 0.0
		clip = name
		clock = 0.0
	else:
		clock += delta
	var frames: Array = clips[clip][facing] if is_oblique() else clips[clip]
	var rate := float(metadata.anims[clip].get("fps", metadata.fps))
	var phase := clampf(progress, 0.0, 1.0) * (frames.size() - 1) if progress >= 0.0 else fposmod(clock * rate, float(frames.size()))
	frame_index = int(phase)
	_frame_fraction = phase - frame_index
	_next_frame = mini(frame_index + 1, frames.size() - 1) if progress >= 0.0 else (frame_index + 1) % frames.size()
	_transition = minf(1.0, _transition + delta / 0.065)
	self_modulate.a = _transition
	if _previous:
		_previous.modulate.a = 1.0 - _transition
	texture = frames[frame_index]

func grip(left := false) -> Vector2:
	if clip.is_empty():
		return Vector2.ZERO
	var hands: Array = metadata.anims[clip].hands[facing] if is_oblique() else metadata.anims[clip].hands
	var point: Array = hands[frame_index][1 if left else 0]
	var next: Array = hands[_next_frame][1 if left else 0]
	var at := Vector2(float(point[0]), float(point[1])).lerp(Vector2(float(next[0]), float(next[1])), _frame_fraction) * world_scale
	if is_oblique():
		# screen offset from the ground point -> the rotating rig's own space
		at = at.rotated(-_facing_angle)
	return (_last_grips[1 if left else 0] as Vector2).lerp(at, _transition)

## How far up the screen (global px) a hand is drawn above the floor it stands
## over. Top-down and baked clips draw hands on the floor plane.
func grip_lift(_left := false) -> Vector2:
	return Vector2.ZERO

func weapon_angle() -> float:
	if clip.is_empty():
		return 0.0
	var angles: Array = metadata.anims[clip].get("angles", [])
	if angles.is_empty():
		return 0.0
	return lerp_angle(float(angles[frame_index]), float(angles[_next_frame]), _frame_fraction)
