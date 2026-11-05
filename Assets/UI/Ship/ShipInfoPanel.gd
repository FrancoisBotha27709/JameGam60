extends Control
class_name ShipInfoPanel

@export var node_title : Label
@export var node_data : RichTextLabel

@export var padding : float = 8.0:
	set(value):
		padding = maxf(value, 0.0)
		_layout()

@export var title_height : float = 24.0:
	set(value):
		title_height = maxf(value, 0.0)
		_layout()

@export var title_gap : float = 4.0:
	set(value):
		title_gap = maxf(value, 0.0)
		_layout()

@export_group("Typewriter")
@export var chars_per_second : float = 90.0
@export var replace_chars_per_second : float = 700.0
## How many characters ahead of the reveal show random symbols.
@export_range(0, 12) var scramble_window : int = 3
@export var scramble_glyphs : String = "█▓▒░▚▞◆◇○●□■△▲▽▼◈⌬⎔≡∑∆∇Ω¤§¶ϟᚠᚢᚦᚨᚱ"
@export var key_color : Color = Color("#aaaaaa")
@export var value_color : Color = Color("#ffffff")

var _title : String = ""
var _data : Dictionary = {}
var _title_parsed : Dictionary = {"tokens": [], "length": 0}
var _entries : Array[Dictionary] = []
var _total_chars : int = 0
var _reveal : float = 0.0
var _tween : Tween
var _tag_regex := RegEx.new()

var _play_pending : bool = false
var _pending_replace : bool = false
var _pending_delay : float = 0.0


func _ready() -> void:
	_ensure_regex()

	if is_instance_valid(node_data):
		node_data.bbcode_enabled = true

	_layout()

	if _play_pending:
		_play_pending = false
		_play(_pending_replace, _pending_delay)
	else:
		_render()


## animate: play the typewriter. replace: use the fast speed (ship swap).
## delay: seconds to wait before typing starts.
func setup(title: String, data: Dictionary, animate: bool = true,
		replace: bool = false, delay: float = 0.0) -> void:
	_ensure_regex()

	_title = title
	_data = data.duplicate(true)
	_rebuild_entries()

	if is_instance_valid(node_data):
		node_data.bbcode_enabled = true

	_layout()
	_stop_tween()

	if not animate:
		_set_reveal(float(_total_chars))
		return

	# Start fully hidden (the scramble window sits "before" zero).
	_set_reveal(-float(scramble_window))

	if is_inside_tree():
		_play(replace, delay)
	else:
		_play_pending = true
		_pending_replace = replace
		_pending_delay = delay


func get_title() -> String:
	return _title


func set_title(value: String) -> void:
	setup(value, _data, false)


func get_data() -> Dictionary:
	return _data.duplicate(true)


func set_data(value: Dictionary) -> void:
	setup(_title, value, false)


func _ensure_regex() -> void:
	if not _tag_regex.is_valid():
		_tag_regex.compile("\\[/?[a-zA-Z][^\\[\\]]*\\]")


func _play(replace: bool, delay: float) -> void:
	_stop_tween()

	var cps := maxf(
		replace_chars_per_second if replace else chars_per_second,
		1.0
	)
	var start := -float(scramble_window)
	var end := float(_total_chars)

	_tween = create_tween()

	if delay > 0.0:
		_tween.tween_interval(delay)

	_tween.tween_method(_set_reveal, start, end, maxf((end - start) / cps, 0.001))


func _stop_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _set_reveal(value: float) -> void:
	_reveal = value
	_render()


func _rebuild_entries() -> void:
	_entries.clear()

	_title_parsed = _parse(_title, false)
	var offset: int = _title_parsed.get("length", 0)

	for key in _data:
		var value: Variant = _data[key]
		var value_text: String = ("%.2f" % value) if value is float else str(value)

		var key_parsed := _parse(str(key), true)
		var value_parsed := _parse(value_text, true)
		var key_len: int = key_parsed["length"]
		var value_len: int = value_parsed["length"]

		_entries.append({
			"key": key_parsed,
			"value": value_parsed,
			"key_start": offset,
			"value_start": offset + key_len,
		})

		offset += key_len + value_len

	_total_chars = offset


func _render() -> void:
	var reveal := int(floor(_reveal))

	if is_instance_valid(node_title):
		node_title.text = _render_tokens(_title_parsed, 0, reveal, false)

	if is_instance_valid(node_data):
		node_data.text = _build_bbcode(reveal)


func _build_bbcode(reveal: int) -> String:
	var lines := PackedStringArray()
	var key_hex := key_color.to_html(false)
	var value_hex := value_color.to_html(false)
	var limit := reveal + scramble_window

	for entry in _entries:
		var key_start: int = entry["key_start"]
		if limit - key_start <= 0:
			break

		var key_text := _render_tokens(entry["key"], key_start, reveal, true)
		var line := "[color=#%s]%s[/color]" % [key_hex, key_text]

		# Only add the gap and value once the key is fully on screen.
		var value_start: int = entry["value_start"]
		if limit - value_start > 0:
			var value_text := _render_tokens(entry["value"], value_start, reveal, true)
			line += "  [color=#%s]%s[/color]" % [value_hex, value_text]

		lines.append(line)

	return "\n".join(lines)


## Splits text into BBCode tags and plain text. Tags don't count toward length.
func _parse(text: String, parse_tags: bool) -> Dictionary:
	var tokens: Array[Dictionary] = []
	var length := 0

	if not parse_tags:
		tokens.append({"tag": false, "text": text})
		return {"tokens": tokens, "length": text.length()}

	_ensure_regex()
	var pos := 0

	for m in _tag_regex.search_all(text):
		if m.get_start() > pos:
			var plain := text.substr(pos, m.get_start() - pos)
			tokens.append({"tag": false, "text": plain})
			length += plain.length()
		tokens.append({"tag": true, "text": m.get_string()})
		pos = m.get_end()

	if pos < text.length():
		var rest := text.substr(pos)
		tokens.append({"tag": false, "text": rest})
		length += rest.length()

	return {"tokens": tokens, "length": length}


## Tags pass through untouched. Visible characters before `reveal` are real,
## the next `scramble_window` are random glyphs, the rest are hidden.
func _render_tokens(parsed: Dictionary, start: int, reveal: int, escape: bool) -> String:
	var out := ""
	var stack: Array[String] = []
	var index := start
	var limit := reveal + scramble_window
	var cut := false

	for token in parsed.get("tokens", []):
		var text: String = token["text"]

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
				out += "[lb]" if (escape and c == "[") else c
			else:
				out += c if c == " " else _random_glyph()

			index += 1

		if cut:
			break

	# Close anything still open so partial text never leaves broken markup.
	for i in range(stack.size() - 1, -1, -1):
		out += "[/%s]" % stack[i]

	return out


func _random_glyph() -> String:
	if scramble_glyphs.is_empty():
		return "#"
	return scramble_glyphs[randi() % scramble_glyphs.length()]


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	if not is_inside_tree():
		return

	if is_instance_valid(node_title):
		node_title.position = Vector2(padding, padding)
		node_title.size = Vector2(
			maxf(size.x - padding * 2.0, 0.0),
			title_height
		)

	if is_instance_valid(node_data):
		node_data.position = Vector2(
			padding,
			padding + title_height + title_gap
		)
		node_data.size = Vector2(
			maxf(size.x - padding * 2.0, 0.0),
			maxf(size.y - padding * 2.0 - title_height - title_gap, 0.0)
		)
