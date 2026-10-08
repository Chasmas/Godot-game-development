class_name Decor
extends RefCounted
## Atmospheric set dressing: swaying palms, flickering neon signs, animated
## pool caustics. Built from the level JSON "decor" list.

static func build(level: Node, root: Node2D, builder: LevelBuilder, items: Array) -> void:
	for it in items:
		var cell := Vector2i(int(it.pos[0]), int(it.pos[1]))
		var p := Vector2(float(it.pos[0]) * 16.0 + 8.0, float(it.pos[1]) * 16.0 + 8.0)
		match str(it.type):
			"rendered_prop":
				var rendered_root := level.props_root as Node2D if bool(it.get("sort_with_actors", false)) else root
				# Blender render framed about its authored ground footprint.
				# Imported textures are shared and remain available in exports.
				var path := str(it.get("texture", ""))
				if not ResourceLoader.exists(path):
					push_warning("Missing rendered decor: " + path)
					continue
				var tex := load(path) as Texture2D
				if tex == null:
					continue
				var sp := Sprite2D.new()
				sp.texture = tex
				sp.position = p
				var offset: Array = it.get("render_offset", [0,0])
				sp.offset = Vector2(float(offset[0]),float(offset[1]))
				sp.scale = Vector2.ONE * float(it.get("width", 56.32)) / tex.get_width()
				var brightness := float(it.get("brightness", 1.0))
				sp.modulate = Color(brightness,brightness,brightness,1)
				sp.z_index = 1
				sp.set_meta("rendered_decor_id", str(it.get("id", "")))
				rendered_root.add_child(sp)
				var footprint: Array = it.get("footprint", [])
				if footprint.size() == 4:
					var area := Rect2(float(footprint[0]),float(footprint[1]),float(footprint[2]),float(footprint[3]))
					var body := StaticBody2D.new()
					body.position = p + area.get_center()
					body.collision_layer = Layers.LOW if str(it.get("collision", "solid")) == "low" else Layers.PROP
					body.collision_mask = 0
					var shape := CollisionShape2D.new()
					var rectangle := RectangleShape2D.new()
					rectangle.size = area.size
					shape.shape = rectangle
					body.add_child(shape)
					rendered_root.add_child(body)
					var bounds := Rect2(p + area.position,area.size)
					for y in range(floori(bounds.position.y/16),ceili(bounds.end.y/16)):
						for x in range(floori(bounds.position.x/16),ceili(bounds.end.x/16)):
							if level.nav.is_in_boundsv(Vector2i(x,y)):
								level.nav.set_point_solid(Vector2i(x,y),true)
			"steam_vent":
				if not _valid_floor_sprite(builder, cell):
					continue
				var vent := Node2D.new()
				vent.set_script(load("res://scripts/levels/steam_vent.gd"))
				vent.texture = load("res://assets/art/vfx/steam_wisp_v1.png")
				vent.position = p + Vector2(0, -10)
				vent.z_index = 2
				root.add_child(vent)
			"palm":
				var pt := PalmTree.new()
				pt.position = p
				pt.size = float(it.get("size", 1.0))
				root.add_child(pt)
			"sprite":
				# a painted prop laid on the floor (studio cameras, lights...)
				# Never render a floor piece on the wall top or in a doorway. A
				# malformed decor entry should fail quietly instead of producing a
				# floating prop over the room divider.
				if it.get("floor", false) and not _valid_floor_sprite(builder, cell):
					continue
				var tex := ArtLib.sprite(str(it.get("id", "")))
				if tex:
					var sp := Sprite2D.new()
					sp.texture = tex
					sp.set_meta("decor_asset_id",str(it.get("id","")))
					sp.scale = Vector2.ONE * float(it.get("size", 0.5))
					sp.position = p
					if it.get("floor", false):
						sp.rotation = deg_to_rad(float(it.get("rot", 0.0)))
						sp.z_index = -5
					else:
						# Standing things are drawn from the oblique camera: turning them
						# stands them on their heads. A mirror gives the variety instead,
						# and they sort against the cast by their foot (origin at the base).
						var turned := fposmod(float(it.get("rot", 0.0)), 360.0)
						sp.flip_h = turned > 90.0 and turned < 270.0
						sp.offset.y = -tex.get_height() * 0.5
						sp.position.y += tex.get_height() * 0.5 * sp.scale.y
						sp.z_index = 1
					if str(it.get("id", "")) in ["motel_pool_float", "motel_pool_float_flamingo"]:
						sp.set_script(load("res://scripts/levels/animated_prop.gd"))
						sp.bob_amplitude = 1.1
						sp.bob_speed = 0.85
						sp.drift_amplitude = 1.6
					elif str(it.get("id", "")) == "motel_pool_party_ruin":
						sp.set_script(load("res://scripts/levels/animated_prop.gd"))
						sp.bob_amplitude = 0.45
						sp.bob_speed = 0.55
						sp.sway_amplitude = 0.018
					elif str(it.get("id", "")) == "motel_tv_crt":
						sp.set_script(load("res://scripts/levels/ambient_screen.gd"))
						sp.pulse_speed = 2.1
						sp.pulse_amount = 0.06
					root.add_child(sp)
					# Light-emitting props cast a PointLight2D so they feel like
					# real sources instead of painted decoration.
					var lc := _light_cfg(str(it.get("id", "")))
					if not lc.is_empty():
						var lf := LightFixture.new()
						lf.setup(builder.zone_at_cell(cell.x, cell.y),
							lc["color"], lc["radius"], lc["energy"],
							lc.get("shadows", false), lc.get("flicker", false))
						lf.position = p + lc.get("offset", Vector2.ZERO)
						root.add_child(lf)
			"pickup":
				# an old pickup truck, parked for good: solid, blocks shots
				var pk := OldPickup.new()
				pk.position = p
				pk.rotation = deg_to_rad(float(it.get("rot", 0.0)))
				root.add_child(pk)
				var nav: AStarGrid2D = level.get("nav")
				if nav:
					var hs := Vector2(26, 14)
					for yy in range(int((p.y - 20) / 16.0), int((p.y + 20) / 16.0) + 1):
						for xx in range(int((p.x - 30) / 16.0), int((p.x + 30) / 16.0) + 1):
							var cc := Vector2(xx * 16 + 8, yy * 16 + 8) - p
							var lc := cc.rotated(-pk.rotation)
							if absf(lc.x) < hs.x and absf(lc.y) < hs.y and nav.is_in_boundsv(Vector2i(xx, yy)):
								nav.set_point_solid(Vector2i(xx, yy), true)
			"trash":
				# litter spread around a spot: cans, paper, cups, butts, a tyre
				var tr := TrashScatter.new()
				tr.position = p
				tr.radius = float(it.get("radius", 40.0))
				tr.count = int(it.get("count", 26))
				root.add_child(tr)
			"vacancy":
				var vs := WallArt.VacancySign.new()
				vs.position = p
				root.add_child(vs)
			"neon":
				var ns := NeonSign.new()
				ns.text = str(it.get("text", "OPEN"))
				ns.color = Color.html("#" + str(it.get("color", "ff3d7f")))
				ns.font_size = int(it.get("size", 14))
				ns.zone = builder.zone_at_cell(int(it.pos[0]), int(it.pos[1]))
				var spot := mount_sign(builder, int(it.pos[0]), int(it.pos[1]), ns.board_size().x)
				ns.position = spot.pos
				ns.mount = spot.mount
				root.add_child(ns)
	var pool := PoolFX.new()
	pool.builder = builder
	root.add_child(pool)

