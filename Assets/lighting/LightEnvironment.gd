class_name LightEnvironment
extends Node

@export var ambient := Color(0.04, 0.05, 0.09)
@export_range(0.0, 10.0, 0.1, "suffix:s") var fade_time := 0.0

@export_group("Sun")
@export var sun_enabled := false
@export_range(-180.0, 180.0, 1.0, "suffix:°") var sun_angle := 30.0
@export var sun_color := Color(1.0, 0.95, 0.8)
@export_range(0.0, 2.0, 0.01) var sun_energy := 0.6
@export var sun_shadows := true
@export_range(0.0, 10000.0, 10.0, "suffix:px") var sun_shadow_distance := 0.0

@export_group("Star (positional light)")
@export var star_enabled := false
@export var star_position := Vector2.ZERO
@export var star_preset : LightPreset

var _star : SpaceLight

func _ready() -> void:
	apply()

func apply() -> void:
	LightManager.set_ambient(ambient, fade_time)
	if sun_enabled:
		LightManager.set_sun(sun_angle, sun_color, sun_energy, sun_shadows, sun_shadow_distance)
	else:
		LightManager.remove_sun()

	if is_instance_valid(_star):
		_star.queue_free()
	_star = null
	if star_enabled:
		var p := star_preset if star_preset != null else LightPreset.star()
		_star = LightManager.spawn(p, star_position, self)

func _exit_tree() -> void:
	if sun_enabled:
		LightManager.remove_sun()