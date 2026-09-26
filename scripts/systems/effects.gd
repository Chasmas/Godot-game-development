class_name Effects
extends Node2D
## Per-level visual effects hub: pooled particles, persistent decals
## (blood, glass, casings, scorch), muzzle flashes and score popups.
## Static helpers let any object spawn effects without holding a reference.

const MAX_DECALS := 900

var decals: DecalLayer
var pools: Gore.PoolLayer
var gib_root: Node2D
var _pools: Dictionary = {}
var _pool_index: Dictionary = {}
var _flash_light: PointLight2D
var _flash_time := 0.0
var _popup_layer: Node2D

static func get_fx() -> Effects:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("effects") as Effects

func _ready() -> void:
	add_to_group("effects")
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.enemy_alerted.connect(_on_enemy_alerted)
	Score.combo_changed.connect(_on_combo_changed)
	pools = Gore.PoolLayer.new()
	pools.z_index = -9
	add_child(pools)
	decals = DecalLayer.new()
	decals.z_index = -8
	add_child(decals)
	gib_root = Node2D.new()
	gib_root.name = "Gibs"
	gib_root.z_index = -3
	add_child(gib_root)
	_popup_layer = Node2D.new()
	_popup_layer.z_index = 50
	add_child(_popup_layer)
	_make_pool("blood", Color(0.75, 0.05, 0.12), 14, 0.45, 90.0, 12, 1.6)
	_make_pool("spark", Color(1.0, 0.85, 0.35), 8, 0.22, 160.0, 8, 1.0)
	_make_pool("glass", Color(0.65, 0.9, 1.0, 0.9), 18, 0.6, 120.0, 6, 1.2)
	_make_pool("smoke", Color(0.5, 0.48, 0.55, 0.5), 10, 0.9, 30.0, 6, 3.0)
	_make_pool("debris", Color(0.55, 0.36, 0.2), 12, 0.5, 110.0, 6, 1.4)
	_make_pool("fire", Color(1.0, 0.55, 0.15), 24, 0.7, 90.0, 4, 2.2)
	_flash_light = PointLight2D.new()
	_flash_light.texture = SpriteLib.light_texture(128)
	_flash_light.texture_scale = 1.4
	_flash_light.energy = 0.0
	_flash_light.color = Color(1, 0.8, 0.4)
	add_child(_flash_light)

func _on_enemy_killed(_enemy: Node, info: Dictionary) -> void:
	# A short, high-contrast impact language makes every kill feel authored.
	var pos: Vector2 = info.get("pos", Vector2.ZERO)
	var method: StringName = info.get("method", &"gun")
	var kill_scale := 1.0
	if method == &"execution" or method == &"explosion":
		kill_scale = 1.45
	elif method == &"melee" or method == &"counter":
		kill_scale = 1.2
	emit("spark", pos, Vector2.RIGHT.rotated(randf() * TAU), 1.0)
	if kill_scale > 1.0:
		emit("debris", pos, Vector2.RIGHT.rotated(randf() * TAU))
		var ring := KillRingFX.new()
		ring.global_position = pos
		ring.radius = 22.0 * kill_scale
		ring.big = kill_scale > 1.3
		add_child(ring)
	Events.camera_shake.emit(2.2 * kill_scale)
	Events.camera_punch.emit(1.0 + 0.035 * kill_scale, 0.07 if kill_scale > 1.3 else 0.045)
	PostFX.flash(Color(1.0, 0.28, 0.42) if method == &"gun" else Color(1.0, 0.72, 0.32), 0.08 if kill_scale <= 1.0 else 0.14)

func _on_combo_changed(count: int, time_left: float, _window: float) -> void:
	if count < 2:
		return
	if count == 3 or count == 5 or count == 8 or count == 12:
		PostFX.flash(Color(1.0, 0.28, 0.55), 0.045)
		Events.camera_punch.emit(1.015 + minf(count * 0.002, 0.035), 0.07)
	if count >= 4 and time_left < 0.75:
		# The shrinking window becomes visually urgent instead of being only UI.
		PostFX.vhs_glitch(clampf((0.75 - time_left) * 0.18, 0.0, 0.14))


func _on_enemy_alerted(_enemy: Node) -> void:
	# Brief danger strobe when the AI acquires the player.
	PostFX.flash(Color(1.0, 0.12, 0.22), 0.055)

