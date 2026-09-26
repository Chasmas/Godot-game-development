extends SceneTree
## Dev tool: force-load every script and resource so parse errors surface.
## godot --headless --path . --script tools/compile_all.gd

func _init() -> void:
	var bad := 0
	for path in _walk("res://scripts") + _walk("res://data"):
		if path.ends_with(".gd") or path.ends_with(".tres"):
			var r = load(path)
			if r == null:
				print("FAILED: ", path)
				bad += 1
			elif r is GDScript and not (r as GDScript).can_instantiate() and not (r as GDScript).is_abstract():
				print("CANNOT INSTANTIATE: ", path)
				bad += 1
	print("compile_all done, failures: ", bad)
	quit(1 if bad > 0 else 0)

func _walk(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out.append(dir + "/" + f)
	for sub in d.get_directories():
		out += _walk(dir + "/" + sub)
	return out
