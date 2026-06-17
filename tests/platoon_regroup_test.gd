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
	var platoon_id: int = sim.units.platoon_id[int(ids[0])]
	var attacker: int = sim.units.spawn(1, "warrior", sim.units.tile_x(int(ids[0])) + 1, sim.units.tile_y(int(ids[0])), int(sim.balance["units"]["warrior"]["hp"]))
	var command: Dictionary = sim.commands.make_command(sim.tick + 1, 1, "attack_target", [attacker], [], int(ids[0]))
	sim.commands.enqueue(command)
	for i in range(4):
		sim.step()
	if not sim.platoons.broken[platoon_id]:
		push_error("Expected combat contact to mark platoon formation as broken")
		quit(1)
		return

	sim.units.hp[attacker] = 0
	sim.step()
	for id_value in ids:
		sim.units.stop(int(id_value))
	for i in range(40):
		sim.step()
	if sim.platoons.broken[platoon_id]:
		push_error("Expected idle broken platoon to regroup after calm ticks")
		quit(1)
		return

	var unique_targets: Dictionary = {}
	for id_value in ids:
		var id := int(id_value)
		var key := "%s,%s" % [sim.units.target_x[id], sim.units.target_y[id]]
		unique_targets[key] = true
	if unique_targets.size() < 20:
		push_error("Expected regroup to assign spread formation targets")
		quit(1)
		return

	print("Platoon regroup test passed")
	quit(0)
