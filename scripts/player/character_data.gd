class_name CharacterData
extends Resource
## A playable character: identity, feel and signature ability.

@export var id: StringName = &"cass"
@export var display_name := "Cass Moreno"
@export var archetype := "THE STAR"
@export var year_first_seen := 1988
@export_multiline var bio := ""
@export var persona: StringName = &"star"
@export var palette := "cass"
@export var playable_in_slice := false

@export_group("Movement")
@export var move_speed := 150.0
@export var accel := 2100.0
@export var decel := 2600.0
@export var sprint_mult := 1.3
@export var dash_speed := 430.0
@export var dash_time := 0.15
@export var dash_cooldown := 0.42

@export_group("Kit")
@export var start_weapon: StringName = &""
@export var ability: StringName = &"spotlight"
@export var equipment: StringName = &"flare"
@export var equipment_count := 2
@export var melee_damage_mult := 1.0
@export var reload_mult := 1.0
@export var strengths := ""
@export var weaknesses := ""
