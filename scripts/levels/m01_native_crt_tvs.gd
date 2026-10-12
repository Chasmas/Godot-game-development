class_name M01NativeCrtTVs
extends RefCounted
const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/crt_tv_v1/"
static func build(level: Level) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout":return
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"contract.json"));if not parsed is Dictionary or not bool(parsed.get("runtime_approved",false)):return
	var c:Dictionary=parsed;if str(c.get("source_level_sha256",""))!=FileAccess.get_sha256("res://levels/m01_sunset_palms.json"):return
	var tex:=load(DIRECTORY+str(c.get("file",""))) as Texture2D;var decor:=level.get_node_or_null("Decor") as Node2D;if tex==null or decor==null:return
	var count:=0
	for n in decor.get_children():
		if not n is Sprite2D:continue
		var a:=n as Sprite2D;if str(a.get_meta("decor_asset_id",""))!="motel_tv_crt" or a.has_node("NativeM01CrtTV"):continue
		var v := Sprite2D.new()
		v.name = "NativeM01CrtTV"
		v.texture = tex
		# Fit the visible silhouette in world pixels, independent of legacy art scale.
		var visible_width := float(c.get("visible_width_px", tex.get_width()))
		var world_width := float(c.get("world_width_px", 12.8))
		v.scale = Vector2.ONE * world_width / visible_width / maxf(absf(a.global_scale.x), 0.001)
		v.offset.y = tex.get_height() * 0.5 - float(c.get("visible_bottom_px", tex.get_height()))
		v.flip_h = a.flip_h
		v.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		v.z_index = 1
		v.light_mask = a.light_mask
		v.set_script(load("res://scripts/levels/ambient_screen.gd"))
		v.pulse_speed = 2.1
		v.pulse_amount = 0.06
		v.set_meta("native_m01_crt_tv", true)
		a.add_child(v)
		a.self_modulate.a = 0.0
		count += 1
	Engine.set_meta("m01_crt_tv_review",{"count":count,"collision_added":false,"ambient_pulse_preserved":true})
