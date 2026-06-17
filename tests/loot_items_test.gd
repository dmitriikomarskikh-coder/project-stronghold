extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var carrier: int = sim.units.spawn(0, "peasant", 50, 50, int(sim.balance["units"]["peasant"]["hp"]))
	carrier = carrier
	sim.units.hp[carrier] = 0
	sim.units.carry_type[carrier] = "wood"
	sim.units.carry_amount[carrier] = 5
	sim.step()
	if sim.loot_items.alive.size() == 0 or not sim.loot_items.alive[0] or sim.loot_items.amount[0] != 5:
		push_error("Expected dead carrier to drop a wood loot item")
		quit(1)
		return
	var picker: int = sim.units.spawn(0, "peasant", sim.loot_items.pos_x[0], sim.loot_items.pos_y[0], int(sim.balance["units"]["peasant"]["hp"]))
	sim.step()
	if sim.units.carry_amount[picker] != 5 or sim.units.carry_type[picker] != "wood":
		push_error("Expected peasant to pick up loot on its tile")
		quit(1)
		return
	if sim.loot_items.alive[0]:
		push_error("Expected depleted loot item to be removed")
		quit(1)
		return
	print("Loot items test passed")
	quit(0)
