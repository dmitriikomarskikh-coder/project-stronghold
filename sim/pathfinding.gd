extends RefCounted

const NEIGHBORS := [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]

const STRAIGHT_COST := 256
const DIAGONAL_COST := 362

func find_path(map_state, start: Vector2i, goal: Vector2i, max_tiles: int = 64) -> Array:
	if start == goal:
		return []
	if not map_state.in_bounds(goal.x, goal.y) or not map_state.is_walkable(goal.x, goal.y):
		return []

	var open: Array = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = { map_state.index(start.x, start.y): 0 }
	var closed: Dictionary = {}
	var best: Vector2i = start
	var best_h: int = _heuristic(start, goal)

	while not open.is_empty():
		var current: Vector2i = _pop_best(open, g_score, goal, map_state)
		var current_index: int = map_state.index(current.x, current.y)
		closed[current_index] = true
		var current_h: int = _heuristic(current, goal)
		if current_h < best_h or (current_h == best_h and g_score[current_index] < g_score.get(map_state.index(best.x, best.y), 999999999)):
			best = current
			best_h = current_h
		if current == goal:
			return _reconstruct(came_from, current, map_state)
		if _path_tile_distance(start, current) >= max_tiles:
			continue
		for delta: Vector2i in NEIGHBORS:
			var next: Vector2i = current + delta
			if not map_state.in_bounds(next.x, next.y) or not map_state.is_walkable(next.x, next.y):
				continue
			var next_index: int = map_state.index(next.x, next.y)
			if closed.has(next_index):
				continue
			var step_cost: int = DIAGONAL_COST if delta.x != 0 and delta.y != 0 else STRAIGHT_COST
			var tentative: int = int(g_score[current_index]) + step_cost
			if tentative < int(g_score.get(next_index, 999999999)):
				came_from[next_index] = current
				g_score[next_index] = tentative
				if not _contains_tile(open, next):
					open.append(next)
	if best != start:
		return _reconstruct(came_from, best, map_state)
	return []

func _pop_best(open: Array, g_score: Dictionary, goal: Vector2i, map_state) -> Vector2i:
	var best_i := 0
	var best_tile: Vector2i = open[0]
	var best_f: int = int(g_score[map_state.index(best_tile.x, best_tile.y)]) + _heuristic(best_tile, goal)
	var best_index: int = map_state.index(best_tile.x, best_tile.y)
	for i in range(1, open.size()):
		var tile: Vector2i = open[i]
		var index: int = map_state.index(tile.x, tile.y)
		var f: int = int(g_score[index]) + _heuristic(tile, goal)
		if f < best_f or (f == best_f and index < best_index):
			best_i = i
			best_tile = tile
			best_f = f
			best_index = index
	open.remove_at(best_i)
	return best_tile

func _reconstruct(came_from: Dictionary, current: Vector2i, map_state) -> Array:
	var reversed_path: Array[Vector2i] = [current]
	var current_index: int = map_state.index(current.x, current.y)
	while came_from.has(current_index):
		current = came_from[current_index]
		current_index = map_state.index(current.x, current.y)
		reversed_path.append(current)
	reversed_path.reverse()
	if not reversed_path.is_empty():
		reversed_path.remove_at(0)
	return reversed_path

func _heuristic(a: Vector2i, b: Vector2i) -> int:
	var dx: int = abs(a.x - b.x)
	var dy: int = abs(a.y - b.y)
	var diag: int = min(dx, dy)
	var straight: int = max(dx, dy) - diag
	return diag * DIAGONAL_COST + straight * STRAIGHT_COST

func _path_tile_distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

func _contains_tile(items: Array, needle: Vector2i) -> bool:
	for item in items:
		if item == needle:
			return true
	return false
