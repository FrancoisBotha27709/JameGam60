extends Control
class_name TutorialPopup

signal closed
signal open
signal page_changed(index : int)
signal typing(value : bool)
signal typing_started
signal typing_stopped

const COLOR_KEY := "#ffd27f"
const COLOR_GOOD := "#7dffb0"
const COLOR_WARN := "#ffd24a"
const COLOR_BAD := "#ff6b6b"
const COLOR_INFO := "#8be9ff"
const COLOR_DIM := "#8a97a6"

## Optional. Leave empty if the theme is inherited from the menu or set project-wide.
@export var ui_theme : Theme
@export var tint : Color = Color(0.3, 0.85, 1.0)
@export var panel_size : Vector2 = Vector2(900, 680)

@export_group("Text")
@export var body_font_size : int = 24
@export var body_line_spacing : int = 8

@export_group("Typewriter")
@export var chars_per_second : float = 130.0
## Extra delay, measured in characters, after each kind of punctuation.
@export var comma_pause : float = 4.0
@export var sentence_pause : float = 9.0
@export var newline_pause : float = 3.0
## How many characters ahead of the reveal show random symbols.
@export_range(0, 12) var scramble_window : int = 3
@export var scramble_glyphs : String = "█▓▒░▚▞◆◇○●□■△▲▽▼◈⌬⎔≡∑∆∇Ω¤§¶ϟᚠᚢᚦᚨᚱ"

@export_group("Timing")
@export var intensity_fade : float = 0.3
@export_range(0.0, 1.0) var backdrop_intensity : float = 0.35
@export var window_open_time : float = 0.25
@export var title_slam_time : float = 0.3
@export var title_start_scale : float = 2.5
@export var calm_title_start_scale : float = 1.2
@export var tag_fade_time : float = 0.2

@export_group("Slam")
@export_range(0.0, 1.0) var slam_flash_alpha : float = 0.35
@export var slam_flash_fade : float = 0.25
@export var slam_shake_time : float = 0.4
@export var shake_strength : float = 10.0

@export_group("Tag Blink")
@export var blink_time : float = 0.5
@export_range(0.0, 1.0) var blink_min_alpha : float = 0.25

# Nodes that live in TutorialPopup.tscn.
@export var _flash : ColorRect
@export var _panel : PanelContainer
@export var _tag : Label
@export var _title : Label
@export var _sub : Label
@export var _body : RichTextLabel
@export var _hint : Label
@export var _btn : Button

# Created in code.
var _vignette : DitherVignette
var _nav : HBoxContainer
var _prev_btn : Button
var _next_btn : Button
var _page_label : Label

var _tween : Tween
var _slam_tween : Tween
var _blink : Tween
var _calm : bool = false
var _shake : float = 0.0
var _closing : bool = false
var _finished : bool = false

var _pages : Array[Dictionary] = []
var _page : int = 0

# Typewriter state.
var _is_typing : bool = false
var _typing_signal : bool = false
var _type_target : Control
var _type_text : String = ""
var _type_total : int = 0
var _type_shown : int = 0
var _type_wait : float = 0.0
var _type_done : Callable
var _type_full : String = ""
var _type_parsed : Dictionary = {}

var _tag_regex := RegEx.new()
var _sub_full : String = ""

func _ready() -> void:
	if ui_theme != null:
		theme = ui_theme

	_tag_regex.compile("\\[/?[a-zA-Z][^\\[\\]]*\\]")
	_sub_full = _sub.text

	_apply_style()
	_add_vignette()
	_build_nav()
	_btn.pressed.connect(close)
	set_process(false)
	visible = false   # stays hidden until show_popup() is called

## Call this from the menu to play the intro animation.
func show_popup() -> void:
	if visible:
		return

	# Reset anything a previous run left behind.
	_kill_tweens()
	_cancel_typing()
	_closing = false
	modulate.a = 1.0
	position = Vector2.ZERO
	_vignette.intensity = 0.0
	_flash.color = Color(1, 1, 1, 0)

	_build_pages()   # rebuilt each time so the key names match the current control mode
	visible = true
	_play()

