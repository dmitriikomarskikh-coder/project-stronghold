extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var barracks: int = sim.buildings.spawn(0, "barracks", 35, 35, int(sim.balance["buildings"]["barracks"]["hp"]), 1)
	var initial_warriors := _warrior_count(sim, 0)
	var command: Dictionary = sim.commands.make_command(sim.tick + 1, 0, "produce", [], [], barracks, {"unit_type": "warrior"})
	sim.commands.enqueue(command)
	for i in range(260):
		sim.step()
	if _warrior_count(sim, 0) <= initial_warriors:
		push_error("Expected barracks to produce a warrior")
		quit(1)
		return
	print("Barracks production test passed")
	quit(0)

func _warrior_count(sim: RefCounted, player_id: int) -> int:
	var count := 0
	for id in range(sim.units.alive.size()):
		if sim.units.alive[id] and sim.units.owner[id] == player_id and sim.units.unit_type[id] == "warrior":
			count += 1
	return count
