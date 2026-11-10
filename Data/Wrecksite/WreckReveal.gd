extends Resource
class_name WreckReveal

const EXPLOSION_PIXEL_SCALE := 2.0
const EXPLOSION_POWER := 2.0
const PREVIEW_DELAY_SHARE := 0.6
const PREVIEW_TRAVEL_EXTRA := 0.2

@export var fx_preset : String = "explosion"
@export var travel_time : float = 1.2
@export var hold_time : float = 1.0
@export var pop_time : float = 0.3
@export var fade_time : float = 0.4
@export var max_preview_debris : int = 60
@export var return_time : float = 1.5
@export_group("Explosion Debris")
@export var min_explosions : int = 3
@export var max_explosions : int = 7
@export var explosion_radius : float = 100.0
@export var explosion_stagger : float = 0.07
@export_group("Impact")
@export var travel_rumble : float = 5.0
@export var intro_shake : float = 10.0
@export var intro_shake_duration : float = 0.5
@export var intro_vignette : float = 0.4
@export var explosion_shake : float = 8.0
@export var explosion_shake_duration : float = 0.25
@export var site_shake : float = 30.0
@export var site_shake_duration : float = 0.8
@export var site_vignette : float = 1.0
@export var site_zoom_punch : float = 0.08
@export var release_shake : float = 16.0
@export var release_shake_duration : float = 0.5
@export var release_vignette : float = 0.6
@export var release_zoom_punch : float = 0.05

var _skipped : bool = false

class SkipListener extends Node:
	signal skip_pressed

	func _input(event : InputEvent) -> void:
		if not event.is_pressed() or event.is_echo():
			return
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			skip_pressed.emit()

func play(host : Main, sites : Array[WreckSite], cam : Cam, player : Player,
		debris_field : DebrisField, rng : RandomNumberGenerator) -> void:
	if sites.is_empty() or cam == null:
		return
	var tree := host.get_tree()
	while tree.paused:
		await tree.process_frame

	_skipped = false
	var listener := SkipListener.new()
	listener.skip_pressed.connect(_on_skip_pressed)
	host.add_child(listener)

	if is_instance_valid(player):
		player.set_physics_process(false)

	cam.impact(intro_shake, intro_shake_duration, intro_vignette, 0.0)

	var previews : Array[Node2D] = []
	for site_index in sites.size():
		if _skipped:
			break
		var site := sites[site_index]
		var center := site.origin + site.direction * site.length * 0.5
		cam.focus_point(center)
		cam.set_rumble(travel_rumble)
		await _wait(host, travel_time)
		if _skipped:
			break
		cam.set_rumble(0.0)
		cam.impact(site_shake, site_shake_duration, site_vignette, site_zoom_punch)
		_burst(host, cam, center, rng)
		previews.append_array(_spawn_previews(host, debris_field, site_index, center, rng))
		await _wait(host, hold_time)

	cam.set_rumble(0.0)
	if not _skipped:
		cam.return_to_target()
		await _wait(host, return_time)

	if is_instance_valid(listener):
		listener.queue_free()

	if _skipped:
		cam.clear_impact()
		cam.snap_to_target()
		_free_previews(previews)
	else:
		cam.impact(release_shake, release_shake_duration, release_vignette, release_zoom_punch)
		_fade_out(host, previews)

	if is_instance_valid(player):
		player.set_physics_process(true)
	if debris_field != null:
		debris_field.start_streaming()

func _on_skip_pressed() -> void:
	_skipped = true

func _wait(host : Node, seconds : float) -> void:
	var remaining := seconds
	while remaining > 0.0 and not _skipped:
		await host.get_tree().process_frame
		if not is_instance_valid(host):
			return
		remaining -= host.get_process_delta_time()

func _burst(host : Node2D, cam : Cam, at : Vector2, rng : RandomNumberGenerator) -> void:
	var amount := rng.randi_range(min_explosions, max_explosions)
	for explosion_index in amount:
		if _skipped or not is_instance_valid(host):
			return
		_spawn_explosion(host, at, rng)
		if is_instance_valid(cam):
			cam.impact(explosion_shake, explosion_shake_duration, 0.0, 0.0)
		await _wait(host, explosion_stagger)

func _spawn_explosion(host : Node2D, at : Vector2, rng : RandomNumberGenerator) -> void:
	var effect := FXPlayer.new()
	effect.preset = fx_preset
	effect.pixel_scale = EXPLOSION_PIXEL_SCALE
	effect.power = EXPLOSION_POWER
	effect.play_mode = FXPlayer.PlayMode.ONCE
	effect.free_on_finish = true
	effect.position = at + _random_offset(rng, explosion_radius)
	host.add_child(effect)

func _random_offset(rng : RandomNumberGenerator, radius : float) -> Vector2:
	return Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, radius)

func _spawn_previews(host : Main, debris_field : DebrisField, site_index : int, center : Vector2,
		rng : RandomNumberGenerator) -> Array[Node2D]:
	var result : Array[Node2D] = []
	if debris_field == null:
		return result
	var entries := debris_field.preview_entries(site_index, max_preview_debris)
	for entry_index in entries.size():
		result.append(_spawn_preview(host, entries[entry_index], center, entry_index, entries.size(), rng))
	return result

func _spawn_preview(host : Main, entry : Dictionary, center : Vector2, entry_index : int, total : int,
		rng : RandomNumberGenerator) -> Node2D:
	var sprite := Sprite2D.new()
	sprite.texture = DebrisShapes.make(entry.tag, entry.variant).tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = center
	sprite.rotation = rng.randf() * TAU
	sprite.scale = Vector2.ZERO
	host.add_child(sprite)
	var destination : Vector2 = host.to_local(entry.position)
	var delay := hold_time * PREVIEW_DELAY_SHARE * float(entry_index) / float(maxi(total, 1))
	_tween_preview(sprite, destination, delay)
	return sprite

func _tween_preview(sprite : Sprite2D, destination : Vector2, delay : float) -> void:
	var tween := sprite.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2.ONE * DebrisShapes.PX, pop_time).set_delay(delay)
	tween.parallel().tween_property(sprite, "position", destination, pop_time + PREVIEW_TRAVEL_EXTRA).set_delay(delay)

func _free_previews(previews : Array[Node2D]) -> void:
	for sprite in previews:
		if is_instance_valid(sprite):
			sprite.queue_free()

func _fade_out(host : Node2D, previews : Array[Node2D]) -> void:
	if previews.is_empty():
		return
	var tween := host.create_tween().set_parallel(true)
	for sprite in previews:
		_fade_sprite(tween, sprite)
	tween.chain().tween_callback(_free_previews.bind(previews))

func _fade_sprite(tween : Tween, sprite : Node2D) -> void:
	tween.tween_property(sprite, "modulate:a", 0.0, fade_time)