extends Control
class_name ToolTip

@export var title_label : Label
@export var body_label : RichTextLabel
@export var texure_rect : TextureRect

func config(data : Debris) -> void:
	if not title_label or not body_label:
		await self.ready
	title_label.text = "%s" % data.display_name
	texure_rect.texture = data.texture
	body_label.text = data.get_description()

func _make_custom_tooltip(_for_text: String) -> Object:
	if not data:
		return null
	var tooltip := preload("res://Assets/Nodes/tool_tip.tscn").instantiate() as ToolTip
	tooltip.config(data)
	return tooltip