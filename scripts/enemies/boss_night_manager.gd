class_name BossNightManager
extends Enemy
## LYLE HARCOURT, NIGHT MANAGER of the Sunset Palms.
## Phase 1 "FRONT DESK": moves between cover, revolver volleys. His vest soaks
##   3 hits; every hit he retreats to new cover and calls security on the
##   intercom (reinforcements through the side doors).
## Phase 2 "LIGHTS OUT": he kills the power. Pitch dark, his flashlight is the
##   only light; he hunts you with a shotgun. One clean hit drops him.
## Finale: he's down and talking. Execute him - or walk away.

signal defeated(boss: BossNightManager)

var phase := 1
var cover_points: PackedVector2Array = []
var _cover_i := 0
var _bark := ""
var _bark_t := 0.0
var _relocating := false
var flashlight: PointLight2D
var _defeated := false
var active := false
var _phase_intro_t := 0.0
var _rage_pulse_t := 0.0

const BARKS_HIT := ["You're bleeding on my carpet!", "SECURITY! Front desk!", "Do you know who OWNS this place?"]
const BARKS_P2 := ["Let's see how you do in the dark, hotshot."]

func setup(p_data: EnemyData, p_level: Node, p_facing: Vector2) -> void:
	super.setup(p_data, p_level, p_facing)
	required = true
	flashlight = PointLight2D.new()
	flashlight.texture = SpriteLib.cone_texture(256)
	flashlight.offset = Vector2(128, 0)
	flashlight.texture_scale = 1.2
	flashlight.energy = 1.6
	flashlight.color = Color(1, 0.95, 0.8)
	flashlight.shadow_enabled = true
	flashlight.visible = false
	visual.rig.add_child(flashlight)

func activate() -> void:
	active = true
	_enter_combat()

func _physics_process(delta: float) -> void:
	_bark_t = maxf(0.0, _bark_t - delta)
	_phase_intro_t = maxf(0.0, _phase_intro_t - delta)
	_rage_pulse_t += delta
	if phase == 2 and active and not _defeated and fmod(_rage_pulse_t, 2.4) < delta:
		flashlight.energy = 2.15
		var ft := create_tween()
		ft.tween_property(flashlight, "energy", 1.6, 0.22)
	if not active:
		visual.set_aim(facing.angle())
		return
	super._physics_process(delta)
	if _bark_t > 0.0:
		queue_redraw()

func _perceive() -> void:
	super._perceive()
	if phase == 2 and not _sees_player:
		# he knows this building in the dark: always roughly aware of you
		var p := _player()
		if p and p.alive and Engine.get_physics_frames() % 90 == 0:
			_last_known = p.global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))

func _combat(delta: float) -> Vector2:
	if _relocating and not cover_points.is_empty():
		var target := cover_points[_cover_i % cover_points.size()]
		if global_position.distance_to(target) < 10.0:
			_relocating = false
		else:
			return _go_to(target, data.run_speed)
	return super._combat(delta)

func _gun_combat(p: Player, dist: float, delta: float) -> Vector2:
	var move := super._gun_combat(p, dist, delta)
	if phase == 1:
		return move * 0.5    # holds his ground behind cover
	# phase 2: stalks you
	if dist > 60.0:
		return _go_to(p.global_position, data.walk_speed * 1.4)
	return move

func _on_armor_hit(_info: DamageInfo) -> void:
	_say(BARKS_HIT[(data.armor - armor_left - 1) % BARKS_HIT.size()])
	Audio.play_at("intercom", global_position)
	_cover_i += 1
	_relocating = true
	if level and level.has_method("spawn_reinforcements"):
		level.spawn_reinforcements(2 if armor_left > 0 else 1)
	Events.boss_phase.emit(1)
	if armor_left <= 0:
		_start_phase_two()

func _start_phase_two() -> void:
	phase = 2
	weapon = WeaponInstance.create(DB.weapon(&"shotgun"))
	visual.set_weapon(weapon.data)
	flashlight.visible = true
	data = data.duplicate()
	data.burst = 1
	data.reaction_time = 0.45
	data.aim_error_deg = 6.0
	_say(BARKS_P2[0])
	_phase_intro_t = 1.0
	visual.flash(0.22)
	PostFX.flash(Color(0.2, 0.35, 0.75), 0.18)
	Events.camera_shake.emit(6.0)
	Events.camera_punch.emit(1.16, 0.32)
	Audio.play_at("power_down", global_position, 2.0)
	Events.boss_phase.emit(2)
	if level and level.has_method("boss_lights_out"):
		level.boss_lights_out()

func take_damage(info: DamageInfo) -> String:
	if _defeated:
		return "pass"
	if info.source is Enemy or (not info.from_player and not bool(info.get_meta("player_caused", false))):
		return "pass" if info.type == DamageInfo.Type.BALLISTIC else "blocked"
	if not active:
		activate()
	if phase == 2 and (info.lethal or info.type == DamageInfo.Type.EXPLOSIVE):
		_final_down(info)
		return "killed"
	if phase == 1 and info.type != DamageInfo.Type.BALLISTIC and info.lethal:
		# heavy blows count as armour hits too - no cheesing him with one knife
		if armor_left > 0:
			armor_left -= 1
			visual.hit_react(info.dir, true, 0.18)
			Events.camera_punch.emit(1.07, 0.12)
			_knock = info.dir * 200.0
			Audio.play_at("hit_blunt", global_position)
			_on_armor_hit(info)
			return "absorbed"
	return super.take_damage(info)

func _final_down(info: DamageInfo) -> void:
	_defeated = true
	flashlight.visible = false
	state = State.DOWNED
	_down_t = 9999.0
	collision_layer = 0
	visual.torso.texture = SpriteLib.downed(data.palette)
	visual.legs.visible = false
	visual.weapon_sprite.visible = false
	visual.fall(info.dir)
	PostFX.flash(Color(1.0, 0.16, 0.22), 0.16)
	Events.camera_shake.emit(9.0)
	_knock = info.dir * 150.0
	Effects.blood(global_position, info.dir, true)
	Audio.play_at("body_fall", global_position)
	Events.hit_stop.emit(0.2)
	Events.camera_punch.emit(1.3, 1.0)
	if weapon:
		_drop_weapon(info.dir * 50.0)
	defeated.emit(self)

## Finale resolution from the level (after the dialogue choice).
func resolve(executed: bool, by: Node) -> void:
	if executed:
		var info := DamageInfo.make(DamageInfo.Type.MELEE, by, global_position, Vector2.RIGHT, &"fists", &"execution")
		info.lethal = true
		info.from_player = true
		Score.add_bonus("CHECKED OUT", 5000, global_position)
		state = State.COMBAT
		_die(info)
	else:
		Score.add_bonus("MERCY", 2500, global_position)
		_say("...you'll regret that, kid.")
		state = State.EXECUTED   # removed from fight, lies there alive
		remove_from_group("enemies")
		remove_from_group("damageable")

func is_downed() -> bool:
	return false   # can't be executed with the normal prompt - the finale handles it

func _say(t: String) -> void:
	_bark = t
	_bark_t = 3.0
	queue_redraw()

func _draw() -> void:
	super._draw()
	if _bark_t > 0.0 and _bark != "":
		var f := UIStyle.font_bold()
		var w := f.get_string_size(_bark, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_rect(Rect2(-w * 0.5 - 3, -28, w + 6, 12), Color(0.35, 0.02, 0.08, 0.9))
		draw_string(f, Vector2(-w * 0.5, -19), _bark, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.PAPER)
