extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var initial_units: int = sim.live_units_for_player(0)
	var initial_food: int = sim.player_food[0]
	var initial_wood: int = sim.player_wood[0]
	var initial_stone: int = sim.player_stone[0]
	var initial_resource_left: int = _total_resource_left(sim)

	sim.enqueue_player_command("produce", [], [], {"unit_type": "peasant"})
	sim.enqueue_player_command("gather", [0, 1], [15, 18])
	sim.enqueue_player_command("gather", [2, 3], [30, 23])
	for i in range(700):
		sim.step()

	if sim.live_units_for_player(0) <= initial_units:
		push_error("Expected peasant production to increase player 0 unit count")
		quit(1)
		return
	if sim.player_food[0] >= initial_food:
		push_error("Expected peasant production and upkeep to spend food")
		quit(1)
		return
	if _total_resource_left(sim) >= initial_resource_left:
		push_error("Expected workers to harvest wood from an accessible resource tile")
		quit(1)
		return
	if sim.player_wood[0] <= initial_wood:
		push_error("Expected workers to deposit harvested wood")
		quit(1)
		return
	if sim.player_stone[0] <= initial_stone:
		push_error("Expected workers to deposit harvested stone")
		quit(1)
		return
	print("Economy test passed")
	quit(0)

func _total_resource_left(sim: RefCounted) -> int:
	var total := 0
	for value in sim.map_state.resource_amount:
		total += int(value)
	return total
