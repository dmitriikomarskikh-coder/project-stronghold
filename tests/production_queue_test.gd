extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var initial_units: int = sim.live_units_for_player(0)

	sim.enqueue_player_command("produce", [], [], {"unit_type": "peasant"})
	sim.enqueue_player_command("produce", [], [], {"unit_type": "peasant"})
	for i in range(320):
		sim.step()

	if sim.live_units_for_player(0) < initial_units + 2:
		push_error("Expected two queued peasants to be produced")
		quit(1)
		return
	if sim.buildings.production_type[0] != "" or not sim.buildings.production_queue[0].is_empty():
		push_error("Expected production queue to drain after two peasants")
		quit(1)
		return
	print("Production queue test passed")
	quit(0)
