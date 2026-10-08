extends Node

var failures := 0

func check(condition: bool, message: String) -> void:
	print("PASS " if condition else "FAIL ", message)
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.current_cutscene = "apartment_1988"
	var scene: Control = load("res://scenes/game/cutscene.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	check(scene.sequence == null, "unreviewed camera-move preview cannot replace narrative shots")
	check(scene.shot != null and scene.shot.shot_id == StoryShot.resolve("apartment"), "establishing apartment shot is preserved")
	await capture("apartment")
	Dialogue.start("apartment_1988", false)
	check(scene.shot.shot_id == StoryShot.resolve("machine"), "first dialogue node selects its machine shot")
	Dialogue._goto("c")
	check(scene.shot.shot_id == StoryShot.resolve("machine_close"), "dialogue changes to its authored close shot")
	await capture("machine_close")
	Dialogue._goto("b")
	check(scene.shot.shot_id == StoryShot.resolve("machine"), "dialogue can return to its prior shot")
	print("CUTSCENE SHOT REGRESSION: ", failures, " failures")
	Game.request_quit(1 if failures else 0)

func capture(label: String) -> void:
	if OS.get_environment("CUTSCENE_CAPTURE") != "1":
		return
	# Sample the settled end of the transition, independent of GPU startup stalls.
	var scene: Control = get_child(0)
	scene.shot._process(0.8)
	PostFX._process(0.8)
	for frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/cutscene_review_%s.png" % label)
