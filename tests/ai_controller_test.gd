extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	sim.enable_ai("res://config/ai_normal.json")
	for i in range(625):
		sim.step()
	if not _has_player_command(sim, 1, "gather"):
		push_error("Expected AI to enqueue gather commands for player 1 workers")
		quit(1)
		return
	if not _has_player_command(sim, 1, "produce"):
		push_error("Expected AI to enqueue production commands for player 1")
		quit(1)
		return
	print("AI controller test passed")
	quit(0)

func _has_player_command(sim: RefCounted, player_id: int, command_type: String) -> bool:
	for command in sim.command_log:
		if int(command["player_id"]) == player_id and String(command["type"]) == command_type:
			return true
	return false
