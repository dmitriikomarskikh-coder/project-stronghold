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
		push_error("Expected 30 warriors to form one platoon")
		quit(1)
		return

	var anchor := Vector2i(72, 70)
	sim.enqueue_player_command("move", ids, [anchor.x, anchor.y])
	for i in range(4):
		sim.step()

	var targets: Dictionary = {}
	for id_value in ids:
		var id := int(id_value)
		var slot: int = sim.units.platoon_slot[id]
		var expected: Vector2i = anchor + Vector2i(posmod(slot, 3) - 1, int(slot / 3))
		var actual := Vector2i(int(sim.units.target_x[id]), int(sim.units.target_y[id]))
		if actual != expected:
			push_error("Expected platoon member %s slot %s target %s, got %s" % [id, slot, expected, actual])
			quit(1)
			return
		var key := "%s,%s" % [actual.x, actual.y]
		if targets.has(key):
			push_error("Expected each platoon member to receive a unique formation tile")
			quit(1)
			return
		targets[key] = true

	print("Platoon move formation test passed")
	quit(0)
