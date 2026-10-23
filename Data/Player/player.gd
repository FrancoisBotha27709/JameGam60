extends CharacterBody2D
class_name Player

const _BASE_PROPS : Array[StringName] = [
	&"max_speed", &"rotation_speed", &"throttle_accel", &"thrust_accel", &"tap_impulse",
	&"grip", &"coast_drag", &"weight_drag", &"boost_speed_mult", &"boost_fuel_mult",
	&"fuel_max", &"weight_fuel_factor", &"fuel_depletion_rate", &"tap_fuel_cost",
	&"heat_max", &"cool_rate", &"meltdown_time", &"collision_shape_scale",
	&"tap_heat", &"hold_heat_rate", &"overheat_enabled",
]
var _base : Dictionary = {}

@export_group("Stats")
@export var max_speed : float = 400.0
@export var collision_shape_scale : float = 1.0

@export_subgroup("Rotation")
@export var rotation_speed : float = 2.5

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
var _exploded : bool = false

@export_subgroup("Weight")
@export var weight_drag : float = 0.05
@export var min_speed_factor : float = 0.25

@export_group("Empty Feedback")
## Defaults to the child named "Icon"
@export var node_sprite : Node2D
@export var empty_fx_duration : float = 0.5
@export var empty_shake_strength : float = 4.0

@export_group("Ship Details", "ship_")
@export var ship_color : Color = Color(0.75, 0.8, 0.9)
@export_subgroup("Collision")
@export var bounce_restitution : float = 0.6
@export var bounce_min_speed : float = 140.0
@export var bounce_lock_time : float = 0.25
var _bounce_lock : float = 0.0

@export_group("UI Objects")
@export var ui_root : UIContainer
@export_group("Effects", "fx_")
@export var fx : ShipFX
@export var fx_explosion : FXEmitter
@export var rig : LightRig
@export var collision_shape : CollisionShape2D
@export var circle_fuel_prog_bar : CircleBar
@export var circle_heat_prog_bar : CircleBar

var total_weight : float = 0.0
var attached_debris : Array[DebrisObject] = []

var _hold_time : float = 0.0
var _was_empty : bool = false
var _empty_tween : Tween
var _sprite_origin : Vector2
var _sprite_base_modulate : Color = Color.WHITE

var _since_tap : float = 999.0
var _meltdown : bool = false
var _meltdown_t : float = 0.0
var _flash_phase : float = 0.0

var world_rect : Rect2
var _bounded : bool = false

# Run Stats
var _stat_time : float = 0.0
var _stat_distance : float = 0.0
var _stat_top_speed : float = 0.0
var _stat_crashes : int = 0
var _stat_debris_collected : int = 0
var _stat_debris_delivered : int = 0
var _stat_peak_load : float = 0.0
var _stat_fuel_burned : float = 0.0
var _stat_peak_heat : float = 0.0
var _stat_boost_time : float = 0.0

func _ready() -> void:
	if node_sprite == null:
		node_sprite = get_node_or_null("Icon") as Node2D
	if node_sprite != null:
		_sprite_origin = node_sprite.position
		_sprite_base_modulate = node_sprite.modulate

	_set_labels()
	DataCollector.player = self
	_apply_upgrades()
	DataCollector.run_start_hooks(self)
	throttle = 0.0
	_set_stats()

	SignalBus.update_fuel.connect(_on_fuel_update)
	SignalBus.update_heat.connect(_on_heat_update)
	fx.cough.connect(_on_cough)
	for p in _BASE_PROPS:
		_base[p] = get(p)

func _physics_process(delta : float) -> void:
	_bounce_lock = maxf(_bounce_lock - delta, 0.0)
	DataCollector.physics_hooks(self, delta)
	_handle_rotation(delta)
	_handle_movement(delta)
	_update_heat(delta)
	move_and_slide()
	_track_stats(delta)
	_clamp_to_world()
	_update_bars()
	ui_root.set_speed(velocity.length())
	var thrust01 := throttle / 100.0 if current_fuel > 0.0 else 0.0
	fx.set_thrust(thrust01, _boost_held())
	rig.set_engine(thrust01, _boost_held())

