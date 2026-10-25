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
signal shake_requested(strength : float)   # camera listeners decide how to shake

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

# Property name -> upgrade stat that overrides it (clamped to a minimum).
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
# Upgrade stat -> multiplier applied to several properties at once.
const UPGRADE_MULTIPLIERS := {
	Upgrade.Stat.FUEL_BURN: {minimum = MIN_MULTIPLIER, properties = [&"fuel_depletion_rate", &"tap_fuel_cost"]},
	Upgrade.Stat.HEAT_GAIN: {minimum = MIN_MULTIPLIER, properties = [&"tap_heat", &"hold_heat_rate"]},
}

@export_group("Stats")
@export var max_speed : float = 400.0
@export var collision_shape_scale : float = 1.0

@export_subgroup("Rotation")
@export var rotation_speed : float = 2.5
@export var angular_acceleration : float = 9.0   # how fast the turn rate builds
@export var angular_drag : float = 4.0   # how fast the spin dies when you stop steering

@export_subgroup("Thrust")
@export var thrust_accel : float = 300.0
@export var throttle_accel : float = 60.0
@export var throttle_decel : float = 300.0
@export var throttle : float = 0.0
@export var hold_delay : float = 0.15
@export var tap_impulse : float = 90.0
@export var grip : float = 2.0

@export_subgroup("Momentum")
@export var coast_drag : float = 25.0
@export var brake_drag : float = 250.0
@export var overspeed_drag : float = 400.0
@export var ambient_drift_strength : float = 6.0   # constant gentle sway while coasting
@export var ambient_drift_frequency : float = 0.35
@export var tumble_spin_speed : float = 6.0

@export_subgroup("Boost")
@export var boost_speed_mult : float = 1.6
@export var boost_fuel_mult : float = 2.0

@export_subgroup("Fuel")
@export var fuel_max : float = 100.0
@export var current_fuel : float = 100.0
@export var fuel_depletion_rate : float = 6.0
@export var tap_fuel_cost : float = 0.5
@export var weight_fuel_factor : float = 0.1

@export_subgroup("Overheat")
@export var overheat_enabled : bool = true
@export var heat_max : float = 100.0
@export var heat : float = 0.0
@export var tap_window : float = 0.4
@export var tap_heat : float = 14.0
@export var hold_heat_rate : float = 6.0
@export var cool_rate : float = 12.0
@export var meltdown_time : float = 5.0
@export var meltdown_flash_start : float = 3.0
@export var meltdown_flash_end : float = 14.0

@export_subgroup("Explosion")
@export var blast_radius : float = 600.0
@export var blast_force : float = 900.0

@export_subgroup("Weight")
@export var weight_drag : float = 0.05
@export var min_speed_factor : float = 0.25

@export_group("Empty Feedback")
## Defaults to the child named "Icon"
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
@export var hit_stop_min_impact : float = 0.3   # fraction of max speed
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
@export_group("Effects", "fx_")
@export var fx : ShipFX
@export var fx_explosion : FXEmitter
@export var rig : LightRig
@export var collision_shape : CollisionShape2D
@export var circle_fuel_prog_bar : CircleBar
@export var circle_heat_prog_bar : CircleBar

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

var _base_properties := {}
var _is_bounded := false

func _ready() -> void:
	if node_sprite == null:
		node_sprite = get_node_or_null("Icon") as Node2D
	DataCollector.player = self
	_snapshot_base_properties()
	player_input = PlayerInput.new(self)
	flight = PlayerFlight.new(self)
	heat_system = PlayerHeat.new(self)
	run_stats = PlayerRunStats.new()
	feedback = PlayerFeedback.new(self)
	_build_state_machine()
	_connect_signals()
	_begin_run()
	state_machine.change_state(STATE_COAST)

# Registers every movement state; thrust/boost and coast/brake share one script each.
func _build_state_machine() -> void:
	state_machine = PlayerStateMachine.new()
	state_machine.register(STATE_COAST, PlayerStates.Coast.new(self))
	state_machine.register(STATE_BRAKE, PlayerStates.Coast.new(self, true))
	state_machine.register(STATE_THRUST, PlayerStates.Thrust.new(self))
	state_machine.register(STATE_BOOST, PlayerStates.Thrust.new(self, true))
	state_machine.register(STATE_EMPTY, PlayerStates.Empty.new(self))
	state_machine.register(STATE_TUMBLE, PlayerStates.Tumble.new(self))
	state_machine.register(STATE_EXPLODED, PlayerStates.Exploded.new(self))

