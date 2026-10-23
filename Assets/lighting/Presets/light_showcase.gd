extends Node2D
## Showcase of every preset in LightPreset.library().
## Requires the LightManager autoload. Put this script + the .tscn in res://lighting/
##
## Left click: flash    Right-drag / arrow keys: pan    Wheel: zoom    R: reset view
## 1 / 2 / 3: ambient dark / dim / bright    S: toggle sun
## Space (hold): engine boost    H (hold): overheat tint on engines

const COL_SPACING := 320.0
const ROW_SPACING := 340.0
## Big lights (star, depot...) are capped so they don't flood the neighbours.
const MAX_RADIUS := 280.0
const START_ZOOM := 0.45
const AMBIENTS := [Color(0.04, 0.05, 0.09), Color(0.18, 0.20, 0.30), Color(1, 1, 1)]

const GROUPS := [
	["ENGINES  (LightRig + engine markers)", ["engine_glow", "engine_ion", "engine_fire", "engine_plasma"]],
	["SHIP", ["cockpit", "headlight", "nav_red", "nav_green", "warning_strobe"]],
	["DEBRIS", ["beacon", "radioactive", "sparking", "ember", "crystal", "lamp"]],
	["WORLD  (one-shots re-fire every 2.5s)", ["star", "depot_glow", "explosion", "pickup_flash"]],
]

@onready var cam : Camera2D = $Camera2D
@onready var ui : CanvasLayer = $UI

var _labels : Array = []        # [Label, world_pos, centered]
var _engine_rigs : Array[LightRig] = []
var _oneshots : Array = []      # [LightPreset, parent tile]
var _spinners : Array[Node2D] = []
var _sun_on := false
var _t := 0.0
var _shot_t := 2.5


# Draws a lit "space dust" floor + stars + grid so light pools are easy to see.
class Backdrop extends Node2D:
	var area := Rect2()
	func _draw() -> void:
		draw_rect(area, Color(0.42, 0.44, 0.50))
		var grid := Color(0.30, 0.32, 0.38)
		var x := area.position.x
		while x <= area.end.x:
			draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), grid, 2.0)
			x += 160.0
		var y := area.position.y
		while y <= area.end.y:
			draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), grid, 2.0)
			y += 160.0
		var rng := RandomNumberGenerator.new()
		rng.seed = 12345
		for i in 900:
			var p := area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)
			draw_circle(p, rng.randf_range(1.0, 3.0), Color.WHITE)


func _ready() -> void:
	LightManager.max_shadow_lights = 24
	LightManager.set_ambient(AMBIENTS[0])
	_build_backdrop()
	_build_help()

	var lib := LightPreset.library()
	var origin_y := -(GROUPS.size() - 1) * ROW_SPACING * 0.5
	for r in GROUPS.size():
		var names : Array = GROUPS[r][1]
		var y := origin_y + r * ROW_SPACING
		var x0 := -(names.size() - 1) * COL_SPACING * 0.5
		_add_label(GROUPS[r][0], Vector2(x0 - 140.0, y - 170.0), false, 16)
		for i in names.size():
			var key : String = names[i]
			var p : LightPreset = lib[key].call()
			var pos := Vector2(x0 + i * COL_SPACING, y)
			var shown := p.duplicate() as LightPreset
			shown.radius = minf(p.radius, MAX_RADIUS)
			var note := "*" if p.radius > MAX_RADIUS else ""
			_add_label("%s\nr=%d%s  e=%.1f" % [key, p.radius, note, p.energy], pos + Vector2(0, 120))
			if r == 0:
				_build_ship(pos, shown)
			else:
				_build_tile(pos, shown)

func _exit_tree() -> void:
	LightManager.remove_sun()


# ---------------- Building ----------------

func _build_backdrop() -> void:
	var bg := Backdrop.new()
	bg.area = Rect2(-1300, -950, 2600, 1900)
	bg.z_index = -100
	add_child(bg)

func _build_help() -> void:
	var l := Label.new()
	l.text = "LIGHT SHOWCASE\n" \
		+ "Left click: flash    Right-drag / arrows: pan    Wheel: zoom    R: reset view\n" \
		+ "1/2/3: ambient dark/dim/bright    S: sun    Space: boost    H: overheat tint\n" \
		+ "* = radius capped for the showcase"
	l.position = Vector2(12, 8)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	ui.add_child(l)

func _add_label(text: String, pos: Vector2, center := true, font_size := 13) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(l)
	_labels.append([l, pos, center])

