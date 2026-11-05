extends RefCounted
class_name PlayerHeat

signal heat_changed(heat : float, heat_max : float)
signal meltdown_countdown_changed(seconds_remaining : float)
signal meltdown_expired

var player : Player
var seconds_since_tap := INF
var meltdown_elapsed := 0.0
var is_melting := false

func _init(owning_player : Player) -> void:
	player = owning_player
	player.thrust_tapped.connect(_on_thrust_tapped)

func is_active() -> bool:
	return player.stat(&"overheat_enabled") and DataCollector.is_running \
			and not player.is_exploded() \
			and DataCollector.game_mode != DataCollector.GameMode.FREE_PLAY

func get_meltdown_progress() -> float:
	return clampf(meltdown_elapsed / player.stat_f(&"meltdown_time"), 0.0, 1.0)

func get_meltdown_remaining() -> float:
	return maxf(player.stat_f(&"meltdown_time") - meltdown_elapsed, 0.0)

# Only rapid taps generate heat; the first tap after a pause is free.
func _on_thrust_tapped(_boosting : bool) -> void:
	if not is_active():
		return

	if seconds_since_tap < player.tap_window:
		player.heat += player.stat_f(&"tap_heat")

	seconds_since_tap = 0.0

# Heats while thrusting, cools otherwise, and runs the meltdown countdown at max heat.
func update(delta : float) -> void:
	if not is_active():
		return

	if is_melting:
		meltdown_elapsed += delta

		var remaining := get_meltdown_remaining()
		meltdown_countdown_changed.emit(remaining)

		if meltdown_elapsed >= player.stat_f(&"meltdown_time"):
			player.set_stat(&"overheat_enabled", false)
			meltdown_expired.emit()

		return

	seconds_since_tap += delta

	var heat_rate = player.stat_f(&"hold_heat_rate") * player.flight.get_thrust_ratio() \
			if player.is_thrusting() else -player.stat_f(&"cool_rate")

	player.heat = clampf(player.heat + heat_rate * delta, 0.0, player.stat_f(&"heat_max"))

	heat_changed.emit(player.heat, player.stat_f(&"heat_max"))

	var was_melting := is_melting
	is_melting = player.heat >= player.stat_f(&"heat_max")
	meltdown_elapsed = 0.0

	if is_melting and not was_melting:
		player.melt_screen.show_screen()

	if is_melting:
		meltdown_countdown_changed.emit(get_meltdown_remaining())


func reset() -> void:
	is_melting = false
	meltdown_elapsed = 0.0
	seconds_since_tap = INF

	meltdown_countdown_changed.emit(player.stat_f(&"meltdown_time"))
	heat_changed.emit(0.0, player.stat_f(&"heat_max"))