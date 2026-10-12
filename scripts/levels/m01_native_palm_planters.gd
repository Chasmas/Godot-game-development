class_name M01NativePalmPlanters
extends RefCounted
const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/palm_planter_v1/"
static func build(level: Level) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout":return
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"contract.json"))
	if not parsed is Dictionary or not bool(parsed.get("runtime_approved",false)):return
	var contract:Dictionary=parsed
	if str(contract.get("source_level_sha256",""))!=FileAccess.get_sha256("res://levels/m01_sunset_palms.json"):return
	var texture:=load(DIRECTORY+str(contract.get("file",""))) as Texture2D
	var decor:=level.get_node_or_null("Decor") as Node2D
	if texture==null or decor==null:return
	var rows:Array=[]
	for node in decor.get_children():
		if not node is Sprite2D:continue
		var anchor:=node as Sprite2D
		if str(anchor.get_meta("decor_asset_id",""))!="motel_palm_planter" or anchor.has_node("NativeM01PalmPlanter"):continue
		var visual:=Sprite2D.new();visual.name="NativeM01PalmPlanter";visual.texture=texture;visual.scale=Vector2.ONE*float(contract.get("scale",1.0));visual.position.y=-texture.get_height()*visual.scale.y*.5;visual.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;visual.z_index=1;visual.light_mask=anchor.light_mask;visual.set_meta("native_m01_palm_planter",true);anchor.add_child(visual);anchor.self_modulate.a=0.0;rows.append([anchor.global_position.x,anchor.global_position.y])
	Engine.set_meta("m01_palm_planter_review",{"count":rows.size(),"placements":rows,"collision_added":false})
