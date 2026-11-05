
extends Resource
class_name ShipDesign

const STAT_PROPERTIES: Array[StringName] = [
	&"max_speed", &"collision_shape_scale",
	&"rotation_speed", &"angular_acceleration", &"angular_drag",
	&"thrust_accel", &"throttle_accel", &"throttle_decel",
	&"hold_delay", &"tap_impulse", &"grip",
	&"coast_drag", &"brake_drag", &"overspeed_drag",
	&"boost_speed_mult", &"boost_fuel_mult",
	&"fuel_max", &"fuel_depletion_rate", &"tap_fuel_cost", &"weight_fuel_factor",
	&"overheat_enabled", &"heat_max", &"tap_heat", &"hold_heat_rate",
	&"cool_rate", &"meltdown_time", &"weight_drag", &"min_speed_factor"
]

@export_group("Identity")
@export var ship_name: String
@export_multiline var description: String
@export var diffuse_texture: Texture2D
@export var normal_texture: Texture2D

@export_subgroup("Enlarged")
@export var en_diffuse_texture: Texture2D
@export var en_normal_texture: Texture2D

@export_group("Marker Positions")
@export_subgroup("Thrust")
@export var thrust_marker_position := Vector2.ZERO
@export_subgroup("Wings")
@export var wing_marker_position := Vector2.ZERO
@export_subgroup("Nose / Tip")
@export var tip_marker_position := Vector2.ZERO
@export_subgroup("Exhaust")
@export var exhaust_marker_position := Vector2.ZERO

@export_group("FX")
## Each scene attaches to the marker at the same array index.
@export var fx_scenes: Array[PackedScene] = []
## Each position corresponds to the scene at the same index.
@export var fx_marker_positions: Array[Vector2] = []

@export_group("Abilities")
@export var abilities: Array[Upgrade] = []

@export_group("Stats")
@export var max_speed := 400.0
@export var collision_shape_scale := 1.0

@export_subgroup("Rotation")
@export var rotation_speed := 2.5
@export var angular_acceleration := 9.0
@export var angular_drag := 4.0

@export_subgroup("Thrust")
@export var thrust_accel := 300.0
@export var throttle_accel := 60.0
@export var throttle_decel := 300.0
@export var hold_delay := 0.15
@export var tap_impulse := 90.0
@export var grip := 2.0

@export_subgroup("Momentum")
@export var coast_drag := 25.0
@export var brake_drag := 250.0
@export var overspeed_drag := 400.0

@export_subgroup("Boost")
@export var boost_speed_mult := 1.6
@export var boost_fuel_mult := 2.0

@export_subgroup("Fuel")
@export var fuel_max := 100.0
@export var fuel_depletion_rate := 6.0
@export var tap_fuel_cost := 0.5
@export var weight_fuel_factor := 0.1

@export_subgroup("Overheat")
@export var overheat_enabled := true
@export var heat_max := 100.0
@export var tap_heat := 14.0
@export var hold_heat_rate := 6.0
@export var cool_rate := 12.0
@export var meltdown_time := 5.0

@export_subgroup("Weight")
@export var weight_drag := 0.05
@export var min_speed_factor := 0.25


func make_canvas_texture() -> CanvasTexture:
	var texture := CanvasTexture.new()
	texture.diffuse_texture = en_diffuse_texture
	texture.normal_texture = en_normal_texture
	return texture


