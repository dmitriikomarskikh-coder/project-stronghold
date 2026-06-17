extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	for i in range(195):
		sim.units.spawn(0, "peasant", 12 + i % 20, 40 + int(i / 20), int(sim.balance["units"]["peasant"]["hp"]))
	var start_ms := Time.get_ticks_msec()
	for i in range(200):
		sim.step()
	var elapsed_ms := Time.get_ticks_msec() - start_ms
	if elapsed_ms > 30000:
		push_error("perf_200_idle exceeded headless budget: %d ms" % elapsed_ms)
		quit(1)
		return
	print("perf_200_idle passed: %d ms" % elapsed_ms)
	quit(0)