func _make_pool(pool_name: String, color: Color, amount: int, life: float, speed: float, count: int, size: float) -> void:
	var arr: Array[CPUParticles2D] = []
	for i in count:
		var p := CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = amount
		p.lifetime = life
		p.explosiveness = 0.95
		p.spread = 35.0
		p.initial_velocity_min = speed * 0.4
		p.initial_velocity_max = speed
		p.damping_min = speed * 1.2
		p.damping_max = speed * 2.0
		p.scale_amount_min = size * 0.6
		p.scale_amount_max = size * 1.4
		p.color = color
		p.gravity = Vector2.ZERO
		p.z_index = 5
		if pool_name == "smoke" or pool_name == "fire":
			var ramp := Gradient.new()
			ramp.set_color(0, color)
			ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
			p.color_ramp = ramp
			p.spread = 180.0
		add_child(p)
		arr.append(p)
	_pools[pool_name] = arr
	_pool_index[pool_name] = 0

func emit(pool_name: String, pos: Vector2, dir := Vector2.ZERO, amount_scale := 1.0) -> void:
	if not _pools.has(pool_name):
		return
	var arr: Array = _pools[pool_name]
	var i: int = _pool_index[pool_name]
	_pool_index[pool_name] = (i + 1) % arr.size()
	var p: CPUParticles2D = arr[i]
	p.global_position = pos
	p.direction = dir if dir.length() > 0.01 else Vector2.RIGHT
	if dir.length() <= 0.01:
		p.spread = 180.0
	elif pool_name != "smoke" and pool_name != "fire":
		p.spread = 35.0
	p.restart()
	p.emitting = true

func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		_flash_light.energy = maxf(0.0, _flash_time / 0.05) * 1.3
	elif _flash_light.energy != 0.0:
		_flash_light.energy = 0.0

# ------------------------------------------------------------ static API
static func blood(pos: Vector2, dir: Vector2, big := false) -> void:
	var fx := get_fx()
	if fx == null:
		return
	var gore: int = int(SaveManager.get_setting("gore", 2))
	if gore == 0:
		fx.emit("debris", pos, dir)
		return
	Gore.splatter(pos, dir, 1.8 if big else 0.9)
	if big:
		fx.decals.add_splat(pos + dir * 8.0, randf_range(5.0, 7.0), Color(0.45, 0.01, 0.06, 0.85))

static func sparks(pos: Vector2, normal: Vector2) -> void:
	var fx := get_fx()
	if fx:
		fx.emit("spark", pos, normal)
		fx.decals.add_mark(pos, Color(0.08, 0.06, 0.08, 0.7), 1.2)

static func glass(pos: Vector2, dir: Vector2) -> void:
	var fx := get_fx()
	if fx:
		fx.emit("glass", pos, dir)
		for i in 10:
			fx.decals.add_mark(pos + dir.rotated(randf_range(-1.2, 1.2)) * randf_range(4, 30), Color(0.7, 0.9, 1.0, 0.8), 0.8)

static func debris(pos: Vector2, dir: Vector2) -> void:
	var fx := get_fx()
	if fx:
		fx.emit("debris", pos, dir)

static func smoke(pos: Vector2) -> void:
	var fx := get_fx()
	if fx:
		fx.emit("smoke", pos)

static func explosion(pos: Vector2, radius: float) -> void:
	var fx := get_fx()
	if fx == null:
		return
	fx.emit("fire", pos)
	fx.emit("smoke", pos)
	fx.emit("debris", pos)
	fx.emit("spark", pos)
	fx.decals.add_splat(pos, radius * 0.6, Color(0.05, 0.04, 0.05, 0.8))
	fx._flash_light.global_position = pos
	fx._flash_light.texture_scale = radius / 30.0
	fx._flash_time = 0.25
	var ring := ExplosionRing.new()
	ring.radius = radius
	ring.global_position = pos
	fx.add_child(ring)

static func muzzle(pos: Vector2, dir: Vector2, color: Color, big := false) -> void:
	var fx := get_fx()
	if fx == null:
		return
	fx._flash_light.global_position = pos
	fx._flash_light.color = color
	fx._flash_light.texture_scale = 2.2 if big else 1.4
	fx._flash_time = 0.05
	var f := MuzzleFlash.new()
	f.color = color
	f.big = big
	f.global_position = pos
	f.rotation = dir.angle()
	fx.add_child(f)

## Melee slash trail: a bright crescent sweeping through the attack arc
## (or a thrust streak for knives).
static func slash(pos: Vector2, angle: float, radius: float, arc: float, tint: Color, heavy := false, stab := false, side := 1.0) -> void:
	var fx := get_fx()
	if fx == null:
		return
	var s := SlashFX.new()
	s.global_position = pos
	s.rotation = angle
	s.radius = radius
	s.arc = clampf(arc, 0.4, 3.6)
	s.tint = tint
	s.heavy = heavy
	s.stab = stab
	s.side = signf(side) if side != 0.0 else 1.0
	fx.add_child(s)

