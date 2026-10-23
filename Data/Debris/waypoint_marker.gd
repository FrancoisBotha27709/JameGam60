extends Sprite2D

@export var on_screen_offset : Vector2 = Vector2(0.5, -5.0)
@export var screen_margin : float = 4.0
@export var smoothing_speed : float = 8.0

@export_group("Fade")
@export var fade_near_distance : float = 150.0
@export var fade_far_distance : float = 450.0
@export var fade_speed : float = 6.0

func _process(delta : float) -> void:
	var target := get_parent() as Node2D
	if target == null:
		return

	var canvas_xform := get_viewport().get_canvas_transform()
	var viewport_size := get_viewport().get_visible_rect().size

	var screen_pos := canvas_xform * target.global_position

	var half_size := 0.0
	if texture != null:
		half_size = maxf(texture.get_size().x, texture.get_size().y) * 0.5 \
			* global_scale.abs().x * canvas_xform.get_scale().x
	var inset_rect := Rect2(Vector2.ZERO, viewport_size).grow(-(screen_margin + half_size))

	var display_pos : Vector2
	var display_rot : float

	if inset_rect.has_point(screen_pos):
		display_pos = target.global_position + on_screen_offset
		display_rot = 0.0
	else:
		var clamped := screen_pos.clamp(inset_rect.position, inset_rect.end)
		display_pos = canvas_xform.affine_inverse() * clamped
		display_rot = (target.global_position - display_pos).angle() - PI * 0.5

	var t := minf(delta * smoothing_speed, 1.0)
	global_position = global_position.lerp(display_pos, t)
	rotation = lerp_angle(rotation, display_rot, t)

	# Fade out as the screen centre (the camera) gets close to the waypoint
	var dist := screen_pos.distance_to(viewport_size * 0.5)
	var target_alpha := clampf(inverse_lerp(fade_near_distance, fade_far_distance, dist), 0.0, 1.0)
	modulate.a = lerpf(modulate.a, target_alpha, minf(delta * fade_speed, 1.0))