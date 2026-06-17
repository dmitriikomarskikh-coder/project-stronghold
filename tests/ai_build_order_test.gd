extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	sim.enable_ai("res://config/ai_normal.json")

	for i in range(45):
		sim.step()
	if not _has_player_command(sim, 1, "build_place"):
		push_error("Expected AI build order to place an early economy building")
		quit(1)
		return
	if not _has_player_command(sim, 1, "build_assign"):
		push_error("Expected AI build order to assign workers to its building frame")
		quit(1)
		return

	var barracks: int = sim.buildings.spawn(1, "barracks", 96, 102, int(sim.balance["buildings"]["barracks"]["hp"]), 1)
	for i in range(20):
		sim.step()
	var warrior_command := false
	for command in sim.command_log:
		if int(command["player_id"]) == 1 and String(command["type"]) == "produce" and command["target_entity_id"] != null:
			if int(command["target_entity_id"]) == barracks and String(command["params"].get("unit_type", "")) == "warrior":
				warrior_command = true
				break
	if not warrior_command:
		push_error("Expected AI to queue warrior production at a completed barracks")
		quit(1)
		return

	print("AI build order test passed")
	quit(0)

func _has_player_command(sim: RefCounted, player_id: int, command_type: String) -> bool:
	for command in sim.command_log:
		if int(command["player_id"]) == player_id and String(command["type"]) == command_type:
			return true
	return false
