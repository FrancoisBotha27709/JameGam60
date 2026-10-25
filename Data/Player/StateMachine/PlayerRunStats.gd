extends RefCounted
class_name PlayerRunStats

const DEFAULT_TOTALS := {debris_collected = 0, debris_delivered = 0, time = 0.0, distance = 0.0,
		top_speed = 0.0, crashes = 0, peak_load = 0.0, fuel_burned = 0.0, peak_heat = 0.0, boost_time = 0.0}
const PERCENT := 100.0

var totals := DEFAULT_TOTALS.duplicate()

func reset() -> void:
	totals = DEFAULT_TOTALS.duplicate()

func record_motion(speed : float, delta : float, is_boosting : bool) -> void:
	totals.time += delta
	totals.distance += speed * delta
	totals.top_speed = maxf(totals.top_speed, speed)
	totals.boost_time += delta if is_boosting else 0.0

func record_attached(total_weight : float) -> void:
	totals.debris_collected += 1
	totals.peak_load = maxf(totals.peak_load, total_weight)

func record_delivered(count : int) -> void:
	totals.debris_delivered += count

func record_crash(_impact_speed : float) -> void:
	totals.crashes += 1

func record_fuel(amount : float) -> void:
	totals.fuel_burned += amount

func record_heat(heat : float, _heat_max : float) -> void:
	totals.peak_heat = maxf(totals.peak_heat, heat)

# Raw totals plus derived averages; peak heat is reported as a percentage of max heat.
func get_summary(heat_max : float) -> Dictionary:
	var summary := totals.duplicate()
	summary.erase("peak_heat")
	summary.avg_speed = totals.distance / totals.time if totals.time > 0.0 else 0.0
	summary.peak_heat_pct = totals.peak_heat / heat_max * PERCENT if heat_max > 0.0 else 0.0
	return summary