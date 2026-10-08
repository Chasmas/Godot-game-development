extends SceneTree
const MATERIALS = preload("C:/Users/gil_n/Documents/GitHub/Godot-game-development-codex/scripts/player/cast_gltf_materials.gd")
func _initialize() -> void:
 var args = OS.get_cmdline_user_args()
 var doc = GLTFDocument.new()
 var state = GLTFState.new()
 assert(doc.append_from_file(args[0],state)==OK)
 var model = doc.generate_scene(state)
 root.add_child(model)
 MATERIALS.prepare(model)
 var checked = 0
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  for surface in mesh.mesh.get_surface_count():
   var mat = mesh.get_active_material(surface)
   assert(mat.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
   for field in ["albedo_texture","normal_texture","roughness_texture","metallic_texture"]:
    var texture = mat.get(field)
    if texture != null:
     assert(texture.get_image().has_mipmaps())
     checked += 1
 if checked == 0:
  push_error("No material textures were checked")
  quit(6)
  return
 print("Prepared runtime material textures: ",checked)
 quit()
