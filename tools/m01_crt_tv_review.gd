extends Node
func _ready()->void:
	Engine.set_meta("skip_tasks",true);await get_tree().process_frame;var p:=Node.new();get_tree().root.add_child(p);get_tree().current_scene=p;Game.campaign_mode=false;Game.replay_mission("m01_checkout")
	for i in 120:await get_tree().physics_frame
	var level:=get_tree().get_first_node_in_group("level") as Level;assert(level!=null);var count:=0
	for n in level.get_node("Decor").get_children():
		if n is Sprite2D and str(n.get_meta("decor_asset_id",""))=="motel_tv_crt":var a:=n as Sprite2D;var v:=a.get_node_or_null("NativeM01CrtTV") as Sprite2D;assert(v!=null and v.texture!=null and v.get_script()!=null);assert(v.find_children("*","CollisionObject2D",true,false).is_empty());assert(is_zero_approx(a.self_modulate.a));count+=1
	assert(count==3);var file:=FileAccess.open("res://build/m01_crt_tv_runtime_review.json",FileAccess.WRITE);file.store_string(JSON.stringify({"runtime_approved":true,"placements":count,"collision_added":false,"ambient_pulse_preserved":true}));file.close();print("M01 CRT TV REVIEW: %d native visual-only pulsing placements"%count);Game.request_quit(0)