func close() -> void:
	if _closing:
		return
	_closing = true
	_kill_tweens()
	_cancel_typing()
	position = Vector2.ZERO
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	await t.finished
	visible = false
	closed.emit()

func go_to_page(index : int) -> void:
	if not _finished:
		return
	index = clampi(index, 0, _pages.size() - 1)
	if index == _page:
		return
	_page = index
	_show_page()
	_begin_typing(_body, _pages[_page]["text"], Callable())
	page_changed.emit(_page)

#endregion
#region Style

## Applies the exported tint and panel size on top of the scene's defaults.
func _apply_style() -> void:
	var vp := get_viewport_rect().size
	_panel.custom_minimum_size = Vector2(
		minf(panel_size.x, vp.x * 0.92),
		minf(panel_size.y, vp.y * 0.92))

	_tag.add_theme_color_override("font_color", tint)
	_title.add_theme_color_override("font_color", tint)
	_sub.add_theme_color_override("font_color", tint.lerp(Color.WHITE, 0.55))

	# The StyleBoxFlat is local to the scene, so this only affects this popup.
	var style := _panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.bg_color = Color(0.04, 0.06, 0.09, 0.95)
		style.border_color = tint
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.shadow_color = Color(tint, 0.25)
		style.shadow_size = 24

	var rule := get_node_or_null("Center/Panel/Margin/Box/Rule") as ColorRect
	if rule != null:
		rule.color = Color(tint, 0.6)

	# Inner reading panel with larger text and more breathing room.
	var reading_panel := StyleBoxFlat.new()
	reading_panel.bg_color = Color(0, 0, 0, 0.35)
	reading_panel.border_color = Color(tint, 0.3)
	reading_panel.set_border_width_all(1)
	reading_panel.set_corner_radius_all(4)
	reading_panel.set_content_margin_all(20)
	_body.bbcode_enabled = true
	_body.add_theme_stylebox_override("normal", reading_panel)
	_body.add_theme_font_size_override("normal_font_size", body_font_size)
	_body.add_theme_font_size_override("bold_font_size", body_font_size)
	_body.add_theme_constant_override("line_separation", body_line_spacing)

## Dithered vignette, shared with the run-end banner. Sits above the dim layer
## and below the panel.
func _add_vignette() -> void:
	_vignette = DitherVignette.new()
	_vignette.tint = tint
	_vignette.intensity = 0.0
	add_child(_vignette)
	_vignette.fill_parent()

# Adds [<] 1 / 4 [>] to the footer, just before the acknowledge button.
func _build_nav() -> void:
	var footer := _btn.get_parent()

	_nav = HBoxContainer.new()
	_nav.add_theme_constant_override("separation", 10)
	_nav.modulate.a = 0.0

	_prev_btn = _make_nav_button("[ < ]", -1)
	_next_btn = _make_nav_button("[ > ]", 1)

	_page_label = Label.new()
	_page_label.custom_minimum_size = Vector2(90, 0)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_nav.add_child(_prev_btn)
	_nav.add_child(_page_label)
	_nav.add_child(_next_btn)

	footer.add_child(_nav)
	footer.move_child(_nav, _btn.get_index())

	_hint.text = "[ ← → ] PAGE    [ ESC ] CLOSE"

func _make_nav_button(label : String, step : int) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(56, 48)
	button.disabled = true
	button.pressed.connect(_step_page.bind(step))
	return button

func _step_page(step : int) -> void:
	go_to_page(_page + step)

func _update_nav() -> void:
	_prev_btn.disabled = not _finished or _page <= 0
	_next_btn.disabled = not _finished or _page >= _pages.size() - 1
	_page_label.text = "%d / %d" % [_page + 1, _pages.size()]

