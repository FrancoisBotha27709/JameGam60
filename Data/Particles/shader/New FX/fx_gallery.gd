extends Node2D
## Attach to an empty Node2D and run the scene. Shows every preset in a grid so you can
## judge / tune them side by side. Click or press Space to replay everything.
## Mouse wheel = pixel_scale (chunk size) for all effects.

@export var columns : int = 4
@export var cell_size : Vector2 = Vector2(300, 260)
@export var replay_interval : float = 3.0   # one-shot effects re-trigger on this timer (0 = off)
@export var pixel_scale : float = 1.0

var _fx : Array[FXPlayer] = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.07, 0.07, 0.1))
	var names := FXPresets.names()
	var rows := ceili(names.size() / float(columns))

	for i in names.size():
		var col := i % columns
		var row := floori(i / float(columns))
		var center := Vector2((col + 0.5) * cell_size.x, (row + 0.5) * cell_size.y)

		var fx := FXPlayer.new()
		fx.preset = names[i]
		fx.pixel_scale = pixel_scale
		fx.position = center + Vector2(0, 15)
		add_child(fx)
		_fx.append(fx)

		var label := Label.new()
		label.text = names[i]
		label.position = center + Vector2(-cell_size.x * 0.5 + 8, cell_size.y * 0.5 - 26)
		label.modulate = Color(1, 1, 1, 0.6)
		add_child(label)

	var cam := Camera2D.new()
	cam.position = Vector2(columns * cell_size.x, rows * cell_size.y) * 0.5
	add_child(cam)
	var view := get_viewport_rect().size
	var fit := minf(view.x / (columns * cell_size.x), view.y / (rows * cell_size.y)) * 0.95
	cam.zoom = Vector2(fit, fit)

	if replay_interval > 0.0:
		var timer := Timer.new()
		timer.wait_time = replay_interval
		timer.autostart = true
		timer.timeout.connect(_replay_one_shots)
		add_child(timer)


func _replay_one_shots() -> void:
	for fx in _fx:
		if fx.is_one_shot():
			fx.play()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			for fx in _fx:
				fx.play()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			pixel_scale = clampf(pixel_scale + (0.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.25), 0.0, 8.0)
			for fx in _fx:
				fx.pixel_scale = pixel_scale
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		for fx in _fx:
			fx.play()