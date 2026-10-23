extends Area2D
class_name Depot

@export var fx_attach : FXEmitter
## Asteroid edges are never allowed closer than this to the depot centre.
@export var asteroid_clearance : float = 500.0

func _ready() -> void:
	add_to_group("Depot")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body : Node2D) -> void:
	if body.is_in_group("Player"):
		body.deliver_to(self)
		fx_attach.play()