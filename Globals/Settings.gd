extends Node

signal changed(key : String, value : Variant)

const PATH := "user://settings.cfg"
const RESOLUTIONS : Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const VSYNC := [DisplayServer.VSYNC_DISABLED, DisplayServer.VSYNC_ENABLED, DisplayServer.VSYNC_ADAPTIVE, DisplayServer.VSYNC_MAILBOX]
const MSAA := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]
const PARTICLE_SCALE := [0.35, 0.7, 1.0]
const QUOTA_GROWTH := [1.3, 1.5, 1.8]
enum CONTROLS {MOUSE, KEYBOARD}
const OPTIONS_SCENE := "res://Data/Menu/Options_menu.tscn"

const SCHEMA : Array[Dictionary] = [
	# Video
	{key = "window_mode", cat = "video", label = "Window Mode", type = "option", def = 0, opts = ["Windowed", "Fullscreen", "Borderless"]},
	{key = "resolution", cat = "video", label = "Resolution", type = "option", def = 2, opts = ["1280 x 720", "1600 x 900", "1920 x 1080", "2560 x 1440"], tip = "Windowed mode only"},
	{key = "vsync", cat = "video", label = "VSync", type = "option", def = 1, opts = ["Off", "On", "Adaptive", "Mailbox"]},
	{key = "max_fps", cat = "video", label = "FPS Limit", type = "slider", def = 0.0, lo = 0.0, hi = 240.0, step = 10.0, zero = "Unlimited"},
	{key = "ui_scale", cat = "video", label = "UI Scale", type = "slider", def = 1.0, lo = 0.75, hi = 1.5, step = 0.05, suffix = "x"},
	# Audio (needs buses named Master / Music / SFX; missing ones are skipped)
	{key = "master_volume", cat = "audio", label = "Master Volume", type = "slider", def = 80.0, lo = 0.0, hi = 100.0, step = 1.0, suffix = "%"},
	{key = "music_volume", cat = "audio", label = "Music Volume", type = "slider", def = 70.0, lo = 0.0, hi = 100.0, step = 1.0, suffix = "%"},
	{key = "sfx_volume", cat = "audio", label = "SFX Volume", type = "slider", def = 80.0, lo = 0.0, hi = 100.0, step = 1.0, suffix = "%"},
	{key = "mute_unfocused", cat = "audio", label = "Mute When Unfocused", type = "toggle", def = false},
	# Graphics
	{key = "msaa", cat = "graphics", label = "Anti-Aliasing (MSAA)", type = "option", def = 0, opts = ["Off", "2x", "4x", "8x"]},
	{key = "particle_quality", cat = "graphics", label = "Particle Quality", type = "option", def = 2, opts = ["Low", "Medium", "High"], tip = "Scale emitter amounts with Settings.particle_scale()"},
	{key = "show_fps", cat = "graphics", label = "Show FPS", type = "toggle", def = false},
	# Gameplay
	{key = "game_mode", cat = "gameplay", label = "Game Mode", type = "option", def = 0, opts = ["Timer + Fuel", "Timer Only", "Fuel Only", "Free Play"], tip = "Applies on the next run"},
	{key = "difficulty", cat = "gameplay", label = "Difficulty", type = "option", def = 1, opts = ["Easy", "Normal", "Hard"], tip = "How fast the quota grows"},
	{key = "screen_shake", cat = "gameplay", label = "Screen Shake", type = "slider", def = 100.0, lo = 0.0, hi = 100.0, step = 1.0, suffix = "%"},
	{key = "show_speed", cat = "gameplay", label = "Show Speedometer", type = "toggle", def = true},
	{key = "show_waypoint", cat = "gameplay", label = "Show Waypoint Marker", type = "toggle", def = true},
	{key = "photosensitive", cat = "gameplay", label = "Photosensitive Mode", type = "toggle", def = false, tip = "Reduces motion, flashing and strobing"},
	{key = "controls", cat = "gameplay", label = "Control Mode", type = "option", def = 0, opts = ["Mouse", "Keyboard"], tip = "Changes control scheme"},
]

var values : Dictionary = {}
var _defs : Dictionary = {}
var _dirty : bool = false
var _save_timer : Timer
var _fps_layer : CanvasLayer
var _fps_label : Label
var _options_layer : CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	for d in SCHEMA:
		_defs[d.key] = d

	_load()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.5
	_save_timer.timeout.connect(save)
	add_child(_save_timer)
	_apply_all.call_deferred()   # deferred so every autoload (DataCollector...) exists

