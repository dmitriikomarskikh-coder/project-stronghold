extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var defender: int = sim.units.spawn(0, "warrior", 40, 40, int(sim.balance["units"]["warrior"]["hp"]))
	var attacker: int = sim.units.spawn(1, "warrior", 41, 40, int(sim.balance["units"]["warrior"]["hp"]))
	var command: Dictionary = sim.commands.make_command(sim.tick + 1, 1, "attack_target", [attacker], [], defender)
	sim.commands.enqueue(command)
	for i in range(4):
		sim.step()
	if sim.last_attack_tick[0] < 0:
		push_error("Expected attack event tick for player 0")
		quit(1)
		return
	if sim.last_attack_x[0] != 40 or sim.last_attack_y[0] != 40:
		push_error("Expected attack event tile to match damaged unit tile")
		quit(1)
		return
	print("Attack event test passed")
	quit(0)
