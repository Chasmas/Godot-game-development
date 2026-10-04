class_name Gore
extends RefCounted
## Blood and guts. Spreading blood pools, arterial sprays, and body pieces
## (heads, arms, legs, chunks, bone, teeth) that tumble, bounce off walls,
## smear blood trails and stay on the floor. Respects the Gore setting:
## 0 = off (ink / debris), 1 = reduced (pools + sprays, no body parts), 2 = full.

const MAX_GIBS := 140
const BLOOD := Color(0.58, 0.02, 0.07, 0.95)
const BLOOD_DARK := Color(0.32, 0.0, 0.04, 0.95)

static func level() -> int:
	return int(SaveManager.get_setting("gore", 2))

static func _fx() -> Effects:
	return Effects.get_fx()

## A pool of blood that slowly spreads out to `radius`.
static func pool(pos: Vector2, radius: float, delay := 0.0) -> void:
	var fx := _fx()
	if fx == null or level() == 0:
		return
	if level() == 1:
		radius *= 0.7
	fx.pools.add_pool(pos, radius, delay)

## Arterial spray: pulses of blood thrown in an arc over `dur` seconds.
static func spray(pos: Vector2, dir: Vector2, dur := 0.6, power := 1.0) -> void:
	var fx := _fx()
	if fx == null or level() == 0:
		return
	var s := BloodSpray.new()
	s.position = pos
	s.dir = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	s.dur = dur
	s.power = power
	fx.add_child(s)

## Throw a body part. kind: head, arm, leg, chunk, bone, teeth, brain, eye, tail, dog_head
static func gib(pos: Vector2, vel: Vector2, kind: String, palette := "guard") -> void:
	var fx := _fx()
	if fx == null or level() < 2:
		return
	var tree := fx.get_tree()
	var existing := tree.get_nodes_in_group("gibs")
	if existing.size() >= MAX_GIBS:
		existing[0].queue_free()
	var g := Gib.new()
	g.kind = kind
	g.palette = palette
	g.position = pos
	g.velocity = vel
	g.spin = randf_range(-14.0, 14.0)
	g.rotation = randf() * TAU
	fx.gib_root.add_child(g)

static func splatter(pos: Vector2, dir: Vector2, amount := 1.0) -> void:
	var fx := _fx()
	if fx == null:
		return
	if level() == 0:
		fx.emit("debris", pos, dir)
		return
	fx.emit("blood", pos, dir)
	if amount > 1.2:
		fx.emit("blood", pos, dir.rotated(0.5))
		fx.emit("blood", pos, dir.rotated(-0.5))
	var n := int(6.0 * amount * (1.0 if level() == 2 else 0.5))
	for i in n:
		var off := dir.rotated(randf_range(-0.7, 0.7)) * randf_range(3.0, 16.0 + amount * 12.0)
		fx.decals.add_splat(pos + off, randf_range(1.2, 3.5), Color(0.5 + randf() * 0.2, 0.02, 0.07, 0.92))
	# long streaks in the hit direction
	for i in int(2 * amount):
		var st := pos + dir.rotated(randf_range(-0.3, 0.3)) * randf_range(8.0, 22.0)
		for k in 5:
			fx.decals.add_splat(st + dir * k * 3.0, 1.6 - k * 0.2, Color(0.5, 0.02, 0.07, 0.85))

## Droplets all round whoever was hit: small spots at their feet, a few
## flung further out, so a fight leaves the floor speckled around them,
## not just a streak behind.
static func spatter_around(pos: Vector2, amount := 1.0) -> void:
	var fx := _fx()
	if fx == null or level() == 0:
		return
	var n := int((5.0 + 5.0 * amount) * (1.0 if level() == 2 else 0.5))
	for i in n:
		var a := randf() * TAU
		var d := randf_range(3.0, 10.0) if randf() < 0.7 else randf_range(12.0, 22.0 * amount + 8.0)
		var r := randf_range(0.6, 1.6) if d > 12.0 else randf_range(1.0, 2.6)
		fx.decals.add_splat(pos + Vector2.from_angle(a) * d, r, Color(0.42 + randf() * 0.2, 0.01, 0.06, 0.9))