func _apply_upgrades() -> void:
	# Movement
	max_speed = DataCollector.get_stat(Upgrade.Stat.MAX_SPEED, max_speed)
	rotation_speed = DataCollector.get_stat(Upgrade.Stat.ROTATION_SPEED, rotation_speed)
	throttle_accel = DataCollector.get_stat(Upgrade.Stat.THROTTLE_ACCEL, throttle_accel)
	thrust_accel = DataCollector.get_stat(Upgrade.Stat.THRUST_ACCEL, thrust_accel)
	tap_impulse = DataCollector.get_stat(Upgrade.Stat.TAP_IMPULSE, tap_impulse)
	grip = DataCollector.get_stat(Upgrade.Stat.GRIP, grip)
	coast_drag = maxf(DataCollector.get_stat(Upgrade.Stat.COAST_DRAG, coast_drag), 0.0)
	weight_drag = maxf(DataCollector.get_stat(Upgrade.Stat.WEIGHT_DRAG, weight_drag), 0.0)

	# Boost and fuel
	boost_speed_mult = maxf(DataCollector.get_stat(Upgrade.Stat.BOOST_SPEED, boost_speed_mult), 1.0)
	boost_fuel_mult = maxf(DataCollector.get_stat(Upgrade.Stat.BOOST_FUEL, boost_fuel_mult), 1.0)
	fuel_max = DataCollector.get_stat(Upgrade.Stat.FUEL_MAX, fuel_max)
	weight_fuel_factor = maxf(DataCollector.get_stat(Upgrade.Stat.WEIGHT_FUEL, weight_fuel_factor), 0.0)
	var burn := maxf(DataCollector.get_stat(Upgrade.Stat.FUEL_BURN, 1.0), 0.2)
	fuel_depletion_rate *= burn
	tap_fuel_cost *= burn

	# Overheat
	heat_max = DataCollector.get_stat(Upgrade.Stat.HEAT_MAX, heat_max)
	cool_rate = DataCollector.get_stat(Upgrade.Stat.COOL_RATE, cool_rate)
	meltdown_time = DataCollector.get_stat(Upgrade.Stat.MELTDOWN_TIME, meltdown_time)
	collision_shape_scale = DataCollector.get_stat(Upgrade.Stat.MAGNET_SIZE, collision_shape_scale)
	var gain := maxf(DataCollector.get_stat(Upgrade.Stat.HEAT_GAIN, 1.0), 0.2)
	tap_heat *= gain
	hold_heat_rate *= gain
	collision_shape.scale = Vector2(collision_shape_scale, collision_shape_scale)

func _is_mouse_mode() -> bool:
	return Settings.values.controls == Settings.CONTROLS.MOUSE

func _act(action : StringName) -> StringName:
	return StringName(("mouse_" if _is_mouse_mode() else "keyboard_") + action)

func _pressed(action : StringName) -> bool:
	var a := _act(action)
	return InputMap.has_action(a) and Input.is_action_pressed(a)

func _just_pressed(action : StringName) -> bool:
	var a := _act(action)
	return InputMap.has_action(a) and Input.is_action_just_pressed(a)

func _handle_rotation(delta : float) -> void:
	if _exploded:
		return

	if _is_mouse_mode():
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() < 10.0:   # dead zone so the ship doesn't jitter on top of the cursor
			return
		# Sprite faces UP, so add 90 degrees
		var target := to_mouse.angle() + PI / 2.0
		var step := rotation_speed * delta
		rotation += clampf(angle_difference(rotation, target), -step, step)
	else:
		var dir := -1.0 if DataCollector.flag(&"invert_controls") % 2 == 1 else 1.0
		rotation += Input.get_axis("keyboard_left", "keyboard_right") * dir * rotation_speed * delta

func _boost_held() -> bool:
	return not _exploded and _pressed("boost")

func _boost_just_pressed() -> bool:
	return not _exploded and _just_pressed("boost")

