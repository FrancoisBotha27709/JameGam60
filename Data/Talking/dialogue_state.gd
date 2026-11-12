class_name DialogueState
extends RefCounted

const FORMAT_VERSION : int = 1
const DEFAULT_SAVE_PATH : String = "user://dialogue_state.json"
const JSON_INDENT : String = "\t"

const KEY_VERSION : String = "version"
const KEY_DISCUSSIONS : String = "discussions"
const KEY_FLAGS : String = "flags"
const KEY_FACTS : String = "facts"
const KEY_COUNTERS : String = "counters"
const KEY_VISITED_NODES : String = "visited_nodes"
const KEY_CHOICES : String = "choices"
const KEY_COMPLETED : String = "completed"
const KEY_NODE : String = "node"
const KEY_INDEX : String = "index"
const KEY_TEXT : String = "text"
const KEY_NEXT : String = "next"
const KEY_TIME : String = "time"

static var _shared : DialogueState

var data : Dictionary = {}
var autosave_path : String = DEFAULT_SAVE_PATH

func _init() -> void:
	reset()

#region Shared instance
static func get_shared() -> DialogueState:
	if _shared == null:
		_shared = DialogueState.new()
		_shared.load_from_file()
	return _shared
#endregion

#region Writing
func reset() -> void:
	data = {
		KEY_VERSION: FORMAT_VERSION,
		KEY_DISCUSSIONS: {},
		KEY_FLAGS: {},
		KEY_FACTS: {},
		KEY_COUNTERS: {},
	}

func mark_visited(discussion_id : String, node_id : String) -> void:
	var visited_nodes : Array = _get_discussion_entry(discussion_id)[KEY_VISITED_NODES]
	if not visited_nodes.has(node_id):
		visited_nodes.append(node_id)

func record_choice(discussion_id : String, node_id : String, choice_index : int, choice_text : String, next_node_id : String) -> void:
	var choice_history : Array = _get_discussion_entry(discussion_id)[KEY_CHOICES]
	choice_history.append({
		KEY_NODE: node_id,
		KEY_INDEX: choice_index,
		KEY_TEXT: choice_text,
		KEY_NEXT: next_node_id,
		KEY_TIME: Time.get_unix_time_from_system(),
	})

func complete_discussion(discussion_id : String) -> void:
	_get_discussion_entry(discussion_id)[KEY_COMPLETED] = true

func apply_record(record : Dictionary) -> void:
	var flags : Dictionary = data[KEY_FLAGS]
	var facts : Dictionary = data[KEY_FACTS]
	var counters : Dictionary = data[KEY_COUNTERS]
	flags.merge(record.get(KEY_FLAGS, {}), true)
	facts.merge(record.get(KEY_FACTS, {}), true)
	var counter_changes : Dictionary = record.get(KEY_COUNTERS, {})
	for counter_name : String in counter_changes:
		counters[counter_name] = get_counter(counter_name) + int(counter_changes[counter_name])

func commit() -> void:
	if not autosave_path.is_empty():
		save_to_file(autosave_path)
#endregion

#region Reading
func has_flag(flag_name : String) -> bool:
	return bool(data[KEY_FLAGS].get(flag_name, false))

func get_fact(fact_name : String, default_value : Variant = null) -> Variant:
	return data[KEY_FACTS].get(fact_name, default_value)

func get_counter(counter_name : String) -> int:
	return int(data[KEY_COUNTERS].get(counter_name, 0))

func is_discussion_completed(discussion_id : String) -> bool:
	return bool(_get_discussion_entry(discussion_id)[KEY_COMPLETED])

func get_choice_history(discussion_id : String) -> Array:
	return _get_discussion_entry(discussion_id)[KEY_CHOICES]
#endregion

#region Persistence
func save_to_file(path : String = DEFAULT_SAVE_PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, JSON_INDENT))
	return OK

func load_from_file(path : String = DEFAULT_SAVE_PATH) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var parsed : Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return ERR_PARSE_ERROR
	reset()
	for section_name : String in [KEY_DISCUSSIONS, KEY_FLAGS, KEY_FACTS, KEY_COUNTERS]:
		data[section_name].merge(parsed.get(section_name, {}), true)
	return OK
#endregion

#region Internal
func _get_discussion_entry(discussion_id : String) -> Dictionary:
	var discussions : Dictionary = data[KEY_DISCUSSIONS]
	if not discussions.has(discussion_id):
		discussions[discussion_id] = {
			KEY_VISITED_NODES: [],
			KEY_CHOICES: [],
			KEY_COMPLETED: false,
		}
	return discussions[discussion_id]
#endregion
