extends CharacterBody2D
class_name Player

signal thrust_tapped(boosting : bool)
signal thrust_held(boosting : bool)
signal thrust_stopped
signal boost_started
signal fuel_burned(amount : float)
signal fuel_empty_tapped
signal fuel_low_started
signal fuel_low_stopped
signal fuel_tick
signal fuel_refilled
signal crashed(impact_speed : float)
signal debris_attached(total_weight : float)
signal debris_delivered(count : int)
signal exploded
signal state_changed(previous_state_name : StringName, next_state_name : StringName)
signal shake_requested(strength : float)
signal meltdown_started
signal meltdown_stopped
signal heat_hiss_started
signal heat_hiss_stopped
signal cargo_shed(count : int)
signal health_changed(current_health : float, max_health : float)
signal damaged(amount : float)

const STATE_COAST := &"coast"
const STATE_BRAKE := &"brake"
const STATE_THRUST := &"thrust"
const STATE_BOOST := &"boost"
const STATE_EMPTY := &"empty"
const STATE_TUMBLE := &"tumble"
const STATE_EXPLODED := &"exploded"
const STATE_SHED := &"shed"
const THRUST_STATES : Array[StringName] = [STATE_THRUST, STATE_BOOST]
const NO_STEERING_STATES : Array[StringName] = [STATE_TUMBLE, STATE_EXPLODED, STATE_SHED]
const PERCENT := 100.0
const BOUNCE_THROTTLE_KEEP := 0.5
const BOUNCE_BURST_STRENGTH := 0.8
const NO_MINIMUM := -INF
const MIN_MULTIPLIER := 0.2
const MIN_DIRECTION_LENGTH := 0.001

const UPGRADE_PROPERTIES := {
	&"max_speed": {stat = Upgrade.Stat.MAX_SPEED, minimum = NO_MINIMUM},
	&"rotation_speed": {stat = Upgrade.Stat.ROTATION_SPEED, minimum = NO_MINIMUM},
	&"throttle_accel": {stat = Upgrade.Stat.THROTTLE_ACCEL, minimum = NO_MINIMUM},
	&"thrust_accel": {stat = Upgrade.Stat.THRUST_ACCEL, minimum = NO_MINIMUM},
	&"tap_impulse": {stat = Upgrade.Stat.TAP_IMPULSE, minimum = NO_MINIMUM},
	&"grip": {stat = Upgrade.Stat.GRIP, minimum = NO_MINIMUM},
	&"coast_drag": {stat = Upgrade.Stat.COAST_DRAG, minimum = 0.0},
	&"weight_drag": {stat = Upgrade.Stat.WEIGHT_DRAG, minimum = 0.0},
	&"boost_speed_mult": {stat = Upgrade.Stat.BOOST_SPEED, minimum = 1.0},
	&"boost_fuel_mult": {stat = Upgrade.Stat.BOOST_FUEL, minimum = 1.0},
	&"fuel_max": {stat = Upgrade.Stat.FUEL_MAX, minimum = NO_MINIMUM},
	&"weight_fuel_factor": {stat = Upgrade.Stat.WEIGHT_FUEL, minimum = 0.0},
	&"heat_max": {stat = Upgrade.Stat.HEAT_MAX, minimum = NO_MINIMUM},
	&"cool_rate": {stat = Upgrade.Stat.COOL_RATE, minimum = NO_MINIMUM},
	&"meltdown_time": {stat = Upgrade.Stat.MELTDOWN_TIME, minimum = NO_MINIMUM},
	&"collision_shape_scale": {stat = Upgrade.Stat.MAGNET_SIZE, minimum = NO_MINIMUM},
}
const UPGRADE_MULTIPLIERS := {
	Upgrade.Stat.FUEL_BURN: {minimum = MIN_MULTIPLIER, properties = [&"fuel_depletion_rate", &"tap_fuel_cost"]},
	Upgrade.Stat.HEAT_GAIN: {minimum = MIN_MULTIPLIER, properties = [&"tap_heat", &"hold_heat_rate"]},
}

