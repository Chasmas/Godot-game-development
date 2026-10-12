class_name Upgrades
extends RefCounted
## Mission upgrades found in briefcases around the level. They last until the
## mission ends (kept through checkpoints). Levels mark spots with 'U'; each
## spot rolls a random upgrade the player doesn't already have.

const DEFS := {
	&"laser":      {"name": "LASER SIGHT", "desc": "Tighter aim on every gun. You see exactly where it goes.", "icon": "LS", "color": Color("ff2d4f")},
	&"silencer":   {"name": "SILENCER", "desc": "Every gun you hold is suppressed. Quiet kills stay quiet.", "icon": "SI", "color": Color("9aa6b8")},
	&"armor":      {"name": "KEVLAR VEST", "desc": "Soaks one bullet or blow that would have killed you.", "icon": "KV", "color": Color("35e0ff")},
	&"soft_soles": {"name": "SOFT SOLES", "desc": "Silent footsteps at walking speed. Sprinting is quieter.", "icon": "SS", "color": Color("b18cff")},
	&"ext_mag":    {"name": "EXTENDED MAGS", "desc": "+50% rounds in every magazine.", "icon": "XM", "color": Color("ffd23f")},
	&"night_vision": {"name": "NIGHT VISION", "desc": "See in the dark. Blackouts become your home turf.", "icon": "NV", "color": Color("5dff7a")},
	&"brass_knuckles": {"name": "BRASS KNUCKLES", "desc": "Your punches kill.", "icon": "BK", "color": Color("e8b04a")},
	&"adrenaline": {"name": "ADRENALINE", "desc": "Kills refresh your dodge and give a burst of speed.", "icon": "AD", "color": Color("ff8a20")},
	&"quick_hands": {"name": "QUICK HANDS", "desc": "Faster reloads and faster melee recovery.", "icon": "QH", "color": Color("ff5aa0")},
}

static func all_ids() -> Array:
	return DEFS.keys()

static func def(id: StringName) -> Dictionary:
	return DEFS.get(id, {"name": String(id).to_upper(), "desc": "", "icon": "?", "color": Color.WHITE})

## Pick a random upgrade not in `owned` and not in `taken`.
static func roll(owned: Array, taken: Array) -> StringName:
	var pool: Array = []
	for id in DEFS.keys():
		if not owned.has(id) and not taken.has(id):
			pool.append(id)
	if pool.is_empty():
		return &""
	return pool[randi() % pool.size()]


## The briefcase on the floor.
class Pickup extends Node2D:
	var upgrade_id: StringName = &""
	var item_id := ""
	var taken := false
	var _t := 0.0
	signal collected(p: Pickup)

	func _ready() -> void:
		add_to_group("interactable")
		# A case belongs on the floor with the rest of the room dressing; it
		# should not overlay the character like a HUD icon.
		z_index = 0
		_t = randf() * 5.0
		var l := PointLight2D.new()
		l.texture = SpriteLib.light_texture(64)
		l.texture_scale = 0.42
		l.energy = 0.24
		l.color = Upgrades.def(upgrade_id).get("color", Color.WHITE)
		l.range_item_cull_mask = 1
		l.name = "Glow"
		add_child(l)

	func can_interact(_p: Node) -> bool:
		return not taken and upgrade_id != &""

	func get_prompt() -> String:
		return tr("TAKE ") + tr(str(Upgrades.def(upgrade_id).name))

	func interact(by: Node) -> void:
		if taken:
			return
		taken = true
		if by.has_method("add_upgrade"):
			by.add_upgrade(upgrade_id)
		collected.emit(self)
		queue_free()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if upgrade_id == &"":
			return
		var d := Upgrades.def(upgrade_id)
		var col: Color = d.color
		var bob := sin(_t * 3.0) * 1.0
		var ink := Color("0b0710")
		# A small marker makes it discoverable without turning the prop into a
		# floating objective icon.
		draw_circle(Vector2(0, bob), 7.5, Color(0, 0, 0, 0.18))
		draw_set_transform(Vector2(1.5, 3.5), 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# briefcase: ink, body, cel shade band, clasp, handle
		var r := Rect2(-7, -5 + bob, 14, 10)
		draw_rect(r.grow(1.0), ink)
		draw_rect(r, Color(0.35, 0.2, 0.12))
		draw_rect(Rect2(r.position + Vector2(0, 6), Vector2(14, 4)), Color(0.24, 0.13, 0.08))
		draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(12, 1)), Color(0.55, 0.36, 0.22))
		draw_rect(Rect2(-4, -7 + bob, 8, 2), ink)
		draw_rect(Rect2(-3, -7 + bob, 6, 1), Color(0.2, 0.2, 0.22))
		draw_rect(Rect2(-6, -1 + bob, 12, 2), col)
		draw_rect(Rect2(-1, -2 + bob, 2, 4), Color(0.95, 0.85, 0.4))
		var marker := Vector2(0, -10.0 + bob + sin(_t * 2.2) * 0.6)
		draw_colored_polygon(PackedVector2Array([marker + Vector2(0, -2.5), marker + Vector2(2.5, 0), marker + Vector2(0, 2.5), marker + Vector2(-2.5, 0)]), col)
		draw_circle(marker, 0.8, Color.WHITE)


