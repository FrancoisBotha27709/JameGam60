extends UpgradeEffect
class_name FlagEffect

@export var flag : StringName

func on_take(_stacks : int) -> void:
    DataCollector.flags[flag] = DataCollector.flag(flag) + 1