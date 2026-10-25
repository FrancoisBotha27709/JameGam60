extends RefCounted
class_name PlayerStates

const HALF := 0.5
const EMPTY_DRAG_MULTIPLIER := 3.0
const MINIMUM_SPEED_SCALE := 0.01
const DEBRIS_GROUP := &"Debris"
const LIGHT_NODE_NAMES : Array[StringName] = [&"SpaceLight", &"SpaceLight2"]
const EXPLOSION_FLASH_COLOR := Color(1.0, 0.6, 0.25)
const EXPLOSION_FLASH_RADIUS := 450.0
const EXPLOSION_FLASH_DURATION := 0.7
const EXPLOSION_FLASH_INTENSITY := 3.0
const EXPLOSION_CULL_RECT := Rect2(-600, -600, 1200, 1200)

# Coasting or braking: the throttle spools down while drag and ambient sway carry the ship.
class Coast extends PlayerState:
	var is_braking : bool

	func _init(owning_player : Player, braking := false) -> void:
		super(owning_player)
		is_braking = braking

	func update(delta : float) -> void:
		player.throttle = move_toward(player.throttle, 0.0, player.throttle_decel * delta)
		player.flight.apply_engine(delta, false)
		if is_braking:
			player.flight.apply_drag(player.brake_drag, delta)
		elif player.throttle <= 0.0:
			player.flight.apply_drag(player.coast_drag, delta)
			player.flight.apply_ambient_drift(delta)
		player.flight.apply_overspeed_drag(false, delta)

# Thrusting or boosting: a tap impulse on entry, then throttle spools up after the hold delay.
class Thrust extends PlayerState:
	var is_boosting : bool

	func _init(owning_player : Player, boosting := false) -> void:
		super(owning_player)
		is_boosting = boosting

	func enter(previous_state_name : StringName) -> void:
		var was_thrusting := previous_state_name in Player.THRUST_STATES
		if not was_thrusting:
			player.thrust_hold_time = 0.0
		if is_boosting or not was_thrusting:
			player.flight.apply_tap(is_boosting)
		if is_boosting:
			player.boost_started.emit()

	func update(delta : float) -> void:
		player.thrust_hold_time += delta
		if player.thrust_hold_time >= player.hold_delay:
			player.throttle = move_toward(player.throttle, PlayerFlight.THROTTLE_MAX, player.throttle_accel * delta)
		player.flight.apply_engine(delta, is_boosting)
		if player.throttle <= 0.0:
			player.flight.apply_drag(player.coast_drag, delta)
		player.flight.apply_overspeed_drag(is_boosting, delta)

# Out of fuel: the engine sputters, drag is heavy, and tapping thrust only flashes a warning.
class Empty extends PlayerState:
	func enter(_previous_state_name : StringName) -> void:
		player.throttle = 0.0
		player.thrust_hold_time = 0.0
		SignalBus.fuel_depleted.emit()
		player.fx.start_sputter()
		player.fuel_empty_tapped.emit()

	func update(delta : float) -> void:
		player.flight.apply_drag(player.coast_drag * PlayerStates.EMPTY_DRAG_MULTIPLIER, delta)
		if player.player_input.thrust_tapped():
			player.fuel_empty_tapped.emit()

# After a crash: controls lock, the ship tumbles and drifts until the lock time runs out.
class Tumble extends PlayerState:
	var seconds_left := 0.0

	func enter(_previous_state_name : StringName) -> void:
		seconds_left = player.bounce_lock_time
		player.angular_velocity += player.tumble_spin_speed * signf(randf() - PlayerStates.HALF)

	func update(delta : float) -> void:
		seconds_left -= delta
		player.throttle = move_toward(player.throttle, 0.0, player.throttle_decel * delta)
		player.flight.apply_drag(player.coast_drag, delta)
		player.flight.apply_ambient_drift(delta)

	func physics_update(delta : float) -> void:
		update(delta)
		if seconds_left <= 0.0:
			transition_requested.emit(player.desired_state_name())

# Destroyed: sheds cargo, shoves nearby debris, plays the explosion, then ends the run.
class Exploded extends PlayerState:
	func enter(_previous_state_name : StringName) -> void:
		player.exploded.emit()
		player.release_debris()
		_shove_nearby_debris()
		player.velocity = Vector2.ZERO
		if player.fx_explosion == null:
			DataCollector.destroy_run()
			return
		_play_explosion()
		var burst_seconds := player.fx_explosion.lifetime / maxf(player.fx_explosion.speed_scale, PlayerStates.MINIMUM_SPEED_SCALE)
		await player.get_tree().create_timer(burst_seconds).timeout   # a timer, so destroy_run() always fires
		if player.is_exploded():
			DataCollector.destroy_run()

	func physics_update(_delta : float) -> void:
		pass

	func _shove_nearby_debris() -> void:
		for node in player.get_tree().get_nodes_in_group(PlayerStates.DEBRIS_GROUP):
			if node is DebrisObject:
				node.apply_blast(player.global_position, player.blast_radius, player.blast_force)

	func _play_explosion() -> void:
		player.rig.set_lights_visible(false)
		LightManager.flash(player.global_position, PlayerStates.EXPLOSION_FLASH_COLOR, PlayerStates.EXPLOSION_FLASH_RADIUS,
				PlayerStates.EXPLOSION_FLASH_DURATION, PlayerStates.EXPLOSION_FLASH_INTENSITY)
		var burst := player.fx_explosion
		burst.preprocess = 0.0   # otherwise the burst is simulated before the first frame
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.visibility_rect = PlayerStates.EXPLOSION_CULL_RECT
		burst.visible = true
		burst.emitting = false
		burst.restart()
		burst.emitting = true
		if player.node_sprite:
			player.node_sprite.hide()
		for light_name in PlayerStates.LIGHT_NODE_NAMES:
			var light := player.get_node_or_null(NodePath(light_name))
			if light:
				light.queue_free()