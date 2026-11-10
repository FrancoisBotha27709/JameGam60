extends PlayerStates.Tumble
class_name PlayerShedState

## A crash while carrying cargo: tumbles like Tumble, but first knocks some pieces loose.
## Impact speed comes from player.last_impact_speed (set in bounce_off).

func enter(previous_state_name : StringName) -> void:
	super(previous_state_name)
	_shed(player.last_impact_speed)

func _shed(impact_speed : float) -> void:
	var held := player.attached_debris
	var ratio := impact_speed / player.stat_f(&"max_speed")
	if held.is_empty() or ratio < player.shed_min_impact_ratio:
		return
	var load_scale := 1.0 + player.total_weight * player.shed_weight_factor
	var fraction := clampf(ratio * player.shed_strength * load_scale, 0.0, 1.0)
	var count := mini(ceili(held.size() * fraction), held.size())
	held.shuffle()
	var weight_scale := DataCollector.get_stat(Upgrade.Stat.DEBRIS_WEIGHT, 1.0)
	for i in count:
		var debris : DebrisObject = held.pop_back()
		player.total_weight = maxf(player.total_weight - debris.get_weight() * weight_scale, 0.0)
		debris.shed(player.global_position, player.shed_force, player.shed_lockout)
	player.cargo_shed.emit(count)