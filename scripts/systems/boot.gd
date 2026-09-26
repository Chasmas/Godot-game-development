extends Node
## Entry point: settle autoloads, then the studio splash (which leads to the title).

const SPLASH_SCENE := "res://scenes/ui/splash_screen.tscn"

const INSTALLER_SCENE := "res://scenes/ui/installer.tscn"

func _ready() -> void:
	await get_tree().process_frame
	# the same exe is its own installer / uninstaller (see installer.gd)
	var args := OS.get_cmdline_args()
	if "--hotshot-install" in args or "--hotshot-uninstall" in args:
		var inst: GDScript = load("res://scripts/ui/installer.gd")
		inst.set("uninstall_mode", "--hotshot-uninstall" in args)
		Game.change_scene(INSTALLER_SCENE, false)
		return
	Game.change_scene(SPLASH_SCENE, false)
