class_name BreakableProp
extends StaticBody2D
## Solid props that react to damage: TVs, vending machines, arcade cabinets,
## floor lamps (turn off their light), plants, fuse boxes (kill a light zone),
## weak walls (secret passages), propane tanks (see ExplosiveTank).

signal broken(prop: BreakableProp)

var kind := "tv"
var size := Vector2(12, 10)
var hp := 2
var is_broken := false
var hit_radius := 8.0
var zone := ""
var solid_after_break := true
var light: LightFixture
var _t := 0.0

const DEFS := {
	"tv":      {"hp": 1, "size": Vector2(12, 9), "sfx": "tv_break", "layer": Layers.PROP},
	"vending": {"hp": 4, "size": Vector2(16, 12), "sfx": "glass", "layer": Layers.PROP},
	"arcade":  {"hp": 3, "size": Vector2(14, 12), "sfx": "tv_break", "layer": Layers.PROP},
	"lamp":    {"hp": 1, "size": Vector2(6, 6), "sfx": "glass", "layer": Layers.PROP},
	"plant":   {"hp": 1, "size": Vector2(10, 10), "sfx": "bottle_break", "layer": Layers.LOW},
	"fuse":    {"hp": 2, "size": Vector2(10, 6), "sfx": "spark", "layer": Layers.PROP},
	"weak_wall": {"hp": 3, "size": Vector2(16, 16), "sfx": "door_break", "layer": Layers.WORLD},
	"ice":     {"hp": 3, "size": Vector2(14, 12), "sfx": "metal_clang", "layer": Layers.PROP},
}

func setup(p_kind: String, center: Vector2, p_zone := "") -> void:
	kind = p_kind
	position = center
	zone = p_zone
	var d: Dictionary = DEFS.get(kind, DEFS["tv"])
	hp = d.hp
	size = d.size

func _ready() -> void:
	add_to_group("damageable")
	add_to_group("props")
	var d: Dictionary = DEFS.get(kind, DEFS["tv"])
	collision_layer = d.layer
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	add_child(cs)
	hit_radius = maxf(size.x, size.y) * 0.5
	# standing props share the cast's layer and y-sort with them (Level)
	z_index = 3 if kind == "weak_wall" else 1
	if kind == "weak_wall":
		light_mask = 2
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		var h := size * 0.5
		poly.polygon = PackedVector2Array([-h, Vector2(h.x, -h.y), h, Vector2(-h.x, h.y)])
		occ.occluder = poly
		occ.name = "Occluder"
		add_child(occ)
	set_process(kind in ["tv", "arcade", "vending", "fuse"])
	if kind == "fuse":
		add_to_group("interactable")

# fuse boxes can be sabotaged by hand (quiet) or smashed / shot (loud)
func can_interact(_p: Node) -> bool:
	return kind == "fuse" and not is_broken

func get_prompt() -> String:
	return "CUT THE POWER"

func interact(by: Node) -> void:
	if kind != "fuse" or is_broken:
		return
	var info := DamageInfo.make(DamageInfo.Type.MELEE, by, global_position, global_position - (by as Node2D).global_position, &"hands", &"melee")
	_break(info, true)

func hit_point(from: Vector2) -> Vector2:
	var half := size * 0.5
	return global_position + (from - global_position).clamp(-half, half)

func take_damage(info: DamageInfo) -> String:
	if is_broken:
		return "pass" if not solid_after_break else "blocked"
	if kind == "weak_wall" and info.type == DamageInfo.Type.BALLISTIC and info.weapon_id != &"shotgun":
		Effects.debris(info.pos, -info.dir)
		return "blocked"
	hp -= 3 if (info.type == DamageInfo.Type.EXPLOSIVE or info.heavy) else 1
	if kind == "plant":
		Effects.debris(info.pos, -info.dir)
	else:
		Effects.sparks(info.pos, -info.dir)
	if hp <= 0:
		_break(info)
	return "blocked" if solid_after_break or kind == "weak_wall" else "pass"

