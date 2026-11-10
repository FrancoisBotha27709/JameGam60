extends Node2D
class_name DebrisField

const SPAWN_CHUNK_SIZE := 2048
const DEACTIVATE_CELL_MARGIN := 1.5
const TIME_CHECK_INTERVAL := 8
const MAX_DEBRIS_TYPES := 256
const MIN_OFFSET_SQUARED := 0.0001
const SETTLE_PASSES := 3
const STATE_GONE := 0
const STATE_SLEEPING := 1
const STATE_ACTIVE := 2

@export var focus : Node2D
@export var cell_size : float = 256.0
@export var activate_radius : float = 1400.0
@export var deactivate_radius : float = 1800.0
@export var refresh_interval : float = 0.2
@export var max_active : int = 2500
@export var pool_nodes : bool = true
@export var delivered_lifetime_min : float = 0.6
@export var delivered_lifetime_max : float = 1.6
@export var asteroid_clearance : float = 48.0

@export_group("Debris Audio")
@export_range(1, 16) var max_debris_audio : int = 3

var _active_debris_audio : Array[AudioStreamPlayer2D] = []

var _definitions : Array[Debris] = []
var _grid := DebrisGrid.new()
var _rect : Rect2
var _center : Vector2
var _leash : float
var _focus_position := Vector2.ZERO
var _type_indices := PackedByteArray()
var _variant_indices := PackedByteArray()
var _quantum_flags := PackedByteArray()
var _states := PackedByteArray()
var _site_starts := PackedInt32Array()
var _site_counts := PackedInt32Array()
var _active : Array[DebrisObject] = []
var _pool : Array = []
var _remaining := 0
var _sweep_cursor := 0
var _seconds_since_refresh := 0.0
var _is_releasing := false
var _is_streaming := false

func _ready() -> void:
	add_to_group("DebrisField")
	set_process(false)

func _exit_tree() -> void:
	_is_releasing = true
	_free_pool()

func remaining() -> int:
	return _remaining

func active_count() -> int:
	return _active.size()

#region Reveal

func start_streaming() -> void:
	if _is_streaming or _states.is_empty():
		return
	_is_streaming = true
	_update_focus_position()
	_grid.queue_cells_near(_focus_position, activate_radius)
	set_process(true)

func preview_entries(site_index : int, max_entries : int) -> Array[Dictionary]:
	var entries : Array[Dictionary] = []
	if site_index < 0 or site_index >= _site_starts.size():
		return entries
	var first := _site_starts[site_index]
	var total := _site_counts[site_index]
	var shown := mini(total, max_entries)
	for entry_index in shown:
		var debris_index := first + floori(float(entry_index * total) / float(shown))
		entries.append({
			tag = _definitions[_type_indices[debris_index]].tag,
			variant = _variant_indices[debris_index],
			position = to_global(_grid.positions[debris_index])})
	return entries

#endregion

#region Minimap

func get_states() -> PackedByteArray:
	return _states if _is_streaming else PackedByteArray()

func get_positions():
	return _grid.positions

func get_active_nodes() -> Array[DebrisObject]:
	return _active

#endregion

#region Build

func build(definitions : Array[Debris], count : int, sites : Array[WreckSite], leash : float,
		rect : Rect2, random_generator : RandomNumberGenerator,
		avoid_point : Vector2 = Vector2.INF, avoid_radius : float = 0.0,
		asteroids : AsteroidField = null) -> void:
	assert(definitions.size() > 0 and definitions.size() <= MAX_DEBRIS_TYPES)
	assert(sites.size() > 0)
	_definitions = definitions
	_rect = rect
	_center = sites[0].origin
	_leash = leash
	deactivate_radius = maxf(deactivate_radius, activate_radius + cell_size * DEACTIVATE_CELL_MARGIN)
	var quantum_chances := _allocate(count)
	_record_sites(sites)
	DataCollector.add_spawn_total(ceili(count / float(SPAWN_CHUNK_SIZE)))
	var site_index := 0
	var site_used := 0
	for debris_index in count:
		while site_index < sites.size() - 1 and site_used >= sites[site_index].count:
			site_index += 1
			site_used = 0
		var site := sites[site_index]
		var progress := (site_used + random_generator.randf()) / maxf(float(site.count), 1.0)
		site_used += 1
		var type_index := random_generator.randi_range(0, definitions.size() - 1)
		_type_indices[debris_index] = type_index
		_variant_indices[debris_index] = random_generator.randi_range(0, DebrisShapes.VARIANTS - 1)
		_quantum_flags[debris_index] = 1 if random_generator.randf() < quantum_chances[type_index] else 0
		var candidate := site.sample(random_generator, progress, _rect)
		_grid.link(debris_index, _settle(candidate, avoid_point, avoid_radius, asteroids))
		if (debris_index + 1) % SPAWN_CHUNK_SIZE == 0:
			DataCollector.report_spawned()
			await DataCollector.spawn_checkpoint()
	if count % SPAWN_CHUNK_SIZE != 0:
		DataCollector.report_spawned()
	_remaining = count

func _record_sites(sites : Array[WreckSite]) -> void:
	_site_starts.clear()
	_site_counts.clear()
	var running_total := 0
	for site in sites:
		_site_starts.append(running_total)
		_site_counts.append(site.count)
		running_total += site.count

func _settle(candidate : Vector2, avoid_point : Vector2, avoid_radius : float, asteroids : AsteroidField) -> Vector2:
	var point := candidate
	for pass_index in SETTLE_PASSES:
		point = _keep_clear(point, avoid_point, avoid_radius)
		if asteroids != null:
			point = to_local(asteroids.resolve_point(to_global(point), asteroid_clearance)).clamp(_rect.position, _rect.end)
	return point