func _handle_movement(delta : float) -> void:
	if _exploded:
		return

	var boosting := _boost_held()
	var thrust_held := _pressed("forward") or boosting
	var thrust_tapped := _just_pressed("forward") or _boost_just_pressed()
	var braking := _pressed("backward") or _pressed("cut_throttle")

	if current_fuel <= 0.0:
		_on_fuel_empty()
		velocity = velocity.move_toward(Vector2.ZERO, coast_drag * 3.0 * delta)
		if thrust_tapped:
			_play_empty_feedback()
		return

	var weight_factor := _get_weight_factor()
	var speed_mult := boost_speed_mult if boosting else 1.0
	var fuel_mult := (1.0 + total_weight * weight_fuel_factor) * (boost_fuel_mult if boosting else 1.0)
	var speed_cap := max_speed * weight_factor * speed_mult
	var forward := Vector2.UP.rotated(rotation) # Assuming the sprite faces up
	var fuel_to_burn := 0.0

	if thrust_tapped:
		var prev_speed := velocity.length()
		velocity += forward * tap_impulse * weight_factor * speed_mult
		velocity = velocity.limit_length(maxf(speed_cap, prev_speed))
		fuel_to_burn += tap_fuel_cost * fuel_mult
		fx.burst(0.6)

	if thrust_held:
		_hold_time += delta
		if _hold_time >= hold_delay:
			throttle = move_toward(throttle, 100.0, throttle_accel * delta)
	else:
		_hold_time = 0.0
		throttle = move_toward(throttle, 0.0, throttle_decel * delta)

	if throttle > 0.0:
		if velocity.length() < speed_cap:
			velocity += forward * thrust_accel * (throttle / 100.0) * weight_factor * speed_mult * delta
			velocity = velocity.limit_length(maxf(speed_cap, 0.0))
		var spd := velocity.length()
		if spd > 0.0 and grip > 0.0 and _bounce_lock <= 0.0:
			velocity = velocity.normalized().slerp(forward, minf(grip * delta, 1.0)) * spd
		fuel_to_burn += fuel_depletion_rate * (throttle / 100.0) * fuel_mult * delta

	if braking:
		velocity = velocity.move_toward(Vector2.ZERO, brake_drag * delta)
	elif throttle <= 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, coast_drag * delta)
	if velocity.length() > speed_cap:
		velocity = velocity.move_toward(velocity.normalized() * speed_cap, overspeed_drag * delta)

	if fuel_to_burn > 0.0:
		_burn_fuel(fuel_to_burn)

func _update_heat(delta : float) -> void:
	if DataCollector.game_mode == DataCollector.GameMode.FREE_PLAY:
		return
	if not overheat_enabled or not DataCollector.is_running:
		return
	if _meltdown:
		_tick_meltdown(delta)
		return
	if _exploded:
		return
	var can_thrust := current_fuel > 0.0
	var held := can_thrust and (_pressed("forward") or _boost_held())
	var tapped := can_thrust and (_just_pressed("forward") or _boost_just_pressed())

	_since_tap += delta
	if tapped:
		# Only rapid fire makes heat
		if _since_tap < tap_window:
			heat += tap_heat
		_since_tap = 0.0
	
	if held:
		heat += hold_heat_rate * (throttle / 100.0) * delta
	else:
		heat -= cool_rate * delta
	
	heat = clampf(heat, 0.0, heat_max)
	SignalBus.emit_signal("update_heat", heat, heat_max)
	_stat_peak_heat = maxf(_stat_peak_heat, heat)
	if heat >= heat_max:
		_meltdown = true
		_meltdown_t = 0.0
		_flash_phase = 0.0
	elif node_sprite != null and not _fx_busy():
		node_sprite.modulate = _sprite_base_modulate.lerp(Color(1.0, 0.45, 0.25), heat / heat_max * 0.7)
		rig.set_tint(Color(1.0, 0.45, 0.25), heat / heat_max * 0.7)

