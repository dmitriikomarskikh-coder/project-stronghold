extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var ids: Array = []
	for id in range(sim.units.alive.size()):
		if sim.units.alive[id] and sim.units.owner[id] == 0:
			ids.append(id)
	for i in range(45):
		ids.append(sim.units.spawn(0, "peasant", 18 + i % 9, 24 + int(i / 9), int(sim.balance["units"]["peasant"]["hp"])))

	sim.enqueue_player_command("move", ids, [50, 52])
	sim.step()
	if sim.pathfinds_last_tick != 0:
		push_error("Expected no pathfinding before the queued command tick")
		quit(1)
		return
	sim.step()
	if sim.pathfinds_last_tick != int(sim.balance["pathfinding"]["max_pathfinds_per_tick"]):
		push_error("Expected pathfinding phase to consume exactly the configured first-tick budget")
		quit(1)
		return
	if sim.path_requests.size() != ids.size() - int(sim.balance["pathfinding"]["max_pathfinds_per_tick"]):
		push_error("Expected remaining path requests to stay queued")
		quit(1)
		return
	for i in range(3):
		sim.step()
	if not sim.path_requests.is_empty():
		push_error("Expected queued path requests to drain deterministically")
		quit(1)
		return
	print("Pathfinding budget test passed")
	quit(0)