## Head burst: blood and a small amount of contextual debris.  The floor is
## readable after a fight; it must not become covered in cartoon bone shards.
static func head_burst(pos: Vector2, dir: Vector2, palette := "guard") -> void:
	splatter(pos, dir, 2.5)
	pool(pos + dir * 6.0, 10.0)
	Audio.play_at("gore", pos, -2.0)
	if randf() < 0.25:
		gib(pos, dir.rotated(randf_range(-0.8, 0.8)) * randf_range(70, 130), "chunk", palette)
	for i in 3:
		gib(pos, dir.rotated(randf_range(-1.2, 1.2)) * randf_range(60, 200), "chunk", palette)

static func decapitate(pos: Vector2, dir: Vector2, palette := "guard", dog := false) -> void:
	splatter(pos, dir, 1.6)
	gib(pos + dir * 5.0, dir.rotated(randf_range(-0.4, 0.4)) * randf_range(140, 210), "dog_head" if dog else "head", palette)
	spray(pos, -dir.rotated(randf_range(-0.4, 0.4)), 0.9, 1.1)
	Audio.play_at("gore", pos, -3.0)

static func dismember(pos: Vector2, dir: Vector2, palette := "guard", part := "arm") -> void:
	splatter(pos, dir, 1.3)
	gib(pos, dir.rotated(randf_range(-0.8, 0.8)) * randf_range(100, 180), part, palette)
	gib(pos, dir.rotated(randf_range(-1.2, 1.2)) * randf_range(60, 140), "chunk", palette)
	spray(pos, dir.orthogonal() * (1.0 if randf() > 0.5 else -1.0), 0.5, 0.7)
	Audio.play_at("gore", pos, -5.0)

static func gut(pos: Vector2, dir: Vector2, palette := "guard") -> void:
	splatter(pos, dir, 1.8)
	pool(pos, 12.0)
	for i in 4:
		gib(pos, dir.rotated(randf_range(-1.3, 1.3)) * randf_range(40, 120), "chunk", palette)

static func explode_body(pos: Vector2, dir: Vector2, palette := "guard") -> void:
	splatter(pos, dir, 3.0)
	pool(pos, 14.0)
	var parts := ["arm", "leg", "chunk", "chunk", "chunk"]
	if randf() < 0.5:
		parts.append("arm")
	for k in parts:
		gib(pos, Vector2.from_angle(randf() * TAU) * randf_range(120, 260) + dir * 60.0, k, palette)