func _tick_meltdown(delta : float) -> void:
	_meltdown_t += delta
	var p := clampf(_meltdown_t / meltdown_time, 0.0, 1.0)

	# Flash gets faster the longer it goes
	_flash_phase += lerpf(meltdown_flash_start, meltdown_flash_end, p) * TAU * delta
	var flash := 0.5 - 0.5 * cos(_flash_phase)
	node_sprite.modulate = _sprite_base_modulate.lerp(Color(1.0, 0.1, 0.1), flash)
	rig.set_tint(Color(1.0, 0.1, 0.1), flash)
	if _meltdown_t >= meltdown_time:
		overheat_enabled = false
		_explode()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var blast_origin := global_position

	# Release everything we're carrying
	for debris in attached_debris:
		debris.detach()
	attached_debris.clear()
	total_weight = 0.0

	# Shockwave: shove every debris in range outwards
	for node in get_tree().get_nodes_in_group("Debris"):
		var d := node as DebrisObject
		if d != null:
			d.apply_blast(blast_origin, blast_radius, blast_force)

	if fx_explosion == null:
		DataCollector.destroy_run()
		return
	rig.set_lights_visible(false)
	LightManager.flash(global_position, Color(1.0, 0.6, 0.25), 450.0, 0.7, 3.0)
	# Make sure the burst actually plays, whatever the preset says
	for debris in attached_debris:
		debris.detach()
	fx_explosion.preprocess = 0.0   # otherwise the burst is simulated before the first frame
	fx_explosion.one_shot = true
	fx_explosion.explosiveness = 1.0
	fx_explosion.visibility_rect = Rect2(-600, -600, 1200, 1200)   # avoid culling
	fx_explosion.visible = true
	fx_explosion.emitting = false
	fx_explosion.restart()
	fx_explosion.emitting = true

	node_sprite.hide()
	get_node_or_null("SpaceLight").queue_free()
	get_node_or_null("SpaceLight2").queue_free()
	velocity = Vector2.ZERO

	# Timer instead of "finished", so destroy_run() always fires
	await get_tree().create_timer(fx_explosion.lifetime / maxf(fx_explosion.speed_scale, 0.01)).timeout
	DataCollector.destroy_run()

#fx_smoke.emitting = heat > heat_max * 0.7
#fx_sparks.emitting = current_fuel <= 0.0

func bounce_off(normal : Vector2, safe_pos : Vector2, rock_vel : Vector2) -> bool:
	global_position = safe_pos          # push out of the rock
	var rel := velocity - rock_vel
	var vn := rel.dot(normal)
	if vn >= 0.0:
		return false
	rel -= normal * vn * (1.0 + bounce_restitution)
	var out := rel.dot(normal)
	if out < bounce_min_speed:
		rel += normal * (bounce_min_speed - out)
	velocity = rock_vel + rel
	throttle *= 0.5
	_bounce_lock = bounce_lock_time
	fx.burst(0.8)
	_stat_crashes += 1
	return true

func _fx_busy() -> bool:
	if _exploded:
		return false
	return _empty_tween != null and _empty_tween.is_valid() and _empty_tween.is_running()

func _burn_fuel(amount : float) -> void:
	if not DataCollector.uses_fuel():
		return
	current_fuel = maxf(current_fuel - amount, 0.0)
	_stat_fuel_burned += amount
	SignalBus.emit_signal("update_fuel", current_fuel)
	if current_fuel <= 0.0:
		_on_fuel_empty()

func _on_fuel_empty() -> void:
	throttle = 0.0
	_hold_time = 0.0
	if not _was_empty:
		_was_empty = true
		SignalBus.emit_signal("fuel_depleted")
		fx.start_sputter()
		_play_empty_feedback()

func _play_empty_feedback() -> void:
	if node_sprite == null:
		return
	if _empty_tween != null and _empty_tween.is_valid() and _empty_tween.is_running():
		return
	_empty_tween = create_tween()
	_empty_tween.tween_method(_empty_fx_step, 0.0, 1.0, empty_fx_duration)
	_empty_tween.tween_callback(_reset_sprite)

# t goes 0 -> 1: two red flashes while the shake fades out
func _empty_fx_step(t : float) -> void:
	var flash := absf(sin(t * TAU))
	node_sprite.modulate = _sprite_base_modulate.lerp(Color(1.0, 0.2, 0.2), flash)
	var shake := (1.0 - t) * empty_shake_strength
	node_sprite.position = _sprite_origin + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake

func _reset_sprite() -> void:
	node_sprite.modulate = _sprite_base_modulate
	node_sprite.position = _sprite_origin

func _set_labels() -> void:
	_update_bars()

func _update_bars() -> void:
	circle_fuel_prog_bar.rotation = -global_rotation
	circle_heat_prog_bar.rotation = -global_rotation