@export_group("Momentum")
@export var ambient_drift_strength : float = 6.0
@export var ambient_drift_frequency : float = 0.35
@export var tumble_spin_speed : float = 6.0

@export_group("Cargo Shedding")
@export_range(0.0, 1.0, 0.01) var shed_min_impact_ratio : float = 0.25
@export var shed_strength : float = 1.0
@export var shed_weight_factor : float = 0.05
@export var shed_force : float = 450.0
@export var shed_lockout : float = 1.2
@export var shed_grace_runs : int = 2

@export_group("Health")
@export var max_health : float = 100.0
@export var health_regen_rate : float = 6.0
@export var health_regen_delay : float = 0.0
@export var crash_damage_per_speed : float = 0.05

@export_group("Ramming")
@export var ram_weight_factor : float = 0.05
@export var ram_boost_multiplier : float = 1.5

@export_group("Shield")
@export var shield_idle : FXPlayer
@export var shield_idle_preset : String = "shield_idle"
@export var shield_hit_preset : String = "shield_hit"
@export var shield_radius : float = 40.0
@export var shield_pixel_scale : float = 2.0
@export var shield_power : float = 1.0
@export var shield_low_health_power_multiplier : float = 2.0
@export var shield_hit_cooldown : float = 0.15
@export var shield_reactivate_delay : float = 0.2
@export var shield_sputter_duration : float = 0.9
@export var shield_sputter_interval : float = 0.07
@export_range(0.0, 1.0, 0.01) var shield_sputter_min_alpha : float = 0.45
@export var shield_wall_min_speed : float = 120.0
@export var shield_idle_timeout : float = 10.0
@export var shield_power_down_duration : float = 1.2
@export_range(0.01, 1.0, 0.01) var shield_power_down_scale : float = 0.05
@export_range(1.0, 3.0, 0.05) var shield_off_damage_multiplier : float = 1.35
@export var shield_warble_speed : float = 7.0
@export var shield_warble_amount : float = 0.025
@export var shield_glitch_interval : float = 0.12
@export var shield_glitch_position : float = 2.0
@export var shield_glitch_rotation : float = 0.08

@export_group("Fuel Audio")
@export_range(0.0, 1.0, 0.01) var low_fuel_threshold : float = 0.3
@export var fuel_tick_interval : float = 5.0

@export_group("Overheat Feedback")
@export var tap_window : float = 0.4
@export var meltdown_flash_start : float = 3.0
@export var meltdown_flash_end : float = 14.0

@export_group("Explosion")
@export var blast_radius : float = 600.0
@export var blast_force : float = 900.0

@export_group("Empty Feedback")
@export var node_sprite : Node2D
@export var empty_fx_duration : float = 0.5
@export var empty_shake_strength : float = 4.0

@export_group("Juice")
@export var tap_punch_strength : float = 0.25
@export var boost_punch_strength : float = 0.45
@export var crash_punch_strength : float = 0.6
@export var pickup_punch_strength : float = 0.15
@export var delivery_punch_strength : float = 0.3
@export var punch_duration : float = 0.4
@export var squash_ratio : float = 0.5
@export var thrust_stretch : float = 0.08
@export var bank_per_angular_velocity : float = 0.06
@export var idle_bob_amplitude : float = 2.0
@export var idle_bob_frequency : float = 0.4
@export var tap_shake_strength : float = 0.1
@export var boost_shake_strength : float = 0.25
@export var crash_shake_strength : float = 1.0
@export var explosion_shake_strength : float = 1.5
@export var hit_stop_duration : float = 0.06
@export var hit_stop_time_scale : float = 0.05
@export var hit_stop_min_impact : float = 0.3
@export var cough_darken : float = 0.35
@export var cough_duration : float = 0.06
@export var heat_tint_max : float = 0.7
@export var heat_color : Color = Color(1.0, 0.45, 0.25)
@export var meltdown_color : Color = Color(1.0, 0.1, 0.1)
@export var empty_color : Color = Color(1.0, 0.2, 0.2)

