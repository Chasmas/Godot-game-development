class_name M01NativePoolCoolers
extends RefCounted
const D="res://assets/art/prerendered/m01_sunset_palms/runtime/pool_cooler_v1/"
static func build(l:Level)->void:
	if l.mission==null or l.mission.id!=&"m01_checkout":return
	var p:Variant=JSON.parse_string(FileAccess.get_file_as_string(D+"contract.json"));if not p is Dictionary or not bool(p.get("runtime_approved",false)):return
	var c:Dictionary=p;if str(c.get("source_level_sha256",""))!=FileAccess.get_sha256("res://levels/m01_sunset_palms.json"):return
	var t:=load(D+str(c.get("file",""))) as Texture2D;var d:=l.get_node_or_null("Decor") as Node2D;if t==null or d==null:return
	var n:=0
	for x in d.get_children():
		if x is Sprite2D and str(x.get_meta("decor_asset_id",""))=="hq_pool_cooler" and not x.has_node("NativeM01PoolCooler"):
			var a:=x as Sprite2D;var v:=Sprite2D.new();v.name="NativeM01PoolCooler";v.texture=t;v.scale=Vector2.ONE*float(c.get("scale",1));v.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;v.z_index=1;v.light_mask=a.light_mask;a.add_child(v);a.self_modulate.a=0;n+=1
	Engine.set_meta("m01_pool_cooler_review",{"count":n,"collision_added":false})
