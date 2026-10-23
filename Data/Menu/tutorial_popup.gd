extends Control
class_name TutorialPopup

signal closed

const TAG_TEXT := "// FIELD MANUAL //"
const TITLE_TEXT := "GARBAGE COLLECTOR"
const SUB_TEXT := "COLLECT DEBRIS - DELIVER IT - MEET THE QUOTA"

# [lb] / [rb] print literal brackets, so "[ W ]" is never parsed as a tag.
const BODY_TEXT := """[color=#6ec6ff]// CONTROLS //[/color]
[table=2]
[cell padding=0,0,24,0][color=#ffd27f][lb] A / D [rb][/color][/cell][cell]Rotate the ship[/cell]
[cell padding=0,0,24,0][color=#ffd27f][lb] W [rb][/color][/cell][cell]Thrust: tap for a quick impulse, hold to ramp up the throttle[/cell]
[cell padding=0,0,24,0][color=#ffd27f][lb] SPACE [rb][/color][/cell][cell]Boost: faster, but burns [color=#ff8a65]2x fuel[/color][/cell]
[cell padding=0,0,24,0][color=#ffd27f][lb] S [rb][/color][/cell][cell]Brake / cut throttle[/cell]
[/table]

[color=#6ec6ff]// OBJECTIVE //[/color]
[color=#8be9ff][lb] 01 [rb][/color] Fly into [color=#ffd27f]debris[/color] to grab it. It trails behind you on a rope.
[color=#8be9ff][lb] 02 [rb][/color] Fly into the [color=#7dffb0]Depot[/color] to deliver everything you carry.
[color=#8be9ff][lb] 03 [rb][/color] Reach the [color=#ffd27f]quota[/color] before time or fuel runs out.

[color=#6ec6ff]// DEBRIS VALUE //[/color]
[table=2]
[cell padding=0,0,24,0][color=#cfcfcf][lb] PLASTIC [rb][/color][/cell][cell]x1.0[/cell]
[cell padding=0,0,24,0][color=#c0c8d0][lb] METAL [rb][/color][/cell][cell]x1.5[/cell]
[cell padding=0,0,24,0][color=#d8b98a][lb] CEMENT [rb][/color][/cell][cell]x2.0[/cell]
[/table]
[color=#8be9ff][lb] ANOMALY [rb][/color] Blue flashing debris is quantum: worth [color=#8be9ff]x3[/color], but it teleports away if you get close and don't grab it fast.

[color=#6ec6ff]// WARNINGS //[/color]
[color=yellow][lb] WARN [rb][/color] Weight: every piece slows you down and burns more fuel. Deliver often.
[color=yellow][lb] WARN [rb][/color] Asteroids: they bounce you away. Route around the big ones.
[color=red][lb] ERROR [rb][/color] Heat: rapid-fire tapping and holding thrust build heat. At maximum the ship explodes.
[color=red][lb] ERROR [rb][/color] Fuel: at zero your engine sputters and the run ends.

[color=#7dffb0][lb] OK [rb][/color] Meet the quota to pick an upgrade and start the next, harder run."""

## Optional. Leave empty if the theme is inherited from the menu or set project-wide.
@export var ui_theme : Theme
@export var tint : Color = Color(0.3, 0.85, 1.0)
@export var panel_size : Vector2 = Vector2(820, 640)

@export_group("Timing")
@export var intensity_fade : float = 0.3
@export_range(0.0, 1.0) var backdrop_intensity : float = 0.35
@export var window_open_time : float = 0.25
@export var title_slam_time : float = 0.3
@export var title_start_scale : float = 2.5
@export var calm_title_start_scale : float = 1.2
@export var tag_fade_time : float = 0.2
@export var sub_type_time : float = 0.6
@export var body_type_time : float = 1.8

@export_group("Slam")
@export_range(0.0, 1.0) var slam_flash_alpha : float = 0.35
@export var slam_flash_fade : float = 0.25
@export var slam_shake_time : float = 0.4
@export var shake_strength : float = 10.0

@export_group("Tag Blink")
@export var blink_time : float = 0.5
@export_range(0.0, 1.0) var blink_min_alpha : float = 0.25

var _vignette : DitherVignette
var _flash : ColorRect
var _panel : PanelContainer
var _tag : Label
var _title : Label
var _sub : Label
var _body : RichTextLabel
var _hint : Label
var _btn : Button

