class_name ArcadeRules
extends Node
## Arcade rule modes played over a mission as written (no waves):
##   chamber - ONE IN THE CHAMBER: a pistol with one round; every kill puts
##             one back. Other guns won't come off the floor. Blades and
##             fists are fair.
##   gungame - GUN GAME: every kill swaps what's in her hands for the next
##             weapon up the ladder, bottomless magazines; a kill with the
##             last one (the gold HOTSHOT) wins the run.
##   clock   - CLOCK'S TICKING: ninety seconds on the clock; a kill buys
##             three more, an execution five. Zero and the tape stops.

const LADDER := [&"pistol", &"revolver", &"smg", &"shotgun", &"rifle", &"boomstick", &"machete", &"knife", &"hotshot"]

var level: Level
var rule := ""
var _rung := 0
var clock := 90.0
var _done := false

func setup(p_level: Level, p_rule: String) -> void:
	level = p_level
	rule = p_rule
	Events.enemy_killed.connect(_on_kill)
	Events.execution_performed.connect(func(_e): if rule == "clock": _add_time(2.0))
	(func():
		var p := level.player
		match rule:
			"chamber":
				_arm(&"pistol", 1)
				level.hud.show_banner(tr("ONE IN THE CHAMBER"), 2.0, UIStyle.GOLD)
			"gungame":
				_arm(LADDER[0], -1)
				level.hud.show_banner(tr("GUN GAME"), 2.0, UIStyle.GOLD)
			"clock":
				level.hud.show_banner(tr("CLOCK'S TICKING"), 2.0, UIStyle.GOLD)
		p._emit_weapon()).call_deferred()

## Put `id` in her hands (slot 0, the other slot emptied); `rounds` -1 keeps
## the gun's own magazine.
func _arm(id: StringName, rounds: int) -> void:
	var p := level.player
	var wd := DB.weapon(id)
	if wd == null:
		return
	var w := WeaponInstance.create(wd)
	if rounds >= 0 and wd.is_firearm():
		w.ammo = rounds
		w.reserve = 0
	p.slots[0] = w
	p.slots[1] = null
	p.slot = 0
	p._refresh_weapon()

## Guns off the floor aren't allowed in these modes (except the clock).
func allows_pickup(w: WeaponInstance) -> bool:
	if rule == "chamber":
		return w == null or not w.data.is_firearm()
	if rule == "gungame":
		return false
	return true

func _on_kill(_e: Node, info: Dictionary) -> void:
	if _done or level.player == null or not level.player.alive:
		return
	match rule:
		"chamber":
			var w: WeaponInstance = level.player.current()
			for s in level.player.slots:
				if s and (s as WeaponInstance).data.id == &"pistol":
					w = s
			if w and w.data.id == &"pistol":
				w.ammo = mini(w.ammo + 1, 1) if w.ammo < 1 else w.ammo
				level.player._emit_weapon()
				Effects.popup(tr("+1 ROUND"), level.player.global_position + Vector2(0, -12), UIStyle.GOLD)
		"gungame":
			var used := StringName(info.get("weapon_id", &""))
			if used != LADDER[_rung]:
				return   # it has to be with what the ladder gave you
			_rung += 1
			if _rung >= LADDER.size():
				_done = true
				level.hud.show_banner(tr("TOP OF THE LADDER"), 2.2, UIStyle.GOLD)
				Score.add_bonus("GUN GAME", 10000, level.player.global_position)
				level.get_tree().create_timer(1.5, false).timeout.connect(level._complete)
				return
			_arm(LADDER[_rung], -1)
			Audio.play("upgrade", -6.0)
			Effects.popup(tr(DB.weapon(LADDER[_rung]).display_name).to_upper(), level.player.global_position + Vector2(0, -12), UIStyle.GOLD)
		"clock":
			_add_time(3.0)

func _add_time(s: float) -> void:
	clock += s
	Effects.popup("+%ds" % int(s), level.player.global_position + Vector2(0, -14), UIStyle.CYAN)

func _process(delta: float) -> void:
	if _done or level == null or level.player == null:
		return
	if rule == "gungame":
		var w: WeaponInstance = level.player.current()
		if w and w.data.is_firearm():
			w.ammo = maxi(w.ammo, 1)   # bottomless
	if rule == "clock" and level.player.alive and not Dialogue.active:
		clock -= delta
		if clock <= 10.0 and fmod(clock, 1.0) > fmod(clock + delta, 1.0):
			Audio.play("beat_tick", -4.0)
		if clock <= 0.0:
			_done = true
			clock = 0.0
			level.hud.show_banner(tr("TIME'S UP"), 2.0, UIStyle.HOT)
			level.get_tree().create_timer(1.6, false).timeout.connect(level._complete)
	if Engine.get_process_frames() % 10 == 0:
		_objective()

func _objective() -> void:
	match rule:
		"chamber":
			Events.objective_changed.emit(tr("ONE IN THE CHAMBER  ·  %d LEFT") % level.remaining_enemies().size())
		"gungame":
			Events.objective_changed.emit(tr("GUN GAME  ·  %d / %d  ·  NEXT: %s") % [_rung + 1, LADDER.size(), tr(DB.weapon(LADDER[mini(_rung + 1, LADDER.size() - 1)]).display_name).to_upper()])
		"clock":
			Events.objective_changed.emit(tr("CLOCK'S TICKING  ·  %d:%02d") % [int(clock) / 60, int(clock) % 60])
