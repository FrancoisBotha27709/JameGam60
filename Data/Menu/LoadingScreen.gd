extends Control
class_name LoadingScreen

const FLAVOR : Array[String] = [
	"[color=green][  OK  ] [/color] Power rails stable",
	"[color=green][  OK  ] [/color] Reactor core online",
	"[color=green][  OK  ] [/color] Coolant loop primed",
	"[color=yellow][ WARN ] [/color] Hull integrity: acceptable",
	"[color=green][  OK  ] [/color] Thruster array calibrated",
	"[color=green][  OK  ] [/color] Magnet coil charged",
	"[color=green][  OK  ] [/color] Debris scanner online",
	"[color=green][  OK  ] [/color] Depot beacon located",
]

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
@export var progress : Label

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
@export var accent : Color = Color(0.3, 1.0, 0.6)
@export_range(0.0, 1.0) var intensity : float = 0.35

@export_group("Progress Bar")
@export var progress_character : String = ":"
@export var progress_empty_character : String = " "
@export var progress_padding : int = 2

var _paths : Array[String] = []
var _done : Dictionary = {}
var _lines : Array[String] = []
var _prog : Array = []
var _shown : float = 0.0
var _flavor_i : int = 0
var _t : float = 0.0
var _leaving : bool = false
var _warm_done : bool = false

func _ready() -> void:
	set_process(false)
	overlay.tint = accent
	overlay.intensity = intensity
	flash.color = Color.BLACK
	tag.text = "// BOOT //"
	title.text = "INITIALIZING"
	sub.text = "LOADING FLIGHT SYSTEMS"
	summary_lbl.text = ""
	for l in [tag, title]:
		l.add_theme_color_override("font_color", accent)
	backpanel.scale = Vector2.ZERO
	overlow.text = ""

	_paths.assign(preload_paths)
	_paths.append(next_scene)
	var tex_count := 0
	for folder in preload_folders:
		for f in _expand(folder):
			for p in _png_files(f):
				if not _paths.has(p):
					_paths.append(p)
					tex_count += 1
	for p in _paths:
		ResourceLoader.load_threaded_request(p)
	_warm_done = not warm_asteroids
	_log("[color=green][  OK  ] [/color] Boot sequence started")
	if tex_count > 0:
		_log("[color=green][  OK  ] [/color] Streaming %d textures" % tex_count)

	await get_tree().process_frame
	_update_progress_bar()
	backpanel.pivot_offset = backpanel.size / 2.0
	var t := create_tween().set_parallel(true)
	t.tween_property(flash, "color:a", 0.0, 0.3)
	t.tween_property(backpanel, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	set_process(true)

func _process(delta : float) -> void:
	if _leaving:
		return
	_t += delta

	if not _warm_done:
		_warm_done = AsteroidShapes.warm_step()
		if _warm_done:
			_log("[color=green][  OK  ] [/color] Asteroid field charted")

	var total := 0.0
	for p in _paths:
		if _done.has(p):
			total += 1.0
			continue
		match ResourceLoader.load_threaded_get_status(p, _prog):
			ResourceLoader.THREAD_LOAD_LOADED:
				_done[p] = true
				total += 1.0
				if p == next_scene or preload_paths.has(p):
					_log("[color=green][  OK  ] [/color] Loaded %s" % p.get_file())
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				total += float(_prog[0])
			_:
				_done[p] = true
				total += 1.0
				push_error("LoadingScreen: failed to load '%s'" % p)
				_log("[color=red][ ERROR ] [/color] Failed %s" % p.get_file())

	var res_frac := total / _paths.size()
	var target := res_frac
	if warm_asteroids:
		var warm_frac := 1.0 if _warm_done else 0.0
		target = 0.5 * res_frac + 0.5 * warm_frac if not _warm_done else 0.5 * res_frac + 0.5

	_shown = lerpf(_shown, target, 1.0 - exp(-progress_smooth * delta))
	if target >= 1.0 and _shown > 0.995:
		_shown = 1.0

	while _flavor_i < FLAVOR.size() and _shown >= float(_flavor_i + 1) / (FLAVOR.size() + 1):
		_log(FLAVOR[_flavor_i])
		_flavor_i += 1
	score.text = "LOADING  %d%%" % roundi(_shown * 100.0)
	_update_progress_bar()
	if _shown >= 1.0 and _t >= min_show_time:
		_finish()

func _update_progress_bar() -> void:
	var available_width := progress.size.x
	var font := progress.get_theme_font("font")
	var font_size := progress.get_theme_font_size("font_size")
	if font == null or available_width <= 0.0:
		return

	var char_width := font.get_string_size(progress_character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if char_width <= 0.0:
		return

	var max_chars := maxi(1, int(available_width / char_width) - progress_padding)
	var filled_chars := clampi(roundi(_shown * max_chars), 0, max_chars)
	progress.text = "〚" \
		+ progress_character.repeat(filled_chars) \
		+ progress_empty_character.repeat(max_chars - filled_chars) \
		+ "〛"

func _finish() -> void:
	_leaving = true
	var scene := ResourceLoader.load_threaded_get(next_scene) as PackedScene
	if scene == null:
		push_error("LoadingScreen: next_scene failed to load")
		return
	_log("[color=green][  OK  ] [/color] All systems nominal")
	var t := create_tween().set_parallel(true)
	t.tween_property(flash, "color:a", 1.0, fade_time)
	t.tween_property(backpanel, "scale", Vector2.ONE * 0.9, fade_time)
	t.tween_property(overlow, "modulate:a", 0.0, fade_time)
	t.tween_property(overlay, "intensity", 0.0, fade_time)
	await t.finished
	get_tree().change_scene_to_packed(scene)

func _log(line : String) -> void:
	_lines.append(line)
	overlow.text = "\n".join(_lines.slice(-max_lines))

func _expand(path : String) -> Array[String]:
	var out : Array[String] = []
	var star := path.find("*")
	if star == -1:
		out.append(path)
		return out
	var base := path.substr(0, star)
	var rest := path.substr(star + 1)
	var d := DirAccess.open(base)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_expand(base + sub + rest))
	return out

func _png_files(folder : String) -> Array[String]:
	var out : Array[String] = []
	var d := DirAccess.open(folder)
	if d == null:
		return out
	for file in d.get_files():
		var f := file.trim_suffix(".import")
		if f.get_extension().to_lower() == "png":
			var p := folder.path_join(f)
			if not out.has(p):
				out.append(p)
	return out