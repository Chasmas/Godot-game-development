extends Node
func _ready()->void:
	Engine.set_meta("skip_tasks",true);await get_tree().process_frame;var p:=Node.new();get_tree().root.add_child(p);get_tree().current_scene=p;Game.campaign_mode=false;Game.replay_mission("m01_checkout");for i in 120:await get_tree().physics_frame
	var l:=get_tree().get_first_node_in_group("level") as Level;assert(l!=null);var n:=0
	for x in l.get_node("Decor").get_children():if x is Sprite2D and str(x.get_meta("decor_asset_id",""))=="motel_bougainvillea":var a:=x as Sprite2D;var v:=a.get_node_or_null("NativeM01Bougainvillea") as Sprite2D;assert(v!=null and v.texture!=null and v.find_children("*","CollisionObject2D",true,false).is_empty() and is_zero_approx(a.self_modulate.a));n+=1
	assert(n==3);var f:=FileAccess.open("res://build/m01_bougainvillea_runtime_review.json",FileAccess.WRITE);f.store_string(JSON.stringify({"runtime_approved":true,"placements":n,"collision_added":false}));f.close();print("M01 BOUGAINVILLEA REVIEW: %d native visual-only placements"%n);Game.request_quit(0)
