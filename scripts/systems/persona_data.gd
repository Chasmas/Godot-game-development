class_name PersonaData
extends Resource
## PERSONAS: psychological identities worn by characters (paint, masks,
## helmets). Rare, meaningful, and each bends one rule of the game.

@export var id: StringName = &"star"
@export var display_name := "THE STAR"
@export_multiline var description := ""
@export var look := ""                    ## how it appears on the character sprite
@export var rule_change := ""             ## human readable gameplay effect
@export var unlocked_by := ""
## Modifiers read by the player/ability code.
@export var ability_charge_mult := 1.0
@export var combo_window_bonus := 0.0
@export var extra_hit := false
@export var start_revealed := false
