
class_name TalkingScreen
extends Control

signal line_started
signal line_finished
signal character_started_talking
signal character_stopped_talking
signal player_started_talking
signal player_stopped_talking
signal advanced
signal choice_selected(index : int)
signal discussion_finished

enum Phase { IDLE, NPC_SPEAKING, PLAYER_SPEAKING }

const CHARACTERS_PER_SECOND : float = 45.0
const MINIMUM_TYPE_TIME : float = 0.2
const STAGE_FADE_TIME : float = 0.25
const HIDE_CHOICES_TIME : float = 0.2
const NOTICE_FADE_TIME : float = 0.3
const NOTICE_HOLD_TIME : float = 2.5
const DIMMED_STAGE_COLOR : Color = Color(0.45, 0.5, 0.6)
const RANK_PREFIX : String = "// "
const NOTICE_PREFIX : String = "// DATA LOGGED: "
const REVEAL_HIDDEN : float = 0.0
const REVEAL_SHOWN : float = 1.0
const TRANSPARENT : float = 0.0
const OPAQUE : float = 1.0
const FIRST_CHOICE_INDEX : int = 0

@export_group("Discussion")
@export_file("*.json") var discussion_path : String = "res://Data/Talking/discussions/depot_briefing.json"
@export_file("*.json") var characters_path : String = "res://Data/Talking/characters.json"
@export var auto_start : bool = true
@export var npc_portrait : Texture2D

@export_group("Nodes", "node_")
@export var node_backdrop : HangarBackdrop
@export var node_npc_stage : Control
@export var node_player_stage : Control
@export var node_npc_portrait : TextureRect
@export var node_ship : TextureRect
@export var node_header : HBoxContainer
@export var node_name_label : Label
@export var node_rank_label : Label
@export var player_node_name_label : Label
@export var player_node_rank_label : Label
@export var node_speech : RichTextLabel
@export var node_choices : VBoxContainer
@export var node_topic_label : Label
@export var node_notice_label : Label

var session : DialogueSession = DialogueSession.new()

var _characters_data : Dictionary = {}
var _current_voice : String = ""
var _audio : Node
var _voice_player : Node
var _choice_buttons : Array[HangarButton] = []
var _phase : Phase = Phase.IDLE
var _choices_open : bool = false
var _type_tween : Tween
var _fade_tween : Tween
var _choice_tween : Tween
var _notice_tween : Tween

#region Lifecycle
func _ready() -> void:
	_collect_choice_buttons()
	resized.connect(_update_focal_point)
	_update_focal_point()

	if npc_portrait != null:
		node_npc_portrait.texture = npc_portrait
	node_notice_label.modulate.a = TRANSPARENT
	_audio = get_node_or_null("/root/Audio")
	_load_characters()
	_load_player_portrait()
	for button_index in _choice_buttons.size():
		_choice_buttons[button_index].pressed.connect(_pick.bind(button_index))
	line_finished.connect(_on_line_finished)
	advanced.connect(_on_advanced)
	choice_selected.connect(_on_choice_selected)

	if auto_start:
		start_discussion()

func _collect_choice_buttons() -> void:
	for child in node_choices.get_children():
		var button := child as HangarButton
		if button != null:
			button.hide()
			_choice_buttons.append(button)

func _update_focal_point() -> void:
	node_backdrop.focal_point = size * 0.5

func _load_characters() -> void:
	if not FileAccess.file_exists(characters_path):
		return
	var parsed_data = JSON.parse_string(FileAccess.get_file_as_string(characters_path))
	if parsed_data is Dictionary:
		_characters_data = parsed_data
#endregion

#region Discussion flow
func start_discussion(path_override : String = "") -> bool:
	var path_to_load := discussion_path if path_override.is_empty() else path_override
	if not session.begin(path_to_load, characters_path, DialogueState.get_shared()):
		return false
	node_topic_label.text = session.title
	_show_current_line()
	return true

func _show_current_line() -> void:
	var line := session.get_current_line()
	var portrait_path : String = line[DialogueSession.LINE_PORTRAIT]
	if not portrait_path.is_empty():
		node_npc_portrait.texture = load(portrait_path) as Texture2D
	_phase = Phase.NPC_SPEAKING
	_speak_line(line)

func _speak_line(line : Dictionary) -> void:
	var speaker_name : String = line[DialogueSession.LINE_NAME]
	var speaker_is_player : bool = line[DialogueSession.LINE_IS_PLAYER]
	_current_voice = _get_voice(speaker_name, speaker_is_player)
	say(
		speaker_name,
		line[DialogueSession.LINE_RANK],
		line[DialogueSession.LINE_TEXT],
		speaker_is_player
	)

func _get_voice(speaker_name : String, speaker_is_player : bool) -> String:
	var character_data : Dictionary = {}
	if speaker_is_player:
		character_data = _characters_data.get("player", {})
	else:
		for character_id in _characters_data:
			var candidate_data : Dictionary = _characters_data[character_id]
			if candidate_data.get("name", "") == speaker_name:
				character_data = candidate_data
				break
	return character_data.get("voice", "")

func _finish_discussion() -> void:
	_stop_voice()
	_phase = Phase.IDLE
	discussion_finished.emit()

func _load_player_portrait() -> void:
	var player_data : Dictionary = _characters_data.get("player", {})
	var portrait_path : String = player_data.get("portrait", "")
	if not portrait_path.is_empty():
		node_ship.texture = load(portrait_path) as Texture2D

