
extends Sprite2D
class_name ShipContainer

@export_group("Markers")
@export var thrust_marker: Marker2D
@export var wing_marker: Marker2D
@export var tip_marker: Marker2D
@export var exhaust_marker: Marker2D

@export_group("FX Markers")
## FX scene index corresponds to marker index.
@export var fx_markers: Array[Marker2D] = []

@export_group("Ship Information")
@export var info_scene: PackedScene
@export var line_straight_length := 50.0
@export var line_diagonal_length := 60.0

@export_group("Automatic Layout")
@export_range(0.0, 64.0, 1.0) var panel_spacing := 12.0
@export_range(0.0, 64.0, 1.0) var container_padding := 8.0
@export_range(0.0, 1.0, 0.01) var preferred_vertical_position := 0.5

var _info_nodes: Array[ShipInfo] = []
var _info_parent: Control
var _design: ShipDesign
var _last_parent_size := Vector2.ZERO
var _fx_nodes: Array[ShipFX] = []

func setup(main_menu: bool = false, selected_design: ShipDesign = null, info_parent: Control = null) -> void:
	_clear_info()
	_design = selected_design if selected_design != null else DataCollector.get_selected_ship()
	_info_parent = info_parent

	if _design == null:
		texture = null
		return

	texture = _design.make_canvas_texture() if main_menu else _design.diffuse_texture
	_apply_marker_positions(_design)

	if main_menu:
		_build_info()
		_schedule_layout()
	if not main_menu:
		_apply_design_fx(_design)

func _apply_design_fx(design: ShipDesign) -> void:
	for marker: Marker2D in fx_markers:
		if is_instance_valid(marker):
			marker.hide()

	for effect: ShipFX in _fx_nodes:
		if is_instance_valid(effect):
			effect.queue_free()
	_fx_nodes.clear()

	if design == null:
		return

	var count := mini(design.fx_scenes.size(), fx_markers.size())

	for i in range(count):
		var scene := design.fx_scenes[i]
		var marker := fx_markers[i]

		if not is_instance_valid(marker):
			continue

		if i < design.fx_marker_positions.size():
			marker.position = design.fx_marker_positions[i]

		if scene == null:
			continue

		marker.show()

		var instance := scene.instantiate()
		marker.add_child(instance)

		if instance is ShipFX:
			_fx_nodes.append(instance as ShipFX)
		else:
			push_warning("FX scene at index %d must have a ShipFX root." % i)
			instance.queue_free()

func get_fx_nodes() -> Array[ShipFX]:
	return _fx_nodes

func _apply_marker_positions(design: ShipDesign) -> void:
	if thrust_marker:
		thrust_marker.position = design.thrust_marker_position
	if wing_marker:
		wing_marker.position = design.wing_marker_position
	if tip_marker:
		tip_marker.position = design.tip_marker_position
	if exhaust_marker:
		exhaust_marker.position = design.exhaust_marker_position


func _build_info() -> void:
	if info_scene == null or _info_parent == null:
		push_warning("ShipContainer: info_scene or info_parent is missing.")
		return

	_add_info("THRUSTERS", thrust_marker, {
		"Thrust Acceleration": _get_stat_display(&"thrust_accel", Upgrade.Stat.THRUST_ACCEL),
		"Throttle Acceleration": _get_stat_display(&"throttle_accel", Upgrade.Stat.THROTTLE_ACCEL),
		"Tap Impulse": _get_stat_display(&"tap_impulse", Upgrade.Stat.TAP_IMPULSE),
		"Hold Delay": _format_plain_value(_design.hold_delay)
	}, false)

	_add_info("WINGS / CONTROL", wing_marker, {
		"Rotation Speed": _get_stat_display(&"rotation_speed", Upgrade.Stat.ROTATION_SPEED),
		"Angular Acceleration": _format_plain_value(_design.angular_acceleration),
		"Angular Drag": _format_plain_value(_design.angular_drag),
		"Grip": _get_stat_display(&"grip", Upgrade.Stat.GRIP)
	}, true)

	_add_info("HULL / NOSE", tip_marker, {
		"Maximum Speed": _get_stat_display(&"max_speed", Upgrade.Stat.MAX_SPEED),
		"Collision Scale": _get_stat_display(&"collision_shape_scale", Upgrade.Stat.MAGNET_SIZE),
		"Weight Drag": _get_stat_display(&"weight_drag", Upgrade.Stat.WEIGHT_DRAG),
		"Minimum Speed Factor": _format_plain_value(_design.min_speed_factor)
	}, true)

	_add_info("FUEL / EXHAUST", exhaust_marker, {
		"Fuel Capacity": _get_stat_display(&"fuel_max", Upgrade.Stat.FUEL_MAX),
		"Fuel Depletion": _get_stat_display(&"fuel_depletion_rate", Upgrade.Stat.FUEL_BURN),
		"Boost Speed": _get_stat_display(&"boost_speed_mult", Upgrade.Stat.BOOST_SPEED),
		"Boost Fuel Cost": _get_stat_display(&"boost_fuel_mult", Upgrade.Stat.BOOST_FUEL)
	}, false)