## A soft dark pool under a standing prop so it sits on the floor instead of floating.
static func _contact_shadow(p: Vector2, sz: Vector2, rot: float) -> Sprite2D:
	var sh := Sprite2D.new()
	sh.texture = SpriteLib.light_texture(128)
	sh.modulate = Color(0, 0, 0, 0.42)
	sh.position = p + Vector2(1.5, sz.y * 0.28)
	sh.rotation = rot
	sh.scale = Vector2(sz.x * 1.05, sz.y * 0.62) / 128.0
	sh.z_index = -6
	sh.light_mask = 2
	return sh

## Light colour/radius for props that are real light sources.
## Keeps Decor self-contained — no data file needed.
static func _light_cfg(id: String) -> Dictionary:
	match id:
		"candelabra":
			return {"color": Color(1.0, 0.72, 0.35), "radius": 52.0, "energy": 0.65, "flicker": true}
		"villa_candle_ring":
			return {"color": Color(1.0, 0.68, 0.28), "radius": 44.0, "energy": 0.55, "flicker": true}
		"villa_wax_and_petals":
			return {"color": Color(1.0, 0.72, 0.38), "radius": 34.0, "energy": 0.45, "flicker": true}
		"yard_burn_barrel":
			return {"color": Color(1.0, 0.42, 0.06), "radius": 64.0, "energy": 0.9, "shadows": true, "flicker": true}
		"studio_overhead_light_rig":
			return {"color": Color(0.88, 0.92, 1.0), "radius": 88.0, "energy": 1.1, "shadows": true}
		"hq_fire_barrel":
			return {"color": Color(1.0, 0.45, 0.08), "radius": 70.0, "energy": 0.95, "shadows": true, "flicker": true, "offset": Vector2(0, -6)}
		"hq_fireplace":
			return {"color": Color(1.0, 0.5, 0.15), "radius": 100.0, "energy": 1.0, "flicker": true}
		"hq_chandelier_big":
			return {"color": Color(1.0, 0.86, 0.58), "radius": 110.0, "energy": 0.9}
		"hq_light_stand":
			return {"color": Color(0.95, 0.97, 1.0), "radius": 96.0, "energy": 1.1, "shadows": true}
		"hq_neon_beer_sign":
			return {"color": Color(1.0, 0.25, 0.35), "radius": 54.0, "energy": 0.7, "flicker": true}
		"hq_motel_vending":
			return {"color": Color(0.5, 0.85, 1.0), "radius": 48.0, "energy": 0.6}
		"hq_monitor_bank":
			return {"color": Color(0.4, 0.85, 1.0), "radius": 70.0, "energy": 0.7, "flicker": true}
		"hq_display_cabinet", "hq_bar_cabinet":
			return {"color": Color(1.0, 0.8, 0.5), "radius": 52.0, "energy": 0.5}
		"hq_makeup_station":
			return {"color": Color(1.0, 0.88, 0.7), "radius": 60.0, "energy": 0.7}
		"floor_lamp":
			return {"color": Color(1.0, 0.82, 0.52), "radius": 72.0, "energy": 0.8}
		"chandelier":
			return {"color": Color(1.0, 0.88, 0.62), "radius": 96.0, "energy": 0.85}
		"motel_neon_vacancy_sign":
			return {"color": Color(1.0, 0.2, 0.6), "radius": 48.0, "energy": 0.7, "flicker": true, "offset": Vector2(0, -8)}
		"motel_bedside_lamp":
			return {"color": Color(1.0, 0.78, 0.45), "radius": 44.0, "energy": 0.6}
		"coffin":
			return {"color": Color(0.35, 0.9, 0.55), "radius": 38.0, "energy": 0.3}
		"villa_fountain":
			return {"color": Color(0.55, 0.82, 1.0), "radius": 56.0, "energy": 0.4}
		"studio_spotlight_beam":
			return {"color": Color(0.95, 0.98, 1.0), "radius": 72.0, "energy": 1.2}
		"yard_welder_sparks":
			return {"color": Color(1.0, 0.65, 0.1), "radius": 40.0, "energy": 1.4, "flicker": true}
		_:
			return {}

