extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var ids: Array = []
	for i in range(90):
		ids.append(sim.units.spawn(0, "warrior", 40 + i % 10, 40 + int(i / 10), int(sim.balance["units"]["warrior"]["hp"])))
	sim.enqueue_player_command("form_up", ids)
	for i in range(3):
		sim.step()
	if sim.platoons.live_count_for_player(0) != 3:
		push_error("Expected 90 warriors to form exactly three platoons")
		quit(1)
		return
	for platoon_id in range(sim.platoons.alive.size()):
		if not sim.platoons.alive[platoon_id] or sim.platoons.owner[platoon_id] != 0:
			continue
		if sim.platoons.members[platoon_id].size() != 30:
			push_error("Expected each full platoon to have 30 members")
			quit(1)
			return
		for slot in range(30):
			var unit_id := int(sim.platoons.members[platoon_id][slot])
			if sim.units.platoon_id[unit_id] != platoon_id or sim.units.platoon_slot[unit_id] != slot:
				push_error("Expected platoon membership and slot to be mirrored on unit state")
				quit(1)
				return
	print("Platoon form-up test passed")
	quit(0)
