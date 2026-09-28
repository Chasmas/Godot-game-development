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

## --- masks (chosen before a job; see Masks)
@export var pro := ""                     ## the upside, one line
@export var con := ""                     ## the price, one line
@export var unlock := ""                  ## start | mission:<id> | rank:<id>:<rank> | rank_any:<rank> | stat:<key>:<n> | secret:<mission>
@export var unlock_hint := ""             ## what the locked card says
@export var move_mult := 1.0
@export var reload_mult := 1.0
@export var dash_cd_mult := 1.0
@export var noise_mult := 1.0             ## how far her gunshots carry
@export var enemy_sight_mult := 1.0
@export var enemy_speed_mult := 1.0
@export var enemy_extra_armor := 0
@export var score_mult := 1.0
@export var lethal_punch := false
@export var no_guns := false
@export var first_hit_kills := false
@export var remix := false                ## every weapon picked up is a random one
@export var dash_volley := false          ## the first shot after a dash fires a fan of three
@export var dogs_ignore := false
@export var melee_wear_mult := 1.0