#endregion
#region Content

func _build_pages() -> void:
	var mouse_mode := Settings.get_controls() == Settings.CONTROLS.MOUSE
	var forward := _action_key(PlayerInput.ACTION_FORWARD, "W")
	var boost := _action_key(PlayerInput.ACTION_BOOST, "SPACE")
	var brake := _action_key(PlayerInput.ACTION_BACKWARD, "S")

	var steering : String
	if mouse_mode:
		steering = _k("MOUSE") + "  Move the mouse. The ship turns to face the cursor."
	else:
		steering = _k(_bound_key(PlayerInput.ACTION_TURN_LEFT, "A")) + " " \
			+ _k(_bound_key(PlayerInput.ACTION_TURN_RIGHT, "D")) + "  Rotate the ship."

	_pages.clear()

	_pages.append({"title": "FLIGHT", "text":
		_heading("01", "FLIGHT")
		+ _dim("Learn to fly first. Everything else depends on it.") + "\n\n"
		+ steering + "\n"
		+ _k(forward) + "  " + _c(COLOR_INFO, "Tap") + " for a short burst. "
		+ _c(COLOR_INFO, "Hold") + " to ramp the throttle up and keep accelerating.\n"
		+ _k(boost) + "  Boost: a higher top speed, but it burns " + _c(COLOR_BAD, "2x fuel") + ".\n"
		+ _k(brake) + "  Brake: cuts the throttle and slows you down.\n\n"
		+ _dim("TIP: There is no air to stop you. Let go and you keep drifting, so start turning early.")})

	_pages.append({"title": "OBJECTIVE", "text":
		_heading("02", "OBJECTIVE")
		+ _dim("Clean up the debris field and hit the quota.") + "\n\n"
		+ _badge("01", COLOR_INFO) + " Fly into " + _c(COLOR_KEY, "debris") + " to grab it. It trails behind you on a rope.\n"
		+ _badge("02", COLOR_INFO) + " Fly into the " + _c(COLOR_GOOD, "Depot") + " to deliver everything you carry. Only delivered debris counts.\n"
		+ _badge("03", COLOR_INFO) + " Reach the " + _c(COLOR_KEY, "quota") + " before time or fuel runs out.\n\n"
		+ _badge("OK", COLOR_GOOD) + " Meet the quota to pick an upgrade and start the next, harder run."})

	_pages.append({"title": "DEBRIS", "text":
		_heading("03", "DEBRIS")
		+ _dim("Not all junk is worth the same.") + "\n\n"
		+ "[table=2]"
		+ _row("PLASTIC", "#cfcfcf", "x1.0 value")
		+ _row("METAL", "#c0c8d0", "x1.5 value")
		+ _row("CEMENT", "#d8b98a", "x2.0 value")
		+ "[/table]\n"
		+ _badge("ANOMALY", COLOR_INFO) + " Blue flashing debris is quantum. Worth " + _c(COLOR_INFO, "x3") + ", but it teleports away if you get close and don't grab it fast.\n\n"
		+ _badge("WARN", COLOR_WARN) + " Everything you carry slows you down and burns more fuel. Deliver often instead of hoarding."})

	_pages.append({"title": "DANGERS", "text":
		_heading("04", "DANGERS")
		+ _dim("Three things end runs. Keep an eye on all of them.") + "\n\n"
		+ _badge("FUEL", COLOR_BAD) + " An alarm sounds when you drop to " + _c(COLOR_WARN, "30%") + ". At zero the engine sputters out and the run ends.\n"
		+ _badge("HEAT", COLOR_BAD) + " Tapping thrust rapidly and holding it both build heat. Ease off to cool down. At maximum a " + _c(COLOR_BAD, "meltdown countdown") + " starts, and if it runs out the ship explodes.\n"
		+ _badge("ROCKS", COLOR_WARN) + " Asteroids bounce you away and lock your controls for a moment while you tumble. Route around the big ones."})

