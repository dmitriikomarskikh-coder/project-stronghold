extends RefCounted

var state: int = 1

func seed_rng(seed_value: int) -> void:
	state = seed_value & 0x7fffffff
	if state == 0:
		state = 1

func next_u31() -> int:
	state = (1103515245 * state + 12345) & 0x7fffffff
	return state

func snapshot_state() -> int:
	return state

func restore(snapshot: int) -> void:
	state = snapshot & 0x7fffffff
	if state == 0:
		state = 1