## Decide what a kill does to the body. Returns the part the corpse is missing
## ("", "head", "arm").
static func on_kill(pos: Vector2, info: DamageInfo, palette: String, source_pos: Vector2) -> String:
	var g := level()
	var dir := info.dir.normalized() if info.dir.length() > 0.01 else Vector2.RIGHT
	var finisher: String = str(info.get_meta("finisher", ""))
	if finisher == "neck":
		return ""
	pool(pos + dir * 4.0, randf_range(9.0, 13.0), 0.35)
	if g == 0:
		return ""
	match finisher:
		"decap":
			decapitate(pos + dir * 5.0, dir, palette)
			return "head"
		"skull":
			head_burst(pos + dir * 5.0, dir, palette)
			return "head"
		"throat":
			spray(pos + dir * 4.0, dir.orthogonal(), 1.1, 1.3)
			pool(pos + dir * 6.0, 14.0, 0.2)
			return ""
		"gut":
			gut(pos, dir, palette)
			return ""
		"limb":
			var part := "arm" if randf() > 0.4 else "leg"
			dismember(pos, dir, palette, part)
			return part
		"teeth":
			for i in 2:
				gib(pos + dir * 5.0, dir.rotated(randf_range(-1, 1)) * 110.0, "teeth", palette)
			splatter(pos, dir, 1.5)
			return ""
	if g < 2:
		return ""
	var dist := pos.distance_to(source_pos)
	match info.type:
		DamageInfo.Type.EXPLOSIVE:
			explode_body(pos, dir, palette)
			return ["head", "arm", "leg", "legs"][randi() % 4]
		DamageInfo.Type.BALLISTIC:
			if info.weapon_id in [&"shotgun", &"hotshot"] and dist < 70.0:
				var r := randf()
				if r < 0.35:
					head_burst(pos + dir * 5.0, dir, palette)
					return "head"
				elif r < 0.6:
					dismember(pos, dir, palette, "arm")
					return "arm"
				elif r < 0.8:
					dismember(pos, dir, palette, "leg")
					return "leg"
				gut(pos, dir, palette)
				return ""
			elif info.weapon_id in [&"rifle", &"revolver", &"boomstick"] and randf() < 0.25:
				head_burst(pos + dir * 5.0, dir, palette)
				return "head"
			splatter(pos, dir, 1.0)
			# a bullet still takes a piece with it now and then
			var roll := randf()
			if roll < 0.12:
				var limb := "arm" if randf() < 0.6 else "leg"
				dismember(pos, dir, palette, limb)
				return limb
			elif roll < 0.55:
				for i in randi_range(1, 2):
					gib(pos + dir * 3.0, dir.rotated(randf_range(-0.9, 0.9)) * randf_range(70, 150), "chunk", palette)
		DamageInfo.Type.MELEE:
			if info.weapon_id == &"machete":
				var r2 := randf()
				if r2 < 0.3:
					decapitate(pos + dir * 5.0, dir, palette)
					return "head"
				elif r2 < 0.55:
					dismember(pos, dir, palette, "arm")
					return "arm"
			elif info.heavy and info.weapon_id in [&"bat", &"pipe", &"brick"] and randf() < 0.3:
				head_burst(pos + dir * 5.0, dir, palette)
				return "head"
			elif info.weapon_id in [&"knife", &"broken_bottle"] and randf() < 0.35:
				spray(pos + dir * 4.0, dir.orthogonal(), 0.7, 1.0)
	return ""


## Spreading pools, drawn beneath splats. Growing pools live in a small
## "wet" layer that redraws while they spread; once settled they are moved
## into static chunks that never redraw again.
class PoolLayer extends Node2D:
	var pools: Array = []     # every pool ever spilled (for tests / stats)
	var _wet: Array = []      # [pos, target, cur, seed, delay]
	var _dry: Array = []      # static chunks
	var _wet_node: Node2D

	func _ready() -> void:
		_wet_node = PoolDraw.new()
		_wet_node.z_index = 1
		add_child(_wet_node)
		set_process(false)

	func add_pool(p: Vector2, r: float, delay := 0.0) -> void:
		var pl := [p, r, 0.5, randi(), delay]
		pools.append(pl)
		if pools.size() > 260:
			pools.pop_front()
		_wet.append(pl)
		_wet_node.items = _wet
		set_process(true)

	func _process(delta: float) -> void:
		var i := _wet.size() - 1
		var settled: Array = []
		while i >= 0:
			var pl: Array = _wet[i]
			if pl[4] > 0.0:
				pl[4] -= delta
			elif pl[2] < pl[1]:
				pl[2] = minf(pl[1], pl[2] + delta * maxf(1.2, (pl[1] - pl[2]) * 1.4))
			else:
				settled.append(pl)
				_wet.remove_at(i)
			i -= 1
		if not settled.is_empty():
			if _dry.is_empty() or (_dry[-1] as PoolDraw).items.size() > 40:
				var d := PoolDraw.new()
				add_child(d)
				move_child(d, 0)
				_dry.append(d)
				if _dry.size() > 8:
					(_dry.pop_front() as Node).queue_free()
			var dd: PoolDraw = _dry[-1]
			dd.items.append_array(settled)
			dd.queue_redraw()
		_wet_node.queue_redraw()
		if _wet.is_empty():
			set_process(false)


