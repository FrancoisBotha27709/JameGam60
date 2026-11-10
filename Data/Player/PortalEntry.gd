extends Resource
class_name PortalEntry

const EMERGE_START_SCALE := 0.05
const FADE_IN_SHARE := 0.25
const ENGINE_BLAZE := 1.0
const ENGINE_OFF := 0.0
const RUMBLE_OFF := 0.0
const NO_SHAKE := 0.0
const NO_ZOOM := 0.0
const NO_DURATION := 0.0

@export var fx_preset : String = "portal"
@export var fx_power : float = 1.5
@export var fx_pixel_scale : float = 2.0
@export var portal_distance : float = 320.0
@export var open_time : float = 1.4
@export var emerge_time : float = 0.9
@export var settle_time : float = 0.35
@export var linger_time : float = 1.2
@export var spin_turns : float = 1.0
@export var land_burst : float = 1.0
@export_group("Impact")
@export var open_rumble : float = 6.0
@export var open_vignette : float = 0.35
@export var emerge_shake : float = 22.0
@export var emerge_shake_duration : float = 0.7
@export var emerge_vignette : float = 0.9
@export var emerge_zoom_punch : float = 0.07
@export var land_shake : float = 12.0
@export var land_shake_duration : float = 0.4
@export var land_vignette : float = 0.5
@export var land_zoom_punch : float = 0.04

var _skipped : bool = false
var _host : Main
var _player : Player
var _camera : Cam
var _portal_effect : FXPlayer
var _tweens : Array[Tween] = []
var _portal_center := Vector2.ZERO
var _home_position := Vector2.ZERO
var _home_rotation : float = 0.0
var _home_scale := Vector2.ONE
var _home_modulate := Color.WHITE

func play(host : Main, player : Player, camera : Cam) -> bool:
	if player == null or host == null:
		return false
	var tree := host.get_tree()
	while tree.paused:
		await tree.process_frame

	_host = host
	_player = player
	_camera = camera
	_skipped = false
	_tweens.clear()

	var listener := WreckReveal.SkipListener.new()
	listener.skip_pressed.connect(_on_skip_pressed)
	host.add_child(listener)

	_start()
	await _wait(open_time)
	if not _skipped:
		_emerge()
		await _wait(emerge_time)
	if not _skipped:
		_land()
		await _wait(settle_time)

	if is_instance_valid(listener):
		listener.queue_free()
	if _skipped:
		_abort()
	return _skipped

func _on_skip_pressed() -> void:
	_skipped = true

func _wait(seconds : float) -> void:
	var remaining := seconds
	while remaining > 0.0 and not _skipped:
		await _host.get_tree().process_frame
		if not is_instance_valid(_host):
			return
		remaining -= _host.get_process_delta_time()

#region Sequence

func _start() -> void:
	_home_position = _player.global_position
	_home_rotation = _player.rotation
	_home_scale = _player.scale
	_home_modulate = _player.modulate
	var forward := Vector2.UP.rotated(_home_rotation)
	_portal_center = (_home_position - forward * portal_distance).clamp(_host.world_rect.position, _host.world_rect.end)
	_player.set_physics_process(false)
	_player.visible = false
	_portal_effect = _spawn_portal()
	if is_instance_valid(_camera):
		_camera.focus_point(_portal_center)
		_camera.impact(NO_SHAKE, NO_DURATION, open_vignette, NO_ZOOM)
		var rumble_tween := _host.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		rumble_tween.tween_method(_camera.set_rumble, RUMBLE_OFF, open_rumble, open_time)
		_tweens.append(rumble_tween)

func _emerge() -> void:
	_player.global_position = _portal_center
	_player.rotation = _home_rotation + TAU * spin_turns
	_player.scale = _home_scale * EMERGE_START_SCALE
	_player.modulate = Color(_home_modulate, 0.0)
	_player.visible = true
	_set_engines(ENGINE_BLAZE, true)
	if is_instance_valid(_camera):
		_camera.set_rumble(RUMBLE_OFF)
		_camera.impact(emerge_shake, emerge_shake_duration, emerge_vignette, emerge_zoom_punch)
		_camera.return_to_target()
	var tween := _host.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(_player, "global_position", _home_position, emerge_time)
	tween.tween_property(_player, "scale", _home_scale, emerge_time)
	tween.tween_property(_player, "rotation", _home_rotation, emerge_time).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_player, "modulate:a", _home_modulate.a, emerge_time * FADE_IN_SHARE)
	_tweens.append(tween)

func _land() -> void:
	_set_engines(ENGINE_OFF, false)
	for effect in _player.fx:
		if is_instance_valid(effect):
			effect.burst(land_burst)
	if is_instance_valid(_camera):
		_camera.impact(land_shake, land_shake_duration, land_vignette, land_zoom_punch)
	if is_instance_valid(_portal_effect):
		_portal_effect.stop()
		_host.get_tree().create_timer(linger_time).timeout.connect(_portal_effect.queue_free)

func _abort() -> void:
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	if is_instance_valid(_portal_effect):
		_portal_effect.clear()
		_portal_effect.queue_free()
	_player.global_position = _home_position
	_player.rotation = _home_rotation
	_player.scale = _home_scale
	_player.modulate = _home_modulate
	_player.visible = true
	_set_engines(ENGINE_OFF, false)
	if is_instance_valid(_camera):
		_camera.clear_impact()
		_camera.snap_to_target()

#endregion

#region Helpers

func _spawn_portal() -> FXPlayer:
	var effect := FXPlayer.new()
	effect.preset = fx_preset
	effect.pixel_scale = fx_pixel_scale
	effect.power = fx_power
	effect.play_mode = FXPlayer.PlayMode.LOOP
	effect.free_on_finish = false
	effect.z_index = _player.z_index - 1
	_host.add_child(effect)
	effect.global_position = _portal_center
	effect.rotation = _home_rotation
	return effect

func _set_engines(thrust_ratio : float, is_boosting : bool) -> void:
	for effect in _player.fx:
		if is_instance_valid(effect):
			effect.set_thrust(thrust_ratio, is_boosting)
	if is_instance_valid(_player.rig):
		_player.rig.set_engine(thrust_ratio, is_boosting)

#endregion