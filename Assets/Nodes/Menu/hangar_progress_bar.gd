class_name HangarProgressBar
extends HangarPlate

const FILL_ALPHA := 0.85
const FILL_MIN_VALUE := 0.002
const BREATH_SPEED := 2.5
const BREATH_DEPTH := 0.15
const EDGE_WIDTH := 3.0
const TICK_COUNT := 10
const TICK_ALPHA := 0.12
const SHINE_ALPHA := 0.25

@export_range(0.0, 1.0) var value : float = 0.0

var _glow_seconds : float = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5

func _process(delta: float) -> void:
	super._process(delta)
	_glow_seconds += delta

#region Drawing
func _draw_plate_content(plate_size: Vector2) -> void:
	if value > FILL_MIN_VALUE:
		_draw_fill(plate_size)
	_draw_ticks(plate_size)

func _draw_fill(plate_size: Vector2) -> void:
	var fill_edge := lerpf(slant, plate_size.x, value)
	var breathing := 0.5 + 0.5 * sin(_glow_seconds * BREATH_SPEED)
	draw_colored_polygon(PackedVector2Array([
		Vector2(slant, 0.0),
		Vector2(fill_edge, 0.0),
		Vector2(fill_edge - slant, plate_size.y),
		Vector2(0.0, plate_size.y),
	]), Color(accent_color, FILL_ALPHA - BREATH_DEPTH * breathing))
	if fill_edge > slant * 2.0 + SCAN_BAND_WIDTH:
		_draw_scan_band(fill_edge, plate_size.y, SHINE_ALPHA)
	draw_line(Vector2(fill_edge, 0.0), Vector2(fill_edge - slant, plate_size.y), MenuStyle.TEXT, EDGE_WIDTH)

func _draw_ticks(plate_size: Vector2) -> void:
	for tick_index in range(1, TICK_COUNT):
		var tick_x := lerpf(slant, plate_size.x, float(tick_index) / TICK_COUNT)
		draw_line(Vector2(tick_x, 0.0), Vector2(tick_x - slant, plate_size.y), Color(MenuStyle.TEXT, TICK_ALPHA), 1.0)
#endregion
