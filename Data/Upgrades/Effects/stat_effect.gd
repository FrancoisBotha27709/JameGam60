extends UpgradeEffect
class_name StatEffect

@export var stats : Array[Upgrade.Stat] = []
@export var mode : Upgrade.Mode = Upgrade.Mode.MULTIPLY
@export var amount : float = 0.1

func is_relevant() -> bool:
    return stats.any(DataCollector.is_stat_relevant)

func on_take(_stacks : int) -> void:
    for s in stats:
        DataCollector.change_stat(s, mode, amount)