extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")

func _init() -> void:
	_attack_target_kills_adjacent_enemy()
	_attack_move_acquires_enemy()
	_attack_target_destroys_building_and_sets_winner()
	_tower_attacks_enemy_unit()
	_defense_stance_reacts_to_threat()
	_hold_stance_ignores_threat_chase()
	print("Combat test passed")
	quit(0)

func _attack_target_kills_adjacent_enemy() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var attacker: int = sim.units.spawn(0, "warrior", 40, 40, int(sim.balance["units"]["warrior"]["hp"]))
	var target: int = sim.units.spawn(1, "warrior", 41, 40, int(sim.balance["units"]["warrior"]["hp"]))
	var command: Dictionary = sim.commands.make_command(sim.tick + 1, 0, "attack_target", [attacker], [], target)
	sim.commands.enqueue(command)
	var initial_hp: int = sim.units.hp[target]
	for i in range(15):
		sim.step()
	if sim.units.hp[target] >= initial_hp:
		push_error("Expected attack_target to damage an adjacent enemy")
		quit(1)
		return
	for i in range(120):
		sim.step()
	if sim.units.alive[target]:
		push_error("Expected repeated attacks to kill the target")
		quit(1)
		return

func _attack_move_acquires_enemy() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var attacker: int = sim.units.spawn(0, "warrior", 50, 50, int(sim.balance["units"]["warrior"]["hp"]))
	var target: int = sim.units.spawn(1, "warrior", 53, 50, int(sim.balance["units"]["warrior"]["hp"]))
	sim.enqueue_player_command("attack_move", [attacker], [60, 50])
	var initial_hp: int = sim.units.hp[target]
	for i in range(120):
		sim.step()
	if sim.units.hp[target] >= initial_hp:
		push_error("Expected attack_move to acquire and damage an enemy in aggression radius")
		quit(1)
		return

func _attack_target_destroys_building_and_sets_winner() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var attacker: int = sim.units.spawn(0, "warrior", 107, 108, int(sim.balance["units"]["warrior"]["hp"]))
	var target_building := -1
	for id in range(sim.buildings.alive.size()):
		if sim.buildings.alive[id] and sim.buildings.owner[id] == 1:
			target_building = id
			break
	for id in range(sim.buildings.alive.size()):
		if sim.buildings.alive[id] and sim.buildings.owner[id] == 1:
			sim.buildings.hp[id] = 1 if id == target_building else 0
	var command: Dictionary = sim.commands.make_command(sim.tick + 1, 0, "attack_target", [attacker], [], target_building, {"target_kind": "building"})
	sim.commands.enqueue(command)
	for i in range(80):
		sim.step()
		if sim.winner_player == 0:
			break
	if sim.buildings.alive[target_building]:
		push_error("Expected attack_target to destroy an enemy building")
		quit(1)
		return
	if sim.winner_player != 0:
		push_error("Expected player 0 to win after all enemy buildings are destroyed")
		quit(1)
		return

func _tower_attacks_enemy_unit() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var tower: int = sim.buildings.spawn(0, "tower", 40, 40, int(sim.balance["buildings"]["tower"]["hp"]), 1)
	var target: int = sim.units.spawn(1, "warrior", 45, 40, int(sim.balance["units"]["warrior"]["hp"]))
	var initial_hp: int = sim.units.hp[target]
	for i in range(20):
		sim.step()
	if sim.units.hp[target] >= initial_hp:
		push_error("Expected tower %d to damage enemy unit %d" % [tower, target])
		quit(1)
		return

func _defense_stance_reacts_to_threat() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var defender: int = sim.units.spawn(0, "warrior", 40, 40, int(sim.balance["units"]["warrior"]["hp"]))
	var attacker: int = sim.units.spawn(1, "warrior", 41, 40, int(sim.balance["units"]["warrior"]["hp"]))
	sim.enqueue_player_command("move", [defender], [45, 40])
	var attack_command: Dictionary = sim.commands.make_command(sim.tick + 1, 1, "attack_target", [attacker], [], defender)
	sim.commands.enqueue(attack_command)
	for i in range(15):
		sim.step()
	if sim.units.order_type[defender] != "attack_target" or sim.units.attack_target_id[defender] != attacker:
		push_error("Expected defense stance unit to react to an attacker")
		quit(1)
		return

func _hold_stance_ignores_threat_chase() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var defender: int = sim.units.spawn(0, "warrior", 40, 40, int(sim.balance["units"]["warrior"]["hp"]))
	var attacker: int = sim.units.spawn(1, "warrior", 41, 40, int(sim.balance["units"]["warrior"]["hp"]))
	var start_tile := Vector2i(sim.units.tile_x(defender), sim.units.tile_y(defender))
	var stance_command: Dictionary = sim.commands.make_command(sim.tick + 1, 0, "set_stance", [defender], [], null, {"stance": "hold"})
	var attack_command: Dictionary = sim.commands.make_command(sim.tick + 1, 1, "attack_target", [attacker], [], defender)
	sim.commands.enqueue(stance_command)
	sim.commands.enqueue(attack_command)
	for i in range(15):
		sim.step()
	if sim.units.tile_x(defender) != start_tile.x or sim.units.tile_y(defender) != start_tile.y or not sim.units.path[defender].is_empty():
		push_error("Expected hold stance unit not to chase attackers")
		quit(1)
		return
