extends Control
class_name RunStartBanner

signal sequence_finished

const BOOT_LOG : String = "[color=green][  OK  ] [/color] Power rails stable
[color=green][  OK  ] [/color] Reactor core online
[color=green][  OK  ] [/color] Coolant loop primed
[color=yellow][ WARN ] [/color] Hull integrity: acceptable
[color=green][  OK  ] [/color] Thruster array calibrated
[color=green][  OK  ] [/color] Fuel lines pressurized
[color=green][  OK  ] [/color] Magnet coil charged
[color=green][  OK  ] [/color] Navigation uplink established
[color=green][  OK  ] [/color] Debris scanner online
[color=green][  OK  ] [/color] Depot beacon located
[color=green][  OK  ] [/color] Life support nominal
[color=green][  OK  ] [/color] Memory integrity verified
[color=green][  OK  ] [/color] Kernel loaded
[color=green][  OK  ] [/color] Flight systems armed
[color=green][  OK  ] [/color] All systems nominal
[color=green][  OK  ] [/color] Awaiting pilot
"

@export_group("Nodes")
@export var overlay : DitherVignette
@export var backpanel : Panel
@export var tag : Label
@export var title : Label
@export var sub : Label
@export var score : Label
@export var flash : ColorRect
@export var overlow : RichTextLabel
@export var summary_lbl : Label

@export_group("Look")
@export var accent : Color = Color(0.3, 1.0, 0.6)
@export var shake_strength : float = 6.0
@export var allow_skip : bool = true

@export_group("Phase 1 : Boot")
@export var black_hold : float = 0.25
@export var boot_time : float = 1.4
@export_range(0.0, 1.0) var boot_intensity_start : float = 0.05
@export_range(0.0, 1.0) var boot_intensity_end : float = 0.5
@export_range(0.0, 1.0) var boot_flicker_chance : float = 0.5
@export var boot_flicker_alpha : Vector2 = Vector2(0.3, 0.8)
@export var calm_boot_time : float = 1.0

@export_group("Phase 2 : Reveal")
@export var power_on_fade : float = 0.35
@export var backdrop_fade_time : float = 0.3
@export_range(0.0, 1.0) var backdrop_text_alpha : float = 0.2
@export_range(0.0, 1.0) var backdrop_intensity : float = 0.25
@export var window_open_time : float = 0.3
@export var title_slam_time : float = 0.3
@export var title_start_scale : float = 2.0
@export var calm_title_start_scale : float = 1.1
@export var tag_fade_time : float = 0.15
@export var sub_type_time : float = 0.6
@export var score_fade_time : float = 0.15
@export var summary_type_time : float = 0.7
@export var hold_time : float = 0.8

@export_group("Phase 3 : Outro")
@export var outro_time : float = 0.4

var _tween : Tween
var _calm : bool = false
var _outro_started : bool = false

