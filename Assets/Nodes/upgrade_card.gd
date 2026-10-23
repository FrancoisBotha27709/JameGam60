extends Control
class_name UpgradeCard

signal picked(upgrade : Upgrade)

const SHADER : Shader = preload("res://Data/Menu/PixelDissolve.gdshader")

@export_group("Nodes", "node_")
@export var node_title_lbl : Label
@export var node_desc_lbl : Label
@export var node_icon : TextureRect
@export var node_button : Button

@export_range(0.0, 1.0) var reveal : float = 1.0:
	set(v):
		reveal = v
		_set_param(&"reveal", v)

@export var tint_color : Color = Color.WHITE:
	set(v):
		tint_color = v
		_set_param(&"tint_color", v)

@export_range(0.0, 1.0) var tint_mix : float = 0.0:
	set(v):
		tint_mix = v
		_set_param(&"tint_mix", v)

var upgrade : Upgrade
var _mat : ShaderMaterial

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	for c in find_children("*", "CanvasItem", true, false):
		c.use_parent_material = true
	_set_param(&"reveal", reveal)
	_set_param(&"tint_color", tint_color)
	_set_param(&"tint_mix", tint_mix)
	node_button.pressed.connect(_on_button_pressed)

func _set_param(param : StringName, value : Variant) -> void:
	if _mat:
		_mat.set_shader_parameter(param, value)

func set_data(data : Upgrade) -> void:
	upgrade = data
	node_title_lbl.text = data.title
	node_desc_lbl.text = data.description
	node_icon.texture = data.icon

func lock() -> void:
	node_button.disabled = true

func unlock() -> void:
	node_button.disabled = false

func _on_button_pressed() -> void:
	picked.emit(upgrade)