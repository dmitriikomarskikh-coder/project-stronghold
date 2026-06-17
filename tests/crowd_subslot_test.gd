extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	for i in range(6):
		sim.units.spawn(0, "peasant", 50, 50, int(sim.balance["units"]["peasant"]["hp"]))
	sim.step()

	var tile_counts := {}
	var tile_slots := {}
	for id in range(sim.units.alive.size()):
		if not sim.units.alive[id] or sim.units.tile_x(id) < 49 or sim.units.tile_x(id) > 51 or sim.units.tile_y(id) < 49 or sim.units.tile_y(id) > 51:
			continue
		var key := "%d,%d" % [sim.units.tile_x(id), sim.units.tile_y(id)]
		tile_counts[key] = int(tile_counts.get(key, 0)) + 1
		if not tile_slots.has(key):
			tile_slots[key] = {}
		if tile_slots[key].has(sim.units.subslot[id]):
			push_error("Duplicate subslot on tile %s" % key)
			quit(1)
			return
		tile_slots[key][sim.units.subslot[id]] = true

	for key in tile_counts.keys():
		if int(tile_counts[key]) > 4:
			push_error("Tile %s has more than four units" % key)
			quit(1)
			return
	print("Crowd subslot test passed")
	quit(0)
