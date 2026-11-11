class_name LoadingScreen
extends BaseMenu

enum LogStatus { OK, WARN, ERROR }

const STATUS_LABELS := {LogStatus.OK: "  OK  ", LogStatus.WARN: " WARN ", LogStatus.ERROR: " ERROR "}
const STATUS_COLORS := {LogStatus.OK: MenuStyle.ACCENT, LogStatus.WARN: MenuStyle.WARNING, LogStatus.ERROR: MenuStyle.DANGER}
const FLAVOR_LINES := [
	[LogStatus.OK, "Power rails stable"],
	[LogStatus.OK, "Reactor core online"],
	[LogStatus.OK, "Coolant loop primed"],
	[LogStatus.WARN, "Hull integrity: acceptable"],
	[LogStatus.OK, "Thruster array calibrated"],
	[LogStatus.OK, "Magnet coil charged"],
	[LogStatus.OK, "Debris scanner online"],
	[LogStatus.OK, "Depot beacon located"],
]
const ASTEROID_WARM_WEIGHT := 0.5
const COMPLETE_SNAP_THRESHOLD := 0.995
const SCORE_FORMAT := "LOADING  %d%%"
const PUNCH_RISE_DURATION := 0.12
const PUNCH_SETTLE_DURATION := 0.25

@export_group("Scene Nodes")
@export_subgroup("Backdrop")
@export var backdrop : HangarBackdrop
@export var overlay : DitherVignette
@export var flash : ColorRect
@export_subgroup("Header")
@export var tag_label : Label
@export var title_label : Label
@export var subtitle_label : Label
@export var score_label : Label
@export_subgroup("Feed")
@export var log_label : RichTextLabel
@export var progress_bar : HangarProgressBar

@export_group("Loading")
@export_file("*.tscn") var next_scene : String = "res://Data/main.gd"
@export var preload_paths : Array[String] = []
@export var preload_folders : Array[String] = [
	"res://Assets/UI/SpaceBackground/*/background/",
	"res://Assets/UI/SpaceBackground/*/mist/",
	"res://Assets/UI/SpaceBackground/*/galaxies/",
	"res://Assets/UI/SpaceBackground/*/planets/",
	"res://Assets/UI/SpaceBackground/*/stars/",
]
@export var warm_asteroids : bool = true
@export var min_show_time : float = 0.6
@export var progress_smooth : float = 10.0
@export var fade_time : float = 0.25
@export var max_lines : int = 20

@export_group("Ambient")
@export_range(0.0, 1.0) var overlay_intensity : float = 0.35
@export_range(0.2, 0.8) var focal_height_ratio : float = 0.5

@export_group("Progress Bar")
@export var complete_punch_scale : float = 1.08

var _paths : Array[String] = []
var _loaded_paths : Dictionary = {}
var _lines : Array[String] = []
var _progress_report : Array = []
var _shown_fraction : float = 0.0
var _flavor_index : int = 0
var _elapsed_seconds : float = 0.0
var _is_open : bool = false
var _is_leaving : bool = false
var _warm_done : bool = false

#region Lifecycle
func _ready() -> void:
	overlay.tint = MenuStyle.ACCENT
	overlay.intensity = overlay_intensity
	resized.connect(_update_focal_point)
	opened.connect(_on_opened)
	_update_focal_point()
	_begin_loading()
	_fade_in_from_black()
	super._ready()

func _process(delta: float) -> void:
	if _is_leaving:
		return
	_elapsed_seconds += delta
	_advance_warmup()

	var target_fraction := _get_target_fraction()
	_shown_fraction = lerpf(_shown_fraction, target_fraction, 1.0 - exp(-progress_smooth * delta))
	if target_fraction >= 1.0 and _shown_fraction > COMPLETE_SNAP_THRESHOLD:
		_shown_fraction = 1.0

	_log_flavor_lines()
	score_label.text = SCORE_FORMAT % roundi(_shown_fraction * 100.0)
	progress_bar.value = _shown_fraction
	if _shown_fraction >= 1.0 and _elapsed_seconds >= min_show_time and _is_open:
		_finish()

func _on_opened() -> void:
	_is_open = true

func _update_focal_point() -> void:
	backdrop.focal_point = Vector2(size.x * 0.5, size.y * focal_height_ratio)

func _fade_in_from_black() -> void:
	create_tween().tween_property(flash, "color:a", 0.0, fade_time)
#endregion

