extends Node

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/m01_sunset_palms.json"))
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/prerendered/m01_sunset_palms/staging/layout_reconstruction_v1/layout_contract.json"))
	var node := Node2D.new()
	var builder := LevelBuilder.new(node, data)
	builder._compute_floors()
	var expected: Array = contract.get("resolved_floor_grid", [])
	if expected.size() != builder.floor_grid.size():
		push_error("Blender floor grid height differs from Godot")
		node.free()
		get_tree().quit(1)
		return
	var failures := 0
	var checked := 0
	for y in builder.h:
		for x in builder.w:
			checked += 1
			if expected[y][x] != builder.floor_grid[y][x]:
				failures += 1
				push_error("Floor mismatch at %d,%d" % [x,y])
	node.free()
	print("M01_FLOOR_PARITY cells=%d mismatches=%d" % [checked, failures])
	get_tree().quit(1 if failures else 0)
