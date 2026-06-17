extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var ids: Array = []
	for i in range(9):
		ids.append(sim.units.spawn(0, "peasant", 18 + i, 32, int(sim.balance["units"]["peasant"]["hp"])))

	var anchor := Vector2i(50, 52)
	var expected := [
		anchor,
		anchor + Vector2i(0, -1),
		anchor + Vector2i(1, 0),
		anchor + Vector2i(0, 1),
		anchor + Vector2i(-1, 0),
		anchor + Vector2i(1, -1),
		anchor + Vector2i(1, 1),
		anchor + Vector2i(-1, 1),
		anchor + Vector2i(-1, -1),
	]

	sim.enqueue_player_command("move", ids, [anchor.x, anchor.y])
	for i in range(3):
		sim.step()

	for i in range(ids.size()):
		var id := int(ids[i])
		var actual := Vector2i(int(sim.units.target_x[id]), int(sim.units.target_y[id]))
		if actual != expected[i]:
			push_error("Expected loose group unit %s target %s, got %s" % [id, expected[i], actual])
			quit(1)
			return

	print("Group move fan test passed")
	quit(0)
