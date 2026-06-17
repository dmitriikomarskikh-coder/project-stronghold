extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	sim.enable_ai("res://config/ai_normal.json")
	for i in range(10):
		sim.units.spawn(1, "warrior", 104 + i, 104, int(sim.balance["units"]["warrior"]["hp"]))

	for i in range(340):
		sim.step()
	if _has_player_command(sim, 1, "attack_move"):
		push_error("Expected AI not to attack unknown enemy buildings through fog")
		quit(1)
		return

	for i in range(580):
		sim.step()
	if not _has_player_command(sim, 1, "move"):
		push_error("Expected AI scout to receive a waypoint move command")
		quit(1)
		return

	print("AI fog test passed")
	quit(0)

func _has_player_command(sim: RefCounted, player_id: int, command_type: String) -> bool:
	for command in sim.command_log:
		if int(command["player_id"]) == player_id and String(command["type"]) == command_type:
			return true
	return false
