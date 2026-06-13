extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var idle: RefCounted = TickRunnerScript.new()
	idle.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var initial_units: int = sim.live_units_for_player(0)
	sim.unit_limit = initial_units
	idle.unit_limit = initial_units

	sim.enqueue_player_command("produce", [], [], {"unit_type": "peasant"})
	for i in range(250):
		sim.step()
		idle.step()

	if sim.live_units_for_player(0) != initial_units:
		push_error("Unit limit must block peasant spawn")
		quit(1)
		return
	if sim.player_food[0] != idle.player_food[0]:
		push_error("Unit limit must block production payment")
		quit(1)
		return
	if sim.buildings.production_type[0] != "peasant":
		push_error("Blocked production should remain queued in the townhall")
		quit(1)
		return
	if sim.buildings.production_paid_food[0] != 0 or sim.buildings.production_ticks[0] != 0:
		push_error("Blocked production must not accumulate time or paid resources")
		quit(1)
		return
	print("Production limit test passed")
	quit(0)
