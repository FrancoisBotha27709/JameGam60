extends Node2D
## Attach to any node in a test scene to see everything working.

func _ready() -> void:
	$Camera2D.position = Vector2(500, 250)
	LightManager.set_ambient(Color(0.03, 0.04, 0.08))
	LightManager.set_sun(30.0)

	LightManager.spawn(LightPreset.beacon(), Vector2(400, 200))

	var p := LightPreset.new()
	p.color = Color(0.4, 1.0, 0.5)
	p.radius = 220.0
	p.pulse = 0.5
	p.cast_shadows = true
	LightManager.spawn(p, Vector2(600, 300))

	for pos in [Vector2(350, 200), Vector2(700, 300), Vector2(520, 380), Vector2(450, 120)]:
		_make_rock(pos)

func _make_rock(pos: Vector2) -> void:
	var pts := PackedVector2Array([Vector2(-30, -10), Vector2(-10, -35), Vector2(25, -25),
		Vector2(35, 10), Vector2(5, 35), Vector2(-25, 25)])
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = Color(0.6, 0.55, 0.5)
	poly.position = pos
	var occ := LightOccluder2D.new()
	occ.occluder = OccluderPolygon2D.new()
	occ.occluder.polygon = pts
	poly.add_child(occ)
	add_child(poly)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		LightManager.flash(get_global_mouse_position())  # click = explosion flash