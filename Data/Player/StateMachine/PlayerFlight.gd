extends RefCounted
class_name PlayerFlight

const THROTTLE_MAX := 100.0
const TAP_BURST_STRENGTH := 0.6
const MILLISECONDS_PER_SECOND := 1000.0
const DRIFT_AXIS_FREQUENCY_RATIO := 1.618   # keeps the sway path from repeating quickly

var player : Player

func _init(owning_player : Player) -> void:
	player = owning_player

func get_thrust_ratio() -> float:
	return player.throttle / THROTTLE_MAX

# Carried debris slows the ship, never below the minimum speed factor.
func get_weight_factor() -> float:
	return maxf(1.0 / (1.0 + player.total_weight * player.weight_drag), player.min_speed_factor)

func get_speed_multiplier(boosting : bool) -> float:
	return player.boost_speed_mult if boosting else 1.0

func get_speed_cap(boosting : bool) -> float:
	return player.max_speed * get_weight_factor() * get_speed_multiplier(boosting)

func get_fuel_multiplier(boosting : bool) -> float:
	return (1.0 + player.total_weight * player.weight_fuel_factor) * (player.boost_fuel_mult if boosting else 1.0)

func get_forward() -> Vector2:
	return Vector2.UP.rotated(player.rotation)

# Instant impulse along the heading, capped by the current speed limit.
func apply_tap(boosting : bool) -> void:
	var previous_speed := player.velocity.length()
	var impulse := get_forward() * player.tap_impulse * get_weight_factor() * get_speed_multiplier(boosting)
	player.velocity = (player.velocity + impulse).limit_length(maxf(get_speed_cap(boosting), previous_speed))
	burn_fuel(player.tap_fuel_cost * get_fuel_multiplier(boosting))
	player.fx.burst(TAP_BURST_STRENGTH)
	player.thrust_tapped.emit(boosting)

# Throttle accelerates the ship and grip bends its velocity toward the heading.
func apply_engine(delta : float, boosting : bool) -> void:
	if player.throttle <= 0.0:
		return
	var throttle_ratio := get_thrust_ratio()
	var speed_cap := get_speed_cap(boosting)
	if player.velocity.length() < speed_cap:
		var acceleration := player.thrust_accel * throttle_ratio * get_weight_factor() * get_speed_multiplier(boosting)
		player.velocity = (player.velocity + get_forward() * acceleration * delta).limit_length(speed_cap)
	var speed := player.velocity.length()
	if speed > 0.0 and player.grip > 0.0:
		player.velocity = player.velocity.normalized().slerp(get_forward(), minf(player.grip * delta, 1.0)) * speed
	burn_fuel(player.fuel_depletion_rate * throttle_ratio * get_fuel_multiplier(boosting) * delta)

# Slows the ship toward a standstill at a constant rate.
func apply_drag(drag_rate : float, delta : float) -> void:
	player.velocity = player.velocity.move_toward(Vector2.ZERO, drag_rate * delta)

# Eases the ship back under its speed cap after the cap shrinks.
func apply_overspeed_drag(boosting : bool, delta : float) -> void:
	var speed_cap := get_speed_cap(boosting)
	if player.velocity.length() > speed_cap:
		player.velocity = player.velocity.move_toward(player.velocity.normalized() * speed_cap, player.overspeed_drag * delta)

# A slow Lissajous sway so a coasting ship never feels perfectly still.
func apply_ambient_drift(delta : float) -> void:
	var phase := Time.get_ticks_msec() / MILLISECONDS_PER_SECOND * TAU * player.ambient_drift_frequency
	var sway := Vector2(sin(phase), cos(phase * DRIFT_AXIS_FREQUENCY_RATIO))
	player.velocity += sway * player.ambient_drift_strength * delta

func burn_fuel(amount : float) -> void:
	if not DataCollector.uses_fuel():
		return
	player.current_fuel = maxf(player.current_fuel - amount, 0.0)
	player.fuel_burned.emit(amount)
	SignalBus.update_fuel.emit(player.current_fuel)