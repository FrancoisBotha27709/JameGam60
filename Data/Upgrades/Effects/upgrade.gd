extends Resource
class_name Upgrade

enum Stat {
	MAX_SPEED, ROTATION_SPEED, THROTTLE_ACCEL, FUEL_MAX, WEIGHT_DRAG, TIME_LIMIT, SCORE,
	THRUST_ACCEL, TAP_IMPULSE, BOOST_SPEED, BOOST_FUEL, FUEL_BURN, WEIGHT_FUEL, COAST_DRAG,
	GRIP, HEAT_MAX, HEAT_GAIN, COOL_RATE, MELTDOWN_TIME, MAGNET_SIZE,
	DEBRIS_WEIGHT, DEBRIS_VALUE, QUOTA,
}

enum Mode { ADD, MULTIPLY }

@export var title : String
@export_multiline var description : String
@export var icon : Texture2D
@export var max_stacks : int = 3
@export var effects : Array[UpgradeEffect] = []

@export_group("Legacy")
@export var stat : Stat
@export var mode : Mode = Mode.MULTIPLY
@export var amount : float = 0.1

func is_relevant() -> bool:
	if effects.is_empty():
		return DataCollector.is_stat_relevant(stat)
	return effects.any(func(e : UpgradeEffect): return e.is_relevant())
