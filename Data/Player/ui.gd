extends Control
class_name UIContainer

@export_group("Nodes", "node_")
@export var node_debris_container : VBoxContainer
@export var node_score_lbl : Label
@export var node_timer_lbl : Label
@export var node_fuel_bar : ProgressBar
@export var node_heat_bar : ProgressBar
@export var node_speed_lbl : Label
@export var run_end_banner : RunEndBanner
@export var pixels_per_meter : float = 10.0
@export var debris_item_scene : PackedScene
@export_subgroup("Upgrades")
@export var node_continue_btn : Button
@export var upgrade_screen : UpgradeScreen

var _quota_met : bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SignalBus.time_updated.connect(_update_timer)
	SignalBus.score_updated.connect(_update_score)
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.run_finished.connect(_on_run_finished)
	SignalBus.update_fuel.connect(_update_fuel)
	SignalBus.update_heat.connect(_update_heat)
	node_continue_btn.hide()
	node_continue_btn.pressed.connect(_on_continue_pressed)
	node_fuel_bar.visible = DataCollector.uses_fuel()
	_update_score(0)
	_on_setting(&"show_speed", Settings.get_value("show_speed"))
	Settings.changed.connect(_on_setting)
	
func _on_setting(key : String, value : Variant) -> void:
	if key == "show_speed":
		node_speed_lbl.visible = value

func setup_fuel(max_fuel : float, current : float) -> void:
	node_fuel_bar.max_value = max_fuel
	node_fuel_bar.value = current

func _update_fuel(value : float) -> void:
	node_fuel_bar.value = value

func _update_heat(value : float, max_value : float) -> void:
	node_heat_bar.max_value = max_value
	node_heat_bar.value = value

func _update_timer(time_left : float) -> void:
	if not DataCollector.uses_timer():
		node_timer_lbl.text = "∞"
		return
	var total_seconds := ceili(time_left)
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	node_timer_lbl.text = "%d:%02d" % [minutes, seconds]


func _update_score(value : int) -> void:
	node_score_lbl.text = "Score: %d / %d" % [value, DataCollector.get_quota()]

func _on_run_started(_duration : float) -> void:
	# run_number has just increased, so the quota shown needs refreshing
	_update_score(0)

func _on_run_finished(final_score : int, breakdown : Dictionary, quota_met : bool) -> void:
	node_debris_container.modulate.a = 1.0
	_update_score(final_score)
	node_timer_lbl.text = "QUOTA MET" if quota_met else "QUOTA MISSED"

	for child in node_debris_container.get_children():
		child.queue_free()

	for tag_name in breakdown:
		var entry : Dictionary = breakdown[tag_name]
		if not entry.has("debris"):
			push_error("Breakdown entry '%s' has no debris: %s" % [tag_name, entry])
			continue
		var debris : Debris = entry["debris"]
		var item := debris_item_scene.instantiate() as DebrisUI
		if item == null:
			push_error("debris_item_scene root doesn't use the DebrisUI script")
			continue
		node_debris_container.add_child(item)
		item.set_data(debris, tag_name.capitalize(), entry["count"], entry["points"])

	if quota_met:
		node_continue_btn.hide()
		upgrade_screen.open()
		return

	# Failure: play the banner first, then reveal the breakdown and button
	node_continue_btn.hide()
	node_timer_lbl.hide()
	node_score_lbl.hide()
	node_debris_container.modulate.a = 0.0
	run_end_banner.play(DataCollector.end_reason, final_score, DataCollector.get_quota())
	await run_end_banner.sequence_finished

	node_continue_btn.text = "TRY AGAIN"
	node_continue_btn.show()
	node_continue_btn.grab_focus()
	create_tween().tween_property(node_debris_container, "modulate:a", 1.0, 0.4)

func _on_continue_pressed() -> void:
	run_end_banner.stop()
	get_tree().paused = false
	Engine.time_scale = 1.0
	DataCollector.reset_progress()
	get_tree().reload_current_scene()

func set_speed(pixels_per_sec : float) -> void:
	node_speed_lbl.text = "%d m/s" % roundi(pixels_per_sec / pixels_per_meter)