extends Node2D
class_name PlayerAudio

enum EndStyle { NONE, MELTDOWN, FUEL, QUOTA }

@export_group("Thrusters")
@export_subgroup("Tap")
@export var tap_audios : Array[AudioStream]
@export_range(0.0, 1.0) var pitch_variation_chance := 0.25
@export_range(0.0, 0.2) var pitch_variation := 0.05

@export_subgroup("Hold")
@export var thrust_audios : Array[AudioStream]
@export var transition_duration := 0.25
@export var fade_out_duration := 0.2

@export_group("Audio Players")
@export var tap_player : AudioStreamPlayer2D
@export var thrust_player : AudioStreamPlayer2D
@export var music_player : AudioStreamPlayer2D

@export_group("Music Muffle")
@export var muffle_volume_drop_db := 12.0
@export var muffle_cutoff_hz := 700.0
@export var muffle_in_duration := 0.35
@export var muffle_out_duration := 0.9

@export_group("Music End : Meltdown")
@export var meltdown_pitch_rise := 0.12
@export var meltdown_pitch_wobble := 0.05
@export_range(0.0, 1.0) var meltdown_drive := 0.7
@export var meltdown_ring_time := 3.0

@export_group("Music End : Fuel Empty")
@export_range(0.05, 1.0) var fuel_min_pitch := 0.25
@export var fuel_end_cutoff_hz := 250.0
@export var fuel_volume_drop_db := 18.0

@export_group("Music End : Quota Missed")
@export_range(0.05, 1.0) var quota_min_pitch := 0.7
@export var quota_end_cutoff_hz := 500.0
@export var quota_volume_drop_db := 6.0
@export var quota_recover_time := 1.5

const OPEN_CUTOFF_HZ := 20500.0
const SILENCE_DB := 70.0

var music_original_volume : float = 0
var music_original_pitch : float = 1.0
var muffle_amount := 0.0 : set = _set_muffle_amount
var end_progress := 0.0 : set = _set_end_progress
var cut_amount := 0.0 : set = _set_cut_amount
var end_style : EndStyle = EndStyle.NONE
var _thrust_tween : Tween
var _muffle_tween : Tween
var _end_tween : Tween
var _muffle_filter : AudioEffectLowPassFilter
var _distortion : AudioEffectDistortion
var _music_bus := -1
var _filter_index := -1
var _dist_index := -1
var is_thrusting := false

func _ready() -> void:
	if music_player == null:
		return
	music_original_volume = music_player.volume_db
	music_original_pitch = music_player.pitch_scale
	_music_bus = AudioServer.get_bus_index(music_player.bus)
	if _music_bus == -1:
		return
	_muffle_filter = AudioEffectLowPassFilter.new()
	_muffle_filter.cutoff_hz = OPEN_CUTOFF_HZ
	_muffle_filter.resonance = 0.6
	AudioServer.add_bus_effect(_music_bus, _muffle_filter)
	_filter_index = AudioServer.get_bus_effect_count(_music_bus) - 1
	AudioServer.set_bus_effect_enabled(_music_bus, _filter_index, false)
	_distortion = AudioEffectDistortion.new()
	_distortion.mode = AudioEffectDistortion.MODE_CLIP
	_distortion.drive = 0.0
	_distortion.post_gain = -4.0
	AudioServer.add_bus_effect(_music_bus, _distortion)
	_dist_index = AudioServer.get_bus_effect_count(_music_bus) - 1
	AudioServer.set_bus_effect_enabled(_music_bus, _dist_index, false)

func _exit_tree() -> void:
	if _music_bus == -1 or _music_bus >= AudioServer.get_bus_count():
		return
	_remove_effect(_muffle_filter)
	_remove_effect(_distortion)

func _remove_effect(effect : AudioEffect) -> void:
	if effect == null:
		return
	for i in range(AudioServer.get_bus_effect_count(_music_bus)):
		if AudioServer.get_bus_effect(_music_bus, i) == effect:
			AudioServer.remove_bus_effect(_music_bus, i)
			return

func muffle_music() -> void:
	_tween_muffle(1.0, muffle_in_duration, Tween.EASE_OUT)

func restore_music() -> void:
	_tween_muffle(0.0, muffle_out_duration, Tween.EASE_IN_OUT)
	if end_style == EndStyle.NONE:
		return
	_kill_end_tween()
	_end_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_end_tween.tween_property(self, "end_progress", 0.0, muffle_out_duration)
	_end_tween.tween_property(self, "cut_amount", 0.0, muffle_out_duration)
	_end_tween.chain().tween_callback(_clear_end_style)

func begin_end(reason : int) -> void:
	_kill_end_tween()
	end_style = _style_for(reason)
	end_progress = 0.0
	cut_amount = 0.0
	muffle_music()

func set_end_progress(t : float) -> void:
	end_progress = t

