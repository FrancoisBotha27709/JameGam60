
extends Control
class_name UpgradeCard

signal picked(upgrade : Upgrade)

const SHADER : Shader = preload("res://Data/Menu/PixelDissolve.gdshader")

@export_group("Nodes", "node_")
@export var node_title_lbl : Label
@export var node_desc_lbl : RichTextLabel
@export var node_icon : TextureRect
@export var node_button : Button

@export_group("Display")
@export var description_bbcode : bool = true
@export var hide_empty_icon : bool = false

@export_range(0.0, 1.0) var reveal : float = 1.0:
	set(value):
		reveal = clampf(value, 0.0, 1.0)
		_set_param(&"reveal", reveal)

@export var tint_color : Color = Color.WHITE:
	set(value):
		tint_color = value
		_set_param(&"tint_color", tint_color)

@export_range(0.0, 1.0) var tint_mix : float = 0.0:
	set(value):
		tint_mix = clampf(value, 0.0, 1.0)
		_set_param(&"tint_mix", tint_mix)

var upgrade : Upgrade
var _mat : ShaderMaterial
var _locked : bool = true
var _ready_complete : bool = false


func _ready() -> void:
	_setup_shader()
	_setup_nodes()

	node_desc_lbl.bbcode_enabled = description_bbcode
	node_desc_lbl.fit_content = false

	if not node_button.pressed.is_connected(_on_button_pressed):
		node_button.pressed.connect(_on_button_pressed)

	node_button.disabled = true

	_ready_complete = true

	_apply_shader_parameters()

func _setup_shader() -> void:
	if SHADER == null:
		push_error("UpgradeCard: PixelDissolve.gdshader could not be loaded.")
		return

	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat

	# Make descendants inherit the dissolve and tint shader.
	for child in find_children("*", "CanvasItem", true, false):
		var canvas_item := child as CanvasItem

		if canvas_item != null:
			canvas_item.use_parent_material = true

func _setup_nodes() -> void:
	if node_title_lbl == null:
		push_error("UpgradeCard: node_title_lbl is not assigned.")

	if node_desc_lbl == null:
		push_error("UpgradeCard: node_desc_lbl is not assigned.")

	if node_icon == null:
		push_warning("UpgradeCard: node_icon is not assigned.")

	if node_button == null:
		push_error("UpgradeCard: node_button is not assigned.")

func _apply_shader_parameters() -> void:
	_set_param(&"reveal", reveal)
	_set_param(&"tint_color", tint_color)
	_set_param(&"tint_mix", tint_mix)

func _set_param(param : StringName, value : Variant) -> void:
	if _mat == null:
		return

	_mat.set_shader_parameter(param, value)

func set_data(data : Upgrade) -> void:
	if data == null:
		push_warning("UpgradeCard: received a null Upgrade resource.")
		upgrade = null
		return

	upgrade = data

	node_title_lbl.text = data.title

	node_desc_lbl.bbcode_enabled = description_bbcode
	node_desc_lbl.text = data.description
	node_desc_lbl.scroll_to_line(0)

	node_icon.texture = data.icon
	node_icon.visible = not hide_empty_icon or data.icon != null

	# Reset card presentation when a card is reused.
	reveal = 0.0
	tint_color = Color.WHITE
	tint_mix = 0.0

	if _ready_complete:
		_apply_shader_parameters()

func lock() -> void:
	_locked = true

	node_button.disabled = true

func unlock() -> void:
	if upgrade == null:
		return

	_locked = false

	node_button.disabled = false

func _on_button_pressed() -> void:
	if _locked or upgrade == null:
		return

	picked.emit(upgrade)
