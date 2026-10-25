extends RefCounted
class_name DebrisGrid

const EMPTY_CELL := -1

var rect : Rect2
var cell_size := 256.0
var columns := 1
var rows := 1
var positions := PackedVector2Array()
var next_in_cell := PackedInt32Array()   # linked list of debris per cell
var cell_heads := PackedInt32Array()
var pending_cells := PackedInt32Array()
var pending_cursor := 0

# Sizes the grid over a rect and the per-debris arrays for a given count.
func setup(world_rect : Rect2, cell_length : float, count : int) -> void:
	rect = world_rect
	cell_size = cell_length
	columns = maxi(1, ceili(rect.size.x / cell_size))
	rows = maxi(1, ceili(rect.size.y / cell_size))
	cell_heads.resize(columns * rows)
	cell_heads.fill(EMPTY_CELL)
	positions.resize(count)
	next_in_cell.resize(count)

func cell_of(world_position : Vector2) -> Vector2i:
	return Vector2i(((world_position - rect.position) / cell_size).floor()).clamp(Vector2i.ZERO, Vector2i(columns - 1, rows - 1))

# Stores a debris position and pushes it onto the head of its cell's list.
func link(debris_index : int, world_position : Vector2) -> void:
	var cell := cell_of(world_position)
	var cell_index := cell.y * columns + cell.x
	positions[debris_index] = world_position
	next_in_cell[debris_index] = cell_heads[cell_index]
	cell_heads[cell_index] = debris_index

# Queues every non-empty cell whose nearest point lies within the radius of the focus.
func queue_cells_near(focus_position : Vector2, radius : float) -> void:
	pending_cells.clear()
	pending_cursor = 0
	var reach := Vector2(radius, radius)
	var first_cell := cell_of(focus_position - reach)
	var last_cell := cell_of(focus_position + reach)
	for row in range(first_cell.y, last_cell.y + 1):
		for column in range(first_cell.x, last_cell.x + 1):
			var cell_corner := rect.position + Vector2(column, row) * cell_size
			var nearest_point := focus_position.clamp(cell_corner, cell_corner + Vector2(cell_size, cell_size))
			if cell_heads[row * columns + column] != EMPTY_CELL and focus_position.distance_squared_to(nearest_point) <= radius * radius:
				pending_cells.append(row * columns + column)

func has_pending() -> bool:
	return pending_cursor < pending_cells.size()

func clear_pending() -> void:
	pending_cells.clear()
	pending_cursor = 0

# Removes and returns the next queued debris index, or EMPTY_CELL when the queue is exhausted.
func pop_pending() -> int:
	while has_pending():
		var cell_index := pending_cells[pending_cursor]
		var debris_index := cell_heads[cell_index]
		if debris_index != EMPTY_CELL:
			cell_heads[cell_index] = next_in_cell[debris_index]
			return debris_index
		pending_cursor += 1
	clear_pending()
	return EMPTY_CELL