## Engines: a little ship with engine markers + LightRig, driven by a fake throttle.
func _build_ship(pos: Vector2, p: LightPreset) -> void:
	var ship := Node2D.new()
	ship.position = pos
	add_child(ship)
	var hull := PackedVector2Array([Vector2(0, -40), Vector2(24, 26), Vector2(0, 14), Vector2(-24, 26)])
	var body := Polygon2D.new()
	body.polygon = hull
	body.color = Color(0.75, 0.8, 0.9)
	ship.add_child(body)
	var shadow := Polygon2D.new()    # LightRig turns this into an occluder
	shadow.name = "shadow_polygon"
	shadow.polygon = hull
	ship.add_child(shadow)
	for side in [-1, 1]:
		var m := Marker2D.new()
		m.name = "engine_marker_%s" % ("left" if side < 0 else "right")
		m.position = Vector2(12 * side, 28)
		ship.add_child(m)
	var rig := LightRig.new()
	rig.engine_preset = p
	ship.add_child(rig)              # builds on ready, after the markers exist
	_engine_rigs.append(rig)

## Everything else: the light sits among a few rocks so you can see shadows.
func _build_tile(pos: Vector2, p: LightPreset) -> void:
	var tile := Node2D.new()
	tile.position = pos
	add_child(tile)
	for off in [Vector2(90, -30), Vector2(-75, 55), Vector2(55, 95)]:
		_add_rock(tile, off)
	p.cast_shadows = true
	p.shadow_range = p.radius * 0.7   # demo the shadow fade on every tile
	p.shadow_fade = 0.6
	if p.lifetime > 0.0:
		_oneshots.append([p, tile])
		return
	var parent : Node2D = tile
	if p.shape == LightPreset.Shape.CONE:   # spin cones so the sweep hits the rocks
		parent = Node2D.new()
		tile.add_child(parent)
		_spinners.append(parent)
	LightManager.spawn(p, Vector2.ZERO, parent)

func _add_rock(parent: Node2D, off: Vector2) -> void:
	var pts := PackedVector2Array([Vector2(-14, -22), Vector2(18, -16), Vector2(16, 20), Vector2(-18, 14)])
	var rock := Polygon2D.new()
	rock.polygon = pts
	rock.color = Color(0.6, 0.55, 0.5)
	rock.position = off
	var occ := LightOccluder2D.new()
	occ.occluder = OccluderPolygon2D.new()
	occ.occluder.polygon = pts
	rock.add_child(occ)
	parent.add_child(rock)


# ---------------- Runtime ----------------

func _process(delta: float) -> void:
	_t += delta

	var pan := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	cam.position += pan * 900.0 * delta / cam.zoom.x
	cam.force_update_scroll()

	var boost := Input.is_key_pressed(KEY_SPACE)
	var hot := 0.7 if Input.is_key_pressed(KEY_H) else 0.0
	for i in _engine_rigs.size():
		var level := 0.5 + 0.5 * sin(_t * 1.6 + i * 1.3)
		_engine_rigs[i].set_engine(level, boost)
		_engine_rigs[i].set_tint(Color(1.0, 0.45, 0.25), hot)

	for s in _spinners:
		s.rotation += delta * 0.9

	_shot_t += delta
	if _shot_t >= 2.5:
		_shot_t = 0.0
		for e in _oneshots:
			LightManager.spawn(e[0], Vector2.ZERO, e[1])

	var xf := get_viewport().get_canvas_transform()
	for e in _labels:
		var l : Label = e[0]
		l.position = xf * (e[1] as Vector2)
		if e[2]:
			l.position.x -= l.size.x * 0.5

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				LightManager.flash(get_global_mouse_position())
			MOUSE_BUTTON_WHEEL_UP:
				cam.zoom = (cam.zoom * 1.1).clamp(Vector2(0.15, 0.15), Vector2(2, 2))
			MOUSE_BUTTON_WHEEL_DOWN:
				cam.zoom = (cam.zoom / 1.1).clamp(Vector2(0.15, 0.15), Vector2(2, 2))
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		cam.position -= event.relative / cam.zoom.x
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: LightManager.set_ambient(AMBIENTS[0], 0.4)
			KEY_2: LightManager.set_ambient(AMBIENTS[1], 0.4)
			KEY_3: LightManager.set_ambient(AMBIENTS[2], 0.4)
			KEY_S:
				_sun_on = not _sun_on
				if _sun_on:
					LightManager.set_sun(30.0)
				else:
					LightManager.remove_sun()
			KEY_R:
				cam.position = Vector2.ZERO
				cam.zoom = Vector2(START_ZOOM, START_ZOOM)