func _get_stat_display(property: StringName, stat: int) -> String:
	var base := float(_design.get(property))
	var current := base
	var positive := 0.0
	var negative := 0.0

	for upgrade: Upgrade in _design.abilities:
		if not is_instance_valid(upgrade):
			continue

		if upgrade.effects.is_empty():
			if upgrade.stat != stat:
				continue
			var next := _apply_modifier(current, upgrade.mode, upgrade.amount)
			_accumulate_change(current, next, positive, negative)
			if next > current:
				positive += next - current
			else:
				negative += next - current
			current = next
			continue

		for ability: Resource in upgrade.effects:
			if not is_instance_valid(ability) or not ability is StatEffect:
				continue
			var effect := ability as StatEffect
			if stat not in effect.stats:
				continue
			var next := _apply_modifier(current, effect.mode, effect.amount)
			if next > current:
				positive += next - current
			else:
				negative += next - current
			current = next

	if is_equal_approx(base, current):
		return "[color=gold]%s[/color]" % _format_number(current)

	var result := "[color=cyan]%s[/color]" % _format_number(base)
	if not is_zero_approx(positive):
		result += " [color=lime](+%s)[/color]" % _format_number(positive)
	if not is_zero_approx(negative):
		result += " [color=red](%s)[/color]" % _format_number(negative)
	return result + " | [color=gold]%s[/color]" % _format_number(current)


func _accumulate_change(_old: float, _new: float, _positive: float, _negative: float) -> void:
	pass


func _format_plain_value(value: Variant) -> String:
	return _format_number(float(value)) if value is int or value is float else str(value)


func _format_number(value: float) -> String:
	return str(int(roundf(value))) if is_equal_approx(value, roundf(value)) else "%.2f" % value


func _apply_modifier(value: float, mode: Upgrade.Mode, amount: float) -> float:
	match mode:
		Upgrade.Mode.ADD:
			return value + amount
		Upgrade.Mode.MULTIPLY:
			return value * (1.0 + amount)
	return value


func _add_info(title: String, marker: Marker2D, data: Dictionary, place_right: bool) -> void:
	if marker == null:
		push_warning("ShipContainer: marker missing for " + title)
		return

	var info := info_scene.instantiate() as ShipInfo
	if info == null:
		push_warning("ShipContainer: info_scene root must use ShipInfo.gd.")
		return

	_info_parent.add_child(info)
	info.position = _info_parent.get_global_transform().affine_inverse() * marker.global_position
	info.setup(title, data, place_right, line_straight_length, line_diagonal_length)
	_info_nodes.append(info)


func _schedule_layout() -> void:
	if is_instance_valid(_info_parent):
		_layout_info_panels.call_deferred()


func _layout_info_panels() -> void:
	if not is_instance_valid(_info_parent) or not is_instance_valid(self) or not is_inside_tree():
		return

	var bounds := Rect2(Vector2.ZERO, _info_parent.size).grow(-container_padding)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return

	var left: Array[ShipInfo] = []
	var right: Array[ShipInfo] = []

	for info in _info_nodes:
		if not is_instance_valid(info) or not info.is_inside_tree():
			continue
		(right if info.is_placed_right() else left).append(info)

	_layout_side(left, bounds)
	_layout_side(right, bounds)


func _layout_side(panels: Array[ShipInfo], bounds: Rect2) -> void:
	if panels.is_empty():
		return

	panels.sort_custom(func(a: ShipInfo, b: ShipInfo) -> bool: return a.position.y < b.position.y)

	var count := panels.size()
	var heights: Array[float] = []
	var widths: Array[float] = []
	var centres: Array[float] = []
	var total_height := 0.0

	for info in panels:
		var size := info.get_panel_size()
		var h := minf(size.y, bounds.size.y)
		heights.append(h)
		widths.append(minf(size.x, bounds.size.x))
		centres.append(clampf(info.position.y, bounds.position.y + h * 0.5, bounds.end.y - h * 0.5))
		total_height += h

	var spacing := minf(panel_spacing, maxf(bounds.size.y - total_height, 0.0) / maxf(float(count - 1), 1.0))

	if total_height + spacing * (count - 1) > bounds.size.y:
		spacing = 0.0
		for i in range(count):
			heights[i] = bounds.size.y / count
			centres[i] = bounds.position.y + heights[i] * (i + 0.5)
	else:
		for i in range(1, count):
			centres[i] = maxf(centres[i], centres[i - 1] + (heights[i - 1] + heights[i]) * 0.5 + spacing)

		var overflow := maxf(centres[count - 1] + heights[count - 1] * 0.5 - bounds.end.y, 0.0)
		for i in range(count):
			centres[i] -= overflow

		for i in range(count - 2, -1, -1):
			centres[i] = minf(centres[i], centres[i + 1] - (heights[i + 1] + heights[i]) * 0.5 - spacing)

		var top_overflow := maxf(bounds.position.y - (centres[0] - heights[0] * 0.5), 0.0)
		for i in range(count):
			centres[i] += top_overflow

	for i in range(count):
		var info := panels[i]
		var x := info.position.x + line_straight_length if info.is_placed_right() else info.position.x - line_straight_length - widths[i]
		var panel_x := clampf(x, bounds.position.x, maxf(bounds.end.x - widths[i], bounds.position.x))
		var panel_y := clampf(centres[i] - heights[i] * 0.5, bounds.position.y, maxf(bounds.end.y - heights[i], bounds.position.y))
		info.set_panel_rect(Rect2(Vector2(panel_x, panel_y), Vector2(widths[i], heights[i])))


func _process(_delta: float) -> void:
	if not _info_nodes.is_empty() and is_instance_valid(_info_parent) and _info_parent.size != _last_parent_size:
		_last_parent_size = _info_parent.size
		_schedule_layout()


func _clear_info() -> void:
	for info in _info_nodes:
		if is_instance_valid(info):
			info.queue_free()
	_info_nodes.clear()