@export_group("Ship Details", "ship_")
@export var ship_color : Color = Color(0.75, 0.8, 0.9)
@export_subgroup("Collision")
@export var bounce_restitution : float = 0.6
@export var bounce_min_speed : float = 140.0
@export var bounce_lock_time : float = 0.25

@export_group("UI Objects")
@export var ui_root : UIContainer
@export var melt_screen : MeltdownScreen
@export_group("Effects", "fx_")
@export var collision_shape : CollisionShape2D
@export var circle_fuel_prog_bar : CircleBar
@export var circle_heat_prog_bar : CircleBar
var fx: Array[ShipFX] = []
@export var fx_explosion: FXPlayer
@export var fx_heat : Array[FXPlayer] = []
@export var fx_heat_thresholds : Array[float] = [0.3, 0.6, 0.8]
@export var fx_heat_hysteresis : float = 0.03
@export var rig: LightRig
@export var talking_screen : TalkingScreen
@export_group("Audio")
@export var player_audio : PlayerAudio

var throttle := 0.0
var current_fuel := 0.0
var heat := 0.0
var health := 0.0
var total_weight := 0.0
var attached_debris : Array[DebrisObject] = []
var angular_velocity := 0.0
var thrust_hold_time := 0.0
var world_rect : Rect2
var player_input : PlayerInput
var flight : PlayerFlight
var heat_system : PlayerHeat
var run_stats : PlayerRunStats
var feedback : PlayerFeedback
var state_machine : PlayerStateMachine
var last_impact_speed := 0.0
var design : ShipDesign
var is_talking : bool = false

var _stats := {}
var _is_bounded := false
var _is_fuel_low := false
var _fuel_burned_since_tick := 0.0
var _previous_fuel := -1.0
var _seconds_since_damage := 0.0

var _shield_cooldown := 0.0
var _shield_reactivate_timer := 0.0
var _shield_sputter_timer := 0.0
var _shield_sputter_clock := 0.0
var _shield_health_alpha := 1.0
var _shield_idle_timer := 0.0
var _shield_power_down_timer := 0.0
var _shield_animation_time := 0.0
var _shield_glitch_clock := 0.0
var _shield_is_off := false
var _shield_waking_from_off := false
var _shield_glitch_offset := Vector2.ZERO
var _shield_glitch_rotation := 0.0
var _shield_base_scale := Vector2.ONE
var _shield_base_position := Vector2.ZERO
var _shield_base_rotation := 0.0
var _shield_wake_start_scale := Vector2.ONE
var _shield_wake_start_alpha := 1.0

func _ready() -> void:
	if node_sprite == null:
		node_sprite = get_node_or_null("Icon") as Node2D
	DataCollector.player = self
	_load_design()
	player_input = PlayerInput.new(self)
	flight = PlayerFlight.new(self)
	heat_system = PlayerHeat.new(self)
	run_stats = PlayerRunStats.new()
	feedback = PlayerFeedback.new(self)
	_build_state_machine()
	_build_shield()
	_connect_signals()
	_begin_run()
	state_machine.change_state(STATE_COAST)
	for effect in fx_heat:
		if is_instance_valid(effect):
			effect.play_mode = FXPlayer.PlayMode.LOOP
			effect.stop()

func stat(stat_name : StringName) -> Variant:
	return _stats[stat_name]

func stat_f(stat_name : StringName) -> float:
	return _stats[stat_name]

func set_stat(stat_name : StringName, value : Variant) -> void:
	_stats[stat_name] = value

func muffle_music() -> void:
	if player_audio:
		player_audio.muffle_music()

func restore_music() -> void:
	if player_audio:
		player_audio.restore_music()

func begin_end_music(reason : int) -> void:
	if player_audio:
		player_audio.begin_end(reason)

func set_end_music_progress(t : float) -> void:
	if player_audio:
		player_audio.set_end_progress(t)

func end_music_death() -> void:
	if player_audio:
		player_audio.end_death()

func end_music_aftermath() -> void:
	if player_audio:
		player_audio.end_aftermath()

func _load_design() -> void:
	design = DataCollector.get_selected_ship()

	if design == null:
		design = ShipDesign.new()

	var container := node_sprite as ShipContainer
	if container:
		container.setup(false, design)
		fx = container.get_fx_nodes()

	DataCollector.set_ship_abilities(design.abilities)

