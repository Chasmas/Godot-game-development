class_name CastSprite
extends Sprite2D
## Blender-rendered full-body clips. Gameplay movement remains in Player.
static var _cache: Dictionary = {}
var clips: Dictionary = {}
var metadata: Dictionary = {}
var clip := ""
var clock := 0.0
var frame_index := 0
var world_scale := 0.5
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
			var frames: Array[AtlasTexture] = []
			for i in int(parsed.anims[name].frames):
				var frame := AtlasTexture.new()
				frame.atlas = source
				var columns := int(parsed.anims[name].get("columns", parsed.anims[name].frames))
				frame.region = Rect2((i % columns) * int(parsed.px), (i / columns) * int(parsed.px), int(parsed.px), int(parsed.px))
				frames.append(frame)
			loaded[name] = frames
		_cache[id] = {"meta": parsed, "clips": loaded}
	metadata = _cache[id].meta
	clips = _cache[id].clips
	world_scale = float(metadata.meters) * 16.0 / float(metadata.px)
	scale = Vector2.ONE * world_scale
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	light_mask = 2
	return clips.has("idle") and clips.has("aim")

func play_sample(name: String, delta: float, progress := -1.0) -> void:
	if not clips.has(name):
		name = "idle"
	if clip != name:
		if texture != null:
			_last_grips = [grip(), grip(true)]
			if _previous == null:
				_previous = Sprite2D.new()
				_previous.texture_filter = texture_filter
				_previous.light_mask = light_mask
				add_child(_previous)
			_previous.texture = texture
			_transition = 0.0
		clip = name
		clock = 0.0
	else:
		clock += delta
	var frames: Array = clips[clip]
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
	var pair: Array = metadata.anims[clip].hands[frame_index]
	var point: Array = pair[1 if left else 0]
	var next: Array = metadata.anims[clip].hands[_next_frame][1 if left else 0]
	var at := Vector2(float(point[0]), float(point[1])).lerp(Vector2(float(next[0]), float(next[1])), _frame_fraction) * world_scale
	return (_last_grips[1 if left else 0] as Vector2).lerp(at, _transition)

func weapon_angle() -> float:
	if clip.is_empty():
		return 0.0
	var angles: Array = metadata.anims[clip].get("angles", [])
	if angles.is_empty():
		return 0.0
	return lerp_angle(float(angles[frame_index]), float(angles[_next_frame]), _frame_fraction)
