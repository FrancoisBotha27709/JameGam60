extends Control
class_name RunStartBanner

signal sequence_finished

const BOOT_LOG : String = "[color=#4dd9ff][  OK  ] [/color] Power rails stable
[color=#4dd9ff][  OK  ] [/color] Reactor core online
[color=#4dd9ff][  OK  ] [/color] Coolant loop primed
[color=#ff8c33][ WARN ] [/color] Hull integrity: acceptable
[color=#4dd9ff][  OK  ] [/color] Thruster array calibrated
[color=#4dd9ff][  OK  ] [/color] Fuel lines pressurized
[color=#4dd9ff][  OK  ] [/color] Magnet coil charged
[color=#4dd9ff][  OK  ] [/color] Navigation uplink established
[color=#4dd9ff][  OK  ] [/color] Debris scanner online
[color=#4dd9ff][  OK  ] [/color] Depot beacon located
[color=#4dd9ff][  OK  ] [/color] Life support nominal
[color=#4dd9ff][  OK  ] [/color] Memory integrity verified
[color=#4dd9ff][  OK  ] [/color] Kernel loaded
[color=#4dd9ff][  OK  ] [/color] Flight systems armed
[color=#4dd9ff][  OK  ] [/color] All systems nominal
[color=#4dd9ff][  OK  ] [/color] Awaiting pilot
"
const TRANSPARENT := 0.0
const OPAQUE := 1.0
const TITLE_FADE_TIME := 0.3
const SLAM_SHAKE_TIME := 0.3
const OUTRO_PANEL_SCALE := 0.9
const MSEC_PER_SECOND := 1000.0
const SECONDS_PER_MINUTE := 60

@export_group("Nodes")
@export var overlay : DitherVignette
@export var backpanel : PanelContainer
@export var tag : Label
@export var title : Label
@export var sub : Label
@export var score : Label
@export var flash : ColorRect
@export var overlow : RichTextLabel
@export var summary_lbl : Label
@export var backdrop : HangarBackdrop
@export var progress_bar : HangarProgressBar

@export_group("Look")
@export var accent : Color = MenuStyle.ACCENT
@export var shake_strength : float = 6.0
@export var quick_fade_in : float = 0.3
@export var allow_skip : bool = true
@export var skip_grace_time : float = 0.2

@export_group("Pacing")
@export var full_intro_runs : int = 1
@export var quick_speed_scale : float = 1.8

@export_group("Boot")
@export var black_hold : float = 0.08
@export var boot_time : float = 0.9
@export_range(0.0, 1.0) var boot_intensity_start : float = 0.05
@export_range(0.0, 1.0) var boot_intensity_end : float = 0.5
@export_range(0.0, 1.0) var boot_flicker_chance : float = 0.35
@export var boot_flicker_alpha : Vector2 = Vector2(0.6, 0.9)
@export var boot_flicker_interval : float = 0.07
@export var calm_boot_time : float = 0.7

@export_group("Reveal")
@export var power_on_fade : float = 0.7
@export var backdrop_fade_time : float = 0.25
@export_range(0.0, 1.0) var backdrop_text_alpha : float = 0.2
@export_range(0.0, 1.0) var backdrop_intensity : float = 0.25
@export var window_open_time : float = 0.5
@export var title_slam_time : float = 0.25
@export var title_start_scale : float = 1.15
@export var calm_title_start_scale : float = 1.05
@export var line_stagger : float = 0.1
@export var tag_fade_time : float = 0.15
@export var sub_type_time : float = 0.4
@export var score_fade_time : float = 0.15
@export var summary_type_time : float = 0.4
@export var hold_time : float = 0.45

@export_group("Outro")
@export var outro_time : float = 0.3

var _tween : Tween
var _shake_tween : Tween
var _calm : bool = false
var _quick : bool = false
var _outro_started : bool = false
var _started_msec : int = 0
var _last_flicker_step : int = -1

#region Playback

func _ready() -> void:
	resized.connect(_update_focal_point)
	_update_focal_point()

func _update_focal_point() -> void:
	if backdrop:
		backdrop.focal_point = size * 0.5

func _tint(color : Color) -> void:
	for node in find_children("*", "HangarPlate", true, false):
		(node as HangarPlate).accent_color = color

func play(run : int, quota : int) -> void:
	_calm = Settings.photosensitive()
	_quick = run > full_intro_runs
	_outro_started = false
	_last_flicker_step = -1
	_kill_tweens()
	position = Vector2.ZERO
	modulate.a = TRANSPARENT if _quick else OPAQUE
	show()
	_started_msec = Time.get_ticks_msec()

	overlay.tint = accent
	_set_intensity(boot_intensity_start if not _quick else TRANSPARENT)
	flash.color = Color(0.0, 0.0, 0.0, TRANSPARENT if _quick else OPAQUE)

	tag.text = "// RUN %02d //" % run
	tag.add_theme_color_override("font_color", accent)
	tag.modulate.a = TRANSPARENT
	title.text = "SYSTEMS ONLINE"
	title.modulate.a = TRANSPARENT
	title.add_theme_color_override("font_shadow_color", Color(accent, 0.55))
	_tint(accent)
	_update_focal_point()
	title.scale = Vector2.ONE * (calm_title_start_scale if _calm else title_start_scale)
	sub.text = "COLLECT DEBRIS - DELIVER TO THE DEPOT"
	sub.visible_ratio = TRANSPARENT
	score.text = "QUOTA  %d" % quota
	score.modulate.a = TRANSPARENT
	summary_lbl.text = _format_summary()
	summary_lbl.visible_ratio = TRANSPARENT
	overlow.text = BOOT_LOG
	overlow.visible_ratio = TRANSPARENT
	overlow.modulate.a = OPAQUE if not _quick else TRANSPARENT
	backpanel.scale = Vector2.ONE
	backpanel.modulate.a = TRANSPARENT
	progress_bar.value = OPAQUE if _quick else TRANSPARENT

	await get_tree().process_frame
	title.pivot_offset = Vector2(0.0, title.size.y / 2.0)
	backpanel.pivot_offset = backpanel.size / 2.0

	_tween = create_tween()
	if _quick:
		_tween.set_speed_scale(quick_speed_scale)
		_tween.tween_property(self, "modulate:a", OPAQUE, quick_fade_in)
	else:
		_tween.tween_interval(black_hold)
		# Fade up out of black while the boot log types itself.
		_tween.tween_property(flash, "color:a", TRANSPARENT, power_on_fade)
		_tween.parallel().tween_method(_boot, 0.0, 1.0, calm_boot_time if _calm else boot_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_callback(_boot_done)
	_build_reveal()

func _build_reveal() -> void:
	_tween.tween_property(overlow, "modulate:a", backdrop_text_alpha, backdrop_fade_time)
	_tween.parallel().tween_property(overlay, "intensity", backdrop_intensity, backdrop_fade_time)
	_tween.parallel().tween_property(backpanel, "modulate:a", OPAQUE, window_open_time)
	_tween.tween_callback(_slam)
	_tween.tween_property(title, "modulate:a", OPAQUE, TITLE_FADE_TIME)
	_tween.parallel().tween_property(title, "scale", Vector2.ONE, title_slam_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(tag, "modulate:a", OPAQUE, tag_fade_time).set_delay(line_stagger)
	_tween.parallel().tween_property(sub, "visible_ratio", OPAQUE, sub_type_time).set_delay(line_stagger * 2.0)
	_tween.parallel().tween_property(score, "modulate:a", OPAQUE, score_fade_time).set_delay(line_stagger * 3.0)
	_tween.parallel().tween_property(summary_lbl, "visible_ratio", OPAQUE, summary_type_time).set_delay(line_stagger * 4.0)
	_tween.tween_interval(hold_time)
	_tween.tween_callback(_outro)

func _boot(progress : float) -> void:
	progress_bar.value = progress
	overlow.visible_ratio = progress
	_set_intensity(lerpf(boot_intensity_start, boot_intensity_end, progress))

func _boot_done() -> void:
	progress_bar.value = OPAQUE
	overlow.visible_ratio = OPAQUE

func _slam() -> void:
	if not _calm:
		backdrop.trigger_pulse()

func _shake(strength_ratio : float) -> void:
	var amount := shake_strength * Settings.shake_scale() * strength_ratio
	position = Vector2(randf_range(-OPAQUE, OPAQUE), randf_range(-OPAQUE, OPAQUE)) * amount

func _outro() -> void:
	if _outro_started:
		return
	_outro_started = true
	if not DataCollector.is_world_ready:
		await DataCollector.world_ready
	_kill_tweens()
	position = Vector2.ZERO
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", TRANSPARENT, outro_time)
	_tween.tween_property(backpanel, "scale", Vector2.ONE * OUTRO_PANEL_SCALE, outro_time)
	_tween.tween_property(overlay, "intensity", TRANSPARENT, outro_time)
	await _tween.finished
	stop()
	sequence_finished.emit()

func stop() -> void:
	_kill_tweens()
	position = Vector2.ZERO
	modulate.a = OPAQUE
	hide()

#endregion

#region Skip

func _unhandled_input(event : InputEvent) -> void:
	if not allow_skip or not visible or _outro_started:
		return
	if not event.is_pressed() or event.is_echo():
		return
	if Time.get_ticks_msec() - _started_msec < skip_grace_time * MSEC_PER_SECOND:
		return
	_kill_tweens()
	_complete_text()
	_outro()
	get_viewport().set_input_as_handled()

func _complete_text() -> void:
	position = Vector2.ZERO
	flash.color.a = TRANSPARENT
	backpanel.modulate.a = OPAQUE
	progress_bar.value = OPAQUE
	title.scale = Vector2.ONE
	title.modulate.a = OPAQUE
	tag.modulate.a = OPAQUE
	sub.visible_ratio = OPAQUE
	score.modulate.a = OPAQUE
	summary_lbl.visible_ratio = OPAQUE
	overlow.visible_ratio = OPAQUE
	overlow.modulate.a = backdrop_text_alpha
	_set_intensity(backdrop_intensity)

#endregion

#region Helpers

func _kill_tweens() -> void:
	if _tween:
		_tween.kill()
	if _shake_tween:
		_shake_tween.kill()

func _set_intensity(value : float) -> void:
	overlay.intensity = value

@warning_ignore("integer_division")
func _format_summary() -> String:
	var lines : PackedStringArray = []

	if DataCollector.uses_timer():
		var total_seconds := int(DataCollector.time_limit)
		lines.append("TIME LIMIT  %d:%02d" % [total_seconds / SECONDS_PER_MINUTE, total_seconds % SECONDS_PER_MINUTE])

	if DataCollector.uses_fuel():
		var ship := DataCollector.player as Player
		if ship != null and is_instance_valid(ship):
			lines.append("FUEL  %d" % roundi(ship.stat_f(&"fuel_max")))

	lines.append("UPGRADES  %d" % DataCollector.upgrades_taken)

	return "\n".join(lines)

#endregion
