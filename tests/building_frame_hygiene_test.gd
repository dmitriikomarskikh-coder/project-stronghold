extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	_unassigned_frame_expires()
	_zero_frame_limit_blocks_extra_frames()
	print("Building frame hygiene test passed")
	quit(0)

func _unassigned_frame_expires() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var command: Dictionary = sim.commands.make_command(sim.tick + 1, 0, "build_place", [], [23, 25], null, {"building_type": "farm"})
	sim.commands.enqueue(command)
	for i in range(603):
		sim.step()
	if sim.buildings.zero_progress_frame_count(0) != 0:
		push_error("Expected unassigned zero-progress frame to expire")
		quit(1)
		return

func _zero_frame_limit_blocks_extra_frames() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	for y in range(14, 34, 6):
		for x in range(14, 34, 6):
			sim.units.spawn(0, "peasant", x, y, int(sim.balance["units"]["peasant"]["hp"]))
	var placed := 0
	for y in range(14, 34, 3):
		for x in range(14, 34, 3):
			if placed >= 21:
				break
			if not _valid_farm_anchor(sim, x, y):
				continue
			var command: Dictionary = sim.commands.make_command(sim.tick + 1, 0, "build_place", [], [x, y], null, {"building_type": "farm"})
			sim.commands.enqueue(command)
			placed += 1
		if placed >= 21:
			break
	for i in range(3):
		sim.step()
	if sim.buildings.zero_progress_frame_count(0) != 20:
		push_error("Expected zero-progress frame limit to cap frames at 20")
		quit(1)
		return

func _valid_farm_anchor(sim: RefCounted, x: int, y: int) -> bool:
	for dy in range(2):
		for dx in range(2):
			var tx := x + dx
			var ty := y + dy
			if not sim.map_state.in_bounds(tx, ty) or not sim.map_state.is_walkable(tx, ty):
				return false
			if sim.map_state.resource_type_at(tx, ty) != "":
				return false
			for id in range(sim.buildings.alive.size()):
				if not sim.buildings.alive[id]:
					continue
				var cfg: Dictionary = sim.balance["buildings"][sim.buildings.building_type[id]]
				var footprint: Array = cfg["footprint"]
				var inside_x: bool = tx >= sim.buildings.anchor_x[id] and tx < sim.buildings.anchor_x[id] + int(footprint[0])
				var inside_y: bool = ty >= sim.buildings.anchor_y[id] and ty < sim.buildings.anchor_y[id] + int(footprint[1])
				if inside_x and inside_y:
					return false
	return true
