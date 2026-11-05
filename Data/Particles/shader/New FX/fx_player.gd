@tool
class_name FXPlayer
extends Node2D
## Builds a layered particle effect from an FXPresets preset and plays it.
## Pick a preset in the inspector and it previews live in the editor.
##
## Runtime use:
##   $Fx.play() / $Fx.stop() / $Fx.power = 0.5
##   FXPlayer.spawn("explosion", get_parent(), global_position)       # fire-and-forget
##   $Fx.set_param("turb_amp", 80.0)                                   # any uniform, all layers
##   $Fx.set_param("size_start", 1.2, "flame")                         # one layer only
##
## The two shader files must sit next to this script (or assign sim_shader / draw_shader).

signal finished

enum PlayMode { PRESET, LOOP, ONCE }

const PALETTE_KEYS : Array[String] = ["col_core", "col_hot", "col_mid", "col_cool"]
const DEFAULT_PIXEL_PX := 2.0

static var _quad_tex : Texture2D

@export var preset : String = "fire":
	set(v):
		preset = v
		_dirty()
@export var autoplay : bool = true
@export var play_mode : PlayMode = PlayMode.PRESET:
	set(v):
		play_mode = v
		_dirty()
@export var free_on_finish : bool = false
@export_tool_button("Replay") var replay_preview : Callable = play

@export_group("Tuning")
## Scales particle speed AND size (same meaning as your old `power` uniform).
@export_range(0.0, 2.0, 0.01) var power : float = 1.0:
	set(v):
		power = v
		_apply_runtime()
## Fraction of particles emitted (layers with fewer than 8 particles are unaffected).
@export_range(0.05, 1.0, 0.01) var density : float = 1.0:
	set(v):
		density = v
		_apply_runtime()
@export_range(0.1, 3.0, 0.05) var time_scale : float = 1.0:
	set(v):
		time_scale = v
		_apply_runtime()
## Multiplies every layer's pixel-chunk size. 1 = preset default, 0 = quad-relative `pixel_res` like your original shader.
@export_range(0.0, 8.0, 0.1) var pixel_scale : float = 1.0:
	set(v):
		pixel_scale = v
		_dirty()

@export_group("Colour")
## Replaces the ramp, in this order: core (brightest), hot, mid, cool (darkest). Leave empty to use the preset's colours.
@export var palette_override : Array[Color] = []:
	set(v):
		palette_override = v
		_dirty()
## Limit palette_override to these layer names (empty = all layers).
@export var palette_layers : PackedStringArray = PackedStringArray():
	set(v):
		palette_layers = v
		_dirty()

@export_group("Overrides")
## {"uniform": value} applied to every layer's SIM shader, e.g. {"speed_max": 300.0}
@export var sim_overrides : Dictionary = {}:
	set(v):
		sim_overrides = v
		_dirty()
## {"uniform": value} applied to every layer's DRAW shader, e.g. {"additive": 1.0}
@export var draw_overrides : Dictionary = {}:
	set(v):
		draw_overrides = v
		_dirty()
## {"layer_name": {"sim": {...}, "draw": {...}}}  - wins over everything above.
@export var layer_overrides : Dictionary = {}:
	set(v):
		layer_overrides = v
		_dirty()

@export_group("Shaders")
@export var sim_shader : Shader
@export var draw_shader : Shader

var _layers : Array[Dictionary] = []
var _playing := false
var _has_loop := false
var _pending := 0
var _play_token := 0


func _validate_property(property: Dictionary) -> void:
	if property.name == "preset":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(FXPresets.names())


func _ready() -> void:
	rebuild()
	if autoplay or Engine.is_editor_hint():
		play()


# ----------------------------------------------------------------------------
# public API
# ----------------------------------------------------------------------------

func play() -> void:
	_play_token += 1
	_playing = true
	_pending = 0
	_has_loop = false
	for l in _layers:
		var p := l["node"] as GPUParticles2D
		var once := _layer_one_shot(l)
		p.one_shot = once
		if once:
			_pending += 1
		else:
			_has_loop = true
		var delay : float = l["delay"]
		if delay > 0.0 and is_inside_tree():
			p.restart()
			p.emitting = false   # clear old particles, wait for the delay
			get_tree().create_timer(delay / maxf(time_scale, 0.01)).timeout.connect(_start_layer.bind(l, _play_token))
		else:
			p.restart()


## Stops emitting; particles already alive finish their life.
func stop() -> void:
	_play_token += 1
	_playing = false
	for l in _layers:
		(l["node"] as GPUParticles2D).emitting = false


## Removes every live particle immediately.
func clear() -> void:
	_play_token += 1
	_playing = false
	for l in _layers:
		var p := l["node"] as GPUParticles2D
		p.restart()
		p.emitting = false


func is_one_shot() -> bool:
	for l in _layers:
		if not _layer_one_shot(l):
			return false
	return not _layers.is_empty()


func is_playing() -> bool:
	return _playing


