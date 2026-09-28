class_name Smashable
extends StaticBody2D
## Scenery you can wreck: vases, cardboard boxes, wooden crates, chairs, oil
## drums. Shoot, hit or throw something at them. They break into debris
## that suits them (ceramic shards, cardboard scraps, splinters, sparks) and
## about a third hold something useful - ammo, a flare, cash, a bottle or a
## knife to throw. They block walking (and the enemies' paths) until broken.

const DEFS := {
	"vase":  {"hp": 1, "r": 5.0, "sfx": "bottle_break", "loot": 0.3},
	"box":   {"hp": 1, "r": 6.0, "sfx": "hit_blunt", "loot": 0.45},
	"crate": {"hp": 2, "r": 7.0, "sfx": "door_break", "loot": 0.5},
	"chair": {"hp": 1, "r": 5.0, "sfx": "hit_blunt", "loot": 0.1},
	"drum":  {"hp": 3, "r": 6.0, "sfx": "metal_clang", "loot": 0.25},
}

var kind := "box"
var hp := 1
var variant := 0
var cell := Vector2i.ZERO
var level: Node
var _shake := 0.0
var _rot := 0.0

func setup(p_kind: String, p_cell: Vector2i, p_level: Node, seed_i: int) -> void:
	kind = p_kind
	cell = p_cell
	level = p_level
	variant = seed_i % 3
	hp = int(DEFS[kind].hp)
	position = Vector2(p_cell) * 16.0 + Vector2(8, 8)
	_rot = float((seed_i * 37) % 7 - 3) * 0.06

func _ready() -> void:
	add_to_group("damageable")
	add_to_group("props")
	collision_layer = Layers.PROP
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = float(DEFS[kind].r)
	cs.shape = c
	add_child(cs)
	light_mask = 2
	if level and level.get("nav"):
		(level.nav as AStarGrid2D).set_point_solid(cell, true)

func hit_point(from: Vector2) -> Vector2:
	return global_position + (from - global_position).limit_length(float(DEFS[kind].r))

func take_damage(info: DamageInfo) -> String:
	hp -= 1 if info.type == DamageInfo.Type.BALLISTIC else 2
	_shake = 1.0
	if hp > 0:
		Audio.play_at(DEFS[kind].sfx, global_position, -8.0, 0.1)
		Effects.splinters(global_position, -info.dir, kind in ["crate", "chair"], 0.5)
		return "blocked"
	_break(info.dir)
	return "blocked"

func _break(dir: Vector2) -> void:
	Audio.play_at(DEFS[kind].sfx, global_position, -2.0, 0.1)
	Events.noise.emit(global_position, 200.0, &"thrown", null)
	match kind:
		"vase":
			Effects.shards(global_position, dir, Color("c8d0e8") if variant == 0 else (Color("d86a3a") if variant == 1 else Color("3a7ab0")), 12)
		"box":
			Effects.shards(global_position, dir, Color("b08858"), 9)
			Effects.dust(global_position, dir)
		"crate", "chair":
			Effects.splinters(global_position, dir, true, 1.5)
			Effects.shards(global_position, dir, Color("8a5a30"), 8)
		"drum":
			Effects.sparks(global_position, dir)
			Effects.shards(global_position, dir, Color("5a6a4a"), 6)
	if level and level.get("nav"):
		(level.nav as AStarGrid2D).set_point_solid(cell, false)
	# loot: deterministic per prop, so a checkpoint restart gives the same
	if float(absi(hash(str(cell) + kind)) % 100) / 100.0 < float(DEFS[kind].loot):
		var l := LootPickup.new()
		l.kind = ["ammo", "ammo", "cash", "flare", "bottle", "knife"][absi(hash(str(cell))) % 6]
		# now and then something better is hidden in there
		var rare_roll := absi(hash(str(cell) + "rare")) % 100
		if rare_roll < 14:
			l.kind = ["upgrade", "guard", "spotlight", "gun"][rare_roll % 4]
		l.position = position
		get_parent().add_child.call_deferred(l)
	queue_free()

func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, delta * 6.0)
		queue_redraw()

