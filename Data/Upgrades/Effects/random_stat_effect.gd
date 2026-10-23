extends UpgradeEffect
class_name RandomStatEffect

## Empty == any stat
@export var pool : Array[Upgrade.Stat] = []
@export var count : int = 3
@export var min_amount : float = -0.3
@export var max_amount : float = 0.3

func on_take(_stacks : int) -> void:
    var p : Array = (pool if not pool.is_empty() else Upgrade.Stat.values()).duplicate()
    p.shuffle()
    for s in p.slice(0, count):
        DataCollector.change_stat(s, Upgrade.Mode.MULTIPLY, randf_range(min_amount, max_amount))