extends ColorRect
class_name DitherVignette
const SHADER : Shader = preload("res://Data/Menu/DitherVignette.gdshader")

@export var tint : Color = Color(1.0, 0.2, 0.2):
	set(v):
		tint = v
		_apply(&"tint", v)

@export_range(0.0, 1.0) var intensity : float = 0.0:
	set(v):
		intensity = v
		_apply(&"intensity", v)

@export var pixel_size : float = 4.0:
	set(v):
		pixel_size = v
		_apply(&"pixel_size", v)

var _mat : ShaderMaterial

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	color = Color.WHITE
	_apply(&"tint", tint)
	_apply(&"intensity", intensity)
	_apply(&"pixel_size", pixel_size)

func fill_parent() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func fade_to(value : float, time : float) -> Tween:
	var t := create_tween()
	t.tween_property(self, "intensity", value, time)
	return t

func _apply(param : StringName, value : Variant) -> void:
	if _mat:
		_mat.set_shader_parameter(param, value)