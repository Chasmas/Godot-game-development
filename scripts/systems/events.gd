extends Node
## Global signal bus. Systems talk to each other through here so that no
## gameplay object needs a hard reference to UI, audio or score code.

# --- combat
signal enemy_killed(enemy: Node, info: Dictionary)      # info: method, weapon_id, pos, silent, ...
signal enemy_downed(enemy: Node)
signal enemy_alerted(enemy: Node)
signal player_died(info: Dictionary)
signal player_fired(weapon_id: StringName, hit_something: bool)
signal shot_missed()
signal execution_performed(enemy: Node)
signal weapon_picked_up(weapon_id: StringName)
signal weapon_changed(weapon_id: StringName, ammo: int, reserve: int)
signal ability_changed(charge: float, active: bool)

# --- world / AI
## A noise every enemy may react to. kind: &"gunshot", &"explosion", &"door", &"glass", &"step", &"thrown", &"alarm", &"voice"
signal noise(pos: Vector2, radius: float, kind: StringName, source: Node)
signal alarm_raised(pos: Vector2)
signal lights_changed(zone: StringName, on: bool)
signal upgrade_collected(id: StringName)
signal lock_changed(target: Node)

# --- flow
signal checkpoint_reached(index: int)
signal objective_changed(text: String)
signal level_completed(stats: Dictionary)
signal hint(text: String, duration: float)
signal mask_unlocked(id: StringName)
signal ability_bonus(seconds: float)
signal tutorial(id: String)          ## show a teaching card once (TutorialCards)
signal camera_shake(amount: float)
signal camera_nudge(offset: Vector2)
signal camera_punch(zoom: float, duration: float)
signal hit_stop(duration: float)
signal settings_changed()
signal collectible_found(id: StringName)
signal boss_phase(phase: int)
signal boss_hp(boss: Node, hp: float, max_hp: float)   ## the boss bar
