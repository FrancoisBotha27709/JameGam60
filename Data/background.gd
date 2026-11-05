extends ColorRect

@export var target_camera: Camera2D

var _sky_material: ShaderMaterial


func _ready() -> void:
	_sky_material = material as ShaderMaterial
	assert(_sky_material != null, "Assign a ShaderMaterial with the starfield shader to this ColorRect.")
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var camera := target_camera if target_camera != null else get_viewport().get_camera_2d()
	if camera == null:
		return
	_sky_material.set_shader_parameter("camera_position", camera.get_screen_center_position())
	_sky_material.set_shader_parameter("view_height_world", get_viewport_rect().size.y / camera.zoom.y)
