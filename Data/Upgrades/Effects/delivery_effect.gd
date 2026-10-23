extends UpgradeEffect
class_name DeliveryEffect

@export var points_mult : float = 0.0
@export var fuel : float = 0.0
@export var heat : float = 0.0
@export var time : float = 0.0

func on_delivery(_d : Debris, points : float) -> float:
	var p : Player = DataCollector.player
	p.current_fuel = clampf(p.current_fuel + fuel, 0.0, p.fuel_max)
	p.heat = clampf(p.heat + heat, 0.0, p.heat_max)
	SignalBus.emit_signal("update_fuel", p.current_fuel)
	var t := DataCollector.global_timer
	if time != 0.0 and DataCollector.uses_timer():
		t.start(maxf(t.time_left + time, 0.1))
	return points * (1.0 + points_mult)