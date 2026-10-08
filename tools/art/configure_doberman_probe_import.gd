extends SceneTree

func _initialize() -> void:
	var source := "res://native_walk.glb"
	var scene: Node3D = load(source).instantiate()
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var import_id: String = player.get_meta("import_id", "PATH:" + str(scene.get_path_to(player)))
	var config := ConfigFile.new()
	if config.load(source + ".import") != OK:
		quit(2)
		return
	var resources: Dictionary = config.get_value("params", "_subresources", {})
	var nodes: Dictionary = resources.get("nodes", {})
	var settings: Dictionary = nodes.get(import_id, {})
	settings["optimizer/enabled"] = false
	nodes[import_id] = settings
	resources["nodes"] = nodes
	config.set_value("params", "_subresources", resources)
	# The compression diagnostic did not change contact errors; restore default.
	config.set_value("params", "meshes/force_disable_compression", false)
	var result := config.save(source + ".import")
	print("Probe import optimizer disabled for ", import_id, "; save: ", result)
	scene.free()
	quit(result)