func _build_state_machine() -> void:
	state_machine = PlayerStateMachine.new()
	state_machine.register(STATE_COAST, PlayerStates.Coast.new(self))
	state_machine.register(STATE_BRAKE, PlayerStates.Coast.new(self, true))
	state_machine.register(STATE_THRUST, PlayerStates.Thrust.new(self))
	state_machine.register(STATE_BOOST, PlayerStates.Thrust.new(self, true))
	state_machine.register(STATE_EMPTY, PlayerStates.Empty.new(self))
	state_machine.register(STATE_TUMBLE, PlayerStates.Tumble.new(self))
	state_machine.register(STATE_EXPLODED, PlayerStates.Exploded.new(self))
	state_machine.register(STATE_SHED, PlayerShedState.new(self))

func _connect_signals() -> void:
	SignalBus.update_fuel.connect(_on_fuel_update)
	SignalBus.update_heat.connect(_on_heat_update)
	heat_system.heat_changed.connect(SignalBus.update_heat.emit)
	heat_system.heat_changed.connect(run_stats.record_heat)
	heat_system.meltdown_expired.connect(_on_meltdown_expired)
	heat_system.meltdown_countdown_changed.connect(melt_screen.set_countdown)
	heat_system.meltdown_started.connect(meltdown_started.emit)
	heat_system.meltdown_stopped.connect(meltdown_stopped.emit)
	heat_system.hiss_started.connect(heat_hiss_started.emit)
	heat_system.hiss_stopped.connect(heat_hiss_stopped.emit)
	fuel_burned.connect(run_stats.record_fuel)
	fuel_burned.connect(_on_fuel_burned)
	exploded.connect(_set_fuel_low.bind(false))
	exploded.connect(_stop_heat_fx)
	exploded.connect(_stop_shield)
	state_machine.state_changed.connect(_on_state_changed)
	debris_attached.connect(run_stats.record_attached)
	debris_delivered.connect(run_stats.record_delivered)
	crashed.connect(run_stats.record_crash)

func _physics_process(delta : float) -> void:
	DataCollector.physics_hooks(self, delta)
	_update_rotation(delta)
	state_machine.physics_update(delta)
	heat_system.update(delta)
	_regenerate_health(delta)
	_shield_cooldown = maxf(_shield_cooldown - delta, 0.0)
	_update_shield(delta)
	move_and_slide()
	var speed := velocity.length()
	if DataCollector.is_running:
		run_stats.record_motion(speed, delta, state_machine.current_state_name == STATE_BOOST)
	_clamp_to_world()
	circle_fuel_prog_bar.rotation = -global_rotation
	circle_heat_prog_bar.rotation = -global_rotation
	feedback.update(delta)
	ui_root.set_speed(speed)
	var thrust_ratio := flight.get_thrust_ratio() if current_fuel > 0.0 else 0.0
	var is_boosting := state_machine.current_state_name == STATE_BOOST
	flight.update_thrust_signals(is_boosting)
	for effect in fx:
		if is_instance_valid(effect):
			effect.set_thrust(thrust_ratio, is_boosting)

	rig.set_engine(thrust_ratio, is_boosting)

func desired_state_name() -> StringName:
	if current_fuel <= 0.0:
		return STATE_EMPTY
	if player_input.wants_brake():
		return STATE_BRAKE
	if player_input.wants_boost():
		return STATE_BOOST
	return STATE_THRUST if player_input.wants_thrust() else STATE_COAST

func is_thrusting() -> bool:
	return state_machine.current_state_name in THRUST_STATES

func is_exploded() -> bool:
	return state_machine.current_state_name == STATE_EXPLODED

func _update_rotation(delta : float) -> void:
	var is_steering := state_machine.current_state_name not in NO_STEERING_STATES
	var turn_demand := player_input.get_turn_demand() if is_steering else 0.0
	var turn_rate : float = stat(&"angular_drag") if is_zero_approx(turn_demand) else stat(&"angular_acceleration")
	angular_velocity = move_toward(angular_velocity, turn_demand * stat(&"rotation_speed"), turn_rate * delta)
	rotation += angular_velocity * delta

