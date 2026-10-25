extends RefCounted
class_name PlayerState

signal transition_requested(next_state_name : StringName)

var player : Player
var state_name : StringName

func _init(owning_player : Player) -> void:
	player = owning_player

# Hooks overridden by concrete states.
func enter(_previous_state_name : StringName) -> void:
	pass

func exit() -> void:
	pass

func update(_delta : float) -> void:
	pass

# Runs the state's update, then asks the player which state the current input and fuel call for.
func physics_update(delta : float) -> void:
	update(delta)
	var next_state_name := player.desired_state_name()
	if next_state_name != state_name:
		transition_requested.emit(next_state_name)