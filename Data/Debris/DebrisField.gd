extends Node2D
class_name DebrisField

const SPAWN_CHUNK_SIZE := 2048
const SAMPLE_ATTEMPTS := 4
const DEACTIVATE_CELL_MARGIN := 1.5   # cells of hysteresis between activate and deactivate radius
const TIME_CHECK_INTERVAL := 8   # activations between time-budget checks
const MAX_DEBRIS_TYPES := 256

@export var focus : Node2D
@export var cell_size : float = 256.0
@export var activate_radius : float = 1400.0
@export var deactivate_radius : float = 1800.0
@export var refresh_interval : float = 0.2
@export var max_active : int = 2500
@export var pool_nodes : bool = true
@export var delivered_lifetime_min : float = 0.6
@export var delivered_lifetime_max : float = 1.6

var _definitions : Array[Debris] = []
var _grid := DebrisGrid.new()
var _rect : Rect2
var _center : Vector2
var _leash : float
var _focus_position := Vector2.ZERO
var _type_indices := PackedByteArray()
var _quantum_flags := PackedByteArray()
var _active : Array[DebrisObject] = []
var _pool : Array = []   # one bucket (Array) of idle nodes per debris definition
var _remaining := 0
var _sweep_cursor := 0
var _seconds_since_refresh := 0.0
var _is_releasing := false


func _ready() -> void:
	set_process(false)

func _exit_tree() -> void:
	_is_releasing = true
	_free_pool()

func remaining() -> int:
	return _remaining

func active_count() -> int:
	return _active.size()

# Scatters every debris into the grid in async chunks, then activates the cells around the focus.
func build(definitions : Array[Debris], count : int, center : Vector2, min_distance : float, max_distance : float,
		spread : float, leash : float, rect : Rect2, random_generator : RandomNumberGenerator) -> void:
	assert(definitions.size() > 0 and definitions.size() <= MAX_DEBRIS_TYPES)
	_definitions = definitions
	_rect = rect
	_center = center
	_leash = leash
	deactivate_radius = maxf(deactivate_radius, activate_radius + cell_size * DEACTIVATE_CELL_MARGIN)
	var quantum_chances := _allocate(count)
	DataCollector.add_spawn_total(ceili(count / float(SPAWN_CHUNK_SIZE)))
	for debris_index in count:
		var type_index := random_generator.randi_range(0, definitions.size() - 1)
		_type_indices[debris_index] = type_index
		_quantum_flags[debris_index] = 1 if random_generator.randf() < quantum_chances[type_index] else 0
		_grid.link(debris_index, _sample_position(random_generator, min_distance, max_distance, spread))
		if (debris_index + 1) % SPAWN_CHUNK_SIZE == 0:
			DataCollector.report_spawned()
			await DataCollector.spawn_checkpoint()
	if count % SPAWN_CHUNK_SIZE != 0:
		DataCollector.report_spawned()
	_remaining = count
	_update_focus_position()
	_grid.queue_cells_near(_focus_position, activate_radius)
	while not _work(DataCollector.spawn_budget_usec):
		await get_tree().process_frame
	set_process(true)

# Sizes the grid and data arrays, builds the pools, and returns each type's quantum chance.
func _allocate(count : int) -> PackedFloat32Array:
	_grid.setup(_rect, cell_size, count)
	_type_indices.resize(count)
	_quantum_flags.resize(count)
	_pool.clear()
	var quantum_chances := PackedFloat32Array()
	for definition in _definitions:
		_pool.append([])
		quantum_chances.append(1.0 if definition.data_tags.has("quantum") else definition.quantum_chance)
	return quantum_chances

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

# Picks a point in a ring around the center, falling back to anywhere in the rect.
func _sample_position(random_generator : RandomNumberGenerator, min_distance : float, max_distance : float, spread : float) -> Vector2:
	for attempt in SAMPLE_ATTEMPTS:
		var candidate := _center + Vector2.from_angle(random_generator.randf() * TAU) \
				* random_generator.randf_range(min_distance, max_distance) * spread
		if _rect.has_point(candidate):
			return candidate
	return Vector2(random_generator.randf_range(_rect.position.x, _rect.end.x), random_generator.randf_range(_rect.position.y, _rect.end.y))

# Activates queued debris within a time budget; true when done (or at max_active), false to resume next frame.
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

# Checks a slice of active nodes each frame and deactivates unanchored ones that drifted too far.
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

# Swap-removes a node from the active list in constant time.
func _remove_active(node : DebrisObject) -> void:
	var last_node : DebrisObject = _active.back()
	_active[node.field_slot] = last_node
	last_node.field_slot = node.field_slot
	_active.pop_back()
	node.field_slot = -1
	node.field_idx = -1

# Takes a node from the pool (or creates one), configures it, and adds it to the scene.
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
	node.setup(_definitions[type_index], _center, _leash, _rect)
	node.set_quantum(_quantum_flags[debris_index] == 1, focus)
	node.position = _grid.positions[debris_index]
	node.field_idx = debris_index
	node.field_slot = _active.size()
	_active.append(node)
	add_child(node)

# Saves a node's state back into the grid and returns it to the pool.
func _deactivate(node : DebrisObject) -> void:
	var debris_index := node.field_idx
	_remove_active(node)
	if node.quantum_spent():
		_quantum_flags[debris_index] = 0
	_grid.link(debris_index, node.position)
	_is_releasing = true
	remove_child(node)
	_is_releasing = false
	if pool_nodes:
		_pool[_type_indices[debris_index]].append(node)
	else:
		node.queue_free()

func _retire(node : DebrisObject) -> void:
	_remove_active(node)
	_remaining -= 1

func _on_node_exiting(node : DebrisObject) -> void:
	if not _is_releasing and node.field_idx >= 0:
		_retire(node)

func _on_node_delivered(node : DebrisObject) -> void:
	if node.field_idx < 0:
		return
	_retire(node)
	get_tree().create_timer(randf_range(delivered_lifetime_min, delivered_lifetime_max)).timeout.connect(node.queue_free)

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
	_is_releasing = true
	for node in _active:
		node.field_idx = -1
	for child in get_children():
		child.queue_free()
	_free_pool()
	_is_releasing = false
	_active.clear()
	_grid.clear_pending()
	_sweep_cursor = 0
	_remaining = 0