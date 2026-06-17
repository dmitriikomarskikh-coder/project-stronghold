extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var first: PackedByteArray = _run_once()
	var second: PackedByteArray = _run_once()
	if first != second:
		push_error("50 unit pathfinding scenario is not deterministic")
		quit(1)
		return
	print("50 unit pathfinding test passed")
	quit(0)

func _run_once() -> PackedByteArray:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var ids: Array = []
	for id in range(sim.units.alive.size()):
		if sim.units.alive[id] and sim.units.owner[id] == 0:
			ids.append(id)
	for i in range(45):
		ids.append(sim.units.spawn(0, "peasant", 18 + i % 9, 24 + int(i / 9), int(sim.balance["units"]["peasant"]["hp"])))
	sim.enqueue_player_command("move", ids, [50, 52])
	for i in range(300):
		sim.step()
	for id in ids:
		if sim.units.alive[id] and sim.units.path[id].size() > int(sim.balance["pathfinding"]["max_path_tiles"]):
			push_error("Path exceeds configured max path tiles")
			quit(1)
			return PackedByteArray()
	return sim.snapshot_bytes()
