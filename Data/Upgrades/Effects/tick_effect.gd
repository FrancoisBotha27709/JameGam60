extends UpgradeEffect
class_name TickEffect

@export var fuel_per_sec : float = 0.0
@export var heat_per_sec : float = 0.0
@export var spin : float = 0.0

func on_physics(p : Player, d : float) -> void:
	p.current_fuel = clampf(p.current_fuel + fuel_per_sec * d, 0.0, p.fuel_max)
	p.heat = clampf(p.heat + heat_per_sec * d, 0.0, p.heat_max)
	p.rotation += spin * d