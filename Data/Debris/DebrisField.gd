extends Node2D
class_name DebrisField

const CHUNK := 2048

@export var focus : Node2D
@export var cell_size : float = 256.0
@export var activate_radius : float = 1400.0
@export var deactivate_radius : float = 1800.0
@export var refresh_interval : float = 0.2
@export var max_active : int = 2500
@export var pool_nodes : bool = true
@export var delivered_lifetime_min : float = 0.6
@export var delivered_lifetime_max : float = 1.6

var _defs : Array[Debris] = []
var _rect : Rect2
var _center : Vector2
var _leash : float
var _cols : int
var _rows : int
var _f : Vector2

var _pos := PackedVector2Array()
var _type := PackedByteArray()
var _quantum := PackedByteArray()
var _next := PackedInt32Array()

var _head := PackedInt32Array()

var _active : Array[DebrisObject] = []
var _pool : Array = []
var _remaining : int = 0

var _pending := PackedInt32Array()
var _p_head : int = 0
var _sweep_i : int = 0
var _since_refresh : float = 0.0
var _releasing : bool = false

func _ready() -> void:
	set_process(false)

func _exit_tree() -> void:
	_releasing = true
	for bucket : Array in _pool:
		for n : DebrisObject in bucket:
			if is_instance_valid(n):
				n.free()
		bucket.clear()

func remaining() -> int:
	return _remaining

func active_count() -> int:
	return _active.size()

func build(defs : Array[Debris], count : int, center : Vector2, min_d : float, max_d : float,
		spread : float, leash : float, rect : Rect2, rng : RandomNumberGenerator) -> void:
	assert(defs.size() > 0 and defs.size() <= 256)
	_defs = defs
	_rect = rect
	_center = center
	_leash = leash
	deactivate_radius = maxf(deactivate_radius, activate_radius + cell_size * 1.5)

	_cols = maxi(1, ceili(rect.size.x / cell_size))
	_rows = maxi(1, ceili(rect.size.y / cell_size))
	var cells := _cols * _rows
	_head.resize(cells)
	_head.fill(-1)
	_pos.resize(count)
	_type.resize(count)
	_quantum.resize(count)
	_next.resize(count)

	_pool.clear()
	var chances := PackedFloat32Array()
	for d in defs:
		var bucket : Array[DebrisObject] = []
		_pool.append(bucket)
		chances.append(1.0 if d.data_tags.has("quantum") else d.quantum_chance)

	DataCollector.add_spawn_total(ceili(count / float(CHUNK)))

	var last := defs.size() - 1
	for i in count:
		var p := _sample(rng, min_d, max_d, spread)
		var t := rng.randi_range(0, last)
		_pos[i] = p
		_type[i] = t
		_quantum[i] = 1 if rng.randf() < chances[t] else 0
		var c := _cell_index(p)
		_next[i] = _head[c]
		_head[c] = i
		if (i + 1) % CHUNK == 0:
			DataCollector.report_spawned()
			await DataCollector.spawn_checkpoint()
	if count % CHUNK != 0:
		DataCollector.report_spawned()

	_remaining = count

	_f = focus.global_position if focus != null else _center
	_refresh()
	while not _work(DataCollector.spawn_budget_usec):
		await get_tree().process_frame
	set_process(true)

func _process(delta : float) -> void:
	_f = focus.global_position if focus != null else _center
	_since_refresh += delta
	if _since_refresh >= refresh_interval:
		_since_refresh = 0.0
		_refresh()
	_sweep(delta)
	if _p_head < _pending.size():
		_work(DataCollector.spawn_budget_usec)

func _sample(rng : RandomNumberGenerator, min_d : float, max_d : float, spread : float) -> Vector2:
	for _t in 4:
		var p := _center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(min_d, max_d) * spread
		if _rect.has_point(p):
			return p
	return Vector2(
		rng.randf_range(_rect.position.x, _rect.end.x),
		rng.randf_range(_rect.position.y, _rect.end.y))

func _cell_index(p : Vector2) -> int:
	var cx := clampi(int((p.x - _rect.position.x) / cell_size), 0, _cols - 1)
	var cy := clampi(int((p.y - _rect.position.y) / cell_size), 0, _rows - 1)
	return cy * _cols + cx

func _cell_dist_sq(cx : int, cy : int) -> float:
	var lo := _rect.position + Vector2(cx, cy) * cell_size
	return _f.distance_squared_to(_f.clamp(lo, lo + Vector2(cell_size, cell_size)))