func _rebuild_stats() -> void:
	_stats.clear()
	for stat_name in ShipDesign.STAT_PROPERTIES:
		_stats[stat_name] = design.get(stat_name)
	for stat_name in UPGRADE_PROPERTIES:
		var binding : Dictionary = UPGRADE_PROPERTIES[stat_name]
		_stats[stat_name] = maxf(DataCollector.get_stat(binding.stat, _stats[stat_name]), binding.minimum)
	for upgrade_stat in UPGRADE_MULTIPLIERS:
		var multiplier := maxf(DataCollector.get_stat(upgrade_stat, 1.0), UPGRADE_MULTIPLIERS[upgrade_stat].minimum)
		for stat_name in UPGRADE_MULTIPLIERS[upgrade_stat].properties:
			_stats[stat_name] *= multiplier
	collision_shape.scale = Vector2.ONE * _stats[&"collision_shape_scale"]

func _begin_run() -> void:
	_rebuild_stats()
	DataCollector.run_start_hooks(self)
	throttle = 0.0
	current_fuel = stat(&"fuel_max")
	ui_root.setup_fuel(stat(&"fuel_max"), current_fuel)
	circle_fuel_prog_bar.setup(stat(&"fuel_max"))
	circle_heat_prog_bar.setup(heat)
	SignalBus.update_fuel.emit(current_fuel)
	_seconds_since_damage = 0.0
	_set_health(max_health)
	_restart_shield()


#region Health and shield

func get_ram_multiplier() -> float:
	var boost_multiplier := ram_boost_multiplier if state_machine.current_state_name == STATE_BOOST else 1.0
	return (1.0 + total_weight * ram_weight_factor) * boost_multiplier

func take_damage(amount : float, direction : Vector2) -> void:
	if is_exploded() or health <= 0.0:
		return

	var applied_damage := amount

	if _shield_is_off and amount > 0.0:
		applied_damage *= shield_off_damage_multiplier

	play_shield_hit(direction)

	if applied_damage <= 0.0:
		return

	_seconds_since_damage = 0.0
	_set_health(health - applied_damage)
	damaged.emit(applied_damage)

	if health <= 0.0:
		_stop_shield()
		_on_meltdown_expired()

func play_shield_hit(_direction : Vector2) -> void:
	if is_exploded():
		return
	_shield_waking_from_off = _shield_is_off or _shield_power_down_timer > 0.0
	_shield_wake_start_scale = shield_idle.scale if is_instance_valid(shield_idle) else _shield_base_scale
	_shield_wake_start_alpha = shield_idle.modulate.a if is_instance_valid(shield_idle) else 1.0
	# Any hit wakes the shield and resets its inactivity timer.
	_shield_is_off = false
	_shield_idle_timer = 0.0
	_shield_power_down_timer = 0.0
	_shield_reactivate_timer = shield_reactivate_delay
	_shield_sputter_timer = 0.0
	_shield_sputter_clock = 0.0

	if is_instance_valid(shield_idle):
		shield_idle.stop()

	# Only limit the impact effect, not the shield's wake-up behaviour.
	if _shield_cooldown > 0.0:
		return

	_shield_cooldown = shield_hit_cooldown

	var effect := FXPlayer.new()
	effect.preset = shield_hit_preset
	effect.pixel_scale = shield_pixel_scale
	effect.power = shield_power
	effect.play_mode = FXPlayer.PlayMode.ONCE
	effect.free_on_finish = true
	effect.position = Vector2.ZERO
	effect.rotation = 0.0

	add_child(effect)

func _set_health(value : float) -> void:
	health = clampf(value, 0.0, max_health)
	health_changed.emit(health, max_health)

	var health_ratio := health / maxf(max_health, MIN_DIRECTION_LENGTH)
	var damage_ratio := 1.0 - health_ratio

	# The shield becomes more intense as health gets lower.
	if is_instance_valid(shield_idle):
		shield_idle.power = shield_power * lerpf(
			1.0,
			shield_low_health_power_multiplier,
			damage_ratio
		)

