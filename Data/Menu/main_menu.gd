extends Control
class_name MainMenu

@export var game_path : PackedScene
@export_group("Buttons")
@export var play_btn : Button
@export var options_btn : Button
@export var quit_btn : Button
@export var tutorial_btn : Button   # new button in your menu, assign in the inspector
func _ready() -> void:
	play_btn.pressed.connect(_on_play_btn_pressed)
	options_btn.pressed.connect(_on_options_btn_pressed)
	quit_btn.pressed.connect(_on_quit_btn_pressed)
	tutorial_btn.pressed.connect(_show_tutorial)

func _show_tutorial() -> void:
	if get_node_or_null("TutorialPopup") != null:
		return   # already open
	var popup := TutorialPopup.new()
	popup.name = "TutorialPopup"
	add_child(popup)

func _on_play_btn_pressed() -> void:
	get_tree().change_scene_to_packed(game_path)

func _on_options_btn_pressed() -> void:
	Settings.show_options()

func _on_quit_btn_pressed() -> void:
	get_tree().quit()
