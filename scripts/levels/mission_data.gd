class_name MissionData
extends Resource
## A playable mission. Levels are authored as data (ASCII + JSON) so new
## missions are content, not code.

@export var id: StringName = &"m01_checkout"
@export var title := "Checkout Time"
@export var location := "Sunset Palms Motel, Barstow"
@export var date_text := "JULY 4, 1988"
@export var year := 1988
@export var chapter := 1
@export var level_file := "res://levels/m01_sunset_palms.json"
@export var music_track := "motel"
@export var boss_track := "boss"
@export var default_character: StringName = &"cass"
@export var par_score := 30000
@export var par_time := 360.0
@export_multiline var briefing := ""
@export var objective_type := "clear"   ## clear / escape / protect / hunt / retrieve / survive