## Laser sight: a thin red beam from the muzzle to whatever it hits.
class LaserBeam extends Node2D:
	var player
	func _ready() -> void:
		z_index = 20
		top_level = true
	func _process(_d: float) -> void:
		queue_redraw()
	## Shared physical ray and paired visual endpoints for alternate renderers.
	func sample_beam() -> Dictionary:
		if player==null or not is_instance_valid(player) or not player.alive:return {}
		var floor_from: Vector2=player.visual.muzzle_global()
		var from: Vector2=player.visual.muzzle_tip_global()
		var dir: Vector2=player.aim_dir if player.aim_dir!=Vector2.ZERO else Vector2.from_angle(player.visual.weapon_sprite.global_rotation)
		var query := PhysicsRayQueryParameters2D.create(floor_from,floor_from+dir*420.0,Layers.WORLD | Layers.DOOR | Layers.PROP | Layers.ENEMY | Layers.GLASS | Layers.DOWNED,[player.get_rid()])
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		var floor_to: Vector2=hit.position if not hit.is_empty() else floor_from+dir*420.0
		return {"floor_from":floor_from,"floor_to":floor_to,"visual_from":from,"visual_to":from+(floor_to-floor_from),"hit":not hit.is_empty()}
	func _draw() -> void:
		if player == null or not is_instance_valid(player) or not player.alive:
			return
		var w = player.current()
		if w == null or not w.data.is_firearm():
			return
		# from the barrel's actual tip, along the barrel's actual line (the
		# sprite's own transform: recoil, sway and all)
		var ws: Sprite2D = player.visual.weapon_sprite
		if not ws.visible or ws.texture == null:
			return
		# The ray lives on the floor while the line is drawn at the barrel tip.
		# Keep them paired through one shared delta so moving and aiming in
		# different directions never separates the sight from the weapon.
		var beam := sample_beam()
		if beam.is_empty():return
		var from: Vector2=beam.visual_from
		var to: Vector2=beam.visual_to
		var flick := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.05)
		# a hairline core with a faint haze, fading along its length
		var mid := from.lerp(to, 0.6)
		draw_line(from, to, Color(1.0, 0.1, 0.2, 0.22 * flick), 1.6)
		draw_line(from, mid, Color(1.0, 0.35, 0.4, 0.95 * flick), 0.7)
		draw_line(mid, to, Color(1.0, 0.35, 0.4, 0.6 * flick), 0.7)
		if beam.hit:
			draw_circle(to, 1.4, Color(1, 0.2, 0.3, 0.35))
			draw_circle(to, 0.6, Color(1, 0.85, 0.85, 0.95))


## Kevlar plates drawn over the torso while the vest is intact.
class Vest extends Node2D:
	func _ready() -> void:
		z_index = 1
	func _draw() -> void:
		var ink := Color("0b0710")
		draw_rect(Rect2(-3.5, -4.5, 6, 9), ink)
		draw_rect(Rect2(-3, -4, 5, 8), Color(0.18, 0.2, 0.24))
		draw_rect(Rect2(-3, -4, 5, 2), Color(0.3, 0.33, 0.38))
		draw_rect(Rect2(-1, -1, 2, 2), Color(0.35, 0.88, 1.0))
