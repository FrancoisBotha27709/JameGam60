extends Control
class_name MeltdownScreen

@export_group("References")
@export var meltdown_timer_lbl : Label
@export var warning_background : DitherVignette

@export_group("Alarm")
@export_range(0.0, 1.0) var alarm_min_intensity := 0.15
@export_range(0.0, 1.0) var alarm_max_intensity := 0.8
@export var alarm_pulse_time := 0.4

var alarm_tween : Tween

func _ready() -> void:
	hide()

func show_screen() -> void:
	show()
	start_alarm()

func set_countdown(seconds_remaining : float) -> void:
	meltdown_timer_lbl.text = "%.1f" % maxf(seconds_remaining, 0.0)

func start_alarm() -> void:
	if not warning_background:
		return

	stop_alarm()
	warning_background.intensity = alarm_min_intensity

	alarm_tween = create_tween()
	alarm_tween.set_loops()

	alarm_tween.tween_property(
		warning_background,
		"intensity",
		alarm_max_intensity,
		alarm_pulse_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	alarm_tween.tween_property(
		warning_background,
		"intensity",
		alarm_min_intensity,
		alarm_pulse_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop_alarm() -> void:
	if alarm_tween and alarm_tween.is_running():
		alarm_tween.kill()

	alarm_tween = null