func _refresh() -> void:
	_pending.clear()
	_p_head = 0
	var r := activate_radius
	var min_cx := clampi(int((_f.x - r - _rect.position.x) / cell_size), 0, _cols - 1)
	var max_cx := clampi(int((_f.x + r - _rect.position.x) / cell_size), 0, _cols - 1)
	var min_cy := clampi(int((_f.y - r - _rect.position.y) / cell_size), 0, _rows - 1)
	var max_cy := clampi(int((_f.y + r - _rect.position.y) / cell_size), 0, _rows - 1)
	var r2 := r * r
	for cy in range(min_cy, max_cy + 1):
		for cx in range(min_cx, max_cx + 1):
			var c := cy * _cols + cx
			if _head[c] != -1 and _cell_dist_sq(cx, cy) <= r2:
				_pending.append(c)

func _work(budget_usec : int) -> bool:
	var t0 := Time.get_ticks_usec()
	while _p_head < _pending.size():
		var c := _pending[_p_head]
		var i := _head[c]
		var n := 0
		while i != -1:
			if _active.size() >= max_active:
				_head[c] = i
				_pending.clear()
				_p_head = 0
				return true
			var nxt := _next[i]
			_activate(i)
			i = nxt
			n += 1
			if (n & 7) == 0 and Time.get_ticks_usec() - t0 >= budget_usec:
				_head[c] = i
				return false
		_head[c] = -1
		_p_head += 1
	_pending.clear()
	_p_head = 0
	return true

func _sweep(delta : float) -> void:
	var n := _active.size()
	if n == 0:
		return
	var steps := mini(ceili(n * delta / refresh_interval) + 1, n)
	var r2 := deactivate_radius * deactivate_radius
	for _k in steps:
		if _active.is_empty():
			return
		if _sweep_i >= _active.size():
			_sweep_i = 0
		var node := _active[_sweep_i]
		if node.anchor == null and node.position.distance_squared_to(_f) > r2:
			_deactivate(node)
		else:
			_sweep_i += 1

func _remove_active(node : DebrisObject) -> void:
	var slot = node.field_slot
	var moved : DebrisObject = _active[_active.size() - 1]
	_active[slot] = moved
	moved.field_slot = slot
	_active.pop_back()
	node.field_slot = -1

func _activate(idx : int) -> void:
	var t := _type[idx]
	var def := _defs[t]
	var bucket : Array[DebrisObject] = _pool[t]
	var node : DebrisObject
	if bucket.is_empty():
		node = def.scene.instantiate() as DebrisObject
		node.tree_exiting.connect(_on_node_exiting.bind(node))
		node.delivered.connect(_on_node_delivered.bind(node))
		node.quantum_expired.connect(_on_node_quantum_expired.bind(node))
	else:
		node = bucket.pop_back()

	node.anchor = null
	node.rope = null
	if not node.monitoring:
		node.set_deferred("monitoring", true)

	node.setup(def, _center, _leash, _rect)
	node.set_quantum(_quantum[idx] == 1, focus)
	node.position = _pos[idx]
	node.field_idx = idx
	node.field_slot = _active.size()
	_active.append(node)
	add_child(node)

func _deactivate(node : DebrisObject) -> void:
	var idx = node.field_idx
	_remove_active(node)
	node.field_idx = -1

	if node.quantum_spent():
		_quantum[idx] = 0

	_pos[idx] = node.position
	var c := _cell_index(_pos[idx])
	_next[idx] = _head[c]
	_head[c] = idx

	_releasing = true
	remove_child(node)
	_releasing = false
	if pool_nodes:
		var bucket : Array[DebrisObject] = _pool[_type[idx]]
		bucket.append(node)
	else:
		node.queue_free()

func _retire(node : DebrisObject) -> void:
	_remove_active(node)
	node.field_idx = -1
	_remaining -= 1

func _on_node_exiting(node : DebrisObject) -> void:
	if _releasing or node.field_idx < 0:
		return
	_retire(node)

func _on_node_delivered(node : DebrisObject) -> void:
	if node.field_idx < 0:
		return
	_retire(node)
	var life := randf_range(delivered_lifetime_min, delivered_lifetime_max)
	get_tree().create_timer(life).timeout.connect(_free_delivered.bind(node))

func _free_delivered(node : DebrisObject) -> void:
	if is_instance_valid(node):
		node.queue_free()

func _on_node_quantum_expired(node : DebrisObject) -> void:
	if node.field_idx >= 0:
		_quantum[node.field_idx] = 0

func clear() -> void:
	set_process(false)
	_releasing = true
	for node in _active:
		node.field_idx = -1
	for child in get_children():
		child.queue_free()
	for bucket : Array in _pool:
		for n : DebrisObject in bucket:
			if is_instance_valid(n):
				n.free()
		bucket.clear()
	_releasing = false
	_active.clear()
	_pending.clear()
	_p_head = 0
	_sweep_i = 0
	_remaining = 0