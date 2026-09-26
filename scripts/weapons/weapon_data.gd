class_name WeaponData
extends Resource
## Data definition for any weapon (firearm, melee or throwable junk).
## Create new weapons by duplicating a .tres in res://data/weapons/.

enum Kind { FIREARM, MELEE, THROWABLE }
enum Hold { ONE_HAND, TWO_HAND, MELEE_ONE, MELEE_TWO, NONE }

@export var id: StringName = &"pistol"
@export var display_name := "Pistol"
@export var kind: Kind = Kind.FIREARM
@export var hold: Hold = Hold.ONE_HAND
@export_multiline var flavor := ""

@export_group("Firearm")
@export var automatic := false
@export var fire_rate := 4.0              ## shots per second
@export var magazine := 12
@export var spare_mags := 1              ## magazines carried on pickup (reserve = magazine * spare_mags)
@export var reload_time := 1.0
@export var pellets := 1
@export var spread_deg := 3.0
@export var move_spread_deg := 4.0        ## extra spread at full speed
@export var recoil_deg := 2.0             ## added bloom per shot
@export var bullet_speed := 1400.0
@export var hitscan := false
@export var max_range := 900.0
@export var penetration := 0              ## number of bodies/doors a bullet passes through
@export var ricochet := 0
@export var damage := 1.0
@export var noise_radius := 520.0
@export var suppressed := false
@export var camera_kick := 2.5
@export var knockback := 120.0

@export_group("Melee")
@export var melee_range := 22.0
@export var melee_arc_deg := 110.0
@export var melee_cooldown := 0.32
@export var melee_windup := 0.04
@export var lethal := true                ## false = knocks down instead of killing (fists, bat on heavies...)
@export var durability := -1              ## hits before breaking, -1 = unbreakable
@export var breaks_into: StringName = &"" ## e.g. bottle -> broken_bottle
@export var heavy_charge := 0.35          ## hold time for heavy attack

@export_group("Throw")
@export var throw_lethal := false          ## bladed weapons kill when thrown
@export var throw_speed := 520.0

@export_group("Presentation")
@export var sfx_fire := "pistol"
@export var sfx_hit := "hit_flesh"
@export var muzzle_color := Color(1.0, 0.85, 0.4)
@export var tracer_color := Color(1.0, 0.95, 0.6)
@export var sprite_key := "pistol"
@export var score_tag := "gun"

func is_firearm() -> bool:
	return kind == Kind.FIREARM

func is_melee() -> bool:
	return kind == Kind.MELEE

func reserve_on_pickup() -> int:
	return magazine * spare_mags