func end_death() -> void:
	if end_style == EndStyle.MELTDOWN or end_style == EndStyle.FUEL:
		cut_amount = 1.0

func end_aftermath() -> void:
	match end_style:
		EndStyle.MELTDOWN:
			end_progress = 0.0
			_kill_end_tween()
			_end_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			_end_tween.tween_property(self, "cut_amount", 0.0, meltdown_ring_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		EndStyle.QUOTA:
			_kill_end_tween()
			_end_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			_end_tween.tween_property(self, "end_progress", 0.0, quota_recover_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _style_for(reason : int) -> EndStyle:
	match reason:
		DataCollector.EndReason.MELTDOWN:
			return EndStyle.MELTDOWN
		DataCollector.EndReason.FUEL_EMPTY:
			return EndStyle.FUEL
	return EndStyle.QUOTA

func _clear_end_style() -> void:
	end_style = EndStyle.NONE

func _kill_end_tween() -> void:
	if _end_tween and _end_tween.is_valid():
		_end_tween.kill()

func _tween_muffle(target : float, duration : float, ease_type : Tween.EaseType) -> void:
	if music_player == null:
		return
	if _muffle_tween and _muffle_tween.is_valid():
		_muffle_tween.kill()
	_muffle_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_muffle_tween.tween_property(self, "muffle_amount", target, duration).set_trans(Tween.TRANS_SINE).set_ease(ease_type)

func _set_muffle_amount(value : float) -> void:
	muffle_amount = value
	_apply_music()

func _set_end_progress(value : float) -> void:
	end_progress = value
	_apply_music()

func _set_cut_amount(value : float) -> void:
	cut_amount = value
	_apply_music()

func _apply_music() -> void:
	if music_player == null:
		return
	var p := end_progress
	var drop := muffle_volume_drop_db * muffle_amount
	var pitch := 1.0
	var cutoff_mult := 1.0
	var drive := 0.0
	match end_style:
		EndStyle.MELTDOWN:
			pitch = 1.0 + meltdown_pitch_rise * p + randf_range(-1.0, 1.0) * meltdown_pitch_wobble * p
			drive = meltdown_drive * p
		EndStyle.FUEL:
			pitch = lerpf(1.0, fuel_min_pitch, p)
			drop += fuel_volume_drop_db * p
			cutoff_mult = pow(fuel_end_cutoff_hz / muffle_cutoff_hz, p)
		EndStyle.QUOTA:
			pitch = lerpf(1.0, quota_min_pitch, p)
			drop += quota_volume_drop_db * p
			cutoff_mult = pow(quota_end_cutoff_hz / muffle_cutoff_hz, p)
	drop += SILENCE_DB * cut_amount
	music_player.volume_db = music_original_volume - drop
	music_player.pitch_scale = maxf(music_original_pitch * pitch, 0.05)
	if _filter_index != -1:
		_muffle_filter.cutoff_hz = maxf(OPEN_CUTOFF_HZ * pow(muffle_cutoff_hz / OPEN_CUTOFF_HZ, muffle_amount) * cutoff_mult, 40.0)
		AudioServer.set_bus_effect_enabled(_music_bus, _filter_index, muffle_amount > 0.001)
	if _dist_index != -1:
		_distortion.drive = drive
		AudioServer.set_bus_effect_enabled(_music_bus, _dist_index, drive > 0.001)

func play_tap() -> void:
	if tap_audios.is_empty():
		return

	tap_player.stream = tap_audios.pick_random()
	tap_player.pitch_scale = _get_random_pitch()
	tap_player.play()

func play_thrust() -> void:
	if thrust_audios.is_empty() or is_thrusting:
		return

	is_thrusting = true

	if _thrust_tween and _thrust_tween.is_running():
		_thrust_tween.kill()

	play_tap()

	var tap_duration := 0.0

	if tap_player.stream:
		tap_duration = tap_player.stream.get_length()

	await get_tree().create_timer(tap_duration * 0.65).timeout

	if not is_thrusting:
		return

	thrust_player.stream = thrust_audios.pick_random()
	thrust_player.pitch_scale = _get_random_pitch()
	thrust_player.volume_db = -40.0
	thrust_player.play()

	_thrust_tween = create_tween()
	_thrust_tween.tween_property(
		thrust_player,
		"volume_db",
		0.0,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func stop_thrust() -> void:
	if not is_thrusting:
		return

	is_thrusting = false

	if _thrust_tween and _thrust_tween.is_running():
		_thrust_tween.kill()

	_thrust_tween = create_tween()
	_thrust_tween.tween_property(
		thrust_player,
		"volume_db",
		-40.0,
		fade_out_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_thrust_tween.tween_callback(thrust_player.stop)

func _get_random_pitch() -> float:
	if randf() > pitch_variation_chance:
		return 1.0

	return randf_range(
		1.0 - pitch_variation,
		1.0 + pitch_variation
	)