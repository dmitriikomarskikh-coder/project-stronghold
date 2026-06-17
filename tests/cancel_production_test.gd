extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var townhall := 0
	var start_food: int = sim.player_food[0]
	var produce_command: Dictionary = sim.commands.make_command(sim.tick + 1, 0, "produce", [], [], townhall, {"unit_type": "peasant"})
	sim.commands.enqueue(produce_command)
	for i in range(80):
		sim.step()
	if sim.buildings.production_paid_food[townhall] <= 0:
		push_error("Expected production to pay some food before cancel")
		quit(1)
		return
	var paid_food: int = sim.buildings.production_paid_food[townhall]
	var food_before_cancel: int = sim.player_food[0]
	var cancel_command: Dictionary = sim.commands.make_command(sim.tick + 1, 0, "cancel_production", [], [], townhall)
	sim.commands.enqueue(cancel_command)
	for i in range(3):
		sim.step()
	if sim.buildings.production_type[townhall] != "":
		push_error("Expected cancel_production to clear current production")
		quit(1)
		return
	if sim.player_food[0] < food_before_cancel + paid_food:
		push_error("Expected cancel_production to refund paid food")
		quit(1)
		return
	if sim.player_food[0] > start_food:
		push_error("Expected refund not to exceed original food after normal upkeep")
		quit(1)
		return
	print("Cancel production test passed")
	quit(0)
