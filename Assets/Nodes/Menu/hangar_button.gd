class_name HangarButton
extends BetterButton

const HIGHLIGHT_SPEED := 7.0
const PRESS_FLASH_DECAY := 4.0
const CAPTION_IDLE_ALPHA := 0.4

@export_group("Hangar Nodes", "node_")
@export var node_plate : HangarPlate
@export var node_content : Control
@export var node_index_label : Label
@export var node_caption_label : Label

@export_group("Hangar Style")
@export var plate_style : HangarPlate.PlateStyle = HangarPlate.PlateStyle.LIST_ITEM
@export var accent_color : Color = MenuStyle.ACCENT
@export var slant : float = 18.0
@export var hover_slide : float = 22.0
@export var index_text : String = "" : set = _set_index_text
@export var caption_text : String = "" : set = _set_caption_text

var _emphasis : float = 0.0
var _press_flash : float = 0.0
var _reveal : float = 1.0

#region Lifecycle
func _ready() -> void:
	super._ready()
	node_button.mouse_entered.connect(focus_button)
	pressed.connect(_on_flash_pressed)
	_configure_plate()
	_set_index_text(index_text)
	_set_caption_text(caption_text)

func _process(delta: float) -> void:
	_emphasis = move_toward(_emphasis, 1.0 if _is_highlighted() else 0.0, delta * HIGHLIGHT_SPEED)
	_press_flash = move_toward(_press_flash, 0.0, delta * PRESS_FLASH_DECAY)

	var eased := smoothstep(0.0, 1.0, _emphasis)
	node_plate.emphasis = eased
	node_plate.press_flash = _press_flash
	node_caption_label.modulate.a = lerpf(CAPTION_IDLE_ALPHA, 1.0, eased)
	_apply_visual_offset(eased)

func focus_button() -> void:
	node_button.grab_focus()

func set_reveal(amount: float) -> void:
	_reveal = amount
	node_plate.modulate.a = amount
	node_content.modulate.a = amount
	_apply_visual_offset(smoothstep(0.0, 1.0, _emphasis))
#endregion

#region Visuals
func _configure_plate() -> void:
	node_plate.plate_style = plate_style
	node_plate.accent_color = accent_color
	node_plate.slant = slant
	node_plate.slide_reserve = hover_slide
	node_index_label.self_modulate = Color(accent_color, 0.7)

func _is_highlighted() -> bool:
	return (_focus or _hover) and not disabled

func _on_flash_pressed() -> void:
	_press_flash = 1.0

func _get_slide_direction() -> float:
	return -1.0 if plate_style == HangarPlate.PlateStyle.CHEVRON_LEFT else 1.0

func _apply_visual_offset(eased: float) -> void:
	var offset := hover_slide * eased * _get_slide_direction() - MenuStyle.SLIDE_DISTANCE * (1.0 - _reveal)
	node_plate.position.x = offset
	node_content.position.x = offset

func _set_index_text(value: String) -> void:
	index_text = value
	if node_index_label != null:
		node_index_label.text = value

func _set_caption_text(value: String) -> void:
	caption_text = value
	if node_caption_label != null:
		node_caption_label.text = value
#endregion