func _set_stats() -> void:
	current_fuel = fuel_max
	_was_empty = false
	ui_root.setup_fuel(fuel_max, current_fuel)
	circle_fuel_prog_bar.setup(fuel_max)
	circle_heat_prog_bar.setup(heat)
	SignalBus.emit_signal("update_fuel", current_fuel)

func attach(object : DebrisObject) -> void:
	if _exploded or object in attached_debris:
		return

	var candidates : Array[Node2D] = [self]
	candidates.append_array(attached_debris)
	var anchor : Node2D = candidates.pick_random()

	attached_debris.append(object)
	total_weight += object.get_weight() * DataCollector.get_stat(Upgrade.Stat.DEBRIS_WEIGHT, 1.0)
	_stat_debris_collected += 1
	_stat_peak_load = maxf(_stat_peak_load, total_weight)
	object.attach_to(anchor)

func deliver_to(depot : Node2D) -> void:
	for debris in attached_debris:
		DataCollector.register_delivery(debris.data)
		debris.detach_to(depot)
	_stat_debris_delivered += attached_debris.size()
	attached_debris.clear()
	total_weight = 0.0

func _get_weight_factor() -> float:
	return maxf(1.0 / (1.0 + total_weight * weight_drag), min_speed_factor)

func set_world_bounds(rect : Rect2) -> void:
	world_rect = rect
	_bounded = true

func _clamp_to_world() -> void:
	if not _bounded:
		return
	
	var p := global_position
	var c := p.clamp(world_rect.position, world_rect.end)
	if c == p:
		return
	
	global_position = c
	if c.x != p.x:
		velocity.x = 0.0
	if c.y != p.y:
		velocity.y = 0.0

func _on_fuel_update(fuel : float) -> void:
	circle_fuel_prog_bar.set_value(fuel / fuel_max * 100.0)
	fx.set_fuel_ratio(fuel / fuel_max)
	
func _on_heat_update(new_heat : float, max_heat : float) -> void:
	circle_heat_prog_bar.set_value(new_heat / max_heat * 100.0)

func _on_cough(strength : float) -> void:
	if node_sprite == null or _fx_busy():
		return
	node_sprite.modulate = _sprite_base_modulate.darkened(0.35 * strength)
	get_tree().create_timer(0.06).timeout.connect(func():
		if node_sprite != null and not _fx_busy():
			node_sprite.modulate = _sprite_base_modulate)

func _track_stats(delta : float) -> void:
	if not DataCollector.is_running:
		return
	var spd := velocity.length()
	_stat_time += delta
	_stat_distance += spd * delta
	_stat_top_speed = maxf(_stat_top_speed, spd)
	if _boost_held() and current_fuel > 0.0:
		_stat_boost_time += delta

func get_summary() -> Dictionary:
	return {
		"debris_collected": _stat_debris_collected,
		"debris_delivered": _stat_debris_delivered,
		"time": _stat_time,
		"distance": _stat_distance,
		"top_speed": _stat_top_speed,
		"avg_speed": _stat_distance / _stat_time if _stat_time > 0.0 else 0.0,
		"crashes": _stat_crashes,
		"peak_load": _stat_peak_load,
		"fuel_burned": _stat_fuel_burned,
		"peak_heat_pct": _stat_peak_heat / heat_max * 100.0 if heat_max > 0.0 else 0.0,
		"boost_time": _stat_boost_time,
	}

func reset_for_run() -> void:
	for p in _BASE_PROPS:
		set(p, _base[p])

	_apply_upgrades()
	DataCollector.run_start_hooks(self)
	_set_stats()

	attached_debris.clear()
	total_weight = 0.0
	velocity = Vector2.ZERO
	throttle = 0.0
	heat = 0.0
	_hold_time = 0.0
	_since_tap = 999.0
	_bounce_lock = 0.0
	_meltdown = false
	_meltdown_t = 0.0
	_flash_phase = 0.0
	_exploded = false
	overheat_enabled = true

	if node_sprite != null:
		node_sprite.show()
		_reset_sprite()

	if fx_explosion != null:
		fx_explosion.emitting = false

	SignalBus.emit_signal("update_heat", 0.0, heat_max)