# Wires components together through signals so none of them call each other directly.
func _connect_signals() -> void:
	SignalBus.update_fuel.connect(_on_fuel_update)
	SignalBus.update_heat.connect(_on_heat_update)
	heat_system.heat_changed.connect(SignalBus.update_heat.emit)
	heat_system.heat_changed.connect(run_stats.record_heat)
	heat_system.meltdown_expired.connect(state_machine.change_state.bind(STATE_EXPLODED))
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
	fx.set_thrust(thrust_ratio, is_boosting)
	rig.set_engine(thrust_ratio, is_boosting)

# Chooses the movement state that the current input and fuel call for (brake beats thrust).
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

# Turns with angular inertia: the spin builds while steering and bleeds off slowly after.
func _update_rotation(delta : float) -> void:
	var is_steering := state_machine.current_state_name not in NO_STEERING_STATES
	var turn_demand := player_input.get_turn_demand() if is_steering else 0.0
	var turn_rate := angular_drag if is_zero_approx(turn_demand) else angular_acceleration
	angular_velocity = move_toward(angular_velocity, turn_demand * rotation_speed, turn_rate * delta)
	rotation += angular_velocity * delta

# Remembers un-upgraded values so every run starts from the same baseline.
func _snapshot_base_properties() -> void:
	var property_names : Array = UPGRADE_PROPERTIES.keys()
	for multiplier in UPGRADE_MULTIPLIERS.values():
		property_names.append_array(multiplier.properties)
	property_names.append(&"overheat_enabled")
	for property_name in property_names:
		_base_properties[property_name] = get(property_name)

# Applies the data-driven upgrade tables to the ship's properties.
func _apply_upgrades() -> void:
	for property_name in UPGRADE_PROPERTIES:
		var binding : Dictionary = UPGRADE_PROPERTIES[property_name]
		set(property_name, maxf(DataCollector.get_stat(binding.stat, get(property_name)), binding.minimum))
	for stat in UPGRADE_MULTIPLIERS:
		var multiplier := maxf(DataCollector.get_stat(stat, 1.0), UPGRADE_MULTIPLIERS[stat].minimum)
		for property_name in UPGRADE_MULTIPLIERS[stat].properties:
			set(property_name, get(property_name) * multiplier)
	collision_shape.scale = Vector2.ONE * collision_shape_scale

# Upgrades, hooks, and fresh fuel: everything a run start needs.
func _begin_run() -> void:
	_apply_upgrades()
	DataCollector.run_start_hooks(self)
	throttle = 0.0
	current_fuel = fuel_max
	ui_root.setup_fuel(fuel_max, current_fuel)
	circle_fuel_prog_bar.setup(fuel_max)
	circle_heat_prog_bar.setup(heat)
	SignalBus.update_fuel.emit(current_fuel)

# Reflects off a surface, then tumbles; returns false if the ship was already moving away.
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
	fx.burst(BOUNCE_BURST_STRENGTH)
	crashed.emit(-approach_speed)
	return true

# Ties new debris to the ship or to a random piece already attached.
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

# Keeps the ship inside the world and cancels velocity on any blocked axis.
func _clamp_to_world() -> void:
	if not _is_bounded:
		return
	var clamped_position := global_position.clamp(world_rect.position, world_rect.end)
	var blocked_axes := clamped_position - global_position
	if blocked_axes == Vector2.ZERO:
		return
	global_position = clamped_position
	velocity *= Vector2.ONE - blocked_axes.sign().abs()

func _on_fuel_update(fuel : float) -> void:
	circle_fuel_prog_bar.set_value(fuel / fuel_max * PERCENT)
	fx.set_fuel_ratio(fuel / fuel_max)

func _on_heat_update(new_heat : float, max_heat : float) -> void:
	circle_heat_prog_bar.set_value(new_heat / max_heat * PERCENT)

func get_summary() -> Dictionary:
	return run_stats.get_summary(heat_max)

# Restores baseline stats, re-applies upgrades, and returns every component to its starting state.
func reset_for_run() -> void:
	for property_name in _base_properties:
		set(property_name, _base_properties[property_name])
	_begin_run()
	_clear_load()
	velocity = Vector2.ZERO
	heat = 0.0
	angular_velocity = 0.0
	thrust_hold_time = 0.0
	heat_system.reset()
	run_stats.reset()
	feedback.reset()
	if fx_explosion:
		fx_explosion.emitting = false
	state_machine.change_state(STATE_COAST)