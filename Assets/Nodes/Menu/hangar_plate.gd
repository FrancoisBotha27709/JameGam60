class_name HangarPlate
extends Control

enum PlateStyle { LIST_ITEM, CHEVRON_LEFT, CHEVRON_RIGHT }

const SCAN_SPEED := 0.55
const SCAN_BAND_WIDTH := 36.0
const SCAN_BAND_ALPHA := 0.1
const ACCENT_BAR_MIN_WIDTH := 5.0
const ACCENT_BAR_GROWTH := 10.0
const CHEVRON_HALF_SIZE := Vector2(9.0, 16.0)
const OPTION_ZONE_PADDING := 12.0
const OPTION_ARROW_INSET := 16.0
const OPTION_ARROW_HALF_SIZE := Vector2(5.0, 10.0)
const OPTION_ARROW_KICK_DISTANCE := 8.0

@export_group("Plate Style")
@export var plate_style : PlateStyle = PlateStyle.LIST_ITEM
@export var accent_color : Color = MenuStyle.ACCENT
@export var slant : float = 18.0
@export var slide_reserve : float = 22.0
@export_range(0.0, 1.0) var emphasis : float = 0.0

var press_flash : float = 0.0
var option_zone_width : float = 0.0
var arrow_kick : float = 0.0

var _scan_phase : float = 0.0

func _process(delta: float) -> void:
	_scan_phase = fposmod(_scan_phase + delta * SCAN_SPEED, 1.0)
	queue_redraw()

#region Drawing
func _draw() -> void:
	var plate_size := Vector2(size.x - slide_reserve, size.y)
	var plate := PackedVector2Array([
		Vector2(slant, 0.0),
		Vector2(plate_size.x, 0.0),
		Vector2(plate_size.x - slant, plate_size.y),
		Vector2(0.0, plate_size.y),
	])

	draw_colored_polygon(plate, MenuStyle.PANEL_FILL.lerp(Color(accent_color, 0.42), emphasis))
	_draw_plate_content(plate_size)
	_draw_scan_band(plate_size.x, plate_size.y, SCAN_BAND_ALPHA * emphasis)
	draw_polyline(MenuStyle.closed_outline(plate), Color(accent_color, lerpf(0.35, 1.0, emphasis)), 1.5 + emphasis)
	_draw_accent_bar(plate_size)
	if press_flash > 0.0:
		draw_colored_polygon(plate, Color(1.0, 1.0, 1.0, press_flash * 0.5))
	if plate_style != PlateStyle.LIST_ITEM:
		_draw_chevron(plate_size)
	if option_zone_width > 0.0:
		_draw_option_arrows(plate_size)

# Override to draw between the plate fill and its outline.
func _draw_plate_content(_plate_size: Vector2) -> void:
	pass

func _draw_accent_bar(plate_size: Vector2) -> void:
	var bar_width := ACCENT_BAR_MIN_WIDTH + ACCENT_BAR_GROWTH * emphasis
	draw_colored_polygon(PackedVector2Array([
		Vector2(slant, 0.0),
		Vector2(slant + bar_width, 0.0),
		Vector2(bar_width, plate_size.y),
		Vector2(0.0, plate_size.y),
	]), accent_color)

func _draw_scan_band(travel_end: float, band_height: float, strength: float) -> void:
	if strength <= 0.0:
		return
	var band_start := lerpf(slant, travel_end - SCAN_BAND_WIDTH - slant, _scan_phase)
	draw_colored_polygon(PackedVector2Array([
		Vector2(band_start, 0.0),
		Vector2(band_start + SCAN_BAND_WIDTH, 0.0),
		Vector2(band_start + SCAN_BAND_WIDTH - slant, band_height),
		Vector2(band_start - slant, band_height),
	]), Color(1.0, 1.0, 1.0, strength))

func _draw_chevron(plate_size: Vector2) -> void:
	var direction := -1.0 if plate_style == PlateStyle.CHEVRON_LEFT else 1.0
	var center := plate_size * 0.5
	_draw_arrow(center, direction, CHEVRON_HALF_SIZE, MenuStyle.TEXT_DIM.lerp(accent_color, emphasis), 4.0)

# Two small arrows flank the value zone; the one in the stepped direction kicks outward.
func _draw_option_arrows(plate_size: Vector2) -> void:
	var zone_right := plate_size.x - slant - OPTION_ZONE_PADDING
	var zone_left := zone_right - option_zone_width
	for arrow_direction in [-1.0, 1.0]:
		var kick := maxf(arrow_kick * arrow_direction, 0.0)
		var inset_x := zone_left + OPTION_ARROW_INSET if arrow_direction < 0.0 else zone_right - OPTION_ARROW_INSET
		var center := Vector2(inset_x + arrow_direction * kick * OPTION_ARROW_KICK_DISTANCE, plate_size.y * 0.5)
		var arrow_color := MenuStyle.TEXT_DIM.lerp(accent_color, maxf(emphasis, kick))
		_draw_arrow(center, arrow_direction, OPTION_ARROW_HALF_SIZE, arrow_color, 3.0)

func _draw_arrow(center: Vector2, direction: float, half_size: Vector2, color: Color, width: float) -> void:
	var arm_x := center.x - half_size.x * direction
	draw_polyline(PackedVector2Array([
		Vector2(arm_x, center.y - half_size.y),
		center + Vector2(half_size.x * direction, 0.0),
		Vector2(arm_x, center.y + half_size.y),
	]), color, width)
#endregion
