extends Control
class_name BetterButton

signal pressed
signal hovered

@export_group("Nodes", "node_")
@export var node_button : Button
@export var node_label : RichTextLabel
@export_subgroup("Textures")
@export var node_left_texture : TextureRect
@export var node_right_texture : TextureRect

@export_group("Juice")
@export var hover_scale := 1.06
@export var press_scale := 0.92
@export var punch_scale := 1.14
@export var hover_tint := Color(1.25, 1.25, 1.25)
@export var press_tint := Color(0.8, 0.8, 0.8)
@export var flash_tint := Color(2.2, 2.2, 2.2)
@export var slide_px := 4.0
@export var press_label_drop := 2.0
@export var pitch_range := Vector2(0.92, 1.08)
@export var disabled := false : set = _set_disabled
@export_multiline var text := "" : set = _set_text

var _tween : Tween
var _hover := false
var _focus := false
var _down := false
var _cached := false
var _lp := Vector2.ZERO
var _rp := Vector2.ZERO
var _tp := Vector2.ZERO

func _ready() -> void:
	resized.connect(_piv)
	_piv()
	if node_label and text != "":
		node_label.text = text
	node_button.disabled = disabled
	node_button.mouse_entered.connect(_set_hover.bind(true))
	node_button.mouse_exited.connect(_set_hover.bind(false))
	node_button.focus_entered.connect(_set_focus.bind(true))
	node_button.focus_exited.connect(_set_focus.bind(false))
	node_button.button_down.connect(_set_down.bind(true))
	node_button.button_up.connect(_set_down.bind(false))
	node_button.pressed.connect(_on_pressed)
	await get_tree().process_frame
	if node_left_texture: _lp = node_left_texture.position
	if node_right_texture: _rp = node_right_texture.position
	if node_label: _tp = node_label.position
	_cached = true
	_piv()
	_state()

func _piv() -> void:
	pivot_offset = size * 0.5

func _set_text(v : String) -> void:
	text = v
	if node_label: node_label.text = v

func _set_disabled(v : bool) -> void:
	disabled = v
	if node_button: node_button.disabled = v
	if _cached: _state()

func _set_hover(v : bool) -> void:
	_hover = v
	if v and not disabled:
		hovered.emit()
	_state()

func _set_focus(v : bool) -> void:
	_focus = v
	_state()

func _set_down(v : bool) -> void:
	_down = v
	_state()

func _new_tween() -> Tween:
	if _tween: _tween.kill()
	_tween = create_tween().set_parallel(true)
	return _tween

func _on_pressed() -> void:
	if disabled or not _cached: return
	pressed.emit()
	var t := _new_tween()
	t.tween_property(self, "scale", Vector2.ONE * punch_scale, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate", flash_tint, 0.06)
	t.chain().tween_callback(_state)

func _state() -> void:
	if not _cached: return
	if disabled:
		_apply(1.0, Color(0.5, 0.5, 0.5, 0.8), 0.0, 0.0, 0.15, Tween.TRANS_QUAD)
	elif _down:
		_apply(press_scale, press_tint, press_label_drop, slide_px * 0.5, 0.05, Tween.TRANS_QUAD)
	elif _hover or _focus:
		_apply(hover_scale, hover_tint, -1.0, slide_px, 0.28, Tween.TRANS_BACK)
	else:
		_apply(1.0, Color.WHITE, 0.0, 0.0, 0.2, Tween.TRANS_BACK)

func _apply(s : float, tint : Color, lab : float, tex : float, dur : float, trans : Tween.TransitionType) -> void:
	var t := _new_tween().set_trans(trans).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE * s, dur)
	t.tween_property(self, "modulate", tint, dur)
	if node_label: t.tween_property(node_label, "position", _tp + Vector2(0, lab), dur)
	if node_left_texture: t.tween_property(node_left_texture, "position", _lp + Vector2(-tex, 0), dur)
	if node_right_texture: t.tween_property(node_right_texture, "position", _rp + Vector2(tex, 0), dur)