extends Node2D
func _ready() -> void:
 var visual := CharacterVisual.new()
 add_child(visual)
 visual.setup("cass")
 var failures := 0
 for weapon in [DB.weapon(&"pistol"),DB.weapon(&"chainsaw"),null,DB.weapon(&"pistol"),null]:
  visual.set_weapon(weapon)
  if visual._firearm != (weapon != null and weapon.is_firearm()): failures += 1
  if visual._powered_weapon != (weapon != null and weapon.id == &"chainsaw"): failures += 1
  if visual.powered_cutting: failures += 1
  if visual.weapon_sprite.visible != (weapon != null): failures += 1
  visual.set_powered_cutting(true)
 print("WEAPON VISUAL LIFECYCLE: ",failures," failures")
 Game.request_quit(1 if failures else 0)
