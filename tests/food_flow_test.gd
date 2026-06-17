extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var initial_food: int = sim.player_food[0]
	sim.buildings.spawn(0, "farm", 35, 35, int(sim.balance["buildings"]["farm"]["hp"]), 1)
	for i in range(100):
		sim.step()
	if sim.player_food[0] <= initial_food:
		push_error("Expected farm food flow to outpace upkeep during the test window")
		quit(1)
		return
	if sim.food_trend_10s(0) <= 0:
		push_error("Expected farm food flow to produce a positive 10 second trend")
		quit(1)
		return
	print("Food flow test passed")
	quit(0)
