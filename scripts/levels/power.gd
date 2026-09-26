class_name Power
extends RefCounted
## Power & darkness: wall light switches, the darkness overlay drawn over
## blacked-out zones, and the shader that keeps a pool of vision around the
## player (bigger with night vision) and around burning flares.
##
## Switches can be flipped back on by guards (they walk over to fix it), fuse
## boxes that get smashed kill a zone for good.

const DARK_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform vec2 player_pos;
uniform float radius = 72.0;
uniform float strength = 0.66;
uniform float nv = 0.0;
uniform vec4 flares[4];
uniform float time = 0.0;
varying vec2 world;
void vertex() { world = VERTEX; }
void fragment() {
	float d = distance(world, player_pos);
	float a = strength * smoothstep(radius * 0.3, radius, d);
	for (int i = 0; i < 4; i++) {
		if (flares[i].z > 0.0) {
			float fd = distance(world, flares[i].xy);
			a *= mix(1.0, smoothstep(flares[i].z * 0.25, flares[i].z, fd), 1.0);
		}
	}
	// faint film grain in the dark so it never reads as a flat black box
	float g = fract(sin(dot(floor(world * 0.5) + floor(time * 12.0), vec2(12.9898, 78.233))) * 43758.5453);
	a *= 0.94 + g * 0.06;
	vec3 col = mix(vec3(0.02, 0.0, 0.05), vec3(0.0, 0.07, 0.02), nv);
	COLOR = vec4(col, a);
}
"""


## Wall-mounted light switch for one zone.
class Switch extends Node2D:
	var zone := "default"
	var level: Node
	var _t := 0.0
	var _flip := 0.0

	func _ready() -> void:
		add_to_group("interactable")
		add_to_group("switches")
		z_index = 3

	func is_on() -> bool:
		return level == null or not level.has_method("is_zone_dark") or not level.is_zone_dark(zone)

	func is_dead() -> bool:
		return level != null and level.dead_zones.has(zone)

	func can_interact(_p: Node) -> bool:
		return true

	func get_prompt() -> String:
		if is_dead():
			return "NO POWER"
		return "LIGHTS OFF" if is_on() else "LIGHTS ON"

	func interact(_by: Node) -> void:
		if is_dead() or level == null:
			Audio.play_at("empty", global_position, -6.0)
			return
		_flip = 0.2
		Audio.play_at("light_switch", global_position)
		level.set_zone_lights(zone, not is_on(), "switch")
		queue_redraw()

	## A guard flipping it back on.
	func enemy_use(_e: Node) -> void:
		if is_dead() or level == null or is_on():
			return
		_flip = 0.2
		Audio.play_at("light_switch", global_position)
		level.set_zone_lights(zone, true, "enemy")

	func _process(delta: float) -> void:
		_t += delta
		_flip = maxf(0.0, _flip - delta)
		if Engine.get_process_frames() % 4 == 0:
			queue_redraw()

	func _draw() -> void:
		var ink := Color("0b0710")
		var on := is_on()
		draw_rect(Rect2(-4.5, -5.5, 9, 11), ink)
		draw_rect(Rect2(-3.5, -4.5, 7, 9), Color(0.78, 0.74, 0.66))
		draw_rect(Rect2(-3.5, 1.5, 7, 3), Color(0.62, 0.58, 0.52))
		draw_rect(Rect2(-1.5, -3.0 if on else 0.0, 3, 3), ink)
		draw_rect(Rect2(-1.0, -2.5 if on else 0.5, 2, 2), Color(0.95, 0.92, 0.85))
		var led := Color(0.3, 1.0, 0.4) if on else Color(1.0, 0.25, 0.2)
		if is_dead():
			led = Color(0.25, 0.05, 0.05)
		draw_circle(Vector2(0, -6.5), 1.2, led)
		if not is_dead() and fmod(_t, 1.4) < 0.7:
			draw_circle(Vector2(0, -6.5), 2.4, Color(led, 0.25))


## Dark overlay over zones whose power is off.
class DarknessLayer extends Node2D:
	var level: Node
	var runs: Dictionary = {}        # zone -> Array[Rect2]
	var active: Array = []           # zones currently dark
	var _mat: ShaderMaterial
	var _nv_tinted := false
	var _t := 0.0

	func _ready() -> void:
		z_index = 36
		light_mask = 0
		var sh := Shader.new()
		sh.code = Power.DARK_SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		material = _mat

	func build(builder: LevelBuilder) -> void:
		runs.clear()
		var T := float(LevelBuilder.T)
		for y in builder.h:
			var cur := ""
			var x0 := 0
			for x in builder.w + 1:
				var z := builder.zone_at_cell(x, y) if x < builder.w else ""
				if z != cur:
					if cur != "":
						if not runs.has(cur):
							runs[cur] = []
						runs[cur].append(Rect2(x0 * T, y * T, (x - x0) * T, T))
					cur = z
					x0 = x

	func set_dark(zone: String, dark: bool) -> void:
		if dark and not active.has(zone):
			active.append(zone)
		elif not dark:
			active.erase(zone)
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		if active.is_empty() or level == null:
			if _nv_tinted:
				_nv_tinted = false
				PostFX.set_tint(Color(1, 1, 1, 0))
			return
		var p: Node2D = level.player
		if p == null or not is_instance_valid(p):
			return
		var nv: bool = p.has_method("has_upgrade") and p.has_upgrade(&"night_vision")
		_mat.set_shader_parameter("player_pos", p.global_position)
		_mat.set_shader_parameter("radius", 230.0 if nv else 78.0)
		_mat.set_shader_parameter("strength", 0.42 if nv else 0.7)
		_mat.set_shader_parameter("nv", 1.0 if nv else 0.0)
		_mat.set_shader_parameter("time", _t)
		var fl: Array[Vector4] = []
		for f in get_tree().get_nodes_in_group("flares"):
			if fl.size() < 4:
				fl.append(Vector4((f as Node2D).global_position.x, (f as Node2D).global_position.y, 120.0, 0))
		while fl.size() < 4:
			fl.append(Vector4.ZERO)
		_mat.set_shader_parameter("flares", fl)
		var in_dark: bool = level.is_zone_dark(level.zone_at(p.global_position))
		var want := nv and in_dark
		if want != _nv_tinted:
			_nv_tinted = want
			PostFX.set_tint(Color(0.55, 1.0, 0.55, 0.3) if want else Color(1, 1, 1, 0))

	func _draw() -> void:
		for z in active:
			for r in runs.get(z, []):
				draw_rect(r, Color.WHITE)
