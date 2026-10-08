extends Node
var failures := 0
func _ready() -> void:
	var hud := HUD.new()
	add_child(hud)
	hud.set_process(false)
	for weapon in DB.all_weapons():
		for prefix in ["", "2× "]:
			hud.weapon_label.text = prefix + tr(weapon.display_name).to_upper()
			hud._fit_weapon_name()
			await get_tree().process_frame
			var label := hud.weapon_label
			var width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
			var right := label.get_global_rect().end.x
			if width > label.size.x - 8.0 or right > get_viewport().get_visible_rect().size.x - 15.0:
				failures += 1
				push_error("Weapon name exceeds HUD bounds: " + label.text)
	hud.weapon_label.text = "LOUISVILLE SLUGGER"
	hud._fit_weapon_name()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/hud_weapon_layout.png")
	print("HUD WEAPON LAYOUT: ", failures, " failures across ", DB.all_weapons().size(), " weapons")
	Game.request_quit(1 if failures else 0)
