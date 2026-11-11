extends Control
class_name BootupScreen

const MAIN_MENU_PATH := "res://Data/Menu/main_menu.tscn"

@export_group("Loading")
@export var progress_bar: HangarProgressBar
@export var percent_label: Label
@export var overlay: DitherVignette
@export var backdrop: HangarBackdrop
@export var smooth_progress: bool = true
@export var progress_speed: float = 3.0

@export_group("Bootup Sequence")
@export var wait_for_sequence: bool = true
@export var information_label: RichTextLabel

@export_group("Information Animation")
## BBCode intro: an inline logo image followed by the Made with Godot text. Keep the image path valid in your project.
@export_multiline var godot_intro_text: String = "[center][img=48x48]res://icon.svg[/img]  Made with [b]Godot[/b][/center]"
@export var intro_display_time: float = 1.4
@export var section_cooldown: float = 0.65
@export_range(1.0, 100.0, 1.0) var typing_speed: float = 32.0 ## Characters revealed per second.
@export_range(1.0, 150.0, 1.0) var deleting_speed: float = 55.0 ## Characters erased per second.
## Add, remove, or reorder dictionaries here. Each section needs a "text" and can have a "duration".
@export var credit_sections: Array[Dictionary] = [
	{"text": "[color=#4dd9ff][b]DESIGN & DEVELOPMENT[/b][/color]\nYour Name", "duration": 2.5},
	{"text": "[color=#4dd9ff][b]SPECIAL THANKS[/b][/color]\nEveryone who supported the project", "duration": 2.5}
]

var _menu_loaded: bool = false
var _sequence_finished: bool = false
var _loading_started: bool = false
var _switching: bool = false
var _information_sequence_started: bool = false

var _main_menu_scene: PackedScene
var _target_progress: float = 0.0

func _ready() -> void:
	overlay.tint = MenuStyle.ACCENT
	overlay.intensity = 0.35
	resized.connect(_update_focal_point)
	_update_focal_point()
	_start_loading()
	_start_information_sequence()

func _process(delta: float) -> void:
	if not _loading_started:
		return
	_update_loading_progress(delta)
	if percent_label != null and progress_bar != null:
		percent_label.text = "LOADING  %d%%" % roundi(progress_bar.value * 100.0)

func _update_focal_point() -> void:
	if backdrop != null:
		backdrop.focal_point = size * 0.5

func _start_loading() -> void:
	if _loading_started:
		return

	_loading_started = true
	var error := ResourceLoader.load_threaded_request(MAIN_MENU_PATH, "PackedScene")
	if error != OK:
		push_error("BootupScreen: Failed to start loading Main Menu.")

func _update_loading_progress(delta: float) -> void:
	if _menu_loaded:
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(MAIN_MENU_PATH, progress)

	if not progress.is_empty():
		_target_progress = progress[0] * 100.0
		if progress_bar != null:
			if smooth_progress:
				progress_bar.value = move_toward(progress_bar.value, progress[0], progress_speed * delta)
			else:
				progress_bar.value = progress[0]

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_main_menu_scene = ResourceLoader.load_threaded_get(MAIN_MENU_PATH) as PackedScene
			_menu_loaded = _main_menu_scene != null
			if _menu_loaded:
				_target_progress = 100.0
				if progress_bar != null:
					progress_bar.value = 1.0
				_try_finish()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("BootupScreen: Main Menu failed to load.")


func _input(event: InputEvent) -> void:
	if not _menu_loaded or _sequence_finished:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		finish_sequence()


func _start_information_sequence() -> void:
	if _information_sequence_started:
		return
	_information_sequence_started = true
	_run_information_sequence()


func _run_information_sequence() -> void:
	if information_label == null:
		finish_sequence()
		return

	information_label.bbcode_enabled = true
	information_label.visible = true
	information_label.text = ""
	information_label.visible_characters = 0

	var intro_completed := await _play_typed_message(godot_intro_text, intro_display_time)
	if not intro_completed:
		return

	if section_cooldown > 0.0:
		await get_tree().create_timer(section_cooldown).timeout
		if _sequence_finished or not is_inside_tree():
			return

	for section: Dictionary in credit_sections:
		var section_text := str(section.get("text", ""))
		if section_text.is_empty():
			continue
		var display_time := maxf(float(section.get("duration", 2.5)), 0.0)
		var section_completed := await _play_typed_message(section_text, display_time)
		if not section_completed:
			return
		if section_cooldown > 0.0:
			await get_tree().create_timer(section_cooldown).timeout
			if _sequence_finished or not is_inside_tree():
				return

	information_label.visible = false
	finish_sequence()


## Types a message in, holds it, then erases it character by character.
func _play_typed_message(message: String, display_time: float) -> bool:
	if _sequence_finished or not is_inside_tree():
		return false

	information_label.text = message
	information_label.visible = true
	information_label.visible_characters = 0
	await get_tree().process_frame
	if _sequence_finished or not is_inside_tree():
		return false

	var character_count := information_label.get_total_character_count()
	if character_count > 0:
		var type_duration := float(character_count) / maxf(typing_speed, 1.0)
		var type_tween := create_tween()
		type_tween.tween_method(_set_visible_characters, 0, character_count, type_duration)
		await type_tween.finished
		if _sequence_finished or not is_inside_tree():
			return false

	if display_time > 0.0:
		await get_tree().create_timer(display_time).timeout
		if _sequence_finished or not is_inside_tree():
			return false

	if character_count > 0:
		var delete_duration := float(character_count) / maxf(deleting_speed, 1.0)
		var delete_tween := create_tween()
		delete_tween.tween_method(_set_visible_characters, character_count, 0, delete_duration)
		await delete_tween.finished
		if _sequence_finished or not is_inside_tree():
			return false

	information_label.text = ""
	return true


func _set_visible_characters(count: int) -> void:
	if is_instance_valid(information_label):
		information_label.visible_characters = count


## Call this when the bootup animation finishes, or to skip it after loading is complete.
func finish_sequence() -> void:
	if _sequence_finished:
		return
	_sequence_finished = true
	_try_finish()


## Allows you to restart the bootup sequence's waiting state.
func reset_sequence() -> void:
	_sequence_finished = false


func _try_finish() -> void:
	if _switching or not _menu_loaded:
		return
	if wait_for_sequence and not _sequence_finished:
		return
	_switching = true
	get_tree().change_scene_to_packed(_main_menu_scene)


## Returns loading progress from 0.0 to 100.0.
func get_loading_progress() -> float:
	return _target_progress


## Returns whether the main menu has finished loading.
func is_menu_loaded() -> bool:
	return _menu_loaded


## Returns whether the bootup sequence has finished.
func is_sequence_finished() -> bool:
	return _sequence_finished
