class_name M01NativeBougainvillea
extends RefCounted
const D="res://assets/art/prerendered/m01_sunset_palms/runtime/bougainvillea_v1/"
static func build(l:Level)->void:
	if l.mission==null or l.mission.id!=&"m01_checkout":return
	var p:Variant=JSON.parse_string(FileAccess.get_file_as_string(D+"contract.json"));if not p is Dictionary or not bool(p.get("runtime_approved",false)):return
	var c:Dictionary=p;if str(c.get("source_level_sha256",""))!=FileAccess.get_sha256("res://levels/m01_sunset_palms.json"):return
	var t:=load(D+str(c.get("file",""))) as Texture2D;var d:=l.get_node_or_null("Decor") as Node2D;if t==null or d==null:return
	for x in d.get_children():
		if x is Sprite2D and str(x.get_meta("decor_asset_id",""))=="motel_bougainvillea" and not x.has_node("NativeM01Bougainvillea"):
			var a:=x as Sprite2D;var v:=Sprite2D.new();v.name="NativeM01Bougainvillea";v.texture=t;v.scale=Vector2.ONE*0.48;v.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;v.z_index=1;v.light_mask=a.light_mask;a.add_child(v);a.self_modulate.a=0