func _break(info: DamageInfo, quiet := false) -> void:
	is_broken = true
	var d: Dictionary = DEFS.get(kind, DEFS["tv"])
	Audio.play_at(d.sfx, global_position, -6.0 if quiet else 0.0)
	if not quiet:
		Events.noise.emit(global_position, 200.0, &"glass", null)
	match kind:
		"lamp":
			if light:
				light.set_on(false)
			Effects.glass(global_position, info.dir)
			solid_after_break = false
			collision_layer = 0
		"plant":
			Effects.debris(global_position, info.dir)
			solid_after_break = false
			collision_layer = 0
		"fuse":
			var lvl := get_tree().get_first_node_in_group("level")
			if lvl and lvl.has_method("set_zone_lights"):
				lvl.set_zone_lights(zone, false, "fuse")
			Effects.sparks(global_position, info.dir)
			Audio.play_at("power_down", global_position)
			if info.from_player:
				Score.add_bonus("LIGHTS OUT", 500, global_position)
		"weak_wall":
			collision_layer = 0
			solid_after_break = false
			if has_node("Occluder"):
				get_node("Occluder").queue_free()
			for i in 5:
				Effects.debris(global_position + Vector2(randf_range(-6, 6), randf_range(-6, 6)), info.dir)
			Effects.smoke(global_position)
			var lvl := get_tree().get_first_node_in_group("level")
			if lvl and lvl.has_method("on_secret_found"):
				lvl.on_secret_found("weak_wall_%d_%d" % [int(position.x), int(position.y)])
		"tv", "arcade":
			Effects.sparks(global_position, info.dir)
			Effects.smoke(global_position)
		"vending":
			Effects.glass(global_position, info.dir)
	broken.emit(self)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	if Engine.get_process_frames() % 6 == 0:
		queue_redraw()