## Set any shader uniform at runtime. layer = "" targets all layers.
func set_param(param: StringName, value: Variant, layer: String = "") -> void:
	for l in _layers:
		if layer != "" and (l["node"] as Node).name != layer:
			continue
		(l["sim"] as ShaderMaterial).set_shader_parameter(param, value)
		(l["draw"] as ShaderMaterial).set_shader_parameter(param, value)


## Rebuild all layers from the preset (called automatically when exported settings change).
func rebuild() -> void:
	_clear_layers()
	var def := FXPresets.get_preset(preset)
	if def.is_empty():
		push_warning("FXPlayer: unknown preset '%s'" % preset)
		return
	for ld in def["layers"]:
		_add_layer(ld as Dictionary)
	_apply_runtime()


## Fire-and-forget helper. Looping presets are returned so you can stop() them yourself.
static func spawn(preset_name: String, parent: Node, at: Vector2, rot: float = 0.0) -> FXPlayer:
	var fx := FXPlayer.new()
	fx.preset = preset_name
	fx.free_on_finish = true
	fx.position = at
	fx.rotation = rot
	parent.add_child(fx)
	return fx


# ----------------------------------------------------------------------------
# internals
# ----------------------------------------------------------------------------

func _dirty() -> void:
	if not is_node_ready():
		return
	var was_playing := _playing
	rebuild()
	if was_playing or Engine.is_editor_hint():
		play()


func _clear_layers() -> void:
	_play_token += 1
	for l in _layers:
		var n := l["node"] as Node
		if is_instance_valid(n):
			remove_child(n)
			n.queue_free()
	_layers.clear()
	_playing = false


func _layer_one_shot(l: Dictionary) -> bool:
	match play_mode:
		PlayMode.LOOP: return false
		PlayMode.ONCE: return true
	return l["one_shot"]


func _start_layer(l: Dictionary, token: int) -> void:
	if token != _play_token:
		return
	var p := l["node"] as GPUParticles2D
	if is_instance_valid(p):
		p.restart()


func _on_layer_finished() -> void:
	_pending -= 1
	if _pending <= 0 and not _has_loop and _playing:
		_playing = false
		finished.emit()
		if free_on_finish:
			queue_free()


func _apply_runtime() -> void:
	for l in _layers:
		(l["sim"] as ShaderMaterial).set_shader_parameter("power", power)
		var p := l["node"] as GPUParticles2D
		p.speed_scale = time_scale
		p.amount_ratio = density if p.amount >= 8 else 1.0


func _add_layer(ld: Dictionary) -> void:
	var sim := ShaderMaterial.new()
	sim.shader = _shader(sim_shader, "ship_particles.gdshader")
	var draw := ShaderMaterial.new()
	draw.shader = _shader(draw_shader, "ship_particles_draw.gdshader")

	var layer_name := str(ld.get("name", "layer"))
	var sd : Dictionary = (ld.get("sim", {}) as Dictionary).duplicate()
	var dd : Dictionary = (ld.get("draw", {}) as Dictionary).duplicate()

	# pixel grain: preset value * pixel_scale (0 -> fall back to quad-relative pixel_res)
	var base_px := float(dd.get("pixel_px", DEFAULT_PIXEL_PX))
	dd["pixel_px"] = base_px * pixel_scale

	if palette_override.size() > 0 and (palette_layers.is_empty() or layer_name in palette_layers):
		for i in mini(palette_override.size(), PALETTE_KEYS.size()):
			dd[PALETTE_KEYS[i]] = palette_override[i]

	sd.merge(sim_overrides, true)
	dd.merge(draw_overrides, true)
	if layer_overrides.has(layer_name):
		var lo : Dictionary = layer_overrides[layer_name]
		sd.merge(lo.get("sim", {}), true)
		dd.merge(lo.get("draw", {}), true)

	for k in sd:
		sim.set_shader_parameter(k, sd[k])
	for k in dd:
		draw.set_shader_parameter(k, dd[k])

	var p := GPUParticles2D.new()
	p.name = layer_name
	p.texture = _quad_texture()
	p.amount = int(ld.get("amount", 32))
	p.lifetime = float(ld.get("lifetime", 1.0))
	p.preprocess = float(ld.get("preprocess", 0.0))
	p.explosiveness = float(ld.get("explosiveness", 0.0))
	p.local_coords = bool(ld.get("local_coords", false))
	p.visibility_rect = ld.get("vis", Rect2(-300, -300, 600, 600))
	p.process_material = sim
	p.material = draw
	p.emitting = false
	p.finished.connect(_on_layer_finished)
	add_child(p, false, Node.INTERNAL_MODE_BACK)   # internal: never saved into your scene

	_layers.append({
		"node": p, "sim": sim, "draw": draw,
		"one_shot": bool(ld.get("one_shot", false)),
		"delay": float(ld.get("delay", 0.0)),
	})


func _shader(exported: Shader, file: String) -> Shader:
	if exported:
		return exported
	var dir := (get_script() as Script).resource_path.get_base_dir()
	return load(dir.path_join(file)) as Shader


static func _quad_texture() -> Texture2D:
	if _quad_tex == null:
		var tex := GradientTexture2D.new()
		tex.gradient = Gradient.new()
		tex.width = 16
		tex.height = 16
		_quad_tex = tex
	return _quad_tex