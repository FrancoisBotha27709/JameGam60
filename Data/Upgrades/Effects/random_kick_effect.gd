extends UpgradeEffect
class_name RandomKickEffect

@export var strength : float = 40.0

func on_physics(player : Player, delta : float) -> void:
    player.velocity += Vector2.from_angle(randf() * TAU) * strength * delta