class_name AudioCatalog
extends RefCounted

const SOUND_DIRECTORY := "res://Assets/Sounds"
const EXTENSIONS := ["wav", "ogg", "mp3"]
const BUSES := ["SFX", "Music", "UI", "Voice"]
const DEFAULT_BUS := "SFX"
const MASTER_BUS := "Master"
const AUTO_BUS := "Auto"
const SILENCE_DB := -80.0
const PERCENT_SCALE := 100.0
const VARIATION_SUFFIX_PATTERN := "_?\\d+$"
const CACHE_LIFETIME_MSEC := 2000

## Starting volume per bus in percent. Edit these to retune the whole mix; unlisted buses use the fallback.
const BUS_DEFAULT_PERCENT := {
	"Master": 100.0,
	"SFX": 51.0,
	"Music": 50.0,
	"Thrust": 26.0,
	"UI": 30.0,
	"Voice": 60.0,
}
const FALLBACK_BUS_PERCENT := 30.0

static var _cached_names := PackedStringArray()
static var _cache_timestamp_msec := 0

# Maps each sound name to its file paths and the bus implied by its folder; numbered files become variations.
static func scan() -> Dictionary:
	var suffix_pattern := RegEx.new()
	suffix_pattern.compile(VARIATION_SUFFIX_PATTERN)
	var catalog := {}
	_scan_directory(SOUND_DIRECTORY, DEFAULT_BUS, bus_choices(), suffix_pattern, catalog)
	return catalog

# Lists buses a sound can target: the built-in ones plus any bus in the project's layout, optionally led by "Auto".
static func bus_choices(include_auto := false) -> PackedStringArray:
	var choices := PackedStringArray()
	if include_auto: choices.append(AUTO_BUS)
	choices.append_array(PackedStringArray(BUSES))
	for bus_index in AudioServer.bus_count:
		var bus_name := AudioServer.get_bus_name(bus_index)
		if bus_name != MASTER_BUS and bus_name not in choices: choices.append(bus_name)
	return choices

# Returns the sorted sound names, cached briefly so the editor inspector stays responsive.
static func sound_names() -> PackedStringArray:
	var now_msec := Time.get_ticks_msec()
	var cache_is_fresh := now_msec - _cache_timestamp_msec < CACHE_LIFETIME_MSEC
	if cache_is_fresh and not _cached_names.is_empty(): return _cached_names
	_cache_timestamp_msec = now_msec
	_cached_names = PackedStringArray(scan().keys())
	_cached_names.sort()
	return _cached_names

# Walks a folder tree; a subfolder named after a bus switches the automatic bus for everything inside it.
static func _scan_directory(directory_path : String, current_bus : String, known_buses : PackedStringArray, suffix_pattern : RegEx, catalog : Dictionary) -> void:
	for file_name in DirAccess.get_files_at(directory_path):
		var resource_name := file_name.trim_suffix(".import").trim_suffix(".remap")
		if resource_name.get_extension() not in EXTENSIONS: continue
		var sound_name := suffix_pattern.sub(resource_name.get_basename(), "")
		if not catalog.has(sound_name): catalog[sound_name] = {"paths": [], "bus": current_bus}
		var resource_path := directory_path.path_join(resource_name)
		if resource_path not in catalog[sound_name]["paths"]: catalog[sound_name]["paths"].append(resource_path)
	for folder_name in DirAccess.get_directories_at(directory_path):
		var folder_bus := folder_name if folder_name in known_buses else current_bus
		_scan_directory(directory_path.path_join(folder_name), folder_bus, known_buses, suffix_pattern, catalog)

# Returns the quiet starting volume (in percent) for a bus.
static func default_bus_percent(bus_name : String) -> float:
	return BUS_DEFAULT_PERCENT.get(bus_name, FALLBACK_BUS_PERCENT)

# Converts a 0-100 volume percent to decibels, treating zero as full silence.
static func percent_to_db(percent : float) -> float:
	return SILENCE_DB if percent <= 0.0 else linear_to_db(percent / PERCENT_SCALE)

# Turns a string property into a dropdown of the given choices; suggestions also allow typing or clearing the value.
static func apply_enum_hint(property : Dictionary, choices : PackedStringArray, suggestions_only := false) -> void:
	if choices.is_empty(): return
	property["hint"] = PROPERTY_HINT_ENUM_SUGGESTION if suggestions_only else PROPERTY_HINT_ENUM
	property["hint_string"] = ",".join(choices)

# Lists the sorted signal names an object can emit, for editor dropdowns and validation.
static func signal_names(emitter : Object) -> PackedStringArray:
	var names := PackedStringArray()
	if emitter == null: return names
	for signal_info in emitter.get_signal_list(): names.append(signal_info["name"])
	names.sort()
	return names

# Connects a signal, unbinding any arguments the callback does not accept; returns false when the signal is missing.
static func connect_ignoring_arguments(emitter : Object, signal_name : String, callback : Callable) -> bool:
	if emitter == null or not emitter.has_signal(signal_name): return false
	var argument_count := 0
	for signal_info in emitter.get_signal_list():
		if signal_info["name"] == signal_name: argument_count = signal_info["args"].size()
	emitter.connect(signal_name, callback if argument_count == 0 else callback.unbind(argument_count))
	return true


# Returns the host's world position for positional sounds, or null for non-positional ones.
static func play_position(host : Node, positional : bool) -> Variant:
	return host.global_position if positional and host is Node2D else null