class PoolDraw extends Node2D:
	var items: Array = []
	func _draw() -> void:
		for pl in items:
			var r: float = pl[2]
			if r < 1.0 or pl[4] > 0.0:
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = pl[3]
			var p: Vector2 = pl[0]
			var lobes := []
			for i in 5:
				lobes.append([Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.35, 0.7), r * rng.randf_range(0.4, 0.7)])
			# dark rim, body, then a wet highlight (cel style: 3 flat tones)
			draw_circle(p, r + 1.0, Gore.BLOOD_DARK)
			for l in lobes:
				draw_circle(p + l[0], l[1] + 1.0, Gore.BLOOD_DARK)
			draw_circle(p, r, Color(0.45, 0.01, 0.06, 0.96))
			for l in lobes:
				draw_circle(p + l[0], l[1], Color(0.45, 0.01, 0.06, 0.96))
			draw_circle(p + Vector2(-r * 0.25, -r * 0.3), r * 0.45, Color(0.56, 0.03, 0.09, 0.9))
			draw_set_transform(p + Vector2(-r * 0.35, -r * 0.4), -0.5, Vector2(1.0, 0.4))
			draw_circle(Vector2.ZERO, maxf(1.0, r * 0.22), Color(1.0, 0.6, 0.65, 0.35))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Pulsing arterial spray.
class BloodSpray extends Node2D:
	var dir := Vector2.RIGHT
	var dur := 0.6
	var power := 1.0
	var _t := 0.0
	var _acc := 0.0
	func _process(delta: float) -> void:
		_t += delta
		_acc += delta
		var fx := Effects.get_fx()
		if fx == null:
			queue_free()
			return
		# heartbeat pulses
		var pulse := 0.5 + 0.5 * sin(_t * 22.0)
		if _acc > 0.025:
			_acc = 0.0
			var k := 1.0 - _t / dur
			var sweep := dir.rotated(sin(_t * 5.0) * 0.5)
			var dist := randf_range(6.0, 30.0) * power * (0.4 + pulse * 0.8) * k
			fx.decals.add_splat(global_position + sweep * dist + sweep.orthogonal() * randf_range(-2, 2), randf_range(0.8, 2.2), Color(0.6, 0.02, 0.08, 0.92))
			if pulse > 0.7:
				fx.emit("blood", global_position, sweep)
		if _t >= dur:
			queue_free()


