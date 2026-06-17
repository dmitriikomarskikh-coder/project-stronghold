extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	sim.enqueue_player_command("gather", [0, 1, 2, 3], [15, 18])
	sim.step()
	sim.step()
	var targets := {}
	for id in [0, 1, 2, 3]:
		if sim.units.order_type[id] != "gather_to_resource" and sim.units.order_type[id] != "gathering":
			push_error("Expected worker %d to receive a gather order" % id)
			quit(1)
			return
		var key := "%d,%d" % [sim.units.target_x[id], sim.units.target_y[id]]
		if targets.has(key):
			push_error("Expected grouped workers to reserve distinct resource work slots")
			quit(1)
			return
		targets[key] = true
	print("Resource multi-slot test passed")
	quit(0)
