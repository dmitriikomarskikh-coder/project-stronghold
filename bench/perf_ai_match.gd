extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim_a: RefCounted = TickRunnerScript.new()
	var sim_b: RefCounted = TickRunnerScript.new()
	sim_a.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	sim_b.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	sim_a.enable_ai("res://config/ai_normal.json")
	sim_b.enable_ai("res://config/ai_normal.json")
	var start_ms := Time.get_ticks_msec()
	for i in range(1200):
		sim_a.step()
		sim_b.step()
		if i % 100 == 0 and sim_a.snapshot_bytes() != sim_b.snapshot_bytes():
			push_error("perf_ai_match desync at tick %d" % i)
			quit(1)
			return
	var elapsed_ms := Time.get_ticks_msec() - start_ms
	if elapsed_ms > 90000:
		push_error("perf_ai_match exceeded headless budget: %d ms" % elapsed_ms)
		quit(1)
		return
	print("perf_ai_match passed: %d ms" % elapsed_ms)
	quit(0)
