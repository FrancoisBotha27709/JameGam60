class_name HangarOptionButton
extends HangarButton

signal selection_changed(option_index: int)

const STEP_ACTIONS := {&"ui_left": -1, &"ui_right": 1}
const VALUE_TYPE_DURATION := 0.2
const KICK_DECAY := 5.0
const PIP_SIZE := Vector2(12.0, 4.0)
const PIP_SIZE_SELECTED := Vector2(24.0, 4.0)

@export_group("Option Nodes", "node_")
@export var node_value_zone : Control
@export var node_value_label : Label
@export var node_pips : Control

@export_group("Option Style")
@export var options : Array[String] = [] : set = _set_options
@export var selected_index : int = 0 : set = _set_selected_index
@export var wrap_selection : bool = true
@export var value_zone_width : float = 240.0

var _arrow_kick : float = 0.0
var _value_tween : Tween

#region Lifecycle
func _ready() -> void:
	super._ready()
	pressed.connect(step.bind(1))
	node_plate.option_zone_width = value_zone_width
	_layout_value_zone()
	_refresh_display()

func _process(delta: float) -> void:
	super._process(delta)
	_arrow_kick = move_toward(_arrow_kick, 0.0, delta * KICK_DECAY)
	node_plate.arrow_kick = _arrow_kick

# Left and right step the value only while this button holds focus, so other controls keep their own input.
func _input(event: InputEvent) -> void:
	if disabled or not node_button.has_focus():
		return
	for action in STEP_ACTIONS:
		if event.is_action_pressed(action, true):
			step(STEP_ACTIONS[action])
			get_viewport().set_input_as_handled()
			return
#endregion

#region Selection
func step(direction: int) -> void:
	if options.size() < 2 or disabled:
		return
	var next_index := posmod(selected_index + direction, options.size()) if wrap_selection else clampi(selected_index + direction, 0, options.size() - 1)
	_arrow_kick = signf(direction)
	_on_flash_pressed()
	if next_index == selected_index:
		return
	selected_index = next_index
	_value_tween = MenuStyle.type_on(self, node_value_label, _value_tween, VALUE_TYPE_DURATION)
	selection_changed.emit(selected_index)

func _set_options(value: Array[String]) -> void:
	options = value
	_set_selected_index(selected_index)

func _set_selected_index(value: int) -> void:
	selected_index = clampi(value, 0, maxi(options.size() - 1, 0))
	_refresh_display()
#endregion

#region Visuals
func _refresh_display() -> void:
	if node_value_label == null:
		return
	node_value_label.text = "" if options.is_empty() else options[selected_index]
	node_pips.visible = options.size() > 1 and options.size() <= node_pips.get_child_count()
	MenuStyle.refresh_pips(node_pips, options.size(), selected_index, PIP_SIZE, PIP_SIZE_SELECTED, accent_color)

func _layout_value_zone() -> void:
	var zone_right := -(hover_slide + slant + HangarPlate.OPTION_ZONE_PADDING)
	node_value_zone.offset_right = zone_right
	node_value_zone.offset_left = zone_right - value_zone_width
#endregion
