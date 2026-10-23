@tool
class_name FXEmitter
extends GPUParticles2D

const PRESET_DIR := "res://Data/Particles/Preset Particles/"
const SIM := preload("res://Data/Particles/shader/fx_particles_draw.gdshader")
const DRAW := preload("res://Data/Particles/shader/fx_particles_draw.gdshader")
const NODE_PROPS := ["amount", "lifetime", "one_shot", "explosiveness", "randomness", "preprocess",
		"speed_scale", "amount_ratio", "local_coords", "fixed_fps", "quad_px"]

static var _names : PackedStringArray
static var _types : Dictionary

@export var preset : String = "":
	set(v):
		preset = v
		if is_node_ready():
			apply()
@export_tool_button("Reset to preset", "Reload") var _reset_btn := reset
@export var apply_on_ready : bool = true
@export var quad_px : int = 16
@export var autoplay : bool = true
var _base_amount : int = 0

func _ready() -> void:
	_base_amount = amount
	if apply_on_ready and preset != "":
		apply()
	if Engine.is_editor_hint():
		return   # autoloads like Settings don't exist in the editor
	if not autoplay:
		emitting = false
	_apply_quality()
	Settings.changed.connect(_on_setting)

func _on_setting(key : String, _value : Variant) -> void:
	if key == "particle_quality":
		_apply_quality()

func _apply_quality() -> void:
	amount = maxi(1, roundi(_base_amount * Settings.particle_scale()))

func _validate_property(p : Dictionary) -> void:
	if p.name == "preset":
		_scan()
		p.hint = PROPERTY_HINT_ENUM
		p.hint_string = ",".join(_names)

func reset() -> void:
	_types.clear()
	_scan()
	notify_property_list_changed()
	apply()

func apply() -> void:
	var path := PRESET_DIR + preset + ".json"
	var d = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not (d is Dictionary):
		push_warning("FXEmitter: missing or invalid preset '%s'" % path)
		return

	if not (process_material is ShaderMaterial and (process_material as ShaderMaterial).shader == SIM):
		process_material = _new_mat(SIM)
	if not (material is ShaderMaterial and (material as ShaderMaterial).shader == DRAW):
		material = _new_mat(DRAW)

	var pm := process_material as ShaderMaterial
	if pm == null or pm.shader != SIM or not pm.resource_local_to_scene:
		process_material = _new_mat(SIM)
	var dm := material as ShaderMaterial
	if dm == null or dm.shader != DRAW or not dm.resource_local_to_scene:
		material = _new_mat(DRAW)

	var node : Dictionary = d.get("node", {})
	for k in node:
		if node.has("amount"):
			_base_amount = int(node.amount)
		if k in NODE_PROPS:
			set(k, node[k])

	var tex := texture as GradientTexture2D
	if tex == null or not tex.resource_local_to_scene:
		tex = GradientTexture2D.new()
		tex.gradient = Gradient.new()
		tex.resource_local_to_scene = true
		texture = tex
	tex.width = quad_px
	tex.height = quad_px

	_fill(process_material as ShaderMaterial, d.get("sim", {}))
	_fill(material as ShaderMaterial, d.get("draw", {}))
	if Engine.is_editor_hint() or (emitting and autoplay):
		restart()
	if not Engine.is_editor_hint():
		_apply_quality()
	
func param(name : StringName, value : Variant, on_draw : bool = false) -> void:
	((material if on_draw else process_material) as ShaderMaterial).set_shader_parameter(name, value)

func _fill(mat : ShaderMaterial, vals : Dictionary) -> void:
	var types := _utypes(mat.shader)
	for u in types:
		mat.set_shader_parameter(u, null)  # back to shader default
	for k in vals:
		if types.has(k):
			mat.set_shader_parameter(k, _conv(vals[k], types[k]))
		#else:
			#push_warning("FXEmitter: unknown uniform '%s' in preset '%s'" % [k, preset])

static func _new_mat(sh : Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	m.resource_local_to_scene = true
	return m

static func _utypes(sh : Shader) -> Dictionary:
	if not _types.has(sh):
		var m := {}
		for u in sh.get_shader_uniform_list():
			m[u.name] = u.type
		_types[sh] = m
	return _types[sh]

static func _conv(v : Variant, type : int) -> Variant:
	match type:
		TYPE_BOOL: return bool(v)
		TYPE_INT: return int(v)
		TYPE_FLOAT: return float(v)
		TYPE_VECTOR2: return Vector2(v[0], v[1])
		TYPE_VECTOR3: return Vector3(v[0], v[1], v[2])
		TYPE_VECTOR4: return Vector4(v[0], v[1], v[2], v[3])
		TYPE_COLOR: return Color(v) if v is String else Color(v[0], v[1], v[2], v[3] if v.size() > 3 else 1.0)
	return v

static func _scan() -> void:
	_names.clear()
	if not DirAccess.dir_exists_absolute(PRESET_DIR):
		push_warning("FXEmitter: preset dir not found: " + PRESET_DIR)
		return
	for f in DirAccess.get_files_at(PRESET_DIR):
		if f.ends_with(".json"):
			_names.append(f.get_basename())
	_names.sort()


func play() -> void:
	restart()

func stop() -> void:
	emitting = false