## A body part on the move, then at rest.
class Gib extends Node2D:
	var kind := "chunk"
	var palette := "guard"
	var velocity := Vector2.ZERO
	var spin := 0.0
	var _trail := 0.0
	var _cols := {}
	var _t := 0.0

	func _ready() -> void:
		add_to_group("gibs")
		z_index = -3
		light_mask = 1
		var p: Dictionary = SpriteLib.PALETTES.get(palette, SpriteLib.PALETTES["guard"])
		for k in p.keys():
			_cols[k] = Color.html("#" + str(p[k]))

	func _process(delta: float) -> void:
		_t += delta
		if velocity.length() < 4.0:
			velocity = Vector2.ZERO
			set_process(false)
			if kind in ["head", "arm", "leg", "dog_head"]:
				Gore.pool(global_position, randf_range(3.5, 5.5))
			return
		var step := velocity * delta
		var space := get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step + step.normalized() * 2.0, Layers.WORLD | Layers.PROP | Layers.DOOR)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			velocity = velocity.bounce(hit.normal) * 0.45
			spin *= -0.6
			Effects.get_fx().decals.add_splat(hit.position, 2.0, Color(0.5, 0.02, 0.07, 0.9))
		else:
			position += step
		rotation += spin * delta
		spin = move_toward(spin, 0.0, delta * 20.0)
		velocity = velocity.move_toward(Vector2.ZERO, delta * (260.0 + velocity.length() * 1.5))
		_trail += step.length()
		if _trail > 4.0 and kind != "teeth":
			_trail = 0.0
			var fx := Effects.get_fx()
			if fx:
				fx.decals.add_splat(global_position, randf_range(0.8, 1.6) if kind != "chunk" else 1.2, Color(0.5, 0.02, 0.07, 0.88))

	func _o(pts: PackedVector2Array) -> PackedVector2Array:
		return pts

	func _draw() -> void:
		var ink := Color("0b0710")
		var skin: Color = _cols.get("s", Color.BISQUE)
		var shade: Color = _cols.get("S", skin.darkened(0.25))
		var hair: Color = _cols.get("h", Color.BLACK)
		var sleeve: Color = _cols.get("J", Color.GRAY)
		var pants: Color = _cols.get("p", Color.DIM_GRAY)
		var shoe: Color = _cols.get("P", Color.BLACK)
		var red := Color(0.62, 0.03, 0.09)
		var dred := Color(0.36, 0.0, 0.05)
		match kind:
			"head":
				var hp := ArtLib.sprite("severed_head")
				if hp:
					# the painting (neck to the right); the hair takes the palette
					draw_texture_rect(hp, Rect2(-5.5, -5.5, 11, 11), false)
					return
				# lying on its side: the skull an egg, hair over the crown,
				# an ear, the shut eye, and a torn neck with the spine showing
				draw_set_transform(Vector2(0.8, 1.2), 0.0, Vector2(1.0, 0.8))
				draw_circle(Vector2.ZERO, 4.4, Color(0, 0, 0, 0.3))
				draw_set_transform(Vector2(-0.3, 0), 0.0, Vector2(1.15, 0.92))
				draw_circle(Vector2.ZERO, 3.9, ink)
				draw_circle(Vector2.ZERO, 3.3, skin)
				draw_circle(Vector2(0.6, 0.9), 2.4, shade)
				draw_circle(Vector2(0.2, -1.2), 1.3, skin.lightened(0.18))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				if palette != "heavy":
					var cap := PackedVector2Array([Vector2(-4.4, -0.2), Vector2(-3.9, -2.6), Vector2(-2.2, -3.8), Vector2(-0.2, -3.9), Vector2(0.6, -2.9),
						Vector2(-0.6, -2.4), Vector2(-1.2, -0.6), Vector2(-0.8, 1.4), Vector2(0.2, 3.0), Vector2(-1.4, 3.6), Vector2(-3.4, 2.8)])
					draw_colored_polygon(cap, hair)
					for k in 4:
						var a0 := Vector2(-3.6 + k * 0.7, -2.4 + k * 1.3)
						draw_line(a0, a0 + Vector2(1.5, 0.3), hair.lightened(0.25), 0.4)
				draw_circle(Vector2(0.4, -3.1), 0.9, shade.darkened(0.2))     # ear
				draw_line(Vector2(1.2, -0.9), Vector2(2.0, -0.6), ink, 0.45)  # shut eye
				draw_line(Vector2(1.2, 1.1), Vector2(2.0, 0.9), ink, 0.45)
				draw_circle(Vector2(2.6, 0.1), 0.6, shade)                     # nose
				var stump := PackedVector2Array([Vector2(2.9, -2.4), Vector2(4.3, -2.0), Vector2(4.0, -0.9), Vector2(4.7, 0.1), Vector2(4.1, 1.2), Vector2(4.4, 2.2), Vector2(2.9, 2.5)])
				draw_colored_polygon(stump, red)
				draw_polyline(stump, dred, 0.5)
				draw_circle(Vector2(3.6, 0.1), 0.9, dred)
				draw_circle(Vector2(3.7, 0.1), 0.45, Color(0.92, 0.88, 0.8))   # spine
			"dog_head":
				draw_circle(Vector2.ZERO, 3.4, ink)
				draw_circle(Vector2.ZERO, 2.8, Color(0.16, 0.12, 0.1))
				draw_colored_polygon(PackedVector2Array([Vector2(-1, -2), Vector2(-3.5, -3.5), Vector2(-2.5, -0.5)]), Color(0.1, 0.08, 0.07))
				draw_colored_polygon(PackedVector2Array([Vector2(-1, 2), Vector2(-3.5, 3.5), Vector2(-2.5, 0.5)]), Color(0.1, 0.08, 0.07))
				draw_circle(Vector2(-3.0, 0), 1.4, red)
				draw_rect(Rect2(2.2, -0.8, 2.2, 1.6), Color(0.55, 0.32, 0.16))
			"arm":
				draw_line(Vector2(-4, 0), Vector2(3, 0), ink, 3.6)
				draw_line(Vector2(-4, 0), Vector2(2, 0), sleeve, 2.4)
				draw_line(Vector2(-4, -0.6), Vector2(2, -0.6), sleeve.lightened(0.18), 0.8)
				draw_circle(Vector2(3.4, 0), 1.6, ink)
				draw_circle(Vector2(3.4, 0), 1.1, skin)
				draw_circle(Vector2(-4.4, 0), 1.5, red)
				draw_circle(Vector2(-4.6, 0), 0.6, Color(0.95, 0.9, 0.85))
			"leg":
				draw_line(Vector2(-5, 0), Vector2(3, 0), ink, 4.2)
				draw_line(Vector2(-5, 0), Vector2(3, 0), pants, 3.0)
				draw_line(Vector2(-5, -0.8), Vector2(3, -0.8), pants.lightened(0.15), 0.9)
				draw_circle(Vector2(4.0, 0), 2.0, ink)
				draw_circle(Vector2(4.0, 0), 1.5, shoe)
				draw_circle(Vector2(-5.3, 0), 1.8, red)
				draw_circle(Vector2(-5.5, 0), 0.7, Color(0.95, 0.9, 0.85))
			"chunk":
				var pts := PackedVector2Array()
				var rng := RandomNumberGenerator.new()
				rng.seed = get_instance_id()
				for i in 7:
					pts.append(Vector2.from_angle(i * TAU / 7.0) * rng.randf_range(1.2, 2.6))
				draw_colored_polygon(pts, dred)
				draw_circle(Vector2(-0.4, -0.4), 1.1, red)
				draw_circle(Vector2(-0.6, -0.7), 0.4, Color(1, 0.6, 0.6, 0.7))
			"brain":
				draw_circle(Vector2.ZERO, 2.3, Color(0.55, 0.2, 0.28))
				draw_circle(Vector2.ZERO, 1.8, Color(0.9, 0.55, 0.62))
				draw_arc(Vector2(-0.5, 0), 1.0, 0.5, 3.0, 5, Color(0.6, 0.25, 0.32), 0.6)
				draw_arc(Vector2(0.6, 0.2), 0.8, 3.5, 6.0, 5, Color(0.6, 0.25, 0.32), 0.6)
			"bone":
				draw_line(Vector2(-2.5, 0), Vector2(2.5, 0), ink, 2.4)
				draw_line(Vector2(-2.5, 0), Vector2(2.5, 0), Color(0.95, 0.92, 0.84), 1.4)
				for e in [-2.8, 2.8]:
					draw_circle(Vector2(e, -0.7), 0.9, Color(0.95, 0.92, 0.84))
					draw_circle(Vector2(e, 0.7), 0.9, Color(0.95, 0.92, 0.84))
				draw_circle(Vector2(0, 0), 0.5, red)
			"teeth":
				for i in 3:
					draw_rect(Rect2(Vector2(i * 1.6 - 2.0, (i % 2) * 1.2 - 0.6), Vector2(1.0, 1.2)), Color(0.98, 0.96, 0.88))
			"eye":
				draw_circle(Vector2.ZERO, 1.6, Color(0.98, 0.96, 0.94))
				draw_circle(Vector2(0.5, 0), 0.8, Color(0.2, 0.35, 0.6))
				draw_circle(Vector2(0.6, 0), 0.4, ink)
				draw_line(Vector2(-1.5, 0), Vector2(-3.2, 0.6), red, 0.7)
			"tail":
				draw_line(Vector2(-4, 0), Vector2(4, 0), ink, 2.4)
				draw_line(Vector2(-4, 0), Vector2(4, 0), Color(0.16, 0.12, 0.1), 1.4)
				draw_circle(Vector2(-4, 0), 1.1, red)