static func _valid_floor_sprite(builder: LevelBuilder, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= builder.w or cell.y >= builder.h:
		return false
	if not LevelBuilder.FLOORS.contains(builder.ch(cell.x, cell.y)):
		return false
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var n := builder.ch(cell.x + d.x, cell.y + d.y)
		if n == "D" or n == "L" or n == "W":
			return false
	return true


## Top-down palm: canopy of fronds above everything, with a soft ground
## shadow. The crown is not a rigid picture turning on a pin: it is cut into
## a polar mesh (sectors x rings) and every vertex bends by how far out it is
## - the trunk end stays put, the tips whip. Each frond has its own phase, so
## a wave runs round the crown; the wind comes in gusts (layered slow sines),
## pushes the whole canopy downwind and makes the tips flutter. Now and then a
## leaf lets go, tumbles away with the wind and settles on the ground.
class PalmTree extends Node2D:
	var size := 1.0
	var _burn_t := 0.0
	var _burn_seed := 0.0
	var _canopy_burned := false
	var _burn_particles: Array = []
	var flame_texture: Texture2D
	var trunk_texture: Texture2D
	var smoke_texture: Texture2D
	var _smoke: Array = []
	var _smoke_timer := 0.0
	var _burn_glow: PointLight2D
	var _t := 0.0
	var _seed := 0.0
	var _shadow: Node2D
	var _ground: Node2D
	var _leaves: Array = []      # falling: {p, v, rot, spin, h, vh, s, c}
	var _charred_sectors: Dictionary = {}
	var _next_leaf := 0.0
	const SECTORS := 14
	const RINGS := 4

	func _ready() -> void:
		z_index = 45
		if ResourceLoader.exists("res://assets/art/vfx/flame_v1.png"):
			flame_texture = load("res://assets/art/vfx/flame_v1.png")
		if ResourceLoader.exists("res://assets/art/vfx/palm_trunk_top_v1.png"):
			trunk_texture = load("res://assets/art/vfx/palm_trunk_top_v1.png")
		if ResourceLoader.exists("res://assets/art/vfx/steam_wisp_v1.png"):
			smoke_texture = load("res://assets/art/vfx/steam_wisp_v1.png")
		_seed = randf() * 10.0
		_burn_seed = randf() * 20.0
		_next_leaf = randf_range(2.0, 9.0)
		_vis_t = randf() * 0.25
		_shadow = PalmShadow.new()
		_shadow.size = size
		_shadow.palm = self
		_shadow.z_index = -6
		_shadow.z_as_relative = false
		add_child(_shadow)
		_ground = FallenLeaves.new()
		_ground.z_index = -5
		_ground.z_as_relative = false
		add_child(_ground)

	## The wind is read once a frame (and only while the tree is on screen):
	## the crown's 70 vertices, twice over with the shadow, all use it.
	var _weather: Node
	var _w := 0.2
	var _wdir := Vector2(1, 0.25).normalized()
	var _g := 0.0
	var _sway := 0.0
	var _lean := Vector2.ZERO
	var _breathe := 1.0
	var _vis_t := 0.0

	func _process(d: float) -> void:
		_t += d
		var was_burning := _burn_t > 0.0
		_burn_t = maxf(0.0, _burn_t - d)
		if was_burning and _burn_t <= 0.0:
			_canopy_burned = true
		if _burn_t > 0.0:
			_spawn_burn_particles(d)
		_tick_burn_particles(d)
		_tick_smoke(d)
		_tick_burn_glow()
		_vis_t -= d
		if _vis_t <= 0.0:
			_vis_t = 0.25
			var vp := get_viewport()
			visible = vp.get_visible_rect().grow(160.0).has_point(vp.get_canvas_transform() * global_position)
		if not visible:
			return
		# the crown thins out when she's under it, so nothing hides there
		# (a switch on the wall, a gun on the floor, a guard)
		var pl := get_tree().get_first_node_in_group("player") as Node2D
		var under := pl != null and pl.global_position.distance_to(global_position) < 30.0 * size
		modulate.a = move_toward(modulate.a, 0.35 if under else 1.0, d * 3.0)
		_read_wind()
		_tick_leaves(d)
		queue_redraw()
		if Engine.get_process_frames() % 2 == 0:
			_shadow.queue_redraw()

	## Rare ambient event hook. It is visual only and never changes collision/nav.
	func start_lightning_fire() -> void:
		if _canopy_burned or _burn_t > 0.0:
			return
		_burn_t = 12.0
		_burn_seed = randf() * 20.0
		_burn_particles.clear()
		for i in 22: _add_ember(i % SECTORS)
		queue_redraw()
		var glow := PointLight2D.new()
		glow.texture = SpriteLib.light_texture(96)
		glow.color = Color(1.0, 0.28, 0.06)
		glow.energy = 0.0
		glow.texture_scale = 0.55
		glow.position = bend(0.0, 0.0, 1.0)
		add_child(glow)
		_burn_glow = glow

	func _tick_burn_glow() -> void:
		if not is_instance_valid(_burn_glow): return
		if _burn_t <= 0.0:
			_burn_glow.energy = 0.0
			_burn_glow.queue_free()
			_burn_glow = null
			return
		var foliage := 0.0
		for sector in SECTORS: foliage += sector_survival(sector)
		foliage /= float(SECTORS)
		var ignition := smoothstep(0.0, 0.18, 12.0 - _burn_t)
		var flicker := 0.85 + sin(_t * 9.0 + _burn_seed) * 0.15
		_burn_glow.energy = 0.9 * ignition * foliage * flicker

	func _add_ember(sector: int) -> void:
		if sector_survival(sector) <= 0.05: return
		var lifetime := randf_range(0.7,1.6)
		_burn_particles.append({"p": fire_anchor(sector) + Vector2(randf_range(-2,2),randf_range(-2,2))*size,
			"v": (Vector2(randf_range(-4,4),randf_range(-14,-5)) + _wdir*_g*5.0)*size,
			"life": lifetime, "total": lifetime, "s": randf_range(0.18,0.45)*size,
			"c": Color(1.0,randf_range(0.35,0.75),0.12,0.8)})

	func _spawn_burn_particles(d: float) -> void:
		if _burn_particles.size() >= 38 or randf() > d * 18.0: return
		_add_ember(randi() % SECTORS)

	func _draw_embers() -> void:
		var glow := SpriteLib.light_texture(32)
		for p in _burn_particles:
			var remaining := clampf(float(p.life)/float(p.total),0.0,1.0)
			var fade := smoothstep(0.0,0.4,remaining)
			var radius := float(p.s)*5.0
			draw_texture_rect(glow,Rect2(p.p-Vector2.ONE*radius,Vector2.ONE*radius*2),false,Color(p.c.r,p.c.g,p.c.b,fade*0.5))
			draw_line(p.p,p.p-p.v.normalized()*float(p.s)*2.0,Color(1,0.75,0.35,fade*0.7),maxf(0.25,float(p.s)),true)

	func _tick_burn_particles(d: float) -> void:
		for p in _burn_particles:
			p.p += p.v * d
			p.v.y -= 2.0 * size * d
			p.life -= d
		for i in range(_burn_particles.size() - 1, -1, -1):
			if float(_burn_particles[i].life) <= 0.0:
				_burn_particles.remove_at(i)

	func _tick_smoke(d: float) -> void:
		for puff in _smoke:
			puff.age += d
			puff.p += puff.v * d
		for i in range(_smoke.size()-1,-1,-1):
			if _smoke[i].age >= 3.0: _smoke.remove_at(i)
		_smoke_timer -= d
		if _burn_t <= 0.0 or _smoke_timer > 0.0 or _smoke.size() >= 6: return
		_smoke_timer = 0.6
		var sector := randi() % SECTORS
		if sector_survival(sector) < 0.15: return
		_smoke.append({"p":fire_anchor(sector),"v":(_wdir*(3.0+_g*4.0)+Vector2(0,-5))*size,"age":0.0,"rot":randf_range(-0.15,0.15)})

	func _draw_smoke() -> void:
		if smoke_texture == null: return
		for puff in _smoke:
			var life: float = puff.age/3.0
			var opacity := 0.4*smoothstep(0.0,0.2,life)*(1.0-smoothstep(0.45,1.0,life))
			var dimensions := Vector2(24,30)*size*(0.8+life*0.7)
			draw_set_transform(puff.p,puff.rot+life*0.1)
			draw_texture_rect(smoke_texture,Rect2(-dimensions*0.5,dimensions),false,Color(0.6,0.61,0.65,opacity))
		draw_set_transform(Vector2.ZERO)

	func _read_wind() -> void:
		if _weather == null or not is_instance_valid(_weather):
			_weather = get_tree().get_first_node_in_group("weather")
		_w = float(_weather.wind) if _weather else 0.2
		_wdir = Vector2(1, 0.25).normalized()
		if _weather and "wind_dir" in _weather:
			var v = _weather.wind_dir
			if v is Vector2 and v != Vector2.ZERO:
				_wdir = v.normalized()
		var g := 0.55 + 0.3 * sin(_t * 0.37 + _seed) + 0.2 * sin(_t * 0.91 + _seed * 2.3) + 0.1 * sin(_t * 2.3 + _seed * 0.7)
		_g = _w * clampf(g, 0.1, 1.3)
		_sway = sin(_t * (0.9 + _g * 0.8) + _seed) * (0.03 + _g * 0.06)
		_lean = _wdir * _g * 4.0 * size
		_breathe = 1.0 + sin(_t * 1.7 + _seed) * 0.012 * (1.0 + _w)

	func _wind() -> float:
		return _w

	func _wind_dir() -> Vector2:
		return _wdir

	## 0..~1.3: the wind as it arrives, in gusts and lulls
	func gust() -> float:
		return _g

	## Kept for anything that asks for the crown's overall turn.
	func sway() -> float:
		return _sway

	func lean() -> Vector2:
		return _lean

	func breathe() -> float:
		return _breathe

	## Where a crown point (polar: angle a, radius fraction r 0..1) is now.
	## `amp` lets the shadow exaggerate a touch.
	func bend(a: float, r: float, R: float, amp := 1.0) -> Vector2:
		var g := _g
		var k := r * r                                   # stiff near the trunk, loose at the tips
		var frond := sin(_t * (1.3 + g * 1.4) + a * 3.0 + _seed) * (0.05 + g * 0.1)
		var flutter := sin(_t * (7.0 + g * 6.0) + a * 11.0 + _seed * 3.0) * 0.02 * g
		var ang := a + _sway + (frond + flutter) * k * amp
		var droop := 1.0 + sin(_t * 1.1 + a * 2.0 + _seed) * 0.04 * k - g * 0.05 * k
		var pos := Vector2.from_angle(ang) * r * R * droop * _breathe
		# the canopy is pushed downwind, the tips most of all
		return pos + _lean * (0.35 + k) * amp

	## The deformed crown as triangles with UVs into the painted texture.
	func crown_polys(R: float, amp := 1.0) -> Array:
		var out: Array = []
		var grid: Array = []
		for ri in RINGS + 1:
			var row: Array = []
			var r := float(ri) / RINGS
			for si in SECTORS:
				var a := float(si) / SECTORS * TAU
				row.append([bend(a, r, R, amp), Vector2(0.5, 0.5) + Vector2.from_angle(a) * r * 0.5])
			grid.append(row)
		for ri in RINGS:
			for si in SECTORS:
				var sn := (si + 1) % SECTORS
				var a0: Array = grid[ri][si]
				var a1: Array = grid[ri][sn]
				var b0: Array = grid[ri + 1][si]
				var b1: Array = grid[ri + 1][sn]
				out.append([PackedVector2Array([a0[0], b0[0], b1[0], a1[0]]), PackedVector2Array([a0[1], b0[1], b1[1], a1[1]])])
		return out

	func _draw() -> void:
		var tex := ArtLib.sprite("palm")
		if tex and not _canopy_burned:
			# the painted crown's corners fall outside the circle - the art is
			# a round canopy on a transparent square, so the fan loses nothing
			var R: float = tex.get_width() * 0.5 * 0.5 * size * 1.414
			draw_set_transform(Vector2.ZERO, _seed, Vector2.ONE)
			var polygons := crown_polys(R)
			for qi in polygons.size():
				var q: Array = polygons[qi]
				var survival := sector_survival(qi % SECTORS)
				if survival <= 0.0: continue
				var burn := 1.0 - survival
				var col := Color.WHITE.lerp(Color(0.22, 0.12, 0.07), burn)
				col.a = survival
				var tint := PackedColorArray([col, col, col, col])
				var uv: PackedVector2Array = q[1]
				# the square's corners: stretch the outer ring's UVs to reach them
				var uv2 := PackedVector2Array()
				for u in uv:
					var c := u - Vector2(0.5, 0.5)
					uv2.append(Vector2(0.5, 0.5) + c * 1.414)
				draw_polygon(q[0], tint, uv2, tex)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			_draw_procedural()
		# Sector fading includes the painted centre, but the intact trunk must
		# remain visible throughout the burn, even with faint residual fronds.
		if tex and not _canopy_burned and _burn_t > 0.0:
			_draw_trunk()
		_draw_leaves()
		if _burn_t > 0.0 and flame_texture != null:
			_draw_textured_fire()
			_draw_embers()
			_draw_smoke()
			return
		if _burn_t > 0.0:
			var pulse := 0.82 + sin(_t * 9.0 + _burn_seed) * 0.18
			# The canopy catches first; the trunk remains intact.
			var base := Vector2(0, -34) * size
			draw_circle(base, 13.0 * size * pulse, Color(1.0, 0.10, 0.01, 0.12))
			draw_circle(base, 8.0 * size * pulse, Color(1.0, 0.18, 0.03, 0.3))
			for i in 7:
				var x := (float(i) - 1.5) * 5.0 * size
				var h := (17.0 + fmod(_burn_seed + i * 7.0, 15.0)) * size * pulse
				var tip := base + Vector2(x * 0.35, -h)
				draw_colored_polygon(PackedVector2Array([base + Vector2(x - 5.0, 2), base + Vector2(x + 5.0, 2), tip]), Color(0.95, 0.08 + (i % 3) * 0.08, 0.01, 0.88))
				draw_colored_polygon(PackedVector2Array([base + Vector2(x - 2.0, 0), base + Vector2(x + 2.0, 0), tip + Vector2(0, 3)],), Color(1.0, 0.75, 0.08, 0.9))
				draw_circle(tip, 2.5 * size, Color(1.0, 0.9, 0.3, 0.95))
		_draw_embers()
		_draw_smoke()

	func _draw_textured_fire() -> void:
		for i in 8:
			var phase := _t * (3.8 + float(i) * 0.13) + float(i) * 1.7 + _burn_seed
			var sector := int(float(i) * SECTORS / 8.0)
			var survival := sector_survival(sector)
			if survival <= 0.0: continue
			var anchor := fire_anchor(sector)
			var height := (21.0 + sin(phase) * 2.5 + sin(phase*1.37)*1.5 + float(i % 3)*2.0)*size
			var width := height * (0.48 + float(i%3)*0.035)
			var tint := Color(1,1,1,(0.73+sin(phase*1.23)*0.1)*survival)
			draw_set_transform(anchor)
			for band in 6:
				var lower := float(band)/6.0
				var upper := float(band+1)/6.0
				var bottom := flame_row(lower,phase,width,height)
				var top := flame_row(upper,phase,width,height)
				var points := PackedVector2Array([bottom[0],bottom[1],top[1],top[0]])
				var uv := PackedVector2Array([Vector2(0,1-lower),Vector2(1,1-lower),Vector2(1,1-upper),Vector2(0,1-upper)])
				draw_polygon(points,PackedColorArray([tint,tint,tint,tint]),uv,flame_texture)
		draw_set_transform(Vector2.ZERO)

	func flame_row(fraction: float, phase: float, width: float, height: float) -> PackedVector2Array:
		# Base stays anchored; turbulence grows continuously towards the tip.
		var shift := (sin(phase-fraction*5.0)*2.4+sin(phase*1.61-fraction*9.0)*1.2)*fraction*size
		shift += _wdir.x*_g*fraction*fraction*3.0*size
		var half_width := width*0.5*(1.0+sin(phase*1.3-fraction*6.0)*fraction*0.12)
		return PackedVector2Array([Vector2(shift-half_width,-fraction*height),Vector2(shift+half_width,-fraction*height)])

	func fire_anchor(sector: int) -> Vector2:
		# Match the painted fan's angular sector and final crown rotation.
		return bend((float(sector) + 0.5) * TAU / SECTORS, 0.35, 30.0 * size).rotated(_seed)

	func sector_survival(sector: int) -> float:
		if _canopy_burned: return 0.0
		if _burn_t <= 0.0: return 1.0
		var progress := clampf(1.0 - _burn_t / 12.0, 0.0, 1.0)
		# Spread consumption around the crown instead of erasing every frond
		# on the same frame. The seed stays fixed throughout this tree's life.
		var start := 0.12 + fposmod(float(sector) * 0.618034 + _seed * 0.1, 1.0) * 0.5
		return 1.0 - smoothstep(start, start + 0.26, progress)

	func _draw_procedural() -> void:
		for i in (0 if _canopy_burned else 9):
			var a := i * TAU / 9.0 + _seed
			var L := (26.0 + (i % 3) * 5.0) * size
			var base := bend(a, 0.0, L)
			var tip := bend(a, 1.0, L)
			var midp := bend(a + 0.05, 0.5, L)
			var dir := (tip - base).normalized()
			var w := 5.0 * size
			var pts := PackedVector2Array([base, midp + dir.orthogonal() * w, tip, midp - dir.orthogonal() * w * 0.4])
			draw_colored_polygon(pts, Color(0.1, 0.32, 0.18, 0.96))
			draw_polyline(PackedVector2Array([base, midp, tip]), Color(0.22, 0.55, 0.28, 0.9), 1.0)
			for k in 3:
				var q := bend(a, 0.35 + k * 0.2, L)
				draw_line(q, q + dir.rotated(0.9) * 4.0 * size, Color(0.06, 0.22, 0.12, 0.9), 1.0)
		_draw_trunk()

	func _draw_trunk() -> void:
		var c := bend(0.0, 0.0, 1.0)
		if trunk_texture != null:
			draw_texture_rect(trunk_texture, Rect2(c - Vector2.ONE * 8.0 * size, Vector2.ONE * 16.0 * size), false)
			return
		draw_circle(c, 4.0 * size, Color(0.35, 0.22, 0.1))
		draw_circle(c + Vector2(-1, -1), 2.0 * size, Color(0.55, 0.38, 0.18))

	# ---- leaves letting go
	func _tick_leaves(d: float) -> void:
		var g := gust()
		if _burn_t > 0.0:
			for sector in SECTORS:
				if sector_survival(sector) > 0.2 or _charred_sectors.has(sector): continue
				_charred_sectors[sector] = true
				var angle := (float(sector)+0.5)*TAU/SECTORS
				var origin := bend(angle,0.7,30.0*size).rotated(_seed)
				_leaves.append({"p":origin,"v":_wind_dir()*6.0,"rot":angle+_seed,"spin":randf_range(-2.0,2.0),
					"h":1.0,"vh":0.5,"s":randf_range(0.2,0.45)*size,"c":Color(0.16,0.12,0.09),"ph":randf()*TAU})
		_next_leaf -= d * (0.4 + g * 1.6)
		if not _canopy_burned and _burn_t <= 0.0 and _next_leaf <= 0.0 and _leaves.size() < 6:
			_next_leaf = randf_range(3.0, 11.0)
			var a := randf() * TAU
			var start := bend(a, randf_range(0.6, 0.95), 24.0 * size)
			var greens := [Color(0.16, 0.42, 0.2), Color(0.3, 0.5, 0.18), Color(0.55, 0.5, 0.2), Color(0.45, 0.3, 0.12)]
			_leaves.append({"p": start, "v": _wind_dir() * (10.0 + g * 30.0) + Vector2.from_angle(a) * 8.0,
				"rot": a, "spin": randf_range(-3.0, 3.0), "h": 1.0, "vh": randf_range(0.18, 0.3),
				"s": randf_range(0.8, 1.3) * size, "c": greens[randi() % greens.size()], "ph": randf() * TAU})
		for lf in _leaves:
			var t: float = _t + float(lf.ph)
			# flutter: the leaf rocks side to side as it sinks, sliding downwind
			var side: Vector2 = Vector2.from_angle(float(lf.rot)).orthogonal() * sin(t * 4.0) * 14.0
			lf.v = (lf.v as Vector2).lerp(_wind_dir() * (8.0 + g * 40.0), d * 0.8)
			lf.p = (lf.p as Vector2) + ((lf.v as Vector2) + side) * d
			lf.rot = float(lf.rot) + float(lf.spin) * d * (0.5 + absf(sin(t * 2.0)))
			lf.h = float(lf.h) - float(lf.vh) * d * (0.7 + 0.3 * sin(t * 3.0))
		for k in range(_leaves.size() - 1, -1, -1):
			var lf: Dictionary = _leaves[k]
			if float(lf.h) <= 0.0:
				_ground.land(lf.p, lf.rot, lf.s, lf.c)
				_leaves.remove_at(k)

	func _draw_leaves() -> void:
		for lf in _leaves:
			var h: float = float(lf.h)
			# high up it's bigger (nearer the camera) and throws a shadow below
			var sc: float = float(lf.s) * (0.8 + 0.5 * h)
			var p: Vector2 = lf.p
			_leaf_shape(p + Vector2(6, 8) * h, float(lf.rot), sc, Color(0, 0, 0.02, 0.25 * (1.0 - h * 0.5)))
			_leaf_shape(p, float(lf.rot), sc, lf.c)

	func _leaf_shape(p: Vector2, rot: float, sc: float, col: Color) -> void:
		var d := Vector2.from_angle(rot)
		var n := d.orthogonal()
		var L := 5.0 * sc
		var W := 1.6 * sc
		draw_colored_polygon(PackedVector2Array([p - d * L, p + n * W, p + d * L, p - n * W * 0.6]), col)
		if col.a > 0.5:
			draw_line(p - d * L, p + d * L, col.darkened(0.35), 1.0)


## Leaves that fell: lie on the floor a while, curl and fade.
class FallenLeaves extends Node2D:
	var _items: Array = []
	var _t := 0.0

	func land(p: Vector2, rot: float, s: float, c: Color) -> void:
		_items.append({"p": p, "rot": rot, "s": s, "c": c, "age": 0.0, "life": randf_range(14.0, 26.0)})
		if _items.size() > 14:
			_items.pop_front()

	func _process(d: float) -> void:
		if _items.is_empty():
			return
		_t += d
		for it in _items:
			it.age = float(it.age) + d
		_items = _items.filter(func(it): return float(it.age) < float(it.life))
		if Engine.get_process_frames() % 4 == 0:
			queue_redraw()

	func _draw() -> void:
		for it in _items:
			var fade := clampf((float(it.life) - float(it.age)) / 4.0, 0.0, 1.0)
			var c: Color = (it.c as Color).darkened(clampf(float(it.age) / float(it.life), 0.0, 0.5))
			c.a = fade * 0.95
			var d := Vector2.from_angle(float(it.rot))
			var n := d.orthogonal()
			var L := 5.0 * float(it.s)
			var W := 1.4 * float(it.s)
			var p: Vector2 = it.p
			draw_colored_polygon(PackedVector2Array([p - d * L, p + n * W, p + d * L, p - n * W * 0.6]), c)
			draw_line(p - d * L, p + d * L, c.darkened(0.35), 1.0)


## The palm's shadow on the ground: the crown's own silhouette, thrown down
## and to the side by the light and squashed onto the floor, bending vertex
## for vertex with the tree (same mesh, same gusts) but a touch further, as a
## shadow does.
class PalmShadow extends Node2D:
	var size := 1.0
	var palm: PalmTree
	const OFFSET := Vector2(12, 16)
	const SHADE := Color(0.0, 0.0, 0.02, 0.4)
	func _draw() -> void:
		if palm == null:
			return
		var base := OFFSET * size
		if palm._canopy_burned:
			# Only the intact trunk remains; do not retain a leafy silhouette.
			draw_circle(base, 4.0 * size, SHADE)
			return
		var tex := ArtLib.sprite("palm")
		draw_set_transform_matrix(Transform2D(0.0, Vector2(1.05, 0.72), 0.25, base) * Transform2D(palm._seed, Vector2.ZERO))
		if tex:
			var R: float = tex.get_width() * 0.5 * 0.5 * size * 1.414
			var polygons := palm.crown_polys(R, 1.25)
			for qi in polygons.size():
				var q: Array = polygons[qi]
				var shade := SHADE
				shade.a *= palm.sector_survival(qi % palm.SECTORS)
				var tint := PackedColorArray([shade, shade, shade, shade])
				var uv2 := PackedVector2Array()
				for u in (q[1] as PackedVector2Array):
					uv2.append(Vector2(0.5, 0.5) + (u - Vector2(0.5, 0.5)) * 1.414)
				draw_polygon(q[0], tint, uv2, tex)
		else:
			for i in 9:
				var a := i * TAU / 9.0
				var L := (26.0 + (i % 3) * 5.0) * size
				var b0 := palm.bend(a, 0.0, L, 1.25)
				var tip := palm.bend(a, 1.0, L, 1.25)
				var mid := palm.bend(a + 0.05, 0.5, L, 1.25)
				var dir := (tip - b0).normalized()
				var w := 5.0 * size
				draw_colored_polygon(PackedVector2Array([b0, mid + dir.orthogonal() * w, tip, mid - dir.orthogonal() * w * 0.4]), SHADE)
			draw_circle(Vector2.ZERO, 4.0 * size, SHADE)
		draw_set_transform_matrix(Transform2D.IDENTITY)


## Where a sign really hangs. A sign is never left floating over the floor:
## it goes on the nearest stretch of plain wall (no doors, no windows) whose
## face looks toward where the level put it, sliding along the wall to find
## room; out in the open (lots, drives) it becomes a pylon on two posts.
static func mount_sign(builder: LevelBuilder, cx: int, cy: int, width_px: float) -> Dictionary:
	var need := int(ceil((width_px + 10.0) / 16.0))
	var best := {}
	var best_cost := 1e9
	for dy in [-1, 1, -2, 2, -3, 3]:
		var wy: int = cy + dy
		var face: int = -1 if dy > 0 else 1        # the wall's face looks back toward the sign
		if builder.ch(cx, wy + face) == "#" or builder.ch(cx, wy + face) == "W":
			continue
		for dx in range(-10, 11):
			var x0: int = cx + dx - need / 2
			var ok := true
			var over_glass := 0
			for xx in range(x0, x0 + need):
				# wall (a window's fine to hang over, a door never), open floor in front
				var wc := builder.ch(xx, wy)
				if not (wc == "#" or wc == "W") or builder.ch(xx, wy + face) == "#" or builder.ch(xx, wy + face) == "D":
					ok = false
					break
				if wc == "W":
					over_glass += 1
			# not flush against a doorway either
			if ok and (builder.ch(x0 - 1, wy) in ["D", "L"] or builder.ch(x0 + need, wy) in ["D", "L"]):
				ok = false
			if not ok:
				continue
			var cost := absf(dx) + absf(dy) * 2.5 + (0.0 if face > 0 else 1.5) + over_glass * 0.8
			if cost < best_cost:
				best_cost = cost
				var x_mid := (x0 + need * 0.5) * 16.0
				var y_edge := wy * 16.0 + (16.0 if face > 0 else 0.0)
				best = {"pos": Vector2(x_mid, y_edge), "mount": "wall_s" if face > 0 else "wall_n"}
	if best.is_empty():
		return {"pos": Vector2(cx * 16.0 + 8.0, cy * 16.0 + 8.0), "mount": "pylon"}
	return best


## Neon lettering on a proper sign: a dark metal board with a tube border,
## bolted to a wall (brackets into the brick, a shadow on the floor) or up on
## a pylon with two posts. Buzz-flicker and its own light.
class NeonSign extends Node2D:
	var text := "OPEN"
	var color := Color("ff3d7f")
	var font_size := 14
	var zone := ""
	var mount := ""        ## "wall_s" / "wall_n": on a wall's south / north face; "pylon"; "" floats (breach LOCKED)

	func board_size() -> Vector2:
		var f := UIStyle.font_display()
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		return Vector2(w + 14.0, font_size + 9.0)
	var _t := 0.0
	var _on := 1.0
	var _light: PointLight2D

	func _ready() -> void:
		z_index = 44
		_light = PointLight2D.new()
		_light.texture = SpriteLib.light_texture(256)
		_light.texture_scale = 1.1
		_light.color = color
		_light.energy = 0.9
		_light.shadow_enabled = false
		# the light falls on the floor in front of the board, not inside the wall
		_light.position = {"wall_s": Vector2(0, 10), "wall_n": Vector2(0, -26), "pylon": Vector2(0, -6)}.get(mount, Vector2.ZERO)
		add_child(_light)

	func _process(d: float) -> void:
		_t += d
		var on := 1.0
		if fmod(_t, 5.7) < 0.12 or (fmod(_t, 3.1) < 0.05):
			on = 0.25 + randf() * 0.3
		_on = on
		_light.energy = 0.9 * on
		if Engine.get_process_frames() % 3 == 0:
			queue_redraw()

	func _draw() -> void:
		var f := UIStyle.font_display()
		var bs := board_size()
		var w := bs.x - 14.0
		# the board's centre: half over the wall it hangs on, so it reads as
		# fixed to the brick and barely reaches over the floor
		var c := Vector2.ZERO
		match mount:
			"wall_s": c = Vector2(0, -bs.y * 0.5 - 1.0)
			"wall_n": c = Vector2(0, bs.y * 0.5 + 1.0)
			"pylon": c = Vector2(0, -12)
		var r := Rect2(c - bs * 0.5, bs)
		var metal := Color(0.07, 0.06, 0.09)
		# shadow thrown on the ground
		if mount == "pylon":
			draw_rect(Rect2(r.position + Vector2(7, 14), r.size), Color(0, 0, 0, 0.35))
			for px in [-bs.x * 0.3, bs.x * 0.3]:
				draw_line(Vector2(px + 3, r.end.y - 2), Vector2(px + 5, 8), Color(0, 0, 0, 0.3), 3.0)
				draw_line(Vector2(px, r.end.y - 2), Vector2(px, 6), Color(0.22, 0.2, 0.24), 3.0)
				draw_line(Vector2(px - 1, r.end.y - 2), Vector2(px - 1, 6), Color(0.4, 0.38, 0.42), 1.0)
				draw_circle(Vector2(px, 6), 2.5, Color(0.12, 0.11, 0.13))
		elif mount != "":
			draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.4))
			for bx in [-bs.x * 0.36, bs.x * 0.36]:
				var by := r.end.y + 2.0 if mount == "wall_s" else r.position.y - 2.0
				draw_rect(Rect2(bx - 1.5, minf(by, c.y), 3, absf(by - c.y)), Color(0.28, 0.26, 0.3))
		# the board: dark metal, a lip, rivets
		draw_rect(r, metal)
		draw_rect(r.grow(-1.5), Color(0.1, 0.08, 0.13))
		draw_rect(r, Color(0.3, 0.28, 0.34), false, 1.0)
		for rv in [r.position + Vector2(3, 3), Vector2(r.end.x - 3, r.position.y + 3), Vector2(r.position.x + 3, r.end.y - 3), r.end - Vector2(3, 3)]:
			draw_circle(rv, 0.9, Color(0.45, 0.43, 0.5))
		# the tube border and the glow it throws on the metal
		draw_rect(r.grow(-3.0), Color(color, 0.08 * _on))
		draw_rect(r.grow(-2.5), Color(color, 0.7 * _on), false, 1.0)
		var o := Vector2(c.x - w * 0.5, c.y + font_size * 0.36)
		for g in [3.0, 2.0, 1.0]:
			draw_string_outline(f, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, int(g * 2.0), Color(color, 0.14 * _on))
		draw_string(f, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color.lightened(0.55), _on))
		# a dead letter now and then: the tube's darker core
		if _on < 0.9:
			draw_string(f, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color.darkened(0.6), 0.5))


