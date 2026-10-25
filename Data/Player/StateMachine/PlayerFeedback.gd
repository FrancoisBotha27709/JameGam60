extends RefCounted
class_name PlayerFeedback

const HALF := 0.5

var player : Player
var sprite : Node2D
var sprite_origin := Vector2.ZERO
var sprite_base_modulate := Color.WHITE
var sprite_base_scale := Vector2.ONE
var punch_amount := 0.0
var empty_progress := 0.0
var cough_amount := 0.0
var meltdown_phase := 0.0
var elapsed_time := 0.0
var is_hit_stopped := false
var punch_tween : Tween
var empty_tween : Tween
var cough_tween : Tween

func _init(owning_player : Player) -> void:
	player = owning_player
	sprite = player.node_sprite
	if sprite:
		sprite_origin = sprite.position
		sprite_base_modulate = sprite.modulate
		sprite_base_scale = sprite.scale
	player.thrust_tapped.connect(_on_thrust_tapped)
	player.crashed.connect(_on_crashed)
	player.debris_attached.connect(func(_weight : float) -> void: punch(player.pickup_punch_strength))
	player.debris_delivered.connect(func(_count : int) -> void: punch(player.delivery_punch_strength))
	player.exploded.connect(_on_exploded)
	player.fuel_empty_tapped.connect(_on_fuel_empty_tapped)
	player.fx.cough.connect(_on_cough)

# Eases one of this object's float properties from a start value down to zero on a fresh tween.
func _animate(previous_tween : Tween, property : StringName, start_value : float, duration : float, transition : Tween.TransitionType) -> Tween:
	if previous_tween and previous_tween.is_valid():
		previous_tween.kill()
	set(property, start_value)
	var tween := player.create_tween().set_trans(transition).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, NodePath(property), 0.0, duration)
	return tween

# Squash-and-stretch pulse: the sprite lengthens along its heading, then springs back.
func punch(strength : float) -> void:
	punch_tween = _animate(punch_tween, &"punch_amount", strength, player.punch_duration, Tween.TRANS_ELASTIC)

# Freezes time for a few real-time milliseconds to sell a heavy impact.
func hit_stop() -> void:
	if is_hit_stopped:
		return
	is_hit_stopped = true
	var previous_time_scale := Engine.time_scale
	Engine.time_scale = player.hit_stop_time_scale
	await player.get_tree().create_timer(player.hit_stop_duration, true, false, true).timeout
	Engine.time_scale = previous_time_scale
	is_hit_stopped = false

func _on_thrust_tapped(boosting : bool) -> void:
	punch(player.boost_punch_strength if boosting else player.tap_punch_strength)
	player.shake_requested.emit(player.boost_shake_strength if boosting else player.tap_shake_strength)

func _on_crashed(impact_speed : float) -> void:
	var impact_ratio := clampf(impact_speed / player.max_speed, 0.0, 1.0)
	punch(player.crash_punch_strength * impact_ratio)
	player.shake_requested.emit(player.crash_shake_strength * impact_ratio)
	if impact_ratio >= player.hit_stop_min_impact:
		hit_stop()

func _on_exploded() -> void:
	player.shake_requested.emit(player.explosion_shake_strength)
	hit_stop()

func _on_fuel_empty_tapped() -> void:
	empty_tween = _animate(empty_tween, &"empty_progress", 1.0, player.empty_fx_duration, Tween.TRANS_LINEAR)

func _on_cough(strength : float) -> void:
	cough_tween = _animate(cough_tween, &"cough_amount", strength, player.cough_duration, Tween.TRANS_LINEAR)

# Picks the strongest active tint: meltdown flash, empty-fuel flash, then heat glow.
func _resolve_tint(delta : float) -> Dictionary:
	if player.heat_system.is_melting:
		var flash_speed := lerpf(player.meltdown_flash_start, player.meltdown_flash_end, player.heat_system.get_meltdown_progress())
		meltdown_phase += flash_speed * TAU * delta
		return {color = player.meltdown_color, amount = HALF - HALF * cos(meltdown_phase)}
	if empty_progress > 0.0:
		return {color = player.empty_color, amount = absf(sin(empty_progress * TAU))}
	return {color = player.heat_color, amount = player.heat / player.heat_max * player.heat_tint_max}

# Layers tint, idle bob, shake, banking, and stretch onto the sprite every frame.
func update(delta : float) -> void:
	if sprite == null:
		return
	elapsed_time += delta
	var tint := _resolve_tint(delta)
	sprite.modulate = sprite_base_modulate.lerp(tint.color, tint.amount).darkened(cough_amount * player.cough_darken)
	player.rig.set_tint(tint.color, tint.amount)
	var bob = Vector2.UP * sin(elapsed_time * TAU * player.idle_bob_frequency) * player.idle_bob_amplitude
	var shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * empty_progress * player.empty_shake_strength
	sprite.position = sprite_origin + bob + shake
	sprite.skew = -player.angular_velocity * player.bank_per_angular_velocity
	var stretch = punch_amount + player.flight.get_thrust_ratio() * player.thrust_stretch
	sprite.scale = sprite_base_scale * Vector2(1.0 - stretch * player.squash_ratio, 1.0 + stretch)

# Clears all running effects and restores the sprite for a new run.
func reset() -> void:
	punch_amount = 0.0
	empty_progress = 0.0
	cough_amount = 0.0
	meltdown_phase = 0.0
	if sprite:
		sprite.show()
		sprite.modulate = sprite_base_modulate
		sprite.position = sprite_origin
		sprite.scale = sprite_base_scale
		sprite.skew = 0.0