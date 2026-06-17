extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var ids: Array = []
	for i in range(30):
		ids.append(sim.units.spawn(0, "warrior", 40 + i % 6, 40 + int(i / 6), int(sim.balance["units"]["warrior"]["hp"])))

	sim.enqueue_player_command("form_up", ids)
	for i in range(3):
		sim.step()
	if sim.platoons.live_count_for_player(0) != 1:
		push_error("Expected one platoon after first F")
		quit(1)
		return

	sim.enqueue_player_command("form_up", ids)
	for i in range(3):
		sim.step()
	if sim.platoons.live_count_for_player(0) != 0:
		push_error("Expected second F to disband selected platoon")
		quit(1)
		return
	for id_value in ids:
		var id := int(id_value)
		if sim.units.platoon_id[id] != -1 or sim.units.platoon_slot[id] != -1:
			push_error("Expected disband to clear unit platoon membership")
			quit(1)
			return

	print("Platoon disband test passed")
	quit(0)
