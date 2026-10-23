extends Control
class_name DebrisUI

@export_group("Nodes", "node_")
@export var node_debris_lbl : Label
@export var node_icon : TextureRect

func set_data(debris : Debris, tag_name : String, count : int, points : float) -> void:
	node_debris_lbl.text = "%s x%d  +%.1f" % [tag_name, count, points]
	node_icon.texture = debris.texture
