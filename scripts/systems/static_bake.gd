class_name StaticBake
extends Node
## Layers that never change once the level is built (the floor, the floor
## clutter) are drawn once into a texture and shown as a single sprite.
## Drawn command by command they cost the renderer thousands of draw calls
## a frame - rects, circles and paintings interleaved never batch.
## Needs a real renderer: headless runs (tests) keep the original nodes.

const SCALE := 2.0          ## texels per world pixel in the baked texture
const MAX_TEX := 4096

var jobs: Array = []        ## [node, world rect]

static func queue(host: Node, node: Node2D, world: Rect2) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var b: StaticBake = host.get_node_or_null("StaticBake")
	if b == null:
		b = StaticBake.new()
		b.name = "StaticBake"
		host.add_child(b)
	b.jobs.append([node, world])

func _ready() -> void:
	# wait for the level to finish building, then bake everything at once
	await get_tree().process_frame
	var pending: Array = []
	for j in jobs:
		var node: Node2D = j[0]
		var world: Rect2 = j[1]
		if not is_instance_valid(node) or world.size.x < 1.0 or world.size.y < 1.0:
			continue
		var k := minf(SCALE, float(MAX_TEX) / maxf(world.size.x, world.size.y))
		var vp := SubViewport.new()
		vp.size = Vector2i((world.size * k).ceil())
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		vp.canvas_transform = Transform2D(0.0, Vector2(k, k), 0.0, -world.position * k)
		# a stand-in that draws the same thing inside the viewport
		var parent := node.get_parent()
		var idx := node.get_index()
		parent.remove_child(node)
		vp.add_child(node)
		pending.append([node, world, k, vp, parent, idx])
	if pending.is_empty():
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for p in pending:
		var node: Node2D = p[0]
		var world: Rect2 = p[1]
		var k: float = p[2]
		var vp: SubViewport = p[3]
		var parent: Node = p[4]
		var img: Image = vp.get_texture().get_image() if is_instance_valid(vp) else null
		vp.remove_child(node)
		parent.add_child(node)
		parent.move_child(node, mini(int(p[5]), parent.get_child_count() - 1))
		if img and not img.is_empty():
			var s := Sprite2D.new()
			s.name = str(node.name) + "Baked"
			s.texture = ImageTexture.create_from_image(img)
			s.centered = false
			s.position = world.position
			s.scale = Vector2(1.0 / k, 1.0 / k)
			s.z_index = node.z_index
			s.z_as_relative = node.z_as_relative
			s.light_mask = node.light_mask
			s.material = node.material
			s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			parent.add_child(s)
			node.visible = false
		vp.queue_free()
