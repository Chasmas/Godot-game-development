class_name LightFixture
extends Node2D
## A light source. Belongs to a zone (fuse boxes kill whole zones) and can
## be shot out if it's a lamp. Feeds the level's light-level queries used by
## enemy vision.

signal toggled(on: bool)

var zone := "default"
var radius_px := 96.0
var color := Color(1, 0.8, 0.55)
var energy := 1.0
var shadows := true
var flicker := false
var on := true
var light: PointLight2D
var halo: PointLight2D          ## wide, soft, unshadowed bloom: coloured pools of light on the floor
var _t := 0.0
var _base_energy := 1.0
var factor := 1.0            ## current brightness 0..1 (flicker)
var _out_t := 0.0
var _stutter := 0.0
var _next_evt := 2.0

func setup(p_zone: String, p_color: Color, p_radius: float, p_energy := 1.0, p_shadows := true, p_flicker := false) -> void:
	zone = p_zone
	color = p_color
	radius_px = p_radius
	energy = p_energy
	shadows = p_shadows
	flicker = p_flicker

func _ready() -> void:
	add_to_group("lights")
	light = PointLight2D.new()
	light.texture = SpriteLib.light_texture(256)
	light.texture_scale = radius_px * 2.0 / 256.0
	light.color = color
	light.energy = energy
	light.shadow_enabled = shadows
	light.shadow_color = Color(0, 0, 0, 0.6)
	light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	light.range_item_cull_mask = 1
	light.shadow_item_cull_mask = 1
	add_child(light)
	_base_energy = energy
	# one halo per cluster of lamps: they overlap anyway, and every extra light
	# pushes floor tiles past the per-item light limit (hard seams)
	for other in get_tree().get_nodes_in_group("light_halos"):
		if (other as Node2D).global_position.distance_to(global_position) < 120.0:
			_ready_motes()
			return
	add_to_group("light_halos")
	halo = PointLight2D.new()
	halo.texture = SpriteLib.light_texture(256)
	halo.texture_scale = radius_px * 2.6 / 256.0
	halo.color = Color(color.r, color.g, color.b).lerp(Color(color.r * 1.2, color.g * 0.85, color.b * 0.9), 0.35)
	halo.energy = energy * 0.34
	halo.shadow_enabled = false
	halo.range_item_cull_mask = 1
	add_child(halo)
	_ready_motes()

func _ready_motes() -> void:
	if zone != "exterior" and radius_px < 140.0:
		# dust motes drifting through the light
		var m := CPUParticles2D.new()
		m.amount = 7
		m.lifetime = 5.0
		m.preprocess = 5.0
		m.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		m.emission_sphere_radius = radius_px * 0.35
		m.gravity = Vector2(0, -2)
		m.initial_velocity_min = 1.0
		m.initial_velocity_max = 4.0
		m.direction = Vector2(1, 0)
		m.spread = 180.0
		m.scale_amount_min = 0.6
		m.scale_amount_max = 1.2
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 0.95, 0.85, 0.0))
		ramp.set_color(1, Color(1, 0.95, 0.85, 0.0))
		ramp.add_point(0.5, Color(1, 0.95, 0.85, 0.45))
		m.color_ramp = ramp
		m.z_index = 30
		m.light_mask = 2
		m.name = "Motes"
		add_child(m)
	_t = randf() * 10.0

func set_on(v: bool) -> void:
	if on == v:
		return
	on = v
	light.visible = v
	if halo:
		halo.visible = v
	if not v:
		factor = 1.0
	if has_node("Motes"):
		get_node("Motes").emitting = v
	toggled.emit(v)

func level_at(p: Vector2) -> float:
	if not on:
		return 0.0
	var d := p.distance_to(global_position)
	return clampf(1.0 - d / radius_px, 0.0, 1.0) * energy * factor

func _process(delta: float) -> void:
	if not flicker or not on:
		return
	_t += delta
	# a dying tube: steady hum, stutters, and now and then it cuts out entirely
	if _out_t > 0.0:
		_out_t -= delta
		factor = 0.55 if randf() < 0.04 else 0.0
		if _out_t <= 0.0:
			_stutter = randf_range(0.25, 0.5)
			_buzz()
	elif _stutter > 0.0:
		_stutter -= delta
		factor = 1.0 if randf() < 0.45 else randf_range(0.0, 0.25)
	else:
		factor = 0.9 + 0.1 * sin(_t * 50.0)
		_next_evt -= delta
		if _next_evt <= 0.0:
			_next_evt = randf_range(1.2, 4.5)
			if randf() < 0.35:
				_out_t = randf_range(0.7, 2.6)
			else:
				_stutter = randf_range(0.15, 0.6)
			_buzz()
	light.energy = _base_energy * factor
	if halo:
		halo.energy = _base_energy * 0.34 * factor
	if has_node("Motes"):
		get_node("Motes").emitting = factor > 0.3

func _buzz() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p and p.global_position.distance_to(global_position) < 220.0:
		Audio.play_at("buzz", global_position, -12.0, 0.2)
		if randf() < 0.3:
			Effects.sparks(global_position + Vector2(randf_range(-3, 3), randf_range(-3, 3)), Vector2.DOWN)
