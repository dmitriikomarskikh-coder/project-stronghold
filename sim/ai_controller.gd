extends RefCounted

var config: Dictionary = {}
var next_wave_tick_by_player := {}
var next_scout_tick_by_player := {}
var scout_waypoint_index_by_player := {}

func setup(ai_config: Dictionary) -> void:
	config = ai_config.duplicate(true)

func step(sim, player_id: int) -> void:
	var period := int(config.get("check_period_ticks", 20))
	if period <= 0 or sim.tick % period != 0:
		return
	_assign_builders(sim, player_id)
	_ensure_build_order(sim, player_id)
	_keep_workers_busy(sim, player_id)
	_queue_worker_production(sim, player_id)
	_queue_military_production(sim, player_id)
	_send_scout(sim, player_id)
	_launch_attack_wave(sim, player_id)

func _ensure_build_order(sim, player_id: int) -> void:
	if _first_incomplete_building(sim, player_id) >= 0:
		return
	var desired: Dictionary = _desired_buildings(sim, player_id)
	for type_name in ["storehouse", "farm", "barracks", "tower"]:
		var target_count := int(desired.get(type_name, 0))
		if target_count <= 0 or _building_count(sim, player_id, type_name) >= target_count:
			continue
		if not _can_pay_building(sim, player_id, type_name):
			continue
		var anchor := _find_build_site(sim, player_id, type_name)
		if anchor.x >= 0:
			_enqueue(sim, player_id, "build_place", [], [anchor.x, anchor.y], null, {"building_type": type_name})
			return

func _desired_buildings(sim, player_id: int) -> Dictionary:
	var farms: Array = config.get("farm_targets", [1, 2, 3, 4])
	var minutes := int(sim.tick / 600)
	var farm_target := int(farms[min(minutes, farms.size() - 1)])
	if sim.player_food[player_id] < 250:
		farm_target += 1
	var desired := {
		"storehouse": 1,
		"farm": farm_target,
		"barracks": 1 if _worker_count(sim, player_id) >= int(config.get("barracks_min_workers", 6)) else 0,
		"tower": 1 if sim.tick >= int(config.get("tower_start_tick", 1200)) else 0,
	}
	return desired

func _assign_builders(sim, player_id: int) -> void:
	var frame := _first_incomplete_building(sim, player_id)
	if frame < 0:
		return
	var ids := _workers_near(sim, player_id, Vector2i(sim.buildings.anchor_x[frame], sim.buildings.anchor_y[frame]), int(config.get("builders_per_site", 3)))
	if ids.is_empty():
		return
	_enqueue(sim, player_id, "build_assign", ids, [], frame)

func _keep_workers_busy(sim, player_id: int) -> void:
	var hints: Dictionary = sim.map_state.players[str(player_id)]["resource_hint"]
	var wood_hint: Array = hints["wood"]
	var stone_hint: Array = hints["stone"]
	var use_wood := true
	for id in range(sim.units.alive.size()):
		if not sim.units.alive[id] or sim.units.owner[id] != player_id or sim.units.unit_type[id] != "peasant":
			continue
		if sim.units.order_type[id] != "idle":
			continue
		var target: Array = wood_hint if use_wood else stone_hint
		use_wood = not use_wood
		_enqueue(sim, player_id, "gather", [id], [int(target[0]), int(target[1])])

func _queue_worker_production(sim, player_id: int) -> void:
	var target_workers := _worker_target(sim)
	if _worker_count(sim, player_id) >= target_workers:
		return
	var townhall := _first_building(sim, player_id, "townhall")
	if townhall < 0:
		return
	if sim.buildings.production_type[townhall] != "" or sim.buildings.production_queue[townhall].size() >= 2:
		return
	_enqueue(sim, player_id, "produce", [], [], townhall, {"unit_type": "peasant"})

func _queue_military_production(sim, player_id: int) -> void:
	for id in range(sim.buildings.alive.size()):
		if not sim.buildings.alive[id] or sim.buildings.owner[id] != player_id:
			continue
		if sim.buildings.building_type[id] != "barracks" or not sim.buildings.completed[id]:
			continue
		if sim.buildings.production_type[id] != "" or sim.buildings.production_queue[id].size() >= 2:
			continue
		_enqueue(sim, player_id, "produce", [], [], id, {"unit_type": "warrior"})

func _worker_target(sim) -> int:
	var targets: Array = config.get("worker_targets", [5, 10, 16])
	var minutes := int(sim.tick / 600)
	var index: int = min(minutes, targets.size() - 1)
	return int(targets[index])

func _worker_count(sim, player_id: int) -> int:
	var count := 0
	for id in range(sim.units.alive.size()):
		if sim.units.alive[id] and sim.units.owner[id] == player_id and sim.units.unit_type[id] == "peasant":
			count += 1
	return count

func _building_count(sim, player_id: int, type_name: String) -> int:
	var count := 0
	for id in range(sim.buildings.alive.size()):
		if sim.buildings.alive[id] and sim.buildings.owner[id] == player_id and sim.buildings.building_type[id] == type_name:
			count += 1
	return count