## Animated caustics and highlights over every pool tile.
class PoolFX extends Node2D:
	var builder: LevelBuilder
	var _cells: Array = []
	var _t := 0.0

	func _ready() -> void:
		z_index = -9
		for y in builder.h:
			for x in builder.w:
				if builder.floor_grid[y][x] == "~":
					_cells.append(Vector2(x * 16, y * 16))

	func _process(d: float) -> void:
		_t += d
		if Engine.get_process_frames() % 3 == 0 and not _cells.is_empty():
			queue_redraw()

	func _draw() -> void:
		for c: Vector2 in _cells:
			for i in 2:
				var ph := _t * 1.3 + c.x * 0.05 + c.y * 0.07 + i * 2.1
				var y := c.y + 4.0 + i * 7.0 + sin(ph) * 1.5
				var pts := PackedVector2Array()
				for k in 5:
					pts.append(Vector2(c.x + k * 4.0, y + sin(ph + k * 1.4) * 1.2))
				draw_polyline(pts, Color(0.55, 0.9, 1.0, 0.28 + 0.12 * sin(ph * 1.7)), 1.0)


## An old pickup, abandoned on set: sun-faded two-tone paint, rust along
## the wheel arches, a cracked windshield, a bed full of junk (tyre, crate,
## tarp). Solid - cover you can hide behind.
class OldPickup extends StaticBody2D:
	const L := 52.0
	const WD := 26.0
	func _ready() -> void:
		collision_layer = Layers.WORLD
		collision_mask = 0
		z_index = 2
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(L - 2.0, WD - 4.0)
		cs.shape = r
		add_child(cs)

	func _draw() -> void:
		var ink := Color("0b0710")
		var paint := Color(0.36, 0.55, 0.52)        # faded teal
		var cream := Color(0.86, 0.82, 0.7)
		var rust := Color(0.5, 0.24, 0.1)
		var hl := L * 0.5
		var hw := WD * 0.5
		# shadow
		draw_rect(Rect2(-hl + 3, -hw + 4, L, WD), Color(0, 0, 0, 0.35))
		var ptex := ArtLib.sprite("pickup_truck")
		if ptex:
			ArtLib.draw_fitted(self, ptex, Rect2(-hl - 2, -hw - 2, L + 4, WD + 4))
			return
		# tyres poking out
		for tx in [-hl + 9, hl - 11]:
			for ty in [-hw - 1.0, hw - 3.0]:
				draw_rect(Rect2(tx, ty, 8, 4), ink)
				draw_rect(Rect2(tx + 1, ty + 1, 6, 2), Color(0.16, 0.16, 0.18))
		# the body outline and paint
		draw_rect(Rect2(-hl, -hw + 1, L, WD - 2), ink)
		draw_rect(Rect2(-hl + 1, -hw + 2, L - 2, WD - 4), paint)
		# hood (front is +x) with a cream stripe, grille and bumper
		draw_rect(Rect2(hl - 14, -hw + 2, 13, WD - 4), paint.lightened(0.08))
		draw_rect(Rect2(hl - 14, -2, 13, 4), cream)
		draw_rect(Rect2(hl - 2, -hw + 3, 3, WD - 6), Color(0.62, 0.62, 0.66))
		draw_line(Vector2(hl - 13, -hw + 3), Vector2(hl - 13, hw - 3), paint.darkened(0.35), 1.0)
		# cab roof and windshield (cracked)
		draw_rect(Rect2(hl - 26, -hw + 3, 12, WD - 6), paint.darkened(0.12))
		draw_rect(Rect2(hl - 16, -hw + 4, 3, WD - 8), Color(0.45, 0.6, 0.72))
		draw_line(Vector2(hl - 15.5, -3), Vector2(hl - 14.2, 1), Color(0.9, 0.95, 1.0, 0.8), 0.6)
		draw_line(Vector2(hl - 14.2, 1), Vector2(hl - 15.2, 4), Color(0.9, 0.95, 1.0, 0.6), 0.6)
		draw_rect(Rect2(hl - 27, -hw + 4, 2, WD - 8), Color(0.35, 0.48, 0.58))     # rear window
		# the bed: dark floor with ribs, and junk
		var bed := Rect2(-hl + 2, -hw + 3, L - 30, WD - 6)
		draw_rect(bed, Color(0.18, 0.17, 0.2))
		for i in 5:
			draw_line(Vector2(bed.position.x + 1, bed.position.y + 2 + i * 4), Vector2(bed.end.x - 1, bed.position.y + 2 + i * 4), Color(0.24, 0.23, 0.27), 1.0)
		draw_circle(Vector2(-hl + 9, -3), 4.2, ink)                               # a spare tyre
		draw_circle(Vector2(-hl + 9, -3), 3.4, Color(0.15, 0.15, 0.17))
		draw_circle(Vector2(-hl + 9, -3), 1.4, Color(0.5, 0.5, 0.55))
		draw_rect(Rect2(-hl + 14, 0, 7, 6), Color("8a5a30"))                      # a crate
		draw_rect(Rect2(-hl + 14, 0, 7, 1.5), Color("a87040"))
		draw_colored_polygon(PackedVector2Array([Vector2(-hl + 3, 3), Vector2(-hl + 12, 2), Vector2(-hl + 13, 8), Vector2(-hl + 4, 9)]), Color(0.3, 0.38, 0.55))   # tarp
		# rust along the arches and a primer-grey replacement door
		for rx in [-hl + 8, hl - 12]:
			draw_rect(Rect2(rx, -hw + 2, 9, 1.5), rust)
			draw_rect(Rect2(rx, hw - 3.5, 9, 1.5), rust)
		draw_rect(Rect2(hl - 26, hw - 4, 11, 1.8), Color(0.55, 0.55, 0.52))
		# a sheen along the hood
		draw_line(Vector2(hl - 13, -hw + 3), Vector2(hl - 3, -hw + 3), Color(1, 1, 1, 0.25), 1.0)


