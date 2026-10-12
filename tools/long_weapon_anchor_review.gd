extends Node
func _ready() -> void:
	var rows: Array=[]
	for id in ["shotgun","rifle","smg"]:
		var directory: String="res://assets/art/weapons3d/staging/"+id+"_fit_v1/"
		var document:=GLTFDocument.new()
		var state:=GLTFState.new()
		assert(document.append_from_file(directory+id+".glb",state)==OK)
		var weapon:=document.generate_scene(state)
		add_child(weapon)
		var contract: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory+"contract.json"))
		for name in ["GripAnchor","SupportGrip","ShoulderAnchor","Muzzle"]:
			var marker:=weapon.find_child(name,true,false) as Node3D
			assert(marker!=null)
			var point: Array=contract.anchors_blender[name]
			# glTF converts Blender Z-up to Godot Y-up, -Y to +Z.
			assert(marker.global_position.distance_to(Vector3(point[0],point[2],-point[1]))<.000001)
		var muzzle:=weapon.find_child("Muzzle",true,false) as Node3D
		var shoulder:=weapon.find_child("ShoulderAnchor",true,false) as Node3D
		var support:=weapon.find_child("SupportGrip",true,false) as Node3D
		var grip:=weapon.find_child("GripAnchor",true,false) as Node3D
		assert(shoulder.position.z<grip.position.z and grip.position.z<support.position.z and support.position.z<muzzle.position.z)
		rows.append({"weapon":id,"shoulder_to_muzzle_m":muzzle.global_position.distance_to(shoulder.global_position),"support_to_trigger_m":support.global_position.distance_to(grip.global_position),"runtime_approved":false})
	var report:=FileAccess.open("res://build/long_weapon_anchor_review.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(rows,"\t"))
	print("LONG WEAPON ANCHORS PASSED ",JSON.stringify(rows))
	Game.request_quit(0)
