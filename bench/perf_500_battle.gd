extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var left: Array = []
	var right: Array = []
	for i in range(250):
		left.append(sim.units.spawn(0, "warrior", 48 + i % 25, 50 + int(i / 25), int(sim.balance["units"]["warrior"]["hp"])))
		right.append(sim.units.spawn(1, "warrior", 76 + i % 25, 50 + int(i / 25), int(sim.balance["units"]["warrior"]["hp"])))
	sim.enqueue_player_command("attack_move", left, [76, 55])
	var command: Dictionary = sim.commands.make_command(sim.tick + 1, 1, "attack_move", right, [48, 55], null, {})
	sim.commands.enqueue(command)
	var start_ms := Time.get_ticks_msec()
	for i in range(500):
		sim.step()
	var elapsed_ms := Time.get_ticks_msec() - start_ms
	if elapsed_ms > 90000:
		push_error("perf_500_battle exceeded headless budget: %d ms" % elapsed_ms)
		quit(1)
		return
	print("perf_500_battle passed: %d ms" % elapsed_ms)
	quit(0)
