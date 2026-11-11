class_name HangarTabButton
extends HangarButton

var selected : bool = false

func _is_highlighted() -> bool:
	return selected or super()
