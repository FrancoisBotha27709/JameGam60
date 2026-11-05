extends CharacterBody2D
class_name Player

signal thrust_tapped(boosting : bool)
signal boost_started
signal fuel_burned(amount : float)
signal fuel_empty_tapped
signal crashed(impact_speed : float)
signal debris_attached(total_weight : float)
signal debris_delivered(count : int)
signal exploded
signal shake_requested(strength : float)

const STATE_COAST := &"coast"
const STATE_BRAKE := &"brake"
const STATE_THRUST := &"thrust"
const STATE_BOOST := &"boost"
const STATE_EMPTY := &"empty"
const STATE_TUMBLE := &"tumble"
const STATE_EXPLODED := &"exploded"
const THRUST_STATES : Array[StringName] = [STATE_THRUST, STATE_BOOST]
const NO_STEERING_STATES : Array[StringName] = [STATE_TUMBLE, STATE_EXPLODED]
const PERCENT := 100.0
const BOUNCE_THROTTLE_KEEP := 0.5
const BOUNCE_BURST_STRENGTH := 0.8
const NO_MINIMUM := -INF
const MIN_MULTIPLIER := 0.2

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
@export var fx_explosion: FXEmitter
@export var rig: LightRig

@export_group("Audio")
@export var player_audio : PlayerAudio

var throttle := 0.0
var current_fuel := 0.0
var heat := 0.0
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

var design : ShipDesign
var _stats := {}
var _is_bounded := false

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
	_connect_signals()
	_begin_run()
	state_machine.change_state(STATE_COAST)

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

func _connect_signals() -> void:
	SignalBus.update_fuel.connect(_on_fuel_update)
	SignalBus.update_heat.connect(_on_heat_update)
	heat_system.heat_changed.connect(SignalBus.update_heat.emit)
	heat_system.heat_changed.connect(run_stats.record_heat)
	heat_system.meltdown_expired.connect(_on_meltdown_expired)
	heat_system.meltdown_countdown_changed.connect(melt_screen.set_countdown)
	fuel_burned.connect(run_stats.record_fuel)
	debris_attached.connect(run_stats.record_attached)
	debris_delivered.connect(run_stats.record_delivered)
	crashed.connect(run_stats.record_crash)

func _physics_process(delta : float) -> void:
	DataCollector.physics_hooks(self, delta)
	_update_rotation(delta)
	state_machine.physics_update(delta)
	heat_system.update(delta)
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
	var should_play_thrust := is_thrusting() and current_fuel > 0.0

	if should_play_thrust:
		if not player_audio.is_thrusting:
			player_audio.play_thrust()
	else:
		if player_audio.is_thrusting:
			player_audio.stop_thrust()
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

func bounce_off(surface_normal : Vector2, safe_position : Vector2, surface_velocity : Vector2) -> bool:
	global_position = safe_position
	var relative_velocity := velocity - surface_velocity
	var approach_speed := relative_velocity.dot(surface_normal)
	if approach_speed >= 0.0 or is_exploded():
		return false
	var reflected := relative_velocity - surface_normal * approach_speed * (1.0 + bounce_restitution)
	reflected += surface_normal * maxf(bounce_min_speed - reflected.dot(surface_normal), 0.0)
	velocity = surface_velocity + reflected
	throttle *= BOUNCE_THROTTLE_KEEP
	state_machine.change_state(STATE_TUMBLE)
	for effect in fx:
		if is_instance_valid(effect):
			effect.burst(BOUNCE_BURST_STRENGTH)
	crashed.emit(-approach_speed)
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
		DataCollector.register_delivery(debris.data)
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
	global_position = clamped_position
	velocity *= Vector2.ONE - blocked_axes.sign().abs()

func _on_fuel_update(fuel: float) -> void:
	var fuel_max: float = stat(&"fuel_max")
	circle_fuel_prog_bar.set_value(fuel / fuel_max * PERCENT)

	var fuel_ratio := fuel / fuel_max

	for effect in fx:
		if is_instance_valid(effect):
			effect.set_fuel_ratio(fuel_ratio)

func _on_heat_update(new_heat : float, max_heat : float) -> void:
	circle_heat_prog_bar.set_value(new_heat / max_heat * PERCENT)

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
	if fx_explosion:
		fx_explosion.emitting = false
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