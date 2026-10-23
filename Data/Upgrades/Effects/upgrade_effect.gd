extends Resource
class_name UpgradeEffect

func is_relevant() -> bool: return true
func on_take(_stacks : int) -> void: pass
func on_run_start(_player : Player) -> void: pass
func on_physics(_player : Player, _delta : float) -> void: pass
func on_delivery(_debris : Debris, points : float) -> float: return points