func _heading(number : String, text : String) -> String:
	return "[font_size=%d][color=#%s][b]%s // %s[/b][/color][/font_size]\n" \
		% [body_font_size + 10, tint.to_html(false), number, text]

func _c(color : String, text : String) -> String:
	return "[color=%s]%s[/color]" % [color, text]

func _dim(text : String) -> String:
	return _c(COLOR_DIM, text)

# A keycap-style label.
func _k(label : String) -> String:
	return "[bgcolor=#1d2a36][color=%s][b] %s [/b][/color][/bgcolor]" % [COLOR_KEY, label]

# A tag like [ FUEL ]. [lb] and [rb] are BBCode escapes for the brackets.
func _badge(label : String, color : String) -> String:
	return "[color=%s][b][lb] %s [rb][/b][/color]" % [color, label]

func _row(label : String, color : String, value : String) -> String:
	return _c(color, "[b]" + label + "[/b]") + "   " + value + "\n"

# Key name for a logical action in the current control scheme.
func _action_key(action : StringName, fallback : String) -> String:
	var mouse_mode := Settings.get_controls() == Settings.CONTROLS.MOUSE
	var prefix := PlayerInput.MOUSE_PREFIX if mouse_mode else PlayerInput.KEYBOARD_PREFIX
	return _bound_key(StringName(prefix + action), fallback)

# First bound input of an InputMap action as text, or the fallback if unbound.
func _bound_key(action_name : StringName, fallback : String) -> String:
	if not InputMap.has_action(action_name):
		return fallback
	for input_event in InputMap.action_get_events(action_name):
		if input_event is InputEventKey:
			var key_event := input_event as InputEventKey
			var key_text := key_event.as_text_physical_keycode() \
				if key_event.physical_keycode != KEY_NONE else key_event.as_text_keycode()
			return key_text.to_upper()
		return input_event.as_text().to_upper()
	return fallback

func _show_page() -> void:
	_body.text = ""
	_update_nav()

#endregion
#region Intro

func _play() -> void:
	_calm = Settings.photosensitive()
	_shake = shake_strength * Settings.shake_scale()
	_finished = false
	_page = 0

	_panel.scale = Vector2.ZERO
	_tag.modulate.a = 0.0
	_title.modulate.a = 0.0
	_title.scale = Vector2.ONE * (calm_title_start_scale if _calm else title_start_scale)
	_sub.text = ""
	_show_page()
	_hint.modulate.a = 0.0
	_btn.modulate.a = 0.0
	_btn.disabled = true
	_nav.modulate.a = 0.0

	await get_tree().process_frame   # wait for layout so the pivots are correct
	if _finished or _closing or not visible:
		return   # skipped or closed while waiting

	_title.pivot_offset = _title.size / 2.0
	_panel.pivot_offset = _panel.size / 2.0
	open.emit()
	_tween = create_tween()
	_tween.tween_property(_vignette, "intensity", backdrop_intensity, intensity_fade)
	_tween.parallel().tween_property(_panel, "scale", Vector2.ONE, window_open_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_slam)
	_tween.tween_property(_title, "modulate:a", 1.0, 0.05)
	_tween.parallel().tween_property(_title, "scale", Vector2.ONE, title_slam_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_tag, "modulate:a", 1.0, tag_fade_time)
	_tween.tween_callback(_type_sub)   # sub line types first, then the first page

func _slam() -> void:
	if _calm:
		return
	_flash.color = Color(1, 1, 1, slam_flash_alpha)
	_slam_tween = create_tween().set_parallel(true)
	_slam_tween.tween_property(_flash, "color:a", 0.0, slam_flash_fade)
	_slam_tween.tween_method(_do_shake, 1.0, 0.0, slam_shake_time)

func _do_shake(s : float) -> void:
	position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * s

func _type_sub() -> void:
	_begin_typing(_sub, _sub_full, _type_first_page)

