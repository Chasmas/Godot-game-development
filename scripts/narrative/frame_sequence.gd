class_name FrameSequence
extends Control
## Optional rendered animation layer for Blender PNG sequences or sprite sheets.
## A missing sequence is harmless: callers keep their reviewed still fallback.

signal finished

var frames: Array[Texture2D] = []
var fps := 12.0
var loop := false
var playing := true
var frame := 0
var elapsed := 0.0
var hold_last := true
var _finished_emitted := false

func configure_reviewed(sequence_path: String, shot_id := "") -> bool:
	# Rejecting a replacement must not leave the old approved shot on screen.
	frames.clear()
	frame = 0
	elapsed = 0.0
	playing = false
	set_process(false)
	queue_redraw()
	var manifest_path := sequence_path.path_join("sequence.json")
	if not FileAccess.file_exists(manifest_path):
		return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary or not bool(manifest.get("approved", false)):
		return false
	if shot_id != "" and str(manifest.get("shot", "")) != shot_id:
		return false
	if shot_id == "" and not bool(manifest.get("whole_scene", false)):
		return false
	if not configure(sequence_path, float(manifest.get("fps", 12.0)), bool(manifest.get("loop", false))):
		return false
	if frames.size() < 2 or frames.size() != int(manifest.get("frame_count", 0)):
		frames.clear()
		return false
	return true

func configure(sequence_path: String, rate := 12.0, should_loop := false) -> bool:
	fps = maxf(rate, 1.0)
	loop = should_loop
	frames.clear()
	frame = 0
	elapsed = 0.0
	_finished_emitted = false
	# Numbered renders: frame_0001.png, frame_0002.png ...
	var dir := DirAccess.open(sequence_path)
	if dir == null:
		return false
	var names: Array[String] = []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and (name.to_lower().ends_with(".png") or name.to_lower().ends_with(".webp")):
			names.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	names = ordered_render_names(names)
	for n in names:
		var tex := load(sequence_path.path_join(n)) as Texture2D
		if tex:
			frames.append(tex)
	if frames.is_empty():
		return false
	queue_redraw()
	return true

static func ordered_render_names(candidates: Array[String]) -> Array[String]:
	var indexed := {}
	for candidate in candidates:
		if not candidate.begins_with("frame_"): continue
		var number := candidate.get_basename().trim_prefix("frame_")
		if not number.is_valid_int(): continue
		var index := int(number)
		if index < 1 or indexed.has(index): return []
		indexed[index] = candidate
	var result: Array[String] = []
	for index in range(1,indexed.size()+1):
		if not indexed.has(index): return []
		result.append(str(indexed[index]))
	return result

func configure_textures(source: Array[Texture2D], rate := 12.0, should_loop := false) -> bool:
	frames = source.duplicate()
	fps = maxf(rate, 1.0)
	loop = should_loop
	frame = 0
	elapsed = 0.0
	_finished_emitted = false
	queue_redraw()
	return not frames.is_empty()

func configure_spritesheet(sheet: Texture2D, columns: int, rows: int, rate := 12.0, should_loop := false) -> bool:
	## Accept a Blender-packed atlas without requiring a separate import plugin.
	if sheet == null or columns < 1 or rows < 1:
		return false
	var atlas: Array[Texture2D] = []
	var cell := Vector2(sheet.get_width() / columns, sheet.get_height() / rows)
	for y in rows:
		for x in columns:
			var region := AtlasTexture.new()
			region.atlas = sheet
			region.region = Rect2(Vector2(x, y) * cell, cell)
			atlas.append(region)
	return configure_textures(atlas, rate, should_loop)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func play() -> void:
	playing = true
	set_process(not frames.is_empty())

func pause() -> void:
	playing = false

func _process(delta: float) -> void:
	if not playing or frames.is_empty():
		return
	elapsed += maxf(delta, 0.0)
	var step := 1.0 / fps
	var advance := int(floor(elapsed / step))
	if advance <= 0:
		return
	elapsed = fmod(elapsed, step)
	if loop:
		frame = (frame + advance) % frames.size()
		queue_redraw()
		return
	if advance < frames.size() - frame:
		frame += advance
		queue_redraw()
		return
	frame = frames.size() - 1
	playing = false
	set_process(false)
	if not hold_last:
		frames.clear()
	queue_redraw()
	if not _finished_emitted:
		_finished_emitted = true
		# No mutation after the callback: it may start the next shot.
		finished.emit()

func _draw() -> void:
	if frames.is_empty() or frames[frame] == null:
		return
	var tex := frames[frame]
	var dst := _cover_rect(Vector2(tex.get_width(), tex.get_height()))
	draw_texture_rect(tex, dst, false)

func _cover_rect(source: Vector2) -> Rect2:
	if size.x <= 1.0 or size.y <= 1.0 or source.x <= 0.0 or source.y <= 0.0:
		return Rect2(Vector2.ZERO, size)
	var scale := maxf(size.x / source.x, size.y / source.y)
	var out := source * scale
	return Rect2((size - out) * 0.5, out)