func _on_line_finished() -> void:
	if _phase == Phase.NPC_SPEAKING and session.has_choices():
		show_choices(session.get_choice_labels())

func _on_advanced() -> void:
	match _phase:
		Phase.NPC_SPEAKING:
			if session.has_choices():
				return
			if session.advance():
				_show_current_line()
			else:
				_finish_discussion()
		Phase.PLAYER_SPEAKING:
			if session.is_finished():
				_finish_discussion()
			else:
				_show_current_line()

func _on_choice_selected(index : int) -> void:
	var result := session.choose(index)
	if result.is_empty():
		return
	_phase = Phase.PLAYER_SPEAKING
	_speak_line(result[DialogueSession.KEY_LINE])
	var notice : String = result[DialogueSession.KEY_NOTICE]
	if not notice.is_empty():
		_show_notice(notice)
#endregion

#region Presentation
func say(speaker_name : String, rank_text : String, speech_text : String, speaker_is_player : bool = false) -> void:
	line_started.emit()
	if speaker_is_player:
		player_node_name_label.text = speaker_name
		player_node_rank_label.text = RANK_PREFIX + rank_text
		node_name_label.text = ""
		node_rank_label.text = ""
	else:
		node_name_label.text = speaker_name
		node_rank_label.text = RANK_PREFIX + rank_text
		player_node_name_label.text = ""
		player_node_rank_label.text = ""
	node_header.alignment = BoxContainer.ALIGNMENT_END if speaker_is_player else BoxContainer.ALIGNMENT_BEGIN
	node_speech.text = speech_text
	node_speech.visible_ratio = TRANSPARENT

	_fade_tween = MenuStyle.restart_tween(self, _fade_tween).set_parallel()
	_fade_tween.tween_property(node_npc_stage, "modulate", DIMMED_STAGE_COLOR if speaker_is_player else Color.WHITE, STAGE_FADE_TIME)
	_fade_tween.tween_property(node_player_stage, "modulate", Color.WHITE if speaker_is_player else DIMMED_STAGE_COLOR, STAGE_FADE_TIME)

	var type_time := maxf(node_speech.get_parsed_text().length() / CHARACTERS_PER_SECOND, MINIMUM_TYPE_TIME)
	_type_tween = MenuStyle.restart_tween(self, _type_tween)
	_type_tween.tween_property(node_speech, "visible_ratio", OPAQUE, type_time)
	_type_tween.finished.connect(_on_speech_finished.bind(speaker_is_player))

	_start_voice()

	if speaker_is_player:
		player_started_talking.emit()
	else:
		character_started_talking.emit()

	node_backdrop.trigger_pulse()

func _start_voice() -> void:
	if _audio == null or _current_voice.is_empty():
		return
	_stop_voice()
	_voice_player = _audio.loop(_current_voice, self, 0.0, 1.0, false)

func _stop_voice() -> void:
	if _audio == null or not is_instance_valid(_voice_player):
		_voice_player = null
		return
	_audio.stop_loop(_voice_player, 0.2)
	_voice_player = null

func show_choices(options : Array[String]) -> void:
	if options.is_empty():
		return
	_choices_open = true
	_choice_tween = MenuStyle.restart_tween(self, _choice_tween).set_parallel()
	for button_index in _choice_buttons.size():
		var button := _choice_buttons[button_index]
		button.visible = button_index < options.size()
		if not button.visible:
			continue
		button.text = options[button_index]
		button.set_reveal(REVEAL_HIDDEN)
		_choice_tween.tween_method(button.set_reveal, REVEAL_HIDDEN, REVEAL_SHOWN, MenuStyle.REVEAL_DURATION) \
			.set_delay(button_index * MenuStyle.REVEAL_STAGGER).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_choice_buttons[FIRST_CHOICE_INDEX].focus_button()

func hide_choices() -> void:
	_choices_open = false
	_choice_tween = MenuStyle.restart_tween(self, _choice_tween).set_parallel()
	for button in _choice_buttons:
		if button.visible:
			_choice_tween.tween_method(button.set_reveal, REVEAL_SHOWN, REVEAL_HIDDEN, HIDE_CHOICES_TIME)
	_choice_tween.chain().tween_callback(_hide_buttons)

func _hide_buttons() -> void:
	for button in _choice_buttons:
		button.hide()

func _show_notice(notice : String) -> void:
	node_notice_label.text = NOTICE_PREFIX + notice
	_notice_tween = MenuStyle.restart_tween(self, _notice_tween)
	_notice_tween.tween_property(node_notice_label, "modulate:a", OPAQUE, NOTICE_FADE_TIME)
	_notice_tween.tween_interval(NOTICE_HOLD_TIME)
	_notice_tween.tween_property(node_notice_label, "modulate:a", TRANSPARENT, NOTICE_FADE_TIME)

func _on_speech_finished(speaker_is_player : bool) -> void:
	_stop_voice()
	_current_voice = ""

	if speaker_is_player:
		player_stopped_talking.emit()
	else:
		character_stopped_talking.emit()
	line_finished.emit()

#endregion

#region Input
func _pick(index : int) -> void:
	if _choices_open:
		hide_choices()
		choice_selected.emit(index)

func _unhandled_input(event : InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	var is_click := mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	if not (is_click or event.is_action_pressed(&"ui_accept")):
		return
	if _type_tween != null and _type_tween.is_running():
		_type_tween.kill()
		node_speech.visible_ratio = OPAQUE
		_on_speech_finished(_phase == Phase.PLAYER_SPEAKING)
	elif not _choices_open:
		advanced.emit()
#endregion