#region Loading
func _begin_loading() -> void:
	_paths.assign(preload_paths)
	_paths.append(next_scene)
	var texture_paths := _find_texture_paths()
	_paths.append_array(texture_paths)
	for path in _paths:
		ResourceLoader.load_threaded_request(path)

	_warm_done = not warm_asteroids
	_log_status(LogStatus.OK, "Boot sequence started")
	if not texture_paths.is_empty():
		_log_status(LogStatus.OK, "Streaming %d textures" % texture_paths.size())

func _advance_warmup() -> void:
	if _warm_done:
		return
	_warm_done = AsteroidShapes.warm_step()
	if _warm_done:
		_log_status(LogStatus.OK, "Asteroid field charted")

# Resource loading and asteroid warm-up share the bar; warm-up only counts when enabled.
func _get_target_fraction() -> float:
	var loaded_total := 0.0
	for path in _paths:
		loaded_total += _poll_path(path)
	var resource_fraction := loaded_total / _paths.size()
	if not warm_asteroids:
		return resource_fraction
	return lerpf(resource_fraction, 1.0 if _warm_done else 0.0, ASTEROID_WARM_WEIGHT)

func _poll_path(path: String) -> float:
	if _loaded_paths.has(path):
		return 1.0
	match ResourceLoader.load_threaded_get_status(path, _progress_report):
		ResourceLoader.THREAD_LOAD_LOADED:
			_loaded_paths[path] = true
			if path == next_scene or preload_paths.has(path):
				_log_status(LogStatus.OK, "Loaded %s" % path.get_file())
			return 1.0
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return float(_progress_report[0])
	_loaded_paths[path] = true
	_log_status(LogStatus.ERROR, "Failed %s" % path.get_file())
	return 1.0

func _finish() -> void:
	_is_leaving = true
	var next_packed := ResourceLoader.load_threaded_get(next_scene) as PackedScene
	if next_packed == null:
		_log_status(LogStatus.ERROR, "Could not start %s" % next_scene.get_file())
		return
	_log_status(LogStatus.OK, "All systems nominal")
	backdrop.trigger_pulse()
	await _punch_progress_bar()
	await close()
	get_tree().change_scene_to_packed(next_packed)

func _punch_progress_bar() -> void:
	var punch_tween := create_tween()
	punch_tween.tween_property(progress_bar, "scale", Vector2.ONE * complete_punch_scale, PUNCH_RISE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch_tween.tween_property(progress_bar, "scale", Vector2.ONE, PUNCH_SETTLE_DURATION).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await punch_tween.finished
#endregion

#region Log feed
func _log_flavor_lines() -> void:
	while _flavor_index < FLAVOR_LINES.size() and _shown_fraction >= float(_flavor_index + 1) / (FLAVOR_LINES.size() + 1):
		var flavor_line : Array = FLAVOR_LINES[_flavor_index]
		_log_status(flavor_line[0], flavor_line[1])
		_flavor_index += 1

func _log_status(status: LogStatus, message: String) -> void:
	var tag_color : Color = STATUS_COLORS[status]
	_lines.append("[color=#%s][%s][/color] %s" % [tag_color.to_html(false), STATUS_LABELS[status], message])
	log_label.text = "\n".join(_lines.slice(-max_lines))
#endregion

#region Texture discovery
func _find_texture_paths() -> Array[String]:
	var texture_paths : Array[String] = []
	for folder in preload_folders:
		for expanded_folder in _expand_wildcards(folder):
			for texture_path in _list_pngs(expanded_folder):
				if not _paths.has(texture_path) and not texture_paths.has(texture_path):
					texture_paths.append(texture_path)
	return texture_paths

# Expands each "*" in a path into every matching sub-folder.
func _expand_wildcards(path: String) -> Array[String]:
	var expanded_paths : Array[String] = []
	var wildcard_index := path.find("*")
	if wildcard_index == -1:
		expanded_paths.append(path)
		return expanded_paths
	var base_path := path.substr(0, wildcard_index)
	var remaining_path := path.substr(wildcard_index + 1)
	var directory := DirAccess.open(base_path)
	if directory == null:
		return expanded_paths
	for sub_folder in directory.get_directories():
		expanded_paths.append_array(_expand_wildcards(base_path + sub_folder + remaining_path))
	return expanded_paths

func _list_pngs(folder: String) -> Array[String]:
	var png_paths : Array[String] = []
	var directory := DirAccess.open(folder)
	if directory == null:
		return png_paths
	for file_name in directory.get_files():
		var source_name := file_name.trim_suffix(".import")
		var png_path := folder.path_join(source_name)
		if source_name.get_extension().to_lower() == "png" and not png_paths.has(png_path):
			png_paths.append(png_path)
	return png_paths
#endregion
