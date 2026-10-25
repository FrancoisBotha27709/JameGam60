extends RefCounted
class_name PlayerInput

const MOUSE_PREFIX := "mouse_"
const KEYBOARD_PREFIX := "keyboard_"
const ACTION_FORWARD := &"forward"
const ACTION_BOOST := &"boost"
const ACTION_BACKWARD := &"backward"
const ACTION_CUT_THROTTLE := &"cut_throttle"
const ACTION_TURN_LEFT := &"keyboard_left"
const ACTION_TURN_RIGHT := &"keyboard_right"
const INVERT_FLAG := &"invert_controls"
const INVERT_FLAG_MODULUS := 2
const MOUSE_DEAD_ZONE := 10.0
const MOUSE_FULL_TURN_ANGLE := 0.6   # angle error (radians) that demands full turn speed
const SPRITE_FACING_OFFSET := PI / 2.0   # the sprite faces up, not right

var owner_node : Node2D

func _init(owning_node : Node2D) -> void:
	owner_node = owning_node

func is_mouse_mode() -> bool:
	return Settings.values.controls == Settings.CONTROLS.MOUSE

# Maps a logical action to the active control scheme's input action, if it exists.
func _resolve_action(action : StringName) -> StringName:
	return StringName((MOUSE_PREFIX if is_mouse_mode() else KEYBOARD_PREFIX) + action)

func _is_held(action : StringName) -> bool:
	var resolved_action := _resolve_action(action)
	return InputMap.has_action(resolved_action) and Input.is_action_pressed(resolved_action)

func _was_just_pressed(action : StringName) -> bool:
	var resolved_action := _resolve_action(action)
	return InputMap.has_action(resolved_action) and Input.is_action_just_pressed(resolved_action)

func wants_boost() -> bool:
	return _is_held(ACTION_BOOST)

func wants_thrust() -> bool:
	return _is_held(ACTION_FORWARD)

func wants_brake() -> bool:
	return _is_held(ACTION_BACKWARD) or _is_held(ACTION_CUT_THROTTLE)

func thrust_tapped() -> bool:
	return _was_just_pressed(ACTION_FORWARD) or _was_just_pressed(ACTION_BOOST)

# Signed steering demand in -1..1: the mouse angle error or the keyboard axis.
func get_turn_demand() -> float:
	if is_mouse_mode():
		var to_mouse := owner_node.get_global_mouse_position() - owner_node.global_position
		if to_mouse.length() < MOUSE_DEAD_ZONE:
			return 0.0
		var angle_error := angle_difference(owner_node.rotation, to_mouse.angle() + SPRITE_FACING_OFFSET)
		return clampf(angle_error / MOUSE_FULL_TURN_ANGLE, -1.0, 1.0)
	var is_inverted := DataCollector.flag(INVERT_FLAG) % INVERT_FLAG_MODULUS == 1
	return Input.get_axis(ACTION_TURN_LEFT, ACTION_TURN_RIGHT) * (-1.0 if is_inverted else 1.0)