## Litter: crushed cans, newspaper sheets, paper cups, cigarette butts, a
## takeaway box, the odd bottle and tyre. Drawn once, flat on the floor.
class TrashScatter extends Node2D:
	var radius := 40.0
	var count := 26
	var _items: Array = []
	func _ready() -> void:
		z_index = -3
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(int(position.x), int(position.y)))
		for i in count:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * radius
			var kinds := ["can", "can", "paper", "paper", "cup", "butt", "butt", "butt", "box", "bottle", "bag"]
			if i == 0 and radius > 30.0:
				_items.append({"k": "tyre", "p": Vector2.from_angle(a) * r * 0.6, "r": rng.randf() * TAU, "c": rng.randi() % 3})
				continue
			_items.append({"k": kinds[rng.randi() % kinds.size()], "p": Vector2.from_angle(a) * r, "r": rng.randf() * TAU, "c": rng.randi() % 3})
	func _draw() -> void:
		var ink := Color("0b0710")
		for it in _items:
			draw_set_transform(it.p, it.r, Vector2.ONE)
			match str(it.k):
				"can":
					var cc: Color = [Color(0.8, 0.12, 0.14), Color(0.2, 0.4, 0.8), Color(0.85, 0.85, 0.88)][it.c]
					draw_rect(Rect2(-2.5, -1.3, 5, 2.6), ink)
					draw_rect(Rect2(-2.2, -1.0, 4.4, 2.0), cc)
					draw_rect(Rect2(-2.2, -1.0, 1.0, 2.0), Color(0.75, 0.75, 0.78))
					draw_line(Vector2(-0.3, -1.0), Vector2(0.5, 1.0), cc.darkened(0.4), 0.6)      # crushed
				"paper":
					var pc := Color(0.84, 0.82, 0.76) if it.c != 2 else Color(0.9, 0.86, 0.6)
					draw_colored_polygon(PackedVector2Array([Vector2(-4, -3), Vector2(3.5, -3.5), Vector2(4, 2.5), Vector2(-3.5, 3)]), pc)
					for ln in 3:
						draw_line(Vector2(-3, -1.8 + ln * 1.6), Vector2(2.6, -2.0 + ln * 1.6), Color(0.3, 0.3, 0.32, 0.5), 0.5)
					draw_line(Vector2(-4, -3), Vector2(-1.5, -1.0), Color(0.6, 0.58, 0.52), 0.8)   # a fold
				"cup":
					draw_circle(Vector2.ZERO, 2.0, ink)
					draw_circle(Vector2.ZERO, 1.6, Color(0.92, 0.9, 0.86))
					draw_arc(Vector2.ZERO, 1.4, 0, PI, 6, Color(0.85, 0.2, 0.25), 0.6)
					draw_rect(Rect2(-0.3, -3.6, 0.6, 2.2), Color(0.9, 0.3, 0.35))   # the straw
				"butt":
					draw_rect(Rect2(-1.2, -0.35, 2.4, 0.7), Color(0.92, 0.9, 0.84))
					draw_rect(Rect2(-1.2, -0.35, 0.9, 0.7), Color(0.85, 0.55, 0.25))
				"box":
					draw_rect(Rect2(-3, -2.5, 6, 5), ink)
					draw_rect(Rect2(-2.6, -2.1, 5.2, 4.2), Color(0.95, 0.94, 0.9))
					draw_line(Vector2(-2.6, 0), Vector2(2.6, 0), Color(0.75, 0.2, 0.2), 0.8)
				"bottle":
					draw_rect(Rect2(-3, -1, 5, 2), ink)
					draw_rect(Rect2(-2.7, -0.7, 4.2, 1.4), Color(0.25, 0.5, 0.25, 0.9))
					draw_rect(Rect2(1.5, -0.45, 1.6, 0.9), Color(0.25, 0.5, 0.25, 0.9))
					draw_line(Vector2(-2.4, -0.4), Vector2(0.5, -0.4), Color(1, 1, 1, 0.5), 0.4)
				"bag":
					draw_circle(Vector2.ZERO, 3.2, ink)
					draw_circle(Vector2.ZERO, 2.8, Color(0.12, 0.12, 0.14))
					draw_circle(Vector2(-0.8, -0.8), 1.2, Color(0.26, 0.26, 0.3))
					draw_line(Vector2(2.2, -1.6), Vector2(3.8, -3.0), Color(0.12, 0.12, 0.14), 1.0)
				"tyre":
					draw_circle(Vector2(1, 1.5), 6.5, Color(0, 0, 0, 0.3))
					draw_circle(Vector2.ZERO, 6.2, ink)
					draw_circle(Vector2.ZERO, 5.4, Color(0.14, 0.14, 0.16))
					for k in 10:
						var aa := k * TAU / 10.0
						draw_line(Vector2.from_angle(aa) * 4.2, Vector2.from_angle(aa) * 5.3, Color(0.22, 0.22, 0.25), 0.8)
					draw_circle(Vector2.ZERO, 2.4, Color(0.07, 0.06, 0.08))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
