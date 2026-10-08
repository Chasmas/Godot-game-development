extends Node
var failures := 0
func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value: failures += 1
func _ready() -> void:
	var prop := PropModel.new()
	var root := Node3D.new()
	var group := Node3D.new()
	group.position = Vector3(0, 2, 0)
	group.scale = Vector3(2, 3, 1)
	root.add_child(group)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	mesh.mesh = box
	mesh.position = Vector3(0, .5, 0)
	group.add_child(mesh)
	var bounds := prop._aabb(root)
	check(bounds.position.is_equal_approx(Vector3(-1, 2, -.5)), "nested translation and scale preserve the authored floor")
	check(bounds.size.is_equal_approx(Vector3(2, 3, 1)), "nested scale contributes to prop dimensions")
	group.rotation.z = PI * .5
	bounds = prop._aabb(root)
	check(bounds.position.is_equal_approx(Vector3(-3, 1, -.5)) and bounds.size.is_equal_approx(Vector3(3, 2, 1)), "nested rotation contributes to the bounds")
	check(prop._aabb(mesh).size.is_equal_approx(Vector3.ONE), "mesh root includes its own geometry in local coordinates")
	root.free()
	prop.free()
	print("PROP BOUNDS REVIEW: ", failures, " failures")
	get_tree().quit(1 if failures else 0)
