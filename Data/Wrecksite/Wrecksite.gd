extends RefCounted
class_name WreckSite

var origin := Vector2.ZERO
var direction := Vector2.RIGHT
var length := 800.0
var width := 160.0
var count := 0

func _init(p_origin := Vector2.ZERO, p_direction := Vector2.RIGHT, p_length := 800.0, p_width := 160.0, p_count := 0) -> void:
	origin = p_origin
	direction = p_direction
	length = p_length
	width = p_width
	count = p_count

# A point along the line (t = 0..1) with sideways scatter, clamped into the world.
func sample(rng : RandomNumberGenerator, t : float, rect : Rect2) -> Vector2:
	var side := Vector2(-direction.y, direction.x)
	var point := origin + direction * length * t + side * rng.randfn(0.0, width)
	return point.clamp(rect.position, rect.end)