func _type_first_page() -> void:
	_begin_typing(_body, _pages[_page]["text"], _finish)

func _finish() -> void:
	if _finished:
		return
	_finished = true
	_btn.disabled = false
	_btn.grab_focus()
	_update_nav()
	var t := create_tween().set_parallel(true)
	t.tween_property(_btn, "modulate:a", 1.0, 0.2)
	t.tween_property(_hint, "modulate:a", 0.5, 0.2)
	t.tween_property(_nav, "modulate:a", 1.0, 0.2)
	if not _calm:
		if _blink:
			_blink.kill()
		_blink = create_tween().set_loops()
		_blink.tween_property(_tag, "modulate:a", blink_min_alpha, blink_time)
		_blink.tween_property(_tag, "modulate:a", 1.0, blink_time)

## Jumps straight to the finished state (any key or click during the intro).
func _skip() -> void:
	_kill_tweens()
	_cancel_typing()
	position = Vector2.ZERO
	_flash.color = Color(1, 1, 1, 0)
	_vignette.intensity = backdrop_intensity
	_panel.scale = Vector2.ONE
	_title.scale = Vector2.ONE
	_title.modulate.a = 1.0
	_tag.modulate.a = 1.0
	_sub.text = _sub_full
	_body.text = _pages[_page]["text"]
	_finish()

#endregion
#region Typewriter

# Reveals the target one character at a time, then calls `done` (may be an empty Callable).
# Reveals `full_text` on the target one character at a time, then calls `done`
# (may be an empty Callable). Characters just ahead of the reveal show random glyphs.
func _begin_typing(target : Control, full_text : String, done : Callable) -> void:
	_type_target = target
	_type_full = full_text
	_type_done = done
	_type_parsed = _parse_text(full_text, target is RichTextLabel)
	_type_text = _type_parsed["plain"]
	_type_total = _type_parsed["length"]
	_type_shown = -scramble_window
	_type_wait = 0.0
	_is_typing = true
	_render_typed()
	set_process(true)
	_emit_typing(true)


func _process(delta : float) -> void:
	if not _is_typing:
		return

	var step := 1.0 / maxf(chars_per_second, 1.0)
	_type_wait -= delta

	while _type_wait <= 0.0 and _type_shown < _type_total:
		_type_wait += step * (1.0 + _pause_after(_type_shown))
		_type_shown += 1

	_render_typed()

	if _type_shown >= _type_total:
		_end_typing()


# Extra pause (in characters) after the character at `index`.
func _pause_after(index : int) -> float:
	if index < 0 or index >= _type_text.length():
		return 0.0
	var current := _type_text[index]
	var next := _type_text[index + 1] if index + 1 < _type_text.length() else ""
	match current:
		"\n":
			return newline_pause
		",", ";", ":":
			return comma_pause
		".", "!", "?":
			# No pause inside numbers like x1.5.
			return 0.0 if next.is_valid_int() else sentence_pause
	return 0.0


# Finishes the current text instantly (no leftover glyphs) and runs its done callback.
func _end_typing() -> void:
	if not _is_typing:
		return
	_is_typing = false
	set_process(false)
	_set_target_text(_type_full)

	var done := _type_done
	_type_done = Callable()
	if done.is_valid():
		done.call()   # may start the next typing run

	if not _is_typing:
		_emit_typing(false)


# Stops typing without running the done callback.
func _cancel_typing() -> void:
	_is_typing = false
	_type_done = Callable()
	set_process(false)
	_emit_typing(false)


func _emit_typing(value : bool) -> void:
	if _typing_signal == value:
		return
	_typing_signal = value
	typing.emit(value)
	if value:
		typing_started.emit()
	else:
		typing_stopped.emit()


func _render_typed() -> void:
	_set_target_text(_build_typed(_type_shown, _type_target is RichTextLabel))