func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	var ink := Color(0.06, 0.03, 0.08)
	var painted := {"tv": "tv_crt", "ice": "ice_machine"}
	if painted.has(kind) and not is_broken:
		var ptex := ArtLib.sprite(painted[kind])
		if ptex:
			draw_rect(Rect2(r.position + Vector2(1.5, 2), r.size), Color(0, 0, 0, 0.3))
			ArtLib.draw_fitted(self, ptex, r.grow(1.5))
			if kind == "tv":
				# the screen's glow spilling off the front edge
				var n := sin(_t * 23.0) * 0.5 + 0.5
				draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.2), Color(0.45 + n * 0.2, 0.65, 0.95, 0.8))
			return
	match kind:
		"tv":
			draw_rect(r, Color(0.2, 0.17, 0.2))
			draw_rect(r, ink, false, 1.0)
			var scr := r.grow(-2)
			if is_broken:
				draw_rect(scr, Color(0.05, 0.05, 0.06))
				# readable CRT star crack plus two secondary fractures
				var c := scr.get_center()
				draw_line(c, scr.position + Vector2(2, 1), Color(0.75, 0.82, 0.9), 1.0)
				draw_line(c, scr.position + Vector2(scr.size.x - 2, 2), Color(0.55, 0.65, 0.78), 1.0)
				draw_line(c, scr.position + Vector2(scr.size.x - 3, scr.size.y - 2), Color(0.48, 0.58, 0.7), 1.0)
				draw_circle(c, 1.2, Color(0.8, 0.9, 1.0, 0.8))
			else:
				var n := sin(_t * 23.0) * 0.5 + 0.5
				draw_rect(scr, Color(0.35 + n * 0.2, 0.55 + n * 0.1, 0.85))
				for i in 3:
					var y := scr.position.y + fmod(_t * 12.0 + i * 3.0, scr.size.y)
					draw_line(Vector2(scr.position.x, y), Vector2(scr.end.x, y), Color(1, 1, 1, 0.4))
		"arcade":
			draw_rect(r, Color(0.15, 0.1, 0.3))
			draw_rect(r, ink, false, 1.0)
			var scr2 := Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, r.size.y * 0.55))
			draw_rect(scr2, Color(0.05, 0.05, 0.06) if is_broken else Color.from_hsv(fmod(_t * 0.2, 1.0), 0.8, 0.9))
			if is_broken:
				var ac := scr2.get_center()
				draw_line(ac, scr2.position + Vector2(1, 1), Color(0.85, 0.9, 1.0), 1.0)
				draw_line(ac, scr2.position + Vector2(scr2.size.x - 1, scr2.size.y - 1), Color(0.5, 0.65, 0.9), 1.0)
				if fmod(_t, 0.55) < 0.08:
					draw_circle(r.position + Vector2(r.size.x - 2, 2), 1.2, Color(1.0, 0.75, 0.2))
			draw_rect(Rect2(r.position + Vector2(3, r.size.y - 4), Vector2(r.size.x - 6, 2)), UIStyle.PINK)
		"vending":
			draw_rect(r, Color(0.75, 0.1, 0.18))
			draw_rect(r, ink, false, 1.0)
			var win := Rect2(r.position + Vector2(2, 2), Vector2(r.size.x * 0.6, r.size.y - 4))
			draw_rect(win, Color(0.1, 0.1, 0.12) if is_broken else Color(0.7, 0.9, 1.0, 0.8))
			if not is_broken:
				for i in 3:
					draw_rect(Rect2(win.position + Vector2(1 + i * 3, 2), Vector2(2, 3)), [UIStyle.GOLD, UIStyle.CYAN, Color.WHITE][i])
			else:
				# jagged glass fragments remain readable at the game's pixel scale
				draw_line(win.position + Vector2(1, 1), win.end - Vector2(2, 2), Color(0.75, 0.9, 1.0), 1.0)
				draw_line(win.position + Vector2(win.size.x - 2, 1), win.position + Vector2(3, win.size.y - 2), Color(0.55, 0.75, 0.9), 1.0)
				for i in 2:
					draw_rect(Rect2(win.position + Vector2(2 + i * 5, win.size.y - 2), Vector2(2, 1)), Color(0.65, 0.8, 0.95))
		"lamp":
			draw_circle(Vector2.ZERO, 3.5, ink)
			draw_circle(Vector2.ZERO, 2.5, Color(0.3, 0.3, 0.3) if is_broken else Color(1, 0.95, 0.7))
		"plant":
			var ptx := ArtLib.sprite("plant") if not is_broken else null
			if ptx:
				draw_circle(Vector2(1, 2), 6.0, Color(0, 0, 0, 0.3))
				draw_texture_rect(ptx, Rect2(-7, -7, 14, 14), false)
			elif is_broken:
				# overturned pot: soil and leaves stay low to the floor and never
				# become a navigation obstacle.
				draw_circle(Vector2(-1, 1), 3.0, Color(0.35, 0.2, 0.1))
				for i in 4:
					var a := -0.8 + i * 0.55
					draw_line(Vector2(-1, 1), Vector2.from_angle(a) * (5.0 + i % 2), Color(0.2, 0.5, 0.22), 1.0)
			else:
				draw_circle(Vector2.ZERO, 4.5, Color(0.55, 0.28, 0.12))
				for i in 6:
					var a := i * TAU / 6.0 + 0.3
					draw_line(Vector2.ZERO, Vector2.from_angle(a) * 6.5, Color(0.2, 0.6, 0.3), 2.0)
		"fuse":
			# PixelLab supplies two authored, immediately distinct states.  Keep
			# the original 10x6 collision below the wall-mounted painting so the
			# gameplay footprint and navigation do not change.
			var fuse_tex := ArtLib.sprite("fuse_box_off" if is_broken else "fuse_box_on")
			if fuse_tex:
				var visual_rect := Rect2(-7, -10, 14, 14)
				draw_rect(Rect2(visual_rect.position + Vector2(1, 1.5), visual_rect.size), Color(0, 0, 0, 0.28))
				ArtLib.draw_fitted(self, fuse_tex, visual_rect)
			else:
				draw_rect(r, Color(0.45, 0.48, 0.5))
				draw_rect(r, ink, false, 1.0)
				draw_rect(Rect2(r.position + Vector2(2, 1), Vector2(2, 2)), Color(0.2, 1.0, 0.3) if not is_broken else Color(0.3, 0.05, 0.05))
			if is_broken and fmod(_t, 0.8) < 0.1:
				draw_circle(Vector2(randf_range(-3, 3), randf_range(-2, 2)), 1.5, Color(1, 1, 0.6))
		"weak_wall":
			if not is_broken:
				draw_rect(r, Color(0.86, 0.74, 0.62))
				draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x, 3)), Color(0.6, 0.48, 0.4))
				draw_line(r.position + Vector2(4, 4), r.position + Vector2(9, 10), Color(0.55, 0.45, 0.38), 1.0)
				draw_line(r.position + Vector2(9, 10), r.position + Vector2(7, 14), Color(0.55, 0.45, 0.38), 1.0)
			else:
				for i in 4:
					draw_rect(Rect2(Vector2(randf_range(-7, 5), randf_range(-7, 5)), Vector2(3, 2)), Color(0.7, 0.6, 0.5))
		"ice":
			draw_rect(r, Color(0.75, 0.8, 0.85))
			draw_rect(r, ink, false, 1.0)
			draw_string(UIStyle.font_bold(), r.position + Vector2(1, 8), "ICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.2, 0.5, 0.9))
