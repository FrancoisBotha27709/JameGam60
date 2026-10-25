extends RefCounted
class_name PlayerHeat

signal heat_changed(heat : float, heat_max : float)
signal meltdown_expired

var player : Player
var seconds_since_tap := INF
var meltdown_elapsed := 0.0
var is_melting := false

func _init(owning_player : Player) -> void:
	player = owning_player
	player.thrust_tapped.connect(_on_thrust_tapped)

func is_active() -> bool:
	return player.overheat_enabled and DataCollector.is_running and not player.is_exploded() \
			and DataCollector.game_mode != DataCollector.GameMode.FREE_PLAY

func get_meltdown_progress() -> float:
	return clampf(meltdown_elapsed / player.meltdown_time, 0.0, 1.0)

# Only rapid taps generate heat; the first tap after a pause is free.
func _on_thrust_tapped(_boosting : bool) -> void:
	if not is_active():
		return
	if seconds_since_tap < player.tap_window:
		player.heat += player.tap_heat
	seconds_since_tap = 0.0

# Heats while thrusting, cools otherwise, and runs the meltdown countdown at max heat.
func update(delta : float) -> void:
	if not is_active():
		return
	if is_melting:
		meltdown_elapsed += delta
		if meltdown_elapsed >= player.meltdown_time:
			player.overheat_enabled = false
			meltdown_expired.emit()
		return
	seconds_since_tap += delta
	var heat_rate = player.hold_heat_rate * player.flight.get_thrust_ratio() if player.is_thrusting() else -player.cool_rate
	player.heat = clampf(player.heat + heat_rate * delta, 0.0, player.heat_max)
	heat_changed.emit(player.heat, player.heat_max)
	is_melting = player.heat >= player.heat_max
	meltdown_elapsed = 0.0

func reset() -> void:
	is_melting = false
	meltdown_elapsed = 0.0
	seconds_since_tap = INF
	heat_changed.emit(0.0, player.heat_max)