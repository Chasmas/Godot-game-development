class_name Tuning
extends Resource
## Central gameplay tuning. Every value that designers are likely to tweak
## (hearing, alert propagation, search, avoidance, AI update rates, dodge,
## door kicks, difficulty presets, dog eye glow) lives here instead of being
## scattered through gameplay scripts.
##
## Defaults are the values below. To tune without touching code, save a
## Tuning resource as res://data/tuning.tres and edit it in the inspector:
## Tuning.get_t() loads it if present.
## Distances are in pixels (one tile = 16 px).

const PATH := "res://data/tuning.tres"
static var _inst: Tuning

static func get_t() -> Tuning:
	if _inst == null:
		if ResourceLoader.exists(PATH):
			_inst = load(PATH) as Tuning
		if _inst == null:
			_inst = Tuning.new()
	return _inst

@export_group("Hearing")
## Global scale on every noise radius (weapon noise_radius, doors, glass...).
@export var noise_scale := 0.85
## Each wall between the sound and the listener multiplies the radius by this.
@export var wall_attenuation := 0.42
## A closed door leaf between them.
@export var door_attenuation := 0.62
## Walls/doors counted per check (more = more raycasts).
@export var max_occluders := 3
## Within this fraction of the effective radius a sound is always heard;
## beyond it the chance falls off to 0 at the edge.
@export var sure_hearing_fraction := 0.5
## How far off (as a fraction of the distance) a listener's guess of the
## source position can be. Clamped to [min, max] px, grows with each wall.
@export var position_error_fraction := 0.22
@export var position_error_min := 10.0
@export var position_error_max := 96.0
## Footsteps / scuffles are only heard by listeners with a clear line.
@export var soft_noise_needs_line := true

@export_group("Alerts")
## Radius of an enemy shouting "over here!" when it enters combat.
@export var shout_radius := 170.0
## An enemy shouts at most once per this many seconds.
@export var shout_cooldown := 4.0
## Allies that hear a shout move toward the shouter (not the player) with
## this much spread, so a group fans out instead of stacking.
@export var shout_spread := 40.0

@export_group("Search")
@export var search_time := 9.0
@export var search_time_jitter := 3.0
@export var search_points := 4
@export var search_radius := 88.0
@export var search_look_time := 1.1
## Investigators pick a personal spot this far around the reported position.
@export var investigate_spread := 30.0
@export var suspicious_time := 1.1

@export_group("Crowd")
## Personal space between enemies (centre to centre).
@export var personal_space := 17.0
@export var separation_strength := 5.0
## Steering acceleration: how fast an enemy changes velocity (px/s^2).
@export var enemy_accel := 950.0
## Max enemies allowed to shoot at the player at the same time, and max
## melee enemies allowed to close in, per difficulty (see presets).
@export var ring_min := 44.0

@export_group("AI update rates")
## Perception tick for enemies that are aware or near the player.
@export var perceive_interval_near := 0.1
## Perception tick for calm enemies far from the player (still staggered).
@export var perceive_interval_far := 0.25
@export var near_distance := 420.0

@export_group("Dodge")
## Dash distance = dash_speed * dash_time * this. 1.0 was the old dodge.
@export var dash_distance_scale := 0.74
## Speed at the start and end of the dash, relative to the average.
## A fast start easing out reads as a shove, not a teleport.
@export var dash_start_mult := 1.3
@export var dash_end_mult := 0.62
## End the dash early if a wall eats this fraction of the intended speed.
@export var dash_blocked_fraction := 0.3

@export_group("Doors")
@export var kick_speed := 19.0            ## rad/s given to the leaf by a kick
@export var kick_noise := 300.0
@export var door_friction := 2.2          ## linear damping (1/s)
@export var door_drag := 0.12             ## quadratic damping: fast swings bleed speed quicker
@export var door_hinge_friction := 1.4    ## constant deceleration (rad/s^2): brings the leaf to rest
@export var door_restitution := 0.32      ## bounce off the hinge stop / walls
@export var door_rattle := 0.9            ## visual shudder after a hard stop
@export var kick_max_angle_deg := 100.0   ## must roughly face the door to kick it

@export_group("Dog")
@export var dog_eye_glow := 1.0
@export var dog_eye_light_energy := 0.8

@export_group("Enemy aim")
## Range (px) at which hit chance has dropped to its floor.
@export var enemy_aim_falloff := 420.0
## Seconds of line of sight before an enemy's aim has fully settled.
@export var enemy_aim_settle := 1.1

@export_group("Difficulty")
## Per difficulty (0 easy, 1 normal, 2 hard). Normal is the design baseline.
@export var reaction_mult := [1.45, 1.0, 0.72]
@export var aim_error_mult := [1.6, 1.0, 0.65]
## Base chance that an enemy shot is on target (before range, movement,
## settle-in and burst penalties). The rest are deliberate near-misses.
@export var enemy_hit_chance := [0.3, 0.45, 0.62]
@export var view_distance_mult := [0.68, 0.78, 0.88]
@export var hearing_mult := [0.85, 1.0, 1.12]
@export var fire_cooldown_mult := [1.3, 1.0, 0.85]
@export var melee_windup_mult := [1.35, 1.0, 0.85]
@export var max_shooters := [2, 3, 5]
@export var max_melee := [1, 2, 3]
## Easy: the player can take this many extra hits (regenerating guard).
@export var player_guard_hits := [1, 0, 0]
## Seconds without taking damage before the guard comes back.
@export var player_guard_regen := [6.0, 0.0, 0.0]
## Reserve ammo multiplier on weapon pickups.
@export var ammo_mult := [1.5, 1.0, 0.75]
## Flank chance scale (hard enemies coordinate more).
@export var flank_mult := [0.6, 1.0, 1.5]