func _regenerate_health(delta : float) -> void:
	if is_exploded() or health >= max_health:
		return
	_seconds_since_damage += delta
	if _seconds_since_damage >= health_regen_delay:
		_set_health(health + health_regen_rate * delta)

func _build_shield() -> void:
	if shield_idle == null:
		shield_idle = FXPlayer.new()
		shield_idle.preset = shield_idle_preset
		shield_idle.pixel_scale = shield_pixel_scale
		shield_idle.power = shield_power
		shield_idle.autoplay = false
		add_child(shield_idle)

	shield_idle.play_mode = FXPlayer.PlayMode.LOOP

	_shield_base_scale = shield_idle.scale
	_shield_base_position = shield_idle.position
	_shield_base_rotation = shield_idle.rotation

func _restart_shield() -> void:
	_shield_reactivate_timer = 0.0
	_shield_sputter_timer = 0.0
	_shield_sputter_clock = 0.0
	_shield_idle_timer = 0.0
	_shield_power_down_timer = 0.0
	_shield_animation_time = 0.0
	_shield_glitch_clock = 0.0
	_shield_is_off = false
	_shield_waking_from_off = false
	_shield_glitch_offset = Vector2.ZERO
	_shield_glitch_rotation = 0.0

	if not is_instance_valid(shield_idle):
		return

	shield_idle.scale = _shield_base_scale
	shield_idle.position = _shield_base_position
	shield_idle.rotation = _shield_base_rotation
	shield_idle.modulate.a = 1.0
	shield_idle.power = shield_power

	if not shield_idle.is_playing():
		shield_idle.play()

func _update_shield(delta : float) -> void:
	if not is_instance_valid(shield_idle) or is_exploded():
		return

	_shield_animation_time += delta

	# Gradually wake the shield if it was previously powered down.
	if _shield_reactivate_timer > 0.0:
		_shield_reactivate_timer = maxf(_shield_reactivate_timer - delta, 0.0)

		if _shield_waking_from_off:
			var wake_progress := 1.0 - (_shield_reactivate_timer / maxf(shield_reactivate_delay, MIN_DIRECTION_LENGTH))

			shield_idle.scale = _shield_wake_start_scale.lerp(_shield_base_scale, wake_progress)
			shield_idle.modulate.a = lerpf(_shield_wake_start_alpha, 1.0, wake_progress)

		if _shield_reactivate_timer <= 0.0:
			_shield_waking_from_off = false
			shield_idle.scale = _shield_base_scale
			shield_idle.modulate.a = 1.0
			shield_idle.play()
			_shield_sputter_timer = shield_sputter_duration
			_shield_sputter_clock = 0.0

		return

	# A powered-down shield stays tiny and invisible until another hit.
	if _shield_is_off:
		return

	# Count how long the player has gone without taking damage.
	_shield_idle_timer += delta

	if _shield_idle_timer >= shield_idle_timeout:
		_shield_power_down_timer += delta

		var power_down_progress := clampf(
			_shield_power_down_timer / maxf(shield_power_down_duration, MIN_DIRECTION_LENGTH),
			0.0,
			1.0
		)

		var remaining_scale := lerpf(1.0, shield_power_down_scale, power_down_progress)
		shield_idle.scale = _shield_base_scale * remaining_scale
		shield_idle.modulate.a = 1.0 - power_down_progress

		if power_down_progress >= 1.0:
			_shield_is_off = true
			shield_idle.stop()
			shield_idle.scale = _shield_base_scale * shield_power_down_scale
			shield_idle.modulate.a = 0.0

		return

	var health_ratio := health / maxf(max_health, MIN_DIRECTION_LENGTH)
	var damage_ratio := 1.0 - health_ratio

	# Recent impacts cause temporary sputtering.
	var hit_sputter_strength := 0.0

	if _shield_sputter_timer > 0.0:
		_shield_sputter_timer = maxf(_shield_sputter_timer - delta, 0.0)
		hit_sputter_strength = _shield_sputter_timer / maxf(shield_sputter_duration, MIN_DIRECTION_LENGTH)

	# Low health causes ongoing instability.
	var sputter_strength := maxf(damage_ratio, hit_sputter_strength)

	# Smooth warbling becomes more noticeable at low health.
	var warble_strength := damage_ratio
	var warble := sin(_shield_animation_time * shield_warble_speed) * shield_warble_amount * warble_strength

	var scale_multiplier := 1.0 + warble
	shield_idle.scale = _shield_base_scale * scale_multiplier

	# Random positional and rotational glitches become stronger at low health.
	_shield_glitch_clock -= delta

	if _shield_glitch_clock <= 0.0:
		_shield_glitch_clock = lerpf(
			shield_glitch_interval * 2.0,
			shield_glitch_interval,
			damage_ratio
		)

		_shield_glitch_offset = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * shield_glitch_position * damage_ratio

		_shield_glitch_rotation = randf_range(
			-shield_glitch_rotation,
			shield_glitch_rotation
		) * damage_ratio

	shield_idle.position = _shield_base_position + _shield_glitch_offset
	shield_idle.rotation = _shield_base_rotation + _shield_glitch_rotation

	# Flickering increases as health gets lower.
	if sputter_strength > 0.0:
		_shield_sputter_clock -= delta

		if _shield_sputter_clock <= 0.0:
			var current_sputter_interval := lerpf(
				shield_sputter_interval * 2.0,
				shield_sputter_interval,
				sputter_strength
			)

			_shield_sputter_clock = current_sputter_interval

			var flicker := randf_range(0.0, sputter_strength)
			shield_idle.modulate.a = lerpf(1.0, shield_sputter_min_alpha, flicker)
	else:
		shield_idle.modulate.a = 1.0

