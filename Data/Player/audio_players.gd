extends Node2D
class_name PlayerAudio

enum EndStyle { NONE, MELTDOWN, FUEL, QUOTA }

@export var music_name := "space_ambient"

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

var muffle_amount := 0.0 : set = _set_muffle_amount
var end_progress := 0.0 : set = _set_end_progress
var cut_amount := 0.0 : set = _set_cut_amount
var end_style : EndStyle = EndStyle.NONE
var _muffle_tween : Tween
var _end_tween : Tween
var _filter : AudioEffectLowPassFilter
var _dist : AudioEffectDistortion
var _amp : AudioEffectAmplify
var _bus := -1
var _fi := -1
var _di := -1
var _ai := -1
var _fe := false
var _de := false
var _ae := false
var _pitch := 1.0

func _ready() -> void:
	var p := get_parent()
	while p and not (p is Player):
		p = p.get_parent()
	if p:
		p.boost_started.connect(Audio.play.bind("boost"))
		p.fuel_empty_tapped.connect(Audio.play.bind("empty_click"))
		p.crashed.connect(_on_crash)
		p.debris_attached.connect(_on_attach)
		p.exploded.connect(_on_exploded)
	Audio.music(music_name, 1.0)
	_bus = AudioServer.get_bus_index("Music")
	if _bus == -1:
		return
	_filter = AudioEffectLowPassFilter.new()
	_filter.cutoff_hz = OPEN_CUTOFF_HZ
	_filter.resonance = 0.6
	_dist = AudioEffectDistortion.new()
	_dist.mode = AudioEffectDistortion.MODE_CLIP
	_dist.post_gain = -4.0
	_amp = AudioEffectAmplify.new()
	_fi = AudioServer.get_bus_effect_count(_bus)
	_di = _fi + 1
	_ai = _fi + 2
	for e in [_filter, _dist, _amp]:
		AudioServer.add_bus_effect(_bus, e)
	for i in [_fi, _di, _ai]:
		AudioServer.set_bus_effect_enabled(_bus, i, false)

func _exit_tree() -> void:
	if _bus == -1 or _bus >= AudioServer.get_bus_count():
		return
	for e in [_filter, _dist, _amp]:
		for i in AudioServer.get_bus_effect_count(_bus):
			if AudioServer.get_bus_effect(_bus, i) == e:
				AudioServer.remove_bus_effect(_bus, i)
				break
	Audio.music_pitch(1.0)

func _on_crash(speed : float) -> void:
	Audio.play("crash", null, linear_to_db(clampf(speed / 600.0, 0.2, 1.0)))

func _on_attach(weight : float) -> void:
	Audio.play("attach", null, 0.0, clampf(1.25 - weight * 0.02, 0.6, 1.25))

func _on_exploded() -> void:
	Audio.play("explosion")

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
	if _end_tween:
		_end_tween.kill()

func _tween_muffle(target : float, duration : float, ease_type : Tween.EaseType) -> void:
	if _muffle_tween:
		_muffle_tween.kill()
	_muffle_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_muffle_tween.tween_property(self, "muffle_amount", target, duration).set_trans(Tween.TRANS_SINE).set_ease(ease_type)

func _set_muffle_amount(v : float) -> void:
	muffle_amount = v
	_apply_music()

func _set_end_progress(v : float) -> void:
	end_progress = v
	_apply_music()

func _set_cut_amount(v : float) -> void:
	cut_amount = v
	_apply_music()

func _apply_music() -> void:
	if _bus == -1:
		return
	var p := end_progress
	var drop := muffle_volume_drop_db * muffle_amount
	var pitch := 1.0
	var cm := 1.0
	var drive := 0.0
	match end_style:
		EndStyle.MELTDOWN:
			pitch = 1.0 + meltdown_pitch_rise * p + randf_range(-1.0, 1.0) * meltdown_pitch_wobble * p
			drive = meltdown_drive * p
		EndStyle.FUEL:
			pitch = lerpf(1.0, fuel_min_pitch, p)
			drop += fuel_volume_drop_db * p
			cm = pow(fuel_end_cutoff_hz / muffle_cutoff_hz, p)
		EndStyle.QUOTA:
			pitch = lerpf(1.0, quota_min_pitch, p)
			drop += quota_volume_drop_db * p
			cm = pow(quota_end_cutoff_hz / muffle_cutoff_hz, p)
	drop += SILENCE_DB * cut_amount
	_amp.volume_db = maxf(-drop, -80.0)
	_filter.cutoff_hz = maxf(OPEN_CUTOFF_HZ * pow(muffle_cutoff_hz / OPEN_CUTOFF_HZ, muffle_amount) * cm, 40.0)
	_dist.drive = drive
	_toggle(_ai, drop > 0.001, _ae)
	_toggle(_fi, muffle_amount > 0.001, _fe)
	_toggle(_di, drive > 0.001, _de)
	_ae = drop > 0.001
	_fe = muffle_amount > 0.001
	_de = drive > 0.001
	if pitch != _pitch:
		_pitch = pitch
		Audio.music_pitch(maxf(pitch, 0.05))

func _toggle(i : int, on : bool, was : bool) -> void:
	if on != was:
		AudioServer.set_bus_effect_enabled(_bus, i, on)