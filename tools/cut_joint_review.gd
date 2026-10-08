extends Node
func _ready() -> void:
 var report: Array = []
 for look in ["guard","cass","heavy","demon"]:
  var model := CastModel.create(look)
  add_child(model)
  var mesh := model._model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
  var joints: Dictionary = {}
  for bind in mesh.skin.get_bind_count():
   var bone := mesh.skin.get_bind_bone(bind)
   if bone < 0: bone = model._skeleton.find_bone(mesh.skin.get_bind_name(bind))
   var name: StringName = model._skeleton.get_bone_name(bone)
   if str(name) in ["RightUpLeg","LeftUpLeg","RightLeg","RightFoot","Hips","Head","Neck","RightArm","RightForeArm"]:
    var point := mesh.skin.get_bind_pose(bind).affine_inverse().origin
    joints[str(name)] = [point.x,point.y,point.z]
  report.append({"look":look,"mesh":str(mesh.name),"joints":joints})
  print(look," ",joints)
  model.free()
 var f := FileAccess.open("res://build/cut_joint_review.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(report,"  "))
 Game.request_quit()
