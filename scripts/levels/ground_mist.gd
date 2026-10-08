extends Node2D
## Low translucent banks, confined to the authored outdoor rectangle.
var area := Rect2()

func _ready() -> void:
 z_index = 3
 var sheet := Polygon2D.new()
 sheet.polygon = PackedVector2Array([area.position, Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)])
 sheet.uv = PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)])
 var shader_material := ShaderMaterial.new()
 shader_material.shader = load("res://shaders/ground_mist.gdshader")
 sheet.material = shader_material
 add_child(sheet)
 visible = bool(SaveManager.get_setting("weather", true))
 Events.settings_changed.connect(_settings_changed)

func _settings_changed() -> void:
 visible = bool(SaveManager.get_setting("weather", true))