func _first_incomplete_building(sim, player_id: int) -> int:
	for id in range(sim.buildings.alive.size()):
		if sim.buildings.alive[id] and sim.buildings.owner[id] == player_id and not sim.buildings.completed[id]:
			return id
	return -1

func _workers_near(sim, player_id: int, anchor: Vector2i, limit: int) -> Array:
	var scored: Array = []
	for id in range(sim.units.alive.size()):
		if not sim.units.alive[id] or sim.units.owner[id] != player_id or sim.units.unit_type[id] != "peasant":
			continue
		var score: int = absi(sim.units.tile_x(id) - anchor.x) + absi(sim.units.tile_y(id) - anchor.y)
		scored.append([score, id])
	scored.sort()
	var result: Array = []
	for pair in scored:
		result.append(int(pair[1]))
		if result.size() >= limit:
			break
	return result

func _can_pay_building(sim, player_id: int, type_name: String) -> bool:
	var cost: Dictionary = sim.balance["buildings"][type_name].get("cost", {})
	return sim.player_wood[player_id] >= int(cost.get("wood", 0)) and sim.player_stone[player_id] >= int(cost.get("stone", 0))

func _find_build_site(sim, player_id: int, type_name: String) -> Vector2i:
	var townhall := _first_building(sim, player_id, "townhall")
	if townhall < 0:
		return Vector2i(-1, -1)
	var origin := Vector2i(sim.buildings.anchor_x[townhall], sim.buildings.anchor_y[townhall])
	var offsets := [
		Vector2i(-5, -4), Vector2i(4, -4), Vector2i(-5, 4), Vector2i(4, 4),
		Vector2i(-8, 0), Vector2i(7, 0), Vector2i(0, -7), Vector2i(0, 7),
		Vector2i(-9, -7), Vector2i(7, -7), Vector2i(-9, 7), Vector2i(7, 7),
	]
	for offset in offsets:
		var anchor: Vector2i = origin + offset
		if sim._can_place_building(player_id, type_name, anchor):
			return anchor
	return Vector2i(-1, -1)

func _launch_attack_wave(sim, player_id: int) -> void:
	var wave_start := int(config.get("wave_start", 10))
	var next_tick := int(next_wave_tick_by_player.get(player_id, 300))
	if sim.tick < next_tick:
		return
	var ids: Array = []
	for id in range(sim.units.alive.size()):
		if sim.units.alive[id] and sim.units.owner[id] == player_id:
			ids.append(id)
	if ids.size() < wave_start:
		return
	var target_building := _first_known_enemy_building(sim, player_id)
	if target_building < 0:
		return
	var target_tile := [sim.buildings.anchor_x[target_building], sim.buildings.anchor_y[target_building]]
	_enqueue(sim, player_id, "attack_move", ids, target_tile)
	next_wave_tick_by_player[player_id] = sim.tick + 600

func _send_scout(sim, player_id: int) -> void:
	var period := int(config.get("scout_period_ticks", 900))
	if period <= 0:
		return
	var next_tick := int(next_scout_tick_by_player.get(player_id, period))
	if sim.tick < next_tick:
		return
	var waypoints: Array = sim.map_state.players[str(player_id)].get("scout_waypoints", [])
	if waypoints.is_empty():
		next_scout_tick_by_player[player_id] = sim.tick + period
		return
	var scout := _first_idle_warrior(sim, player_id)
	if scout < 0:
		return
	var index := int(scout_waypoint_index_by_player.get(player_id, 0))
	var waypoint: Array = waypoints[index % waypoints.size()]
	scout_waypoint_index_by_player[player_id] = index + 1
	next_scout_tick_by_player[player_id] = sim.tick + period
	_enqueue(sim, player_id, "move", [scout], [int(waypoint[0]), int(waypoint[1])])

func _first_building(sim, player_id: int, type_name: String) -> int:
	for id in range(sim.buildings.alive.size()):
		if sim.buildings.alive[id] and sim.buildings.owner[id] == player_id and sim.buildings.progress[id] > 0 and sim.buildings.building_type[id] == type_name:
			return id
	return -1

func _first_known_enemy_building(sim, player_id: int) -> int:
	for id in range(sim.buildings.alive.size()):
		if sim.buildings.alive[id] and sim.buildings.owner[id] != player_id and sim.buildings.progress[id] > 0 and sim.buildings.is_known_by(player_id, id):
			return id
	return -1

func _first_idle_warrior(sim, player_id: int) -> int:
	for id in range(sim.units.alive.size()):
		if sim.units.alive[id] and sim.units.owner[id] == player_id and sim.units.unit_type[id] == "warrior" and sim.units.order_type[id] == "idle":
			return id
	return -1

func _enqueue(sim, player_id: int, type: String, unit_ids: Array = [], target_tile: Array = [], target_entity_id = null, params: Dictionary = {}) -> void:
	var command: Dictionary = sim.commands.make_command(sim.tick + 1, player_id, type, unit_ids, target_tile, target_entity_id, params)
	sim.commands.enqueue(command)