func get_value(key : String) -> Variant:
	return values[key]

func get_def(key : String) -> Dictionary:
	return _defs[key]

func set_value(key : String, v : Variant) -> void:
	if not _defs.has(key):
		push_warning("Settings: unknown key '%s'" % key)
		return
	v = _sanitize(_defs[key], v)
	if values[key] == v:
		return
	values[key] = v
	_apply(key)
	changed.emit(key, v)
	_dirty = true
	_save_timer.start()   # debounced: dragging a slider writes once

func reset_category(cat : String) -> void:
	for d in SCHEMA:
		if d.cat == cat:
			set_value(d.key, d.def)

func reset_all() -> void:
	for d in SCHEMA:
		set_value(d.key, d.def)

func particle_scale() -> float:
	return PARTICLE_SCALE[values.particle_quality]

func photosensitive() -> bool:
	return values.photosensitive

func get_controls() -> CONTROLS:
	return values.controls

func shake_scale() -> float:
	var s : float = values.screen_shake / 100.0
	return s * 0.2 if values.photosensitive else s

func save() -> void:
	var cfg := ConfigFile.new()
	for d in SCHEMA:
		cfg.set_value(d.cat, d.key, values[d.key])
	cfg.save(PATH)
	_dirty = false

func _load() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)   # a missing file is fine, defaults are used
	for d in SCHEMA:
		values[d.key] = _sanitize(d, cfg.get_value(d.cat, d.key, d.def))

# Clamps anything read from disk so a hand-edited or old file can never break the game
func _sanitize(d : Dictionary, v : Variant) -> Variant:
	if not (v is int or v is float or v is bool):
		return d.def
	match d.type:
		"slider": return clampf(snappedf(float(v), d.step), d.lo, d.hi)
		"option": return clampi(int(v), 0, d.opts.size() - 1)
	return bool(v)

func _apply_all() -> void:
	for d in SCHEMA:
		_apply(d.key)

func _apply(key : String) -> void:
	var v = values[key]
	match key:
		"window_mode", "resolution": _apply_window()
		"vsync": DisplayServer.window_set_vsync_mode(VSYNC[v])
		"max_fps": Engine.max_fps = int(v)
		"ui_scale": get_window().content_scale_factor = v
		"master_volume": _set_bus("Master", v)
		"music_volume": _set_bus("Music", v)
		"sfx_volume": _set_bus("SFX", v)
		"msaa": get_viewport().msaa_2d = MSAA[v]
		"show_fps": _show_fps(v)
		"game_mode": DataCollector.game_mode = int(v)
		"difficulty": DataCollector.quota_growth = QUOTA_GROWTH[v]
		"controls" : get_controls()
	print(get_controls())
func _apply_window() -> void:
	match int(values.window_mode):
		1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)   # borderless
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var rect := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
			var size := RESOLUTIONS[values.resolution].min(rect.size)
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(rect.position + (rect.size - size) / 2)

func _set_bus(bus : String, percent : float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(percent / 100.0))
	AudioServer.set_bus_mute(i, percent <= 0.0)

func _show_fps(on : bool) -> void:
	if on and _fps_layer == null:
		_fps_layer = CanvasLayer.new()
		_fps_layer.layer = 100
		_fps_label = Label.new()
		_fps_label.position = Vector2(8.0, 4.0)
		_fps_layer.add_child(_fps_label)
		add_child(_fps_layer)
	if _fps_layer != null:
		_fps_layer.visible = on
	set_process(on)

func _process(_delta : float) -> void:
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()

func _notification(what : int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if values.get("mute_unfocused", false):
				AudioServer.set_bus_mute(0, true)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			AudioServer.set_bus_mute(0, values.get("master_volume", 100.0) <= 0.0)
		NOTIFICATION_WM_CLOSE_REQUEST:
			_flush()

func _exit_tree() -> void:
	_flush()   # also covers get_tree().quit() from a Quit button

func _flush() -> void:
	if _dirty:
		save()

func show_options() -> void:
	if _options_layer != null:
		return
	var scene := load(OPTIONS_SCENE) as PackedScene
	if scene == null:
		push_error("Settings: can't load %s" % OPTIONS_SCENE)
		return
	_options_layer = CanvasLayer.new()
	_options_layer.layer = 90
	_options_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_options_layer)
	var menu := scene.instantiate()   # untyped on purpose, avoids a circular class reference
	menu.close_requested.connect(hide_options)
	_options_layer.add_child(menu)

func hide_options() -> void:
	if _options_layer != null:
		_options_layer.queue_free()
		_options_layer = null