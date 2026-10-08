class_name CheckpointMarker
extends Node2D
## A checkpoint on the floor just inside an area's door, centred on it:
## one thin ring of cyan light, breathing, with a faint column of light
## rising from it and a few motes drifting up. Step on it and it saves: the
## ring flashes gold, bursts outward as a wave across the floor, throws a
## handful of sparks, and is gone.

var active := false
var _t := 0.0
var _burst := -1.0           ## 0..1 while it's going, then it frees itself
var _light: PointLight2D
var _motes: Array = []
var _cassette: Sprite2D
var _neon_review := false
var _cassette_edge: Line2D

const R := 9.0

func _ready() -> void:
	z_index = -2
	_t = randf() * 3.0
	_light = PointLight2D.new()
	_light.texture = SpriteLib.light_texture(128)
	_light.texture_scale = 0.35
	_light.energy = 0.25
	_light.color = UIStyle.CYAN
	_light.range_item_cull_mask = 1
	add_child(_light)
	if OS.get_environment("CHECKPOINT_VHS_REVIEW") == "1":
		_neon_review = OS.get_environment("CHECKPOINT_NEON_REVIEW") == "1"
		var path := "res://assets/art/reference/checkpoints/neon_checkpoint_candidate_v1.png" if _neon_review else "res://assets/art/reference/checkpoints/vhs_checkpoint_candidate_v1.png"
		var image := Image.load_from_file(path)
		if image and not image.is_empty():
			_cassette = Sprite2D.new()
			_cassette.texture = ImageTexture.create_from_image(image)
			_cassette.region_enabled = true
			_cassette.region_rect = Rect2(220,230,1100,560)
			_cassette.scale = Vector2.ONE * (14.0 / 1100.0)
			if _neon_review:
				_cassette.region_rect = image.get_used_rect()
				_cassette.scale = Vector2.ONE * (12.0 / _cassette.region_rect.size.x)
				var shader := Shader.new()
				shader.code = "shader_type canvas_item; render_mode unshaded, blend_add; uniform float gain = 1.0; void fragment(){ COLOR = texture(TEXTURE, UV) * COLOR; COLOR.rgb *= gain; }"
				var neon_material := ShaderMaterial.new()
				neon_material.shader = shader
				_cassette.material = neon_material
				_cassette_edge = Line2D.new()
				_cassette_edge.points = PackedVector2Array([Vector2(0,-4),Vector2(0,4)])
				_cassette_edge.width = 0.65
				_cassette_edge.default_color = UIStyle.CYAN
				_cassette_edge.material = neon_material
				_cassette_edge.visible = false
				add_child(_cassette_edge)
			_cassette.light_mask = 2
			add_child(_cassette)
			_light.energy = 0.06
			_light.texture_scale = 0.12
	for i in 5:
		_motes.append(Vector3(randf_range(-R, R) * 0.6, randf(), randf_range(0.6, 1.2)))

## silent: restored from a checkpoint - it's already been taken, so it's gone.
func activate(silent := false) -> void:
	if active:
		return
	active = true
	if silent:
		queue_free()
		return
	_burst = 0.0
	if _neon_review: _t = 0.0
	_light.color = UIStyle.CYAN if _cassette else UIStyle.GOLD

func _process(delta: float) -> void:
	_t += delta
	if _cassette:
		if _neon_review:
			# A tilted plane turning around its vertical axis. Signed width
			# exposes the reverse face, while a slight shear suggests depth.
			var phase := _t * 0.55
			var width := cos(phase)
			var base_scale := 12.0 / _cassette.region_rect.size.x
			_cassette.rotation = deg_to_rad(-25.0) + sin(phase) * 0.06
			_cassette.scale = Vector2(base_scale * width,base_scale * 0.86)
			_cassette.skew = sin(phase) * 0.12
			_cassette_edge.rotation = _cassette.rotation
			_cassette_edge.visible = absf(width) < 0.18
		if _burst >= 0.0:
			_burst += delta / 0.6
			if _neon_review:
				var pulse := 0.0 if SaveManager.settings.get("reduced_flashing",false) else sin(clampf(_burst,0.0,1.0)*PI)*0.4
				(_cassette.material as ShaderMaterial).set_shader_parameter("gain",1.0+pulse)
			_cassette.modulate.a = 1.0 - clampf(_burst,0.0,1.0)
			if _cassette_edge: _cassette_edge.modulate.a = _cassette.modulate.a
			_light.energy = 0.10 * (1.0 - clampf(_burst,0.0,1.0))
			if _burst >= 1.0: queue_free()
		return
	if _burst >= 0.0:
		_burst += delta / 0.9
		_light.energy = 1.6 * (1.0 - _burst)
		_light.texture_scale = 0.35 + _burst * 0.8
		if _burst >= 1.0:
			queue_free()
			return
	else:
		_light.energy = 0.2 + 0.12 * sin(_t * 2.4)
	queue_redraw()

func _draw() -> void:
	if _cassette:
		return
	if _burst >= 0.0:
		var k := _burst
		var e := 1.0 - pow(1.0 - k, 3.0)
		# the wave across the floor, gold into pink
		draw_arc(Vector2.ZERO, R + e * 46.0, 0, TAU, 48, Color(UIStyle.GOLD, (1.0 - k) * 0.9), 2.0 * (1.0 - k) + 0.5)
		draw_arc(Vector2.ZERO, R + e * 28.0, 0, TAU, 40, Color(UIStyle.PINK, (1.0 - k) * 0.5), 1.0)
		draw_circle(Vector2.ZERO, R * (1.0 - k), Color(1, 0.95, 0.75, (1.0 - k) * 0.5))
		# sparks flung out and up
		for i in 10:
			var a := i * TAU / 10.0 + 0.3
			var p := Vector2.from_angle(a) * (R + e * 24.0) + Vector2(0, -e * 10.0 * (0.5 + 0.5 * sin(i * 3.0)))
			draw_rect(Rect2(p, Vector2(1.5, 1.5)), Color(1, 0.9, 0.6, 1.0 - k))
		return
	var breathe := 0.5 + 0.5 * sin(_t * 2.4)
	var col := UIStyle.CYAN
	# the ring: thin, with a soft halo
	draw_arc(Vector2.ZERO, R, 0, TAU, 40, Color(col, 0.18), 3.5)
	draw_arc(Vector2.ZERO, R, 0, TAU, 40, Color(col, 0.55 + 0.35 * breathe), 1.0)
	# a faint column of light rising off it
	for i in 6:
		var h := 4.0 + i * 3.0
		draw_line(Vector2(-R * 0.7, -h), Vector2(R * 0.7, -h), Color(col, 0.06 * (1.0 - i / 6.0) * (0.6 + 0.4 * breathe)), 2.0)
	# motes drifting up
	for m in _motes:
		var y := -fmod(m.y * 20.0 + _t * 8.0 * m.z, 20.0)
		var fade := 1.0 - (-y / 20.0)
		draw_rect(Rect2(Vector2(m.x, y), Vector2(1, 1)), Color(col.lightened(0.4), 0.6 * fade))
