class_name EnemyData
extends Resource
## Behaviour-driven enemy archetype. Enemies differ by *how they act*,
## not by bigger health bars.

enum Combat { SHOOTER, MELEE_RUSHER, SHIELD, ALERTER, BOSS }

@export var id: StringName = &"guard"
@export var display_name := "Guard"
@export var combat: Combat = Combat.SHOOTER
@export var weapon_id: StringName = &"pistol"
@export_multiline var notes := ""

@export_group("Body")
@export var walk_speed := 55.0
@export var run_speed := 120.0
@export var armor := 0                       ## ballistic hits absorbed before lethal hits land
@export var can_be_knocked_down := true
@export var immune_to_punch := false
@export var shield_arc_deg := 0.0            ## frontal arc that blocks bullets (riot)
@export var fleshy := false                  ## armour is meat, not kevlar: hits splatter blood (the dead)

@export_group("Perception")
@export var view_distance := 260.0
@export var view_angle_deg := 110.0
@export var hearing_mult := 1.0
@export var reaction_time := 0.38            ## seconds from spotting to first shot: fairness knob
@export var alert_others_radius := 160.0

@export_group("Combat tuning")
@export var burst := 1
@export var burst_gap := 0.12
@export var aim_error_deg := 5.0
@export var preferred_range := 140.0
@export var flank_chance := 0.3
@export var panic_chance := 0.0              ## chance to panic/flee when allies die nearby
@export var melee_windup := 0.24             ## counter window for melee enemies

@export_group("Look")
@export var palette := "guard"
@export var score_value := 1
