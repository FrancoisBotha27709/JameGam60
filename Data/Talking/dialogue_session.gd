class_name DialogueSession
extends RefCounted

const KEY_ID : String = "id"
const KEY_TITLE : String = "title"
const KEY_START : String = "start"
const KEY_NODES : String = "nodes"
const KEY_CHARACTER : String = "character"
const KEY_TEXT : String = "text"
const KEY_CHOICES : String = "choices"
const KEY_NEXT : String = "next"
const KEY_SAY : String = "say"
const KEY_RECORD : String = "record"
const KEY_NOTICE : String = "notice"
const KEY_NAME : String = "name"
const KEY_RANK : String = "rank"
const KEY_PORTRAIT : String = "portrait"

const KEY_LINE : String = "line"
const LINE_CHARACTER_ID : String = "character_id"
const LINE_NAME : String = "name"
const LINE_RANK : String = "rank"
const LINE_PORTRAIT : String = "portrait"
const LINE_TEXT : String = "text"
const LINE_IS_PLAYER : String = "is_player"

const PLAYER_CHARACTER_ID : String = "player"
const UNKNOWN_NAME : String = "UNKNOWN"
const UNKNOWN_RANK : String = "UNREGISTERED"

var discussion_id : String = ""
var title : String = ""
var state : DialogueState

var _nodes : Dictionary = {}
var _characters : Dictionary = {}
var _current_node_id : String = ""
var _finished : bool = true

#region Lifecycle
func begin(discussion_path : String, characters_path : String, dialogue_state : DialogueState) -> bool:
	state = dialogue_state
	var discussion := _read_json(discussion_path)
	_characters = _read_json(characters_path)
	_nodes = discussion.get(KEY_NODES, {})
	var start_node_id : String = str(discussion.get(KEY_START, ""))
	if not _nodes.has(start_node_id):
		push_error("DialogueSession: start node '%s' not found in '%s'." % [start_node_id, discussion_path])
		return false
	discussion_id = str(discussion.get(KEY_ID, discussion_path.get_file().get_basename()))
	title = str(discussion.get(KEY_TITLE, discussion_id))
	_finished = false
	_move_to(start_node_id)
	return true

func is_finished() -> bool:
	return _finished
#endregion

#region Reading the conversation
func get_current_line() -> Dictionary:
	var node := _get_current_node()
	return _build_line(str(node.get(KEY_CHARACTER, "")), str(node.get(KEY_TEXT, "")), false)

func has_choices() -> bool:
	return not _get_choices().is_empty()

func get_choice_labels() -> Array[String]:
	var labels : Array[String] = []
	for choice : Dictionary in _get_choices():
		labels.append(str(choice.get(KEY_TEXT, "")))
	return labels

func get_character(character_id : String) -> Dictionary:
	return _characters.get(character_id, {})
#endregion

#region Progressing
func choose(choice_index : int) -> Dictionary:
	var choices := _get_choices()
	if choice_index < 0 or choice_index >= choices.size():
		return {}
	var choice : Dictionary = choices[choice_index]
	var choice_text : String = str(choice.get(KEY_TEXT, ""))
	var next_node_id : String = str(choice.get(KEY_NEXT, ""))
	state.record_choice(discussion_id, _current_node_id, choice_index, choice_text, next_node_id)
	state.apply_record(choice.get(KEY_RECORD, {}))
	_move_to(next_node_id)
	state.commit()
	return {
		KEY_LINE: _build_line(PLAYER_CHARACTER_ID, str(choice.get(KEY_SAY, choice_text)), true),
		KEY_NOTICE: str(choice.get(KEY_NOTICE, "")),
	}

func advance() -> bool:
	if has_choices():
		return true
	var next_node_id : String = str(_get_current_node().get(KEY_NEXT, ""))
	if next_node_id.is_empty():
		_finish()
		return false
	_move_to(next_node_id)
	return not _finished
#endregion

#region Internal
func _move_to(node_id : String) -> void:
	if not _nodes.has(node_id):
		_finish()
		return
	_current_node_id = node_id
	state.mark_visited(discussion_id, node_id)
	state.apply_record(_get_current_node().get(KEY_RECORD, {}))

func _finish() -> void:
	_finished = true
	state.complete_discussion(discussion_id)
	state.commit()

func _get_current_node() -> Dictionary:
	return _nodes.get(_current_node_id, {})

func _get_choices() -> Array:
	return _get_current_node().get(KEY_CHOICES, [])

func _build_line(character_id : String, text : String, is_player : bool) -> Dictionary:
	var character := get_character(character_id)
	return {
		LINE_CHARACTER_ID: character_id,
		LINE_NAME: str(character.get(KEY_NAME, UNKNOWN_NAME)),
		LINE_RANK: str(character.get(KEY_RANK, UNKNOWN_RANK)),
		LINE_PORTRAIT: str(character.get(KEY_PORTRAIT, "")),
		LINE_TEXT: text,
		LINE_IS_PLAYER: is_player,
	}

func _read_json(path : String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DialogueSession: file not found '%s'." % path)
		return {}
	var parsed : Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("DialogueSession: '%s' is not a valid JSON object." % path)
		return {}
	return parsed
#endregion