func _keep_clear(candidate : Vector2, avoid_point : Vector2, avoid_radius : float) -> Vector2:
	if avoid_radius <= 0.0 or is_inf(avoid_point.x):
		return candidate
	var offset := candidate - avoid_point
	var offset_squared := offset.length_squared()
	if offset_squared >= avoid_radius * avoid_radius:
		return candidate
	var direction := offset.normalized() if offset_squared > MIN_OFFSET_SQUARED else Vector2.RIGHT
	return (avoid_point + direction * avoid_radius).clamp(_rect.position, _rect.end)

func _allocate(count : int) -> PackedFloat32Array:
	_grid.setup(_rect, cell_size, count)
	_type_indices.resize(count)
	_variant_indices.resize(count)
	_quantum_flags.resize(count)
	_states.resize(count)
	_states.fill(STATE_SLEEPING)
	_pool.clear()
	var quantum_chances := PackedFloat32Array()
	for definition in _definitions:
		_pool.append([])
		quantum_chances.append(1.0 if definition.data_tags.has("quantum") else definition.quantum_chance)
	return quantum_chances

#endregion

func _process(delta : float) -> void:
	_update_focus_position()
	_seconds_since_refresh += delta
	if _seconds_since_refresh >= refresh_interval:
		_seconds_since_refresh = 0.0
		_grid.queue_cells_near(_focus_position, activate_radius)
	_sweep(delta)
	if _grid.has_pending():
		_work(DataCollector.spawn_budget_usec)

func _update_focus_position() -> void:
	_focus_position = focus.global_position if focus else _center

func _work(budget_usec : int) -> bool:
	var start_usec := Time.get_ticks_usec()
	var activated_count := 0
	while _active.size() < max_active:
		var debris_index := _grid.pop_pending()
		if debris_index == DebrisGrid.EMPTY_CELL:
			return true
		_activate(debris_index)
		activated_count += 1
		if activated_count % TIME_CHECK_INTERVAL == 0 and Time.get_ticks_usec() - start_usec >= budget_usec:
			return false
	_grid.clear_pending()
	return true

func _sweep(delta : float) -> void:
	var radius_squared := deactivate_radius * deactivate_radius
	for step in mini(ceili(_active.size() * delta / refresh_interval) + 1, _active.size()):
		if _active.is_empty():
			return
		if _sweep_cursor >= _active.size():
			_sweep_cursor = 0
		var node := _active[_sweep_cursor]
		if node.anchor == null and node.position.distance_squared_to(_focus_position) > radius_squared:
			_deactivate(node)
		else:
			_sweep_cursor += 1

func _remove_active(node : DebrisObject) -> void:
	var last_node : DebrisObject = _active.back()
	_active[node.field_slot] = last_node
	last_node.field_slot = node.field_slot
	_active.pop_back()
	node.field_slot = -1
	node.field_idx = -1

func _activate(debris_index : int) -> void:
	var type_index := _type_indices[debris_index]
	var bucket : Array = _pool[type_index]
	var node : DebrisObject
	if bucket.is_empty():
		node = _definitions[type_index].scene.instantiate() as DebrisObject
		node.tree_exiting.connect(_on_node_exiting.bind(node))
		node.delivered.connect(_on_node_delivered.bind(node))
		node.quantum_expired.connect(_on_node_quantum_expired.bind(node))
	else:
		node = bucket.pop_back()
	node.anchor = null
	node.rope = null
	node.set_deferred("monitoring", true)
	node.setup(_definitions[type_index], _center, _leash, _rect, _variant_indices[debris_index])
	node.set_quantum(_quantum_flags[debris_index] == 1, focus)
	node.position = _grid.positions[debris_index]
	node.field_idx = debris_index
	node.field_slot = _active.size()
	_states[debris_index] = STATE_ACTIVE
	_active.append(node)
	add_child(node)

func _deactivate(node : DebrisObject) -> void:
	var debris_index := node.field_idx
	_remove_active(node)
	if node.quantum_spent():
		_quantum_flags[debris_index] = 0
	_grid.link(debris_index, node.position)
	_states[debris_index] = STATE_SLEEPING
	_is_releasing = true
	remove_child(node)
	_is_releasing = false
	if pool_nodes:
		_pool[_type_indices[debris_index]].append(node)
	else:
		node.queue_free()

func _retire(node : DebrisObject) -> void:
	_states[node.field_idx] = STATE_GONE
	_remove_active(node)
	_remaining -= 1

func _on_node_exiting(node : DebrisObject) -> void:
	if not _is_releasing and node.field_idx >= 0:
		_retire(node)

func _on_node_delivered(node : DebrisObject) -> void:
	if node.field_idx < 0:
		return
	_retire(node)
	get_tree().create_timer(
		randf_range(delivered_lifetime_min, delivered_lifetime_max)
	).timeout.connect(node.queue_free)

func _on_node_quantum_expired(node : DebrisObject) -> void:
	if node.field_idx >= 0:
		_quantum_flags[node.field_idx] = 0

func _free_pool() -> void:
	for bucket : Array in _pool:
		for node : DebrisObject in bucket:
			if is_instance_valid(node):
				node.free()
		bucket.clear()

func clear() -> void:
	set_process(false)
	_is_streaming = false
	_is_releasing = true
	for node in _active:
		node.field_idx = -1
	for child in get_children():
		child.queue_free()
	_free_pool()
	_is_releasing = false
	_active.clear()
	_states.clear()
	_variant_indices.clear()
	_site_starts.clear()
	_site_counts.clear()
	_grid.clear_pending()
	_sweep_cursor = 0
	_remaining = 0
