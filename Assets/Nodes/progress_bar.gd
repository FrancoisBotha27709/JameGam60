extends ProgressBar

@export var bar_text : String
@export var label : Label

func _ready() -> void:
	label.text = bar_text