var _tween : Tween
var _slam_tween : Tween
var _blink : Tween
var _calm : bool = false
var _shake : float = 0.0
var _typing : bool = true
var _closing : bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ui_theme != null:
		theme = ui_theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # block clicks on the menu behind

	_build_ui()
	_play()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# Dithered vignette, shared with the run-end banner
	_vignette = DitherVignette.new()
	_vignette.tint = tint
	_vignette.intensity = 0.0
	add_child(_vignette)
	_vignette.fill_parent()

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Flat panel, same look as the banner's backpanel but with a tinted border
	_panel = PanelContainer.new()
	var vp := get_viewport_rect().size
	_panel.custom_minimum_size = Vector2(
		minf(panel_size.x, vp.x * 0.92),
		minf(panel_size.y, vp.y * 0.92))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style.border_color = tint
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(0)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	_tag = Label.new()
	_tag.text = TAG_TEXT
	_tag.add_theme_font_size_override("font_size", 28)
	_tag.add_theme_color_override("font_color", tint)
	box.add_child(_tag)

	_title = Label.new()
	_title.text = TITLE_TEXT
	_title.add_theme_font_size_override("font_size", 48)
	_title.add_theme_color_override("font_color", tint)
	box.add_child(_title)

	_sub = Label.new()
	_sub.text = SUB_TEXT
	_sub.add_theme_font_size_override("font_size", 24)
	box.add_child(_sub)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = Color(tint, 0.5)
	box.add_child(rule)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.scroll_active = true
	_body.scroll_following_visible_characters = true   # follows the typewriter
	_body.fit_content = false
	_body.focus_mode = Control.FOCUS_NONE
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.text = BODY_TEXT
	box.add_child(_body)

	var footer := HBoxContainer.new()
	box.add_child(footer)

	_hint = Label.new()
	_hint.text = "[ ESC ] CLOSE"
	_hint.modulate = Color(1, 1, 1, 0.5)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_hint)

	_btn = Button.new()
	_btn.text = "[ ACKNOWLEDGE ]"
	_btn.custom_minimum_size = Vector2(0, 48)
	_btn.pressed.connect(close)
	footer.add_child(_btn)

	add_child(_flash)   # last, so the flash covers everything

func _play() -> void:
	_calm = Settings.photosensitive()
	_shake = shake_strength * Settings.shake_scale()

	_panel.scale = Vector2.ZERO
	_tag.modulate.a = 0.0
	_title.modulate.a = 0.0
	_title.scale = Vector2.ONE * (calm_title_start_scale if _calm else title_start_scale)
	_sub.visible_ratio = 0.0
	_body.visible_ratio = 0.0
	_hint.modulate.a = 0.0
	_btn.modulate.a = 0.0
	_btn.disabled = true
	_typing = true

	await get_tree().process_frame   # wait for layout so the pivots are correct
	_title.pivot_offset = _title.size / 2.0
	_panel.pivot_offset = _panel.size / 2.0

	_tween = create_tween()
	_tween.tween_property(_vignette, "intensity", backdrop_intensity, intensity_fade)
	_tween.parallel().tween_property(_panel, "scale", Vector2.ONE, window_open_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_slam)
	_tween.tween_property(_title, "modulate:a", 1.0, 0.05)
	_tween.parallel().tween_property(_title, "scale", Vector2.ONE, title_slam_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_tag, "modulate:a", 1.0, tag_fade_time)
	_tween.tween_property(_sub, "visible_ratio", 1.0, sub_type_time)
	_tween.tween_property(_body, "visible_ratio", 1.0, body_type_time)
	_tween.tween_callback(_finish)

func _slam() -> void:
	if _calm:
		return
	_flash.color = Color(1, 1, 1, slam_flash_alpha)
	_slam_tween = create_tween().set_parallel(true)
	_slam_tween.tween_property(_flash, "color:a", 0.0, slam_flash_fade)
	_slam_tween.tween_method(_do_shake, 1.0, 0.0, slam_shake_time)

func _do_shake(s : float) -> void:
	position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * s

func _finish() -> void:
	_typing = false
	_btn.disabled = false
	_btn.grab_focus()
	var t := create_tween().set_parallel(true)
	t.tween_property(_btn, "modulate:a", 1.0, 0.2)
	t.tween_property(_hint, "modulate:a", 0.5, 0.2)
	if not _calm:
		_blink = create_tween().set_loops()
		_blink.tween_property(_tag, "modulate:a", blink_min_alpha, blink_time)
		_blink.tween_property(_tag, "modulate:a", 1.0, blink_time)

## Jumps straight to the finished state (any key or click while it is typing).
func _skip() -> void:
	_kill_tweens()
	position = Vector2.ZERO
	_flash.color = Color(1, 1, 1, 0)
	_vignette.intensity = backdrop_intensity
	_panel.scale = Vector2.ONE
	_title.scale = Vector2.ONE
	_title.modulate.a = 1.0
	_tag.modulate.a = 1.0
	_sub.visible_ratio = 1.0
	_body.visible_ratio = 1.0
	_finish()

func _input(event : InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif _typing:
		var pressed = (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed)
		if pressed:
			get_viewport().set_input_as_handled()
			_skip()

func close() -> void:
	if _closing:
		return
	_closing = true
	_kill_tweens()
	position = Vector2.ZERO
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	await t.finished
	closed.emit()
	queue_free()

func _kill_tweens() -> void:
	if _tween: _tween.kill()
	if _slam_tween: _slam_tween.kill()
	if _blink: _blink.kill()