func play(run : int, quota : int) -> void:
	_calm = Settings.photosensitive()
	_outro_started = false
	_kill_tweens()
	position = Vector2.ZERO
	modulate.a = 1.0
	show()

	overlay.tint = accent
	_set_intensity(0.0)
	flash.color = Color(0, 0, 0, 1)

	tag.text = "// RUN %02d //" % run
	tag.add_theme_color_override("font_color", accent)
	tag.modulate.a = 0.0
	title.text = "SYSTEMS ONLINE"
	title.add_theme_color_override("font_color", accent)
	title.modulate.a = 0.0
	title.scale = Vector2.ONE * (calm_title_start_scale if _calm else title_start_scale)
	sub.text = "COLLECT DEBRIS - DELIVER TO THE DEPOT"
	sub.visible_ratio = 0.0
	score.text = "QUOTA  %d" % quota
	score.modulate.a = 0.0
	summary_lbl.text = _format_summary()
	summary_lbl.visible_ratio = 0.0
	overlow.text = BOOT_LOG
	overlow.visible_ratio = 0.0
	overlow.modulate.a = 1.0
	backpanel.scale = Vector2.ZERO

	await get_tree().process_frame
	title.pivot_offset = title.size / 2.0
	backpanel.pivot_offset = backpanel.size / 2.0

	_tween = create_tween()
	_tween.tween_interval(black_hold)
	_tween.tween_method(_boot, 0.0, 1.0, calm_boot_time if _calm else boot_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_build_reveal()

func _build_reveal() -> void:
	_tween.tween_callback(_boot_done)
	_tween.tween_property(flash, "color:a", 0.0, power_on_fade)
	_tween.parallel().tween_property(overlow, "modulate:a", backdrop_text_alpha, backdrop_fade_time)
	_tween.parallel().tween_property(overlay, "intensity", backdrop_intensity, backdrop_fade_time)
	_tween.parallel().tween_property(backpanel, "scale", Vector2.ONE, window_open_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_slam)
	_tween.tween_property(title, "modulate:a", 1.0, 0.05)
	_tween.parallel().tween_property(title, "scale", Vector2.ONE, title_slam_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(tag, "modulate:a", 1.0, tag_fade_time)
	_tween.tween_property(sub, "visible_ratio", 1.0, sub_type_time)
	_tween.tween_property(score, "modulate:a", 1.0, score_fade_time)
	_tween.tween_property(summary_lbl, "visible_ratio", 1.0, summary_type_time)
	_tween.tween_interval(hold_time)
	_tween.tween_callback(_outro)

func _boot(t : float) -> void:
	overlow.visible_ratio = t
	_set_intensity(lerpf(boot_intensity_start, boot_intensity_end, t))
	if _calm:
		return
	# power flicker that settles as the boot completes
	overlow.modulate.a = 1.0 if randf() > (1.0 - t) * boot_flicker_chance \
		else randf_range(boot_flicker_alpha.x, boot_flicker_alpha.y)

func _boot_done() -> void:
	overlow.modulate.a = 1.0
	overlow.visible_ratio = 1.0

func _slam() -> void:
	if _calm:
		return
	var t := create_tween()
	t.tween_method(_shake, 1.0, 0.0, 0.3)

func _shake(s : float) -> void:
	var amt := shake_strength * Settings.shake_scale() * s
	position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amt

# Holds until the world has finished spawning, then closes the banner
func _outro() -> void:
	if _outro_started:
		return
	_outro_started = true
	if not DataCollector.is_world_ready:
		await DataCollector.world_ready
	_kill_tweens()
	position = Vector2.ZERO
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, outro_time)
	_tween.tween_property(backpanel, "scale", Vector2.ONE * 0.9, outro_time)
	_tween.tween_property(overlay, "intensity", 0.0, outro_time)
	await _tween.finished
	stop()
	sequence_finished.emit()

func _unhandled_input(event : InputEvent) -> void:
	if not allow_skip or not visible or _outro_started:
		return
	if event.is_pressed() and not event.is_echo():
		_kill_tweens()
		flash.color.a = 0.0
		_outro()
		get_viewport().set_input_as_handled()

func stop() -> void:
	_kill_tweens()
	position = Vector2.ZERO
	modulate.a = 1.0
	hide()

func _kill_tweens() -> void:
	if _tween:
		_tween.kill()

func _set_intensity(v : float) -> void:
	overlay.intensity = v

func _format_summary() -> String:
	var lines : PackedStringArray = []
	if DataCollector.uses_timer():
		var t := int(DataCollector.time_limit)
		lines.append("TIME LIMIT  %d:%02d" % [t / 60, t % 60])
	if DataCollector.uses_fuel() and is_instance_valid(DataCollector.player):
		lines.append("FUEL  %d" % roundi(DataCollector.player.fuel_max))
	lines.append("UPGRADES  %d" % DataCollector.upgrades_taken)
	return "\n".join(lines)