func _stop_shield() -> void:
	_shield_reactivate_timer = 0.0
	_shield_sputter_timer = 0.0
	_shield_sputter_clock = 0.0

	if is_instance_valid(shield_idle):
		shield_idle.stop()

#endregion

func bounce_off(surface_normal : Vector2, safe_position : Vector2, surface_velocity : Vector2, damage_scale : float = 1.0) -> bool:
	global_position = safe_position
	var relative_velocity := velocity - surface_velocity
	var approach_speed := relative_velocity.dot(surface_normal)
	if approach_speed >= 0.0 or is_exploded():
		return false
	var reflected := relative_velocity - surface_normal * approach_speed * (1.0 + bounce_restitution)
	reflected += surface_normal * maxf(bounce_min_speed - reflected.dot(surface_normal), 0.0)
	velocity = surface_velocity + reflected
	throttle *= BOUNCE_THROTTLE_KEEP
	last_impact_speed = -approach_speed
	var sheds := not attached_debris.is_empty() and DataCollector.run_number > shed_grace_runs
	state_machine.change_state(STATE_SHED if sheds else STATE_TUMBLE)
	for effect in fx:
		if is_instance_valid(effect):
			effect.burst(BOUNCE_BURST_STRENGTH)
	crashed.emit(-approach_speed)
	take_damage(-approach_speed * crash_damage_per_speed * damage_scale, -surface_normal)
	return true

func attach(debris : DebrisObject) -> void:
	if is_exploded() or debris in attached_debris:
		return
	var anchor_candidates : Array[Node2D] = [self]
	anchor_candidates.append_array(attached_debris)
	attached_debris.append(debris)
	total_weight += debris.get_weight() * DataCollector.get_stat(Upgrade.Stat.DEBRIS_WEIGHT, 1.0)
	debris.attach_to(anchor_candidates.pick_random())
	debris_attached.emit(total_weight)

func deliver_to(depot : Node2D) -> void:
	for debris in attached_debris:
		DataCollector.register_delivery(debris.data, debris.get_value())
		debris.detach_to(depot)
	debris_delivered.emit(attached_debris.size())
	_clear_load()

func release_debris() -> void:
	for debris in attached_debris:
		debris.detach()
	_clear_load()

func _clear_load() -> void:
	attached_debris.clear()
	total_weight = 0.0

