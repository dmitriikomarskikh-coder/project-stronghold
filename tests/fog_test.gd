extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)

	var own_townhall := _first_building(sim, 0, "townhall")
	var enemy_townhall := _first_building(sim, 1, "townhall")
	if own_townhall < 0 or enemy_townhall < 0:
		push_error("Expected both players to start with a townhall")
		quit(1)
		return

	if not sim.fog.is_visible(0, sim.buildings.anchor_x[own_townhall], sim.buildings.anchor_y[own_townhall]):
		push_error("Expected player 0 start townhall to be visible")
		quit(1)
		return
	if sim.buildings.is_known_by(0, enemy_townhall):
		push_error("Expected enemy townhall to be unknown before scouting")
		quit(1)
		return

	var scout: int = sim.units.spawn(0, "warrior", sim.buildings.anchor_x[enemy_townhall], sim.buildings.anchor_y[enemy_townhall], int(sim.balance["units"]["warrior"]["hp"]))
	sim.step()
	if not sim.fog.is_visible(0, sim.buildings.anchor_x[enemy_townhall], sim.buildings.anchor_y[enemy_townhall]):
		push_error("Expected enemy townhall to become visible after scouting")
		quit(1)
		return
	if not sim.buildings.is_known_by(0, enemy_townhall):
		push_error("Expected enemy townhall known-state to update after scouting")
		quit(1)
		return

	sim.units.pos_x[scout] = 10 * 256
	sim.units.pos_y[scout] = 10 * 256
	sim.step()
	if sim.fog.is_visible(0, sim.buildings.anchor_x[enemy_townhall], sim.buildings.anchor_y[enemy_townhall]):
		push_error("Expected enemy townhall to leave current visibility after scout moves away")
		quit(1)
		return
	if not sim.fog.is_explored(0, sim.buildings.anchor_x[enemy_townhall], sim.buildings.anchor_y[enemy_townhall]):
		push_error("Expected explored fog layer to remember scouted townhall tile")
		quit(1)
		return

	print("Fog test passed")
	quit(0)

func _first_building(sim: RefCounted, player_id: int, type_name: String) -> int:
	for id in range(sim.buildings.alive.size()):
		if sim.buildings.alive[id] and sim.buildings.owner[id] == player_id and sim.buildings.building_type[id] == type_name:
			return id
	return -1