## Melee connect: impact star, shock ring, spray and a slice mark.
static func impact(pos: Vector2, dir: Vector2, kill: bool, blade: bool) -> void:
	var fx := get_fx()
	if fx == null:
		return
	var i := ImpactFX.new()
	i.global_position = pos
	i.rotation = dir.angle()
	i.big = kill
	fx.add_child(i)
	fx.emit("spark", pos, dir)
	if kill and int(SaveManager.get_setting("gore", 2)) > 0:
		fx.emit("blood", pos, dir)
		fx.emit("blood", pos + dir * 4.0, dir.rotated(0.4))
		if blade:
			fx.decals.add_splat(pos + dir * 10.0, 2.0, Color(0.6, 0.02, 0.08, 0.9))
			for k in 5:
				fx.decals.add_splat(pos + dir * (6.0 + k * 5.0) + dir.orthogonal() * randf_range(-2, 2), 1.4, Color(0.55, 0.02, 0.07, 0.85))

static func casing(pos: Vector2, dir: Vector2) -> void:
	var fx := get_fx()
	if fx:
		var side := dir.orthogonal() * randf_range(6, 14) + dir * randf_range(-4, 2)
		fx.decals.add_mark(pos + side, Color(0.95, 0.75, 0.3, 0.9), 1.0)

static func popup(text: String, pos: Vector2, color := Color(1, 0.9, 0.3)) -> void:
	var fx := get_fx()
	if fx == null:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UIStyle.font_bold())
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
	l.add_theme_constant_override("outline_size", 3)
	l.position = pos + Vector2(-30, -22)
	l.size = Vector2(60, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fx._popup_layer.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 14.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


## Persistent floor decals. Stored in small chunks so adding a splat only
## redraws the newest chunk, never the whole floor's worth of blood.
class DecalLayer extends Node2D:
	const CHUNK := 96
	var chunks: Array = []
	var _count := 0

	func _current() -> DecalChunk:
		if chunks.is_empty() or (chunks[-1] as DecalChunk).size() >= CHUNK:
			var c := DecalChunk.new()
			add_child(c)
			chunks.append(c)
			if _count > Effects.MAX_DECALS:
				var old: DecalChunk = chunks.pop_front()
				_count -= old.size()
				old.queue_free()
		return chunks[-1]

	func add_splat(p: Vector2, r: float, c: Color) -> void:
		var ch := _current()
		var rng := RandomNumberGenerator.new()
		rng.seed = randi()
		var blobs := []
		for i in 3:
			blobs.append([Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r)), r * rng.randf_range(0.3, 0.6)])
		ch.splats.append([p.round(), r, c, blobs])
		_count += 1
		ch.dirty()

	func add_mark(p: Vector2, c: Color, s: float) -> void:
		var ch := _current()
		ch.marks.append([p.round(), c, s])
		_count += 1
		ch.dirty()


class DecalChunk extends Node2D:
	var splats: Array = []
	var marks: Array = []
	var _dirty := false
	func size() -> int:
		return splats.size() + marks.size()
	func dirty() -> void:
		if not _dirty:
			_dirty = true
			set_process(true)
	func _process(_d: float) -> void:
		if _dirty:
			_dirty = false
			queue_redraw()
		set_process(false)
	func _draw() -> void:
		for s in splats:
			var p: Vector2 = s[0]
			var c: Color = s[2]
			draw_circle(p, s[1], c)
			for bl in s[3]:
				draw_circle((p + bl[0]).round(), bl[1], c)
		for m in marks:
			var sz: float = m[2]
			draw_rect(Rect2(m[0], Vector2(sz, sz)), m[1])


class MuzzleFlash extends Node2D:
	var color := Color.WHITE
	var big := false
	var t := 0.0
	func _ready() -> void:
		z_index = 20
	func _process(d: float) -> void:
		t += d
		if t > 0.05:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var s := 1.6 if big else 1.0
		var pts := PackedVector2Array([Vector2(0, -3) * s, Vector2(12, 0) * s, Vector2(0, 3) * s, Vector2(3, 0) * s])
		draw_colored_polygon(pts, color)
		draw_circle(Vector2(2, 0), 3.0 * s, Color(1, 1, 0.9))


class ExplosionRing extends Node2D:
	var radius := 60.0
	var t := 0.0
	func _ready() -> void:
		z_index = 30
	func _process(d: float) -> void:
		t += d
		if t > 0.35:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var k := t / 0.35
		draw_circle(Vector2.ZERO, radius * (0.3 + k * 0.7), Color(1, 0.8, 0.4, (1.0 - k) * 0.6))
		draw_arc(Vector2.ZERO, radius * (0.4 + k * 0.8), 0, TAU, 32, Color(1, 1, 0.9, 1.0 - k), 3.0)


