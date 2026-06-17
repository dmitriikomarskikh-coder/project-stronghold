extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	sim.balance["units"]["peasant"]["carry_capacity"] = 1
	sim.balance["pathfinding"]["max_pathfinds_per_tick"] = 1

	sim.enqueue_player_command("gather", [0], [15, 18])
	var saw_return_request := false
	for i in range(300):
		sim.step()
		if _has_path_request(sim, "return_resource"):
			saw_return_request = true
			if sim.units.order_type[0] != "waiting_path":
				push_error("Expected worker to wait for queued return path")
				quit(1)
				return
			sim.step()
			if sim.pathfinds_last_tick != 1:
				push_error("Expected return path to be processed by the per-tick pathfinding budget")
				quit(1)
				return
			if _has_path_request(sim, "return_resource"):
				push_error("Expected queued return path request to be consumed")
				quit(1)
				return
			if sim.units.order_type[0] == "waiting_path" and not _has_path_request(sim, "gather_to_resource"):
				push_error("Expected post-return waiting state to belong to the next queued gather path")
				quit(1)
				return
			break
	if not saw_return_request:
		push_error("Expected gathering to queue a return path request")
		quit(1)
		return

	print("Resource return budget test passed")
	quit(0)

func _has_path_request(sim: RefCounted, resolve_order: String) -> bool:
	for request in sim.path_requests:
		if String(request["resolve_order"]) == resolve_order:
			return true
	return false
