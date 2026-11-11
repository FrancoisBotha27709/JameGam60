class_name MenuStyle
extends RefCounted

const ACCENT := Color(0.30, 0.85, 1.0)
const WARNING := Color(1.0, 0.55, 0.20)
const DANGER := Color(1.0, 0.35, 0.40)
const TEXT := Color(0.88, 0.96, 1.0)
const TEXT_DIM := Color(0.55, 0.70, 0.80)
const PANEL_FILL := Color(0.02, 0.05, 0.09, 0.78)
const ROOM_OUTER_COLOR := Color(0.008, 0.015, 0.03)
const ROOM_INNER_COLOR := Color(0.05, 0.09, 0.15)

const REVEAL_GROUP := &"menu_reveal"
const REVEAL_DURATION := 0.35
const REVEAL_STAGGER := 0.07
const SLIDE_DISTANCE := 90.0
const TYPE_DURATION := 0.35
const DIM_ALPHA := 0.3

static func closed_outline(points: PackedVector2Array) -> PackedVector2Array:
	var outline := points.duplicate()
	outline.append(points[0])
	return outline

static func restart_tween(owner: Node, previous_tween: Tween) -> Tween:
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	return owner.create_tween()

static func type_on(owner: Node, label: Label, previous_tween: Tween, duration: float = TYPE_DURATION) -> Tween:
	label.visible_ratio = 0.0
	var tween := restart_tween(owner, previous_tween)
	tween.tween_property(label, "visible_ratio", 1.0, duration)
	return tween

# Pips are fixed scene nodes; the ones beyond the count are hidden.
static func refresh_pips(pips: Control, count: int, selected_index: int, idle_size: Vector2, selected_size: Vector2, accent: Color = ACCENT) -> void:
	for pip_index in pips.get_child_count():
		var pip := pips.get_child(pip_index) as ColorRect
		var is_selected := pip_index == selected_index
		pip.visible = pip_index < count
		pip.color = accent if is_selected else Color(accent, DIM_ALPHA)
		pip.custom_minimum_size = selected_size if is_selected else idle_size

static func has_focus_within(root: Control) -> bool:
	var focus_owner := root.get_viewport().gui_get_focus_owner()
	return focus_owner != null and root.is_ancestor_of(focus_owner)
