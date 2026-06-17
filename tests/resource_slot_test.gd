extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")
const PathfindingScript := preload("res://sim/pathfinding.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var resource_tile := Vector2i(15, 18)
	var from_tile := Vector2i(18, 22)
	var chosen: Vector2i = sim._resource_work_slot(resource_tile, from_tile)
	var chosen_order: int = _neighbor_order(resource_tile, chosen)
	var chosen_cost: int = _slot_cost(sim, from_tile, chosen)

	for i in range(PathfindingScript.NEIGHBORS.size()):
		var candidate: Vector2i = resource_tile + PathfindingScript.NEIGHBORS[i]
		if not sim.map_state.in_bounds(candidate.x, candidate.y) or not sim.map_state.is_walkable(candidate.x, candidate.y):
			continue
		var cost: int = _slot_cost(sim, from_tile, candidate)
		if cost < 0:
			continue
		if cost < chosen_cost or (cost == chosen_cost and i < chosen_order):
			push_error("Resource slot selection violates path cost or direction order")
			quit(1)
			return
	print("Resource slot test passed")
	quit(0)

func _slot_cost(sim: RefCounted, from_tile: Vector2i, slot: Vector2i) -> int:
	var path: Array = sim.pathfinding.find_path(sim.map_state, from_tile, slot, int(sim.balance["pathfinding"]["max_path_tiles"]))
	if from_tile != slot and path.is_empty():
		return -1
	var cost := 0
	var current := from_tile
	for next_tile: Vector2i in path:
		var dx: int = abs(next_tile.x - current.x)
		var dy: int = abs(next_tile.y - current.y)
		cost += PathfindingScript.DIAGONAL_COST if dx != 0 and dy != 0 else PathfindingScript.STRAIGHT_COST
		current = next_tile
	return cost

func _neighbor_order(resource_tile: Vector2i, slot: Vector2i) -> int:
	var delta := slot - resource_tile
	for i in range(PathfindingScript.NEIGHBORS.size()):
		if PathfindingScript.NEIGHBORS[i] == delta:
			return i
	return 999999