func _draw() -> void:
	var ink := Color("0b0710")
	var j := Vector2(sin(_shake * 40.0), 0) * _shake * 1.5
	draw_set_transform(j, _rot, Vector2.ONE)
	# contact shadow
	draw_circle(Vector2(1.5, 2), float(DEFS[kind].r), Color(0, 0, 0, 0.25))
	var painted := {"box": ["cardboard_box", Vector2(13, 11)], "chair": ["wooden_chair", Vector2(12, 12)]}
	if painted.has(kind):
		var ptex := ArtLib.sprite(str(painted[kind][0]))
		if ptex:
			var sz: Vector2 = painted[kind][1]
			draw_texture_rect(ptex, Rect2(-sz * 0.5, sz), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
	match kind:
		"vase":
			var body: Color = [Color("c8d0e8"), Color("d86a3a"), Color("3a7ab0")][variant]
			draw_circle(Vector2.ZERO, 5.2, ink)
			draw_circle(Vector2.ZERO, 4.4, body)
			draw_circle(Vector2(-1, -1), 2.6, body.lightened(0.25))
			draw_circle(Vector2.ZERO, 1.8, ink)          # the mouth, seen from above
			draw_circle(Vector2.ZERO, 1.2, Color(0.15, 0.1, 0.12))
			for i in 6:
				var a := i * TAU / 6.0
				draw_circle(Vector2.from_angle(a) * 3.4, 0.5, body.darkened(0.35))
			draw_circle(Vector2(-2, -2.2), 0.7, Color(1, 1, 1, 0.8))
			if variant == 1:
				# a cheap plastic palm in the terracotta pot
				for i in 5:
					var a2 := i * TAU / 5.0 + 0.3
					draw_line(Vector2.ZERO, Vector2.from_angle(a2) * 7.0, Color("2a7a3a"), 1.5)
		"box":
			var r := Rect2(-6, -5, 12, 10)
			draw_rect(r.grow(1), ink)
			draw_rect(r, Color("b08858"))
			draw_rect(Rect2(-6, -5, 12, 4), Color("c09868"))
			draw_rect(Rect2(-1, -5, 2, 10), Color("d8c8a0"))    # tape
			draw_line(Vector2(-6, -1), Vector2(6, -1), Color("8a6a40"), 1.0)
			draw_string(UIStyle.font_bold(), Vector2(-5, 4), "↑↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(0.2, 0.12, 0.08, 0.7))
		"crate":
			var r2 := Rect2(-7, -7, 14, 14)
			draw_rect(r2.grow(1), ink)
			draw_rect(r2, Color("8a5a30"))
			for i in 3:
				draw_rect(Rect2(-7, -7 + i * 5, 14, 1), Color("5a3818"))
			draw_rect(Rect2(-7, -7, 14, 2), Color("a87040"))
			draw_line(Vector2(-7, -7), Vector2(7, 7), Color("5a3818"), 1.5)
			for p in [Vector2(-6, -6), Vector2(5, -6), Vector2(-6, 5), Vector2(5, 5)]:
				draw_rect(Rect2(p, Vector2(1, 1)), Color(0.75, 0.75, 0.8))
			draw_string(UIStyle.font_bold(), Vector2(-5, 2), "K-9", HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(0.1, 0.05, 0.02, 0.6)) if variant == 2 else null
		"chair":
			draw_rect(Rect2(-5, -5, 10, 10).grow(1), ink)
			draw_rect(Rect2(-5, -5, 10, 10), Color("6a3a20"))
			draw_rect(Rect2(-5, -5, 10, 3), Color("4a2410"))     # backrest
			draw_rect(Rect2(-4, -1, 8, 5), [Color("a02030"), Color("2a6a5a"), Color("c8a040")][variant])
		"drum":
			draw_circle(Vector2.ZERO, 6.4, ink)
			draw_circle(Vector2.ZERO, 5.6, [Color("5a6a4a"), Color("a03020"), Color("2a4a7a")][variant])
			draw_arc(Vector2.ZERO, 4.2, 0, TAU, 16, Color(0, 0, 0, 0.35), 1.0)
			draw_circle(Vector2(2, -2), 1.1, ink)
			draw_circle(Vector2(-2, -2.5), 1.6, Color(1, 1, 1, 0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## What falls out: walk over it to take it.
class LootPickup extends Node2D:
	var kind := "ammo"
	var _t := 0.0
	var _taken := false
	func _ready() -> void:
		z_index = 3
		Audio.play_at("pickup", global_position, -14.0, 0.1)
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _taken or _t < 0.4:
			return
		var p := get_tree().get_first_node_in_group("player") as Player
		if p == null or not p.alive or p.global_position.distance_to(global_position) > 12.0:
			return
		_take(p)
	func _take(p: Player) -> void:
		var label := ""
		match kind:
			"ammo":
				var w = p.current()
				if w == null or not w.data.is_firearm():
					return   # leave it for when you have a gun
				# a universal magazine: half a load for whatever's in her hands
				var n: int = 3 if w.data.pellets > 1 else maxi(4, int(ceil(p.mag_size(w) * 0.5)))
				w.reserve += n
				p._emit_weapon()
				Audio.play("mag_in", -4.0)
				label = tr("+%d ROUNDS") % n
			"cash":
				Score.add_bonus("CASH", 250, global_position)
			"flare":
				p.equipment_left += 1
				label = "+1 FLARE"
			"bottle", "knife":
				var wd: WeaponData = DB.weapon(StringName(kind))
				if wd:
					WeaponPickup.spawn(get_parent(), WeaponInstance.create(wd), global_position)
			"upgrade":
				var id := Upgrades.roll(p.upgrades.keys(), [])
				if id == &"":
					Score.add_bonus("JACKPOT", 1000, global_position)
				else:
					p.add_upgrade(id)
					label = tr(str(Upgrades.def(id).get("name", "UPGRADE")))
			"guard":
				p.armor_hits += 1
				label = "+1 GUARD"
			"spotlight":
				if p.ability:
					p.ability.add_charge(1.0)
				label = "SPOTLIGHT READY"
			"gun":
				var gd: WeaponData = DB.weapon([&"shotgun", &"smg", &"revolver", &"rifle"][absi(hash(str(global_position))) % 4])
				if gd:
					WeaponPickup.spawn(get_parent(), WeaponInstance.create(gd), global_position)
				label = "STASHED PIECE"
		_taken = true
		Audio.play("pickup", -6.0, 1.1)
		if is_rare():
			Audio.play("upgrade", -4.0)
			PostFX.flash(UIStyle.GOLD, 0.12)
		if label != "":
			Effects.popup(tr(label), global_position, UIStyle.GOLD)
		queue_free()
	func is_rare() -> bool:
		return kind in ["upgrade", "guard", "spotlight", "gun"]
	func _draw() -> void:
		var bob := sin(_t * 4.0) * 1.2
		var pop := clampf(_t / 0.2, 0.0, 1.0)
		draw_set_transform(Vector2(0, -2 + bob), 0.0, Vector2.ONE * pop)
		draw_circle(Vector2.ZERO, 6.0 + sin(_t * 5.0), Color(UIStyle.GOLD, 0.15))
		if is_rare():
			# rare: a turning rainbow ring and sparkles, so it reads from afar
			var hue := fmod(_t * 0.35, 1.0)
			draw_arc(Vector2.ZERO, 9.0, _t * 3.0, _t * 3.0 + TAU * 0.75, 18, Color.from_hsv(hue, 0.7, 1.0, 0.9), 1.5)
			for k in 3:
				var sp := Vector2.from_angle(_t * 2.0 + k * TAU / 3.0) * 11.0
				var tw := absf(sin(_t * 6.0 + k))
				draw_line(sp - Vector2(2, 0) * tw, sp + Vector2(2, 0) * tw, Color(1, 1, 0.85, tw), 1.0)
				draw_line(sp - Vector2(0, 2) * tw, sp + Vector2(0, 2) * tw, Color(1, 1, 0.85, tw), 1.0)
		match kind:
			"upgrade":
				draw_rect(Rect2(-5, -3, 10, 7), Color("0b0710"))
				draw_rect(Rect2(-4.5, -2.5, 9, 6), Color("3a2a50"))
				draw_rect(Rect2(-1.5, -4, 3, 1.5), Color("c8a040"))
				draw_rect(Rect2(-4.5, 0, 9, 1), Color("ffd23f"))
			"guard":
				draw_colored_polygon(PackedVector2Array([Vector2(0, -5), Vector2(4, -3), Vector2(3, 2), Vector2(0, 5), Vector2(-3, 2), Vector2(-4, -3)]), Color("35e0ff"))
				draw_colored_polygon(PackedVector2Array([Vector2(0, -3), Vector2(2, -2), Vector2(1.5, 1), Vector2(0, 3), Vector2(-1.5, 1), Vector2(-2, -2)]), Color("0b3a50"))
			"spotlight":
				draw_circle(Vector2.ZERO, 3.5, Color("ffd23f"))
				for k in 8:
					var d := Vector2.from_angle(k * TAU / 8.0 + _t)
					draw_line(d * 4.5, d * 6.5, Color("ffd23f"), 1.0)
			"gun":
				draw_rect(Rect2(-5, -1.5, 10, 3), Color("0b0710"))
				draw_rect(Rect2(-4.5, -1, 9, 2), Color("8a8e9a"))
				draw_rect(Rect2(-4, 0, 2, 3.5), Color("5a3a22"))
			"ammo":
				# a magazine, rounds showing at the lips
				draw_set_transform(Vector2.ZERO, 0.35, Vector2.ONE)
				draw_rect(Rect2(-2.5, -4.5, 5, 9), Color("0b0710"))
				draw_rect(Rect2(-2, -4, 4, 8), Color("3a3e46"))
				draw_rect(Rect2(-2, 2, 4, 2), Color("24272d"))
				draw_rect(Rect2(-1.2, -5.2, 2.4, 1.6), Color("d8a428"))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"cash":
				draw_rect(Rect2(-4, -2.5, 8, 5), Color("0b0710"))
				draw_rect(Rect2(-3.5, -2, 7, 4), Color("5aa060"))
				draw_rect(Rect2(-1, -2, 2, 4), Color("d8c870"))
			"flare":
				draw_rect(Rect2(-1.5, -4, 3, 8), Color("0b0710"))
				draw_rect(Rect2(-1, -3.5, 2, 7), Color("e03030"))
				draw_circle(Vector2(0, -4), 1.2 + sin(_t * 12.0) * 0.4, Color(1, 0.6, 0.3))
			"bottle":
				draw_rect(Rect2(-1.5, -4, 3, 7), Color("2a6a3a"))
				draw_rect(Rect2(-0.8, -6, 1.6, 2.5), Color("2a6a3a"))
			"knife":
				draw_line(Vector2(-4, 2), Vector2(0, -1), Color("3a2418"), 2.0)
				draw_line(Vector2(0, -1), Vector2(4, -4), Color("c8ccd8"), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
