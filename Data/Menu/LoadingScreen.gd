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
@export var min_show_time : float = 1.2
@export var progress_speed : float = 1.2
@export var fade_time : float = 0.4
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
	for p in _paths:
		ResourceLoader.load_threaded_request(p)
	_log("[color=green][  OK  ] [/color] Boot sequence started")

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
	var total := 0.0
	for p in _paths:
		if _done.has(p):
			total += 1.0
			continue
		match ResourceLoader.load_threaded_get_status(p, _prog):
			ResourceLoader.THREAD_LOAD_LOADED:
				_done[p] = true
				total += 1.0
				_log("[color=green][  OK  ] [/color] Loaded %s" % p.get_file())
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				total += float(_prog[0])
			_:
				_done[p] = true
				total += 1.0
				push_error("LoadingScreen: failed to load '%s'" % p)
				_log("[color=red][ ERROR ] [/color] Failed %s" % p.get_file())

	_shown = move_toward(_shown, total / _paths.size(), progress_speed * delta)
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

	var filled_chars := roundi(_shown * max_chars)
	filled_chars = clampi(filled_chars, 0, max_chars)

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
