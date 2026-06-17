extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var frame: int = sim.buildings.place_frame(0, "farm", 35, 35, 80, 0)
	sim.buildings.invested_wood[frame] = 20
	sim.buildings.progress[frame] = 20
	var before_wood: int = sim.player_wood[0]
	var command: Dictionary = sim.commands.make_command(sim.tick + 1, 0, "demolish", [], [], frame)
	sim.commands.enqueue(command)
	for i in range(3):
		sim.step()
	if sim.buildings.alive[frame]:
		push_error("Expected demolish to remove own building")
		quit(1)
		return
	if sim.player_wood[0] != before_wood + 10:
		push_error("Expected demolish to refund 50 percent of invested wood")
		quit(1)
		return
	print("Demolish test passed")
	quit(0)
