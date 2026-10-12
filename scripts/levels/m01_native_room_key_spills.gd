class_name M01NativeRoomKeySpills
extends RefCounted
const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/room_key_spill_v1/"
static func build(level: Level) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"contract.json"))
	if not parsed is Dictionary or not bool(parsed.get("runtime_approved",false)): return
	var c:Dictionary=parsed
	if str(c.get("source_level_sha256",""))!=FileAccess.get_sha256("res://levels/m01_sunset_palms.json"): return
	var tex:=load(DIRECTORY+str(c.get("file",""))) as Texture2D;var decor:=level.get_node_or_null("Decor") as Node2D
	if tex==null or decor==null:return
	var count:=0
	for n in decor.get_children():
		if not n is Sprite2D:continue
		var a:=n as Sprite2D
		if str(a.get_meta("decor_asset_id",""))!="motel_room_key_spill" or a.has_node("NativeM01RoomKeySpill"):continue
		var v:=Sprite2D.new();v.name="NativeM01RoomKeySpill";v.texture=tex;v.scale=Vector2.ONE*float(c.get("scale",1.0));v.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;v.z_index=1 if a.z_index>=0 else -4;v.light_mask=a.light_mask;v.set_meta("native_m01_room_key_spill",true);a.add_child(v);a.self_modulate.a=0.0;count+=1
	Engine.set_meta("m01_room_key_spill_review",{"count":count,"collision_added":false})