# Only assigns when the text changed, since setting text re-parses it.
func _set_target_text(text : String) -> void:
	if _type_target.get("text") != text:
		_type_target.set("text", text)


# Splits text into BBCode tags and plain text. Tags don't count toward length,
# and [lb] / [rb] count as one character each.
func _parse_text(text : String, rich : bool) -> Dictionary:
	var tokens : Array[Dictionary] = []
	var length := 0
	var plain := ""

	if not rich:
		tokens.append({"tag": false, "text": text})
		return {"tokens": tokens, "length": text.length(), "plain": text}

	var buffer := ""
	var pos := 0

	for m in _tag_regex.search_all(text):
		buffer += text.substr(pos, m.get_start() - pos)
		var tag := m.get_string()
		if tag == "[lb]":
			buffer += "["
		elif tag == "[rb]":
			buffer += "]"
		else:
			if not buffer.is_empty():
				tokens.append({"tag": false, "text": buffer})
				length += buffer.length()
				plain += buffer
				buffer = ""
			tokens.append({"tag": true, "text": tag})
		pos = m.get_end()

	buffer += text.substr(pos)
	if not buffer.is_empty():
		tokens.append({"tag": false, "text": buffer})
		length += buffer.length()
		plain += buffer

	return {"tokens": tokens, "length": length, "plain": plain}


# Characters before `reveal` are real, the next `scramble_window` are random glyphs,
# the rest are hidden. Tags pass through and any still open are closed at the cut.
func _build_typed(reveal : int, rich : bool) -> String:
	var out := ""
	var stack : Array[String] = []
	var index := 0
	var limit := reveal + scramble_window
	var cut := false

	for token in _type_parsed["tokens"]:
		var text : String = token["text"]

		if token["tag"]:
			out += text
			if text.begins_with("[/"):
				if not stack.is_empty():
					stack.pop_back()
			else:
				stack.append(text.substr(1, text.length() - 2).split("=")[0].split(" ")[0])
			continue

		for c in text:
			if index >= limit:
				cut = true
				break

			if index < reveal:
				out += _escape_char(c, rich)
			elif c == " " or c == "\n":
				out += c
			else:
				out += _random_glyph()

			index += 1

		if cut:
			break

	for i in range(stack.size() - 1, -1, -1):
		out += "[/%s]" % stack[i]

	return out


func _escape_char(c : String, rich : bool) -> String:
	if not rich:
		return c
	if c == "[":
		return "[lb]"
	if c == "]":
		return "[rb]"
	return c


func _random_glyph() -> String:
	if scramble_glyphs.is_empty():
		return "#"
	return scramble_glyphs[randi() % scramble_glyphs.length()]

func _plain_text(target : Control) -> String:
	if target is RichTextLabel:
		return (target as RichTextLabel).get_parsed_text()
	return (target as Label).text

func _total_chars(target : Control) -> int:
	if target is RichTextLabel:
		return (target as RichTextLabel).get_total_character_count()
	return (target as Label).get_total_character_count()

#endregion
#region Input

func _input(event : InputEvent) -> void:
	if not visible or _closing:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return

	if _finished:
		if event.is_action_pressed("ui_left"):
			get_viewport().set_input_as_handled()
			go_to_page(_page - 1)
		elif event.is_action_pressed("ui_right"):
			get_viewport().set_input_as_handled()
			go_to_page(_page + 1)
		elif _is_typing and event is InputEventKey and event.pressed and not event.echo:
			# Any key finishes the page text instantly. Clicks still reach the buttons.
			get_viewport().set_input_as_handled()
			_end_typing()
		return

	var pressed := false
	if event is InputEventKey:
		var k := event as InputEventKey
		pressed = k.pressed and not k.echo
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		pressed = m.pressed

	if pressed:
		get_viewport().set_input_as_handled()
		_skip()

func _kill_tweens() -> void:
	if _tween: _tween.kill()
	if _slam_tween: _slam_tween.kill()
	if _blink: _blink.kill()