func get_stats_bbcode() -> String:
	var sections := {
		"MOVEMENT": [
			["Max Speed", &"max_speed", Upgrade.Stat.MAX_SPEED],
			["Rotation Speed", &"rotation_speed", Upgrade.Stat.ROTATION_SPEED],
			["Angular Acceleration", &"angular_acceleration", -1],
			["Angular Drag", &"angular_drag", -1],
			["Thrust Acceleration", &"thrust_accel", Upgrade.Stat.THRUST_ACCEL],
			["Throttle Acceleration", &"throttle_accel", Upgrade.Stat.THROTTLE_ACCEL],
			["Throttle Deceleration", &"throttle_decel", -1],
			["Grip", &"grip", Upgrade.Stat.GRIP],
			["Coast Drag", &"coast_drag", Upgrade.Stat.COAST_DRAG],
			["Brake Drag", &"brake_drag", -1],
			["Overspeed Drag", &"overspeed_drag", -1]
		],
		"FUEL": [
			["Fuel Capacity", &"fuel_max", Upgrade.Stat.FUEL_MAX],
			["Fuel Depletion", &"fuel_depletion_rate", Upgrade.Stat.FUEL_BURN],
			["Tap Fuel Cost", &"tap_fuel_cost", -1],
			["Boost Fuel Multiplier", &"boost_fuel_mult", Upgrade.Stat.BOOST_FUEL],
			["Weight Fuel Factor", &"weight_fuel_factor", Upgrade.Stat.WEIGHT_FUEL]
		],
		"HEAT": [
			["Overheating", &"overheat_enabled", -1],
			["Maximum Heat", &"heat_max", Upgrade.Stat.HEAT_MAX],
			["Tap Heat", &"tap_heat", Upgrade.Stat.HEAT_GAIN],
			["Hold Heat Rate", &"hold_heat_rate", Upgrade.Stat.HEAT_GAIN],
			["Cooling Rate", &"cool_rate", Upgrade.Stat.COOL_RATE],
			["Meltdown Time", &"meltdown_time", Upgrade.Stat.MELTDOWN_TIME]
		],
		"OTHER": [
			["Collision Scale", &"collision_shape_scale", -1],
			["Boost Speed Multiplier", &"boost_speed_mult", Upgrade.Stat.BOOST_SPEED],
			["Hold Delay", &"hold_delay", -1],
			["Tap Impulse", &"tap_impulse", Upgrade.Stat.TAP_IMPULSE],
			["Weight Drag", &"weight_drag", Upgrade.Stat.WEIGHT_DRAG],
			["Minimum Speed Factor", &"min_speed_factor", -1]
		]
	}

	var lines := PackedStringArray()
	var display_name := ship_name if not ship_name.is_empty() else resource_name
	lines.append("[font_size=22][b][color=#7de0ff]%s[/color][/b][/font_size]" % display_name)
	lines.append("[color=#777777]────────────────────────[/color]")

	for section: String in sections:
		lines.append("")
		lines.append("[font_size=16][b]%s[/b][/font_size]" % section)
		for entry: Array in sections[section]:
			lines.append(_format_stat(entry[0], entry[1], entry[2]))

	return "\n".join(lines)


func _format_stat(label: String, property: StringName, stat: int = -1) -> String:
	var value: Variant = get(property)
	var prefix := "[color=#aaaaaa]%s:[/color] "

	if value is bool:
		return (prefix + "[color=#ffffff]%s[/color]") % [label, "Yes" if value else "No"]

	if not (value is int or value is float):
		return (prefix + "[color=#ffffff]%s[/color]") % [label, str(value)]

	var base := float(value)
	var current := base
	var modifiers := PackedStringArray()

	if stat >= 0:
		for upgrade: Upgrade in abilities:
			if not is_instance_valid(upgrade):
				continue

			if upgrade.effects.is_empty():
				if upgrade.stat == stat:
					current = _apply_display_modifier(current, upgrade.mode, upgrade.amount, modifiers)
				continue

			for ability: Resource in upgrade.effects:
				if not is_instance_valid(ability) or not ability is StatEffect:
					continue

				var effect := ability as StatEffect
				if stat in effect.stats:
					current = _apply_display_modifier(current, effect.mode, effect.amount, modifiers)

	var result := (prefix + "[color=#7de0ff]%s[/color]") % [label, _format_number(base)]

	if not modifiers.is_empty():
		result += " " + " ".join(modifiers)
		result += " [color=#777777]|[/color] [color=gold]%s[/color]" % _format_number(current)

	return result


func _apply_display_modifier(value: float, mode: Upgrade.Mode, amount: float, modifiers: PackedStringArray) -> float:
	var result := value
	match mode:
		Upgrade.Mode.ADD:
			result += amount
		Upgrade.Mode.MULTIPLY:
			result *= 1.0 + amount

	var difference := result - value
	if not is_zero_approx(difference):
		modifiers.append("[color=%s](%s%s)[/color]" % [
			"lime" if difference > 0.0 else "red",
			"+" if difference > 0.0 else "",
			_format_number(difference)
		])

	return result


func _format_number(value: float) -> String:
	return str(int(roundf(value))) if is_equal_approx(value, roundf(value)) else "%.2f" % value
