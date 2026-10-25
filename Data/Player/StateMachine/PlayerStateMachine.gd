extends RefCounted
class_name PlayerStateMachine

signal state_changed(previous_state_name : StringName, next_state_name : StringName)

var states := {}
var current_state_name : StringName = &""

# Adds a state under a name and listens for its transition requests.
func register(state_name : StringName, state : PlayerState) -> void:
	state.state_name = state_name
	state.transition_requested.connect(change_state)
	states[state_name] = state

# Exits the current state and enters the requested one; unknown or repeated names are ignored.
func change_state(next_state_name : StringName) -> void:
	if next_state_name == current_state_name or not states.has(next_state_name):
		return
	var previous_state_name := current_state_name
	if states.has(previous_state_name):
		states[previous_state_name].exit()
	current_state_name = next_state_name
	states[next_state_name].enter(previous_state_name)
	state_changed.emit(previous_state_name, next_state_name)

func physics_update(delta : float) -> void:
	if states.has(current_state_name):
		states[current_state_name].physics_update(delta)