extends Resource
class_name Wrecks

const SCATTER_SIGMAS := 3.0
const MIDPOINT_SHARE := 0.5

@export var sites_min : int = 2
@export var sites_max : int = 3
@export var distance_min : float = 900.0
@export var distance_max : float = 1600.0
@export var length_min : float = 500.0
@export var length_max : float = 1100.0
@export var width : float = 160.0
@export var leash : float = 2500.0
@export var weight_min : float = 0.5
@export var weight_max : float = 1.5
@export_group("Spacing")
@export var site_separation : float = 2000.0
@export var player_clear_radius : float = 1500.0
@export var placement_attempts : int = 60

func plan(depots : Array, rect : Rect2, amount : int, rng : RandomNumberGenerator, avoid_point : Vector2 = Vector2.INF) -> Array[WreckSite]:
	var site_count := rng.randi_range(sites_min, maxi(sites_min, sites_max))
	var weights : Array[float] = []
	var total_weight := 0.0
	for site_index in site_count:
		weights.append(rng.randf_range(weight_min, weight_max))
		total_weight += weights[site_index]

	var safe_rect := rect.grow(-length_max)
	var required_clearance := player_clear_radius + width * SCATTER_SIGMAS
	var sites : Array[WreckSite] = []
	var midpoints : Array[Vector2] = []
	var remaining := amount
	for site_index in site_count:
		var count := remaining if site_index == site_count - 1 else mini(roundi(amount * weights[site_index] / total_weight), remaining)
		remaining -= count

		var best_start := Vector2.ZERO
		var best_direction := Vector2.RIGHT
		var best_length := length_min
		var best_midpoint := Vector2.ZERO
		var best_score := -INF
		for attempt in placement_attempts:
			var anchor := _pick_anchor(depots, rng)
			var start := anchor + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(distance_min, distance_max)
			start = start.clamp(safe_rect.position, safe_rect.end)
			var direction := Vector2.from_angle(rng.randf() * TAU)
			var length := rng.randf_range(length_min, length_max)
			var segment_end := (start + direction * length).clamp(rect.position, rect.end)
			var midpoint := start + direction * length * MIDPOINT_SHARE
			var score := minf(
				_clearance(avoid_point, start, segment_end) - required_clearance,
				_separation(midpoint, midpoints) - site_separation)
			if score > best_score:
				best_score = score
				best_start = start
				best_direction = direction
				best_length = length
				best_midpoint = midpoint
			if score >= 0.0:
				break
		midpoints.append(best_midpoint)
		sites.append(WreckSite.new(best_start, best_direction, best_length, width, count))
	return sites

func _pick_anchor(depots : Array, rng : RandomNumberGenerator) -> Vector2:
	if depots.is_empty():
		return Vector2.ZERO
	return (depots[rng.randi_range(0, depots.size() - 1)] as Node2D).global_position

func _clearance(avoid_point : Vector2, segment_start : Vector2, segment_end : Vector2) -> float:
	if is_inf(avoid_point.x):
		return INF
	return avoid_point.distance_to(Geometry2D.get_closest_point_to_segment(avoid_point, segment_start, segment_end))

func _separation(midpoint : Vector2, placed_midpoints : Array[Vector2]) -> float:
	var nearest := INF
	for placed in placed_midpoints:
		nearest = minf(nearest, midpoint.distance_to(placed))
	return nearest