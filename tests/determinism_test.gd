extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var first: Array = _run_once()
	var second: Array = _run_once()
	if first.size() != second.size():
		push_error("Snapshot count differs")
		quit(1)
		return
	for i in range(first.size()):
		if first[i] != second[i]:
			push_error("Determinism mismatch at snapshot %d" % i)
			quit(1)
			return
	print("Determinism test passed: %d snapshots compared" % first.size())
	quit(0)

func _run_once() -> Array:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	sim.enqueue_player_command("produce", [], [], {"unit_type": "peasant"})
	sim.enqueue_player_command("gather", [0, 1], [15, 18])
	sim.enqueue_player_command("move", [2, 3, 4], [24, 26])
	var snapshots: Array = []
	for i in range(500):
		sim.step()
		if i % 100 == 99:
			snapshots.append(sim.snapshot_bytes())
	return snapshots