func set_world_bounds(rect : Rect2) -> void:
	world_rect = rect
	_is_bounded = true

func _clamp_to_world() -> void:
	if not _is_bounded:
		return
	var clamped_position := global_position.clamp(world_rect.position, world_rect.end)
	var blocked_axes := clamped_position - global_position
	if blocked_axes == Vector2.ZERO:
		return
	var inward := blocked_axes.normalized()
	var wall_speed := -velocity.dot(inward)
	global_position = clamped_position
	velocity *= Vector2.ONE - blocked_axes.sign().abs()
	if wall_speed >= shield_wall_min_speed:
		play_shield_hit(-inward)

func _on_fuel_update(fuel: float) -> void:
	var fuel_max: float = stat(&"fuel_max")
	circle_fuel_prog_bar.set_value(fuel / fuel_max * PERCENT)

	var fuel_ratio := fuel / fuel_max

	for effect in fx:
		if is_instance_valid(effect):
			effect.set_fuel_ratio(fuel_ratio)

	_set_fuel_low(fuel > 0.0 and fuel_ratio <= low_fuel_threshold and not is_exploded())

	if fuel >= fuel_max and _previous_fuel >= 0.0 and _previous_fuel < fuel_max:
		_fuel_burned_since_tick = 0.0
		fuel_refilled.emit()
	_previous_fuel = fuel

func _on_fuel_burned(amount : float) -> void:
	_fuel_burned_since_tick += amount
	if _fuel_burned_since_tick >= fuel_tick_interval:
		_fuel_burned_since_tick = fmod(_fuel_burned_since_tick, fuel_tick_interval)
		fuel_tick.emit()

func _set_fuel_low(is_low : bool) -> void:
	if is_low == _is_fuel_low:
		return
	_is_fuel_low = is_low
	if is_low:
		fuel_low_started.emit()
	else:
		fuel_low_stopped.emit()

func _on_heat_update(new_heat : float, max_heat : float) -> void:
	var heat_ratio := new_heat / max_heat
	circle_heat_prog_bar.set_value(heat_ratio * PERCENT)
	_update_heat_fx(heat_ratio)

func _update_heat_fx(heat_ratio : float) -> void:
	for i in fx_heat.size():
		var effect := fx_heat[i]
		if not is_instance_valid(effect):
			continue
		var threshold : float = fx_heat_thresholds[i] if i < fx_heat_thresholds.size() else 1.0
		if heat_ratio >= threshold and not effect.is_playing():
			effect.play()
		elif heat_ratio < threshold - fx_heat_hysteresis and effect.is_playing():
			effect.stop()

func _stop_heat_fx() -> void:
	for effect in fx_heat:
		if is_instance_valid(effect):
			effect.stop()

func get_summary() -> Dictionary:
	return run_stats.get_summary(stat(&"heat_max"))

func reset_for_run() -> void:
	_begin_run()
	_clear_load()
	velocity = Vector2.ZERO
	heat = 0.0
	angular_velocity = 0.0
	thrust_hold_time = 0.0
	heat_system.reset()
	melt_screen.hide()
	melt_screen.stop_alarm()
	run_stats.reset()
	feedback.reset()
	state_machine.change_state(STATE_COAST)

func _update_ship_fx(thrust_ratio: float, boosting: bool) -> void:
	for effect in fx:
		if is_instance_valid(effect):
			effect.set_thrust(thrust_ratio, boosting)

func _set_ship_fx_fuel(ratio: float) -> void:
	for effect in fx:
		if is_instance_valid(effect):
			effect.set_fuel_ratio(ratio)

func _burst_ship_fx(strength: float) -> void:
	for effect in fx:
		if is_instance_valid(effect):
			effect.burst(strength)

func _on_meltdown_expired() -> void:
	melt_screen.hide()
	melt_screen.stop_alarm()

	state_machine.change_state(STATE_EXPLODED)

func _on_state_changed(previous_state_name : StringName, next_state_name : StringName) -> void:
	if previous_state_name == &"":
		return
	state_changed.emit(previous_state_name, next_state_name)