class SlashFX extends Node2D:
	var radius := 24.0
	var arc := 2.0
	var tint := Color.WHITE
	var heavy := false
	var stab := false
	var side := 1.0
	var t := 0.0
	const LIFE := 0.16

	func _ready() -> void:
		z_index = 25

	func _process(d: float) -> void:
		t += d / maxf(Engine.time_scale, 0.05) * 0.6 + d * 0.4
		if t >= LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / LIFE, 0.0, 1.0)
		var reveal := clampf(k / 0.35, 0.0, 1.0)
		var fade := 1.0 - clampf((k - 0.3) / 0.7, 0.0, 1.0)
		if stab:
			var L := radius * (0.6 + 0.6 * reveal)
			var w := 3.0 * fade
			draw_colored_polygon(PackedVector2Array([Vector2(4, -w), Vector2(L, 0), Vector2(4, w)]), Color(tint, 0.85 * fade))
			draw_line(Vector2(6, 0), Vector2(L * 0.95, 0), Color(1, 1, 1, fade), 1.2)
			for j in 2:
				var y := (j * 2 - 1) * 4.0
				draw_line(Vector2(L * 0.3, y), Vector2(L * 0.75, y * 0.5), Color(tint, 0.5 * fade), 1.0)
			return
		var a0 := -arc * 0.5 * side
		var a1 := a0 + arc * side * reveal
		var n := 14
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in n + 1:
			var f := float(i) / n
			var a := lerpf(a0, a1, f)
			var thick := sin(f * PI) * (0.5 if heavy else 0.38)   # crescent: thick in the middle
			outer.append(Vector2.from_angle(a) * radius)
			inner.append(Vector2.from_angle(a) * radius * (1.0 - thick * fade))
		var fillc := Color(tint, (0.55 if heavy else 0.45) * fade)
		for i in n:
			var q := PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]])
			if (outer[i] - inner[i]).length() > 0.3 or (outer[i + 1] - inner[i + 1]).length() > 0.3:
				draw_primitive(q, PackedColorArray([fillc, fillc, fillc, fillc]), PackedVector2Array())
		draw_polyline(outer, Color(1, 1, 1, 0.95 * fade), 2.0 if heavy else 1.4)
		# speed lines
		for i in 3:
			var a := lerpf(a0, a1, 0.25 + i * 0.25)
			draw_line(Vector2.from_angle(a) * radius * 0.45, Vector2.from_angle(a) * radius * 0.8, Color(tint, 0.35 * fade), 1.0)
		if heavy and k < 0.4:
			draw_arc(Vector2.ZERO, radius * (0.8 + k), a0, a1, 12, Color(1, 1, 1, 0.4 * (1.0 - k / 0.4)), 3.0)


class KillRingFX extends Node2D:
	var radius := 22.0
	var big := false
	var t := 0.0
	func _ready() -> void:
		z_index = 29
	func _process(d: float) -> void:
		t += d / maxf(Engine.time_scale, 0.05)
		if t >= 0.22:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var k := clampf(t / 0.22, 0.0, 1.0)
		var r := lerpf(radius * 0.35, radius, k)
		var a := (1.0 - k) * (0.9 if big else 0.55)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(1.0, 0.18, 0.38, a), 2.2 if big else 1.4)
		draw_arc(Vector2.ZERO, r * 0.68, -1.2, 1.0, 12, Color(1.0, 0.8, 0.45, a * 0.7), 1.0)

class ImpactFX extends Node2D:
	var big := false
	var t := 0.0

	func _ready() -> void:
		z_index = 26

	func _process(d: float) -> void:
		t += d / maxf(Engine.time_scale, 0.05) * 0.6 + d * 0.4
		if t > 0.14:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := t / 0.14
		var s := (9.0 if big else 6.0) * (1.0 - k * 0.5)
		var c := Color(1, 1, 0.92, 1.0 - k)
		# 4-point impact star
		draw_colored_polygon(PackedVector2Array([Vector2(-s, 0), Vector2(0, -s * 0.22), Vector2(s * 1.3, 0), Vector2(0, s * 0.22)]), c)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -s), Vector2(s * 0.22, 0), Vector2(0, s), Vector2(-s * 0.22, 0)]), c)
		draw_arc(Vector2.ZERO, 4.0 + k * (16.0 if big else 10.0), 0, TAU, 20, Color(1, 0.4, 0.5, 0.7 * (1.0 - k)), 2.0)
