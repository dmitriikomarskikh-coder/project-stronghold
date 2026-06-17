extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var initial_wood: int = sim.player_wood[0]
	var place_command: Dictionary = sim.commands.make_command(sim.tick + 1, 0, "build_place", [], [23, 25], null, {"building_type": "farm"})
	sim.commands.enqueue(place_command)
	sim.step()
	sim.step()
	var farm := _first_incomplete_building(sim, 0, "farm")
	if farm < 0:
		push_error("Expected build_place to create a farm frame")
		quit(1)
		return
	var assign_command: Dictionary = sim.commands.make_command(sim.tick + 1, 0, "build_assign", [0], [], farm)
	sim.commands.enqueue(assign_command)
	for i in range(220):
		sim.step()
		if sim.buildings.completed[farm]:
			break
	if not sim.buildings.completed[farm]:
		push_error("Expected assigned worker to complete the farm")
		quit(1)
		return
	if sim.player_wood[0] >= initial_wood:
		push_error("Expected construction to spend wood from treasury")
		quit(1)
		return
	print("Building construction test passed")
	quit(0)

func _first_incomplete_building(sim: RefCounted, player_id: int, type_name: String) -> int:
	for id in range(sim.buildings.alive.size()):
		if sim.buildings.alive[id] and sim.buildings.owner[id] == player_id and sim.buildings.building_type[id] == type_name and not sim.buildings.completed[id]:
			return id
	return -1
