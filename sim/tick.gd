extends RefCounted

const Commands := preload("res://sim/commands.gd")
const GameMap := preload("res://sim/map.gd")
const Rng := preload("res://sim/rng.gd")
const Snapshot := preload("res://sim/snapshot.gd")
const Units := preload("res://sim/units.gd")
const Buildings := preload("res://sim/buildings.gd")
const Pathfinding := preload("res://sim/pathfinding.gd")

const TICK_MS := 100

var tick := 0
var render_accumulator := 0.0
var map_state: RefCounted
var commands: RefCounted
var command_log: Array:
	get:
		return commands.log
var rng: RefCounted
var snapshot_writer: RefCounted
var units: RefCounted
var buildings: RefCounted
var pathfinding: RefCounted
var balance: Dictionary = {}
var player_wood := PackedInt32Array([1000, 1000])
var player_stone := PackedInt32Array([1000, 1000])
var player_food := PackedInt32Array([1000, 1000])
var food_acc := PackedInt32Array([0, 0])
var farm_acc := PackedInt32Array([0, 0])
var unit_limit := 200

func load_match(map_path: String, balance_path: String, seed_value: int) -> void:
	balance = _load_json(balance_path)
	player_wood = PackedInt32Array([int(balance["start_resources"]["wood"]), int(balance["start_resources"]["wood"])])
	player_stone = PackedInt32Array([int(balance["start_resources"]["stone"]), int(balance["start_resources"]["stone"])])
	player_food = PackedInt32Array([int(balance["start_resources"]["food"]), int(balance["start_resources"]["food"])])
	unit_limit = int(balance["unit_limit"])

	map_state = GameMap.new()
	map_state.load_from_json(map_path)
	commands = Commands.new()
	rng = Rng.new()
	rng.seed_rng(seed_value)
	snapshot_writer = Snapshot.new()
	units = Units.new()
	buildings = Buildings.new()
	pathfinding = Pathfinding.new()
	_spawn_start_buildings()
	_spawn_start_units()
	tick = 0

func advance_render_time(delta: float) -> void:
	render_accumulator += delta
	while render_accumulator >= 0.1:
		step()
		render_accumulator -= 0.1

func step() -> void:
	var tick_commands: Array = commands.pop_for_tick(tick)
	_apply_commands(tick_commands)
	_phase_movement()
	_phase_combat()
	_phase_gather_and_loot()
	_phase_building()
	_phase_production()
	_phase_food_consumption()
	_phase_cleanup_dead()
	tick += 1

func snapshot_bytes() -> PackedByteArray:
	return snapshot_writer.write_snapshot(self)

func live_units_for_player(player_id: int) -> int:
	return units.live_count_for_player(player_id)

func live_buildings_for_player(player_id: int) -> int:
	return buildings.live_count_for_player(player_id)

func food_trend_10s(_player_id: int) -> int:
	return 0

func _apply_commands(tick_commands: Array) -> void:
	for command in tick_commands:
		var type := String(command["type"])
		if type == "move":
			_apply_move_command(command)
		elif type == "stop":
			for unit_id in command["unit_ids"]:
				units.stop(int(unit_id))
		elif type == "gather":
			_apply_gather_command(command)
		elif type == "produce":
			_apply_produce_command(command)

func enqueue_player_command(type: String, unit_ids: Array, target_tile: Array = [], params: Dictionary = {}) -> void:
	var command: Dictionary = commands.make_command(tick + 1, 0, type, unit_ids, target_tile, null, params)
	commands.enqueue(command)

func _phase_movement() -> void:
	for id in range(units.alive.size()):
		if units.alive[id] and (units.order_type[id] == "move" or units.order_type[id] == "gather_to_resource" or units.order_type[id] == "return_resource"):
			_step_unit_move(id)

func _phase_combat() -> void:
	pass

func _phase_gather_and_loot() -> void:
	for id in range(units.alive.size()):
		if not units.alive[id] or units.unit_type[id] != "peasant":
			continue
		if units.order_type[id] == "gathering":
			_step_gather(id)
		elif units.order_type[id] == "return_resource":
			_try_deposit(id)

func _phase_building() -> void:
	pass

func _phase_production() -> void:
	for id in range(buildings.alive.size()):
		if not buildings.alive[id] or buildings.production_type[id] == "":
			continue
		_step_building_production(id)

func _phase_food_consumption() -> void:
	for player_id in range(2):
		food_acc[player_id] += live_units_for_player(player_id)
		if food_acc[player_id] >= 100:
			var due := int(food_acc[player_id] / 100)
			var actual: int = min(player_food[player_id], due)
			player_food[player_id] -= actual
			food_acc[player_id] %= 100

func _phase_cleanup_dead() -> void:
	units.cleanup_dead()

func _spawn_start_units() -> void:
	for player_key in map_state.players.keys():
		var player_id := int(player_key)
		var area: Array = map_state.players[player_key]["start_workers_area"]
		for i in range(5):
			units.spawn(player_id, "peasant", int(area[0]) + i % 3, int(area[1]) + int(i / 3), int(balance["units"]["peasant"]["hp"]))

func _spawn_start_buildings() -> void:
	for player_key in map_state.players.keys():
		var player_id := int(player_key)
		var townhall_anchor: Array = map_state.players[player_key]["start_townhall"]
		buildings.spawn(player_id, "townhall", int(townhall_anchor[0]), int(townhall_anchor[1]), int(balance["buildings"]["townhall"]["hp"]), 1)
		var hint: Array = map_state.players[player_key]["resource_hint"]["wood"]
		buildings.spawn(player_id, "storehouse", int(hint[0]) + 3, int(hint[1]) + 3, int(balance["buildings"]["storehouse"]["hp"]), 1)

func _apply_move_command(command: Dictionary) -> void:
	var target: Array = command["target_tile"]
	if target.size() < 2:
		return
	var target_tile := Vector2i(int(target[0]), int(target[1]))
	var ids: Array = command["unit_ids"].duplicate()
	ids.sort()
	for unit_id in ids:
		var id := int(unit_id)
		if id < 0 or id >= units.alive.size() or not units.alive[id]:
			continue
		if units.owner[id] != int(command["player_id"]):
			continue
		var start := Vector2i(units.tile_x(id), units.tile_y(id))
		var path: Array = pathfinding.find_path(map_state, start, target_tile, int(balance["pathfinding"]["max_path_tiles"]))
		units.set_move_order(id, target_tile.x, target_tile.y, path)

func _apply_gather_command(command: Dictionary) -> void:
	var target: Array = command["target_tile"]
	if target.size() < 2:
		return
	var resource_tile := Vector2i(int(target[0]), int(target[1]))
	if not map_state.in_bounds(resource_tile.x, resource_tile.y):
		return
	var resource_type: String = map_state.resource_type_at(resource_tile.x, resource_tile.y)
	if resource_type == "" or map_state.resource_left_at(resource_tile.x, resource_tile.y) <= 0:
		return
	var ids: Array = command["unit_ids"].duplicate()
	ids.sort()
	for unit_id in ids:
		var id := int(unit_id)
		if id < 0 or id >= units.alive.size() or not units.alive[id] or units.unit_type[id] != "peasant":
			continue
		if units.owner[id] != int(command["player_id"]):
			continue
		var start := Vector2i(units.tile_x(id), units.tile_y(id))
		var assigned_resource: Vector2i = _nearest_accessible_resource_tile(resource_tile, resource_type, start)
		if assigned_resource.x < 0:
			units.stop(id)
			continue
		var slot := _resource_work_slot(assigned_resource, start)
		if slot.x < 0:
			units.stop(id)
			continue
		var path: Array = pathfinding.find_path(map_state, start, slot, int(balance["pathfinding"]["max_path_tiles"]))
		units.set_gather_order(id, assigned_resource.x, assigned_resource.y, slot.x, slot.y, resource_type, path)

func _step_unit_move(id: int) -> void:
	if units.path_index[id] >= units.path[id].size():
		if units.order_type[id] == "gather_to_resource":
			units.order_type[id] = "gathering"
		elif units.order_type[id] == "return_resource":
			_try_deposit(id)
		else:
			units.stop(id)
		return
	var next_tile: Vector2i = units.path[id][units.path_index[id]]
	var target_pos := Vector2i(next_tile.x * 256, next_tile.y * 256)
	var dx: int = target_pos.x - units.pos_x[id]
	var dy: int = target_pos.y - units.pos_y[id]
	var speed := int(balance["units"][units.unit_type[id]]["move_speed_per_tick"])
	var step: Vector2i = _movement_step(dx, dy, speed)
	units.pos_x[id] += step.x
	units.pos_y[id] += step.y
	if units.pos_x[id] == target_pos.x and units.pos_y[id] == target_pos.y:
		units.path_index[id] += 1
		if units.path_index[id] >= units.path[id].size():
			if units.order_type[id] == "gather_to_resource":
				units.order_type[id] = "gathering"
			elif units.order_type[id] == "return_resource":
				_try_deposit(id)
			else:
				units.stop(id)

func _movement_step(dx: int, dy: int, speed: int) -> Vector2i:
	if dx == 0 and dy == 0:
		return Vector2i.ZERO
	var sx := signi(dx)
	var sy := signi(dy)
	var step_x := 0
	var step_y := 0
	if dx != 0 and dy != 0:
		step_x = min(abs(dx), int(speed * 181 / 256)) * sx
		step_y = min(abs(dy), int(speed * 181 / 256)) * sy
	else:
		step_x = min(abs(dx), speed) * sx
		step_y = min(abs(dy), speed) * sy
	return Vector2i(step_x, step_y)

func signi(value: int) -> int:
	if value < 0:
		return -1
	if value > 0:
		return 1
	return 0

func _resource_work_slot(resource_tile: Vector2i, from_tile: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := 999999999
	for delta: Vector2i in Pathfinding.NEIGHBORS:
		var candidate := resource_tile + delta
		if not map_state.in_bounds(candidate.x, candidate.y) or not map_state.is_walkable(candidate.x, candidate.y):
			continue
		var dist := (candidate.x - from_tile.x) * (candidate.x - from_tile.x) + (candidate.y - from_tile.y) * (candidate.y - from_tile.y)
		if dist < best_dist:
				best = candidate
				best_dist = dist
	return best

func _nearest_accessible_resource_tile(target_tile: Vector2i, resource_type: String, from_tile: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := 999999999
	var radius_limit := int(balance["pathfinding"]["max_path_tiles"])
	for radius in range(radius_limit + 1):
		var min_y: int = max(0, target_tile.y - radius)
		var max_y: int = min(map_state.size_y - 1, target_tile.y + radius)
		var min_x: int = max(0, target_tile.x - radius)
		var max_x: int = min(map_state.size_x - 1, target_tile.x + radius)
		for y in range(min_y, max_y + 1):
			for x in range(min_x, max_x + 1):
				if max(abs(x - target_tile.x), abs(y - target_tile.y)) != radius:
					continue
				if map_state.resource_type_at(x, y) != resource_type or map_state.resource_left_at(x, y) <= 0:
					continue
				var resource_tile := Vector2i(x, y)
				var slot := _resource_work_slot(resource_tile, from_tile)
				if slot.x < 0:
					continue
				var dist: int = (slot.x - from_tile.x) * (slot.x - from_tile.x) + (slot.y - from_tile.y) * (slot.y - from_tile.y)
				var score: int = radius * 1000000 + dist * 1000 + y * map_state.size_x + x
				if score < best_score:
					best = resource_tile
					best_score = score
		if best.x >= 0:
			return best
	return best

func _step_gather(id: int) -> void:
	if map_state.resource_left_at(units.work_x[id], units.work_y[id]) <= 0:
		_route_to_dropoff(id)
		return
	var capacity := int(balance["units"]["peasant"]["carry_capacity"])
	if units.carry_amount[id] >= capacity:
		_route_to_dropoff(id)
		return
	units.gather_acc[id] += 1
	if units.gather_acc[id] >= 10:
		units.gather_acc[id] = 0
		var taken: int = map_state.take_resource(units.work_x[id], units.work_y[id], 1)
		units.carry_amount[id] += taken
		if units.carry_amount[id] >= capacity or taken == 0:
			_route_to_dropoff(id)

func _route_to_dropoff(id: int) -> void:
	if units.carry_amount[id] <= 0:
		units.stop(id)
		return
	var start := Vector2i(units.tile_x(id), units.tile_y(id))
	var drop_id: int = buildings.first_dropoff_for_player(units.owner[id], balance, start)
	if drop_id < 0:
		units.order_type[id] = "idle"
		return
	var drop_tile := Vector2i(buildings.anchor_x[drop_id], buildings.anchor_y[drop_id])
	var slot := _dropoff_slot(drop_id, start)
	var path: Array = pathfinding.find_path(map_state, start, slot, int(balance["pathfinding"]["max_path_tiles"]))
	units.set_return_order(id, drop_tile.x, drop_tile.y, path)

func _dropoff_slot(building_id: int, from_tile: Vector2i) -> Vector2i:
	var cfg: Dictionary = balance["buildings"][buildings.building_type[building_id]]
	var footprint: Array = cfg["footprint"]
	var best := Vector2i(-1, -1)
	var best_dist := 999999999
	for y in range(buildings.anchor_y[building_id] - 1, buildings.anchor_y[building_id] + int(footprint[1]) + 1):
		for x in range(buildings.anchor_x[building_id] - 1, buildings.anchor_x[building_id] + int(footprint[0]) + 1):
			var on_perimeter: bool = x < buildings.anchor_x[building_id] or y < buildings.anchor_y[building_id] or x >= buildings.anchor_x[building_id] + int(footprint[0]) or y >= buildings.anchor_y[building_id] + int(footprint[1])
			if not on_perimeter or not map_state.in_bounds(x, y) or not map_state.is_walkable(x, y):
				continue
			var dist := (x - from_tile.x) * (x - from_tile.x) + (y - from_tile.y) * (y - from_tile.y)
			if dist < best_dist:
				best = Vector2i(x, y)
				best_dist = dist
	return best

func _try_deposit(id: int) -> void:
	if units.carry_amount[id] <= 0:
		units.stop(id)
		return
	if units.carry_type[id] == "wood":
		player_wood[units.owner[id]] += units.carry_amount[id]
	elif units.carry_type[id] == "stone":
		player_stone[units.owner[id]] += units.carry_amount[id]
	units.carry_amount[id] = 0
	units.gather_acc[id] = 0
	var resource_tile := Vector2i(units.work_x[id], units.work_y[id])
	if map_state.in_bounds(resource_tile.x, resource_tile.y) and map_state.resource_left_at(resource_tile.x, resource_tile.y) > 0:
		var slot := _resource_work_slot(resource_tile, Vector2i(units.tile_x(id), units.tile_y(id)))
		var path: Array = pathfinding.find_path(map_state, Vector2i(units.tile_x(id), units.tile_y(id)), slot, int(balance["pathfinding"]["max_path_tiles"]))
		units.set_gather_order(id, resource_tile.x, resource_tile.y, slot.x, slot.y, units.carry_type[id], path)
	else:
		units.stop(id)

func _apply_produce_command(command: Dictionary) -> void:
	var building_id := int(command["target_entity_id"]) if command["target_entity_id"] != null else -1
	if building_id < 0:
		for id in range(buildings.alive.size()):
			if buildings.alive[id] and buildings.owner[id] == int(command["player_id"]) and buildings.building_type[id] == "townhall":
				building_id = id
				break
	if building_id < 0 or building_id >= buildings.alive.size() or not buildings.alive[building_id]:
		return
	if buildings.owner[building_id] != int(command["player_id"]) or buildings.building_type[building_id] != "townhall":
		return
	var unit_type := String(command["params"].get("unit_type", "peasant"))
	if unit_type != "peasant":
		return
	if buildings.production_type[building_id] != "":
		return
	buildings.start_production(building_id, unit_type)

func _step_building_production(building_id: int) -> void:
	var type_name: String = buildings.production_type[building_id]
	var player: int = buildings.owner[building_id]
	var cfg: Dictionary = balance["units"][type_name]
	var production_time := int(cfg["production_time"])
	var cost: Dictionary = cfg["cost"]
	var fully_paid := _production_is_paid(building_id, cost)
	if live_units_for_player(player) >= unit_limit:
		return
	if not fully_paid:
		var advanced := true
		advanced = _advance_production_payment(building_id, player, "food", int(cost.get("food", 0)), production_time) and advanced
		advanced = _advance_production_payment(building_id, player, "wood", int(cost.get("wood", 0)), production_time) and advanced
		advanced = _advance_production_payment(building_id, player, "stone", int(cost.get("stone", 0)), production_time) and advanced
		if not advanced:
			return
		fully_paid = _production_is_paid(building_id, cost)
	buildings.production_ticks[building_id] += 1
	if buildings.production_ticks[building_id] < production_time or not fully_paid:
		return
	var exit_tile: Vector2i = _dropoff_slot(building_id, Vector2i(buildings.anchor_x[building_id], buildings.anchor_y[building_id]))
	if exit_tile.x < 0:
		return
	units.spawn(player, type_name, exit_tile.x, exit_tile.y, int(cfg["hp"]))
	buildings.clear_production(building_id)

func _advance_production_payment(building_id: int, player: int, resource_type: String, cost: int, production_time: int) -> bool:
	if _get_production_paid(building_id, resource_type) >= cost:
		return true
	if _get_player_resource(player, resource_type) <= 0:
		return false
	_set_production_acc(building_id, resource_type, _get_production_acc(building_id, resource_type) + cost)
	if _get_production_acc(building_id, resource_type) >= production_time:
		_set_production_acc(building_id, resource_type, _get_production_acc(building_id, resource_type) - production_time)
		_set_player_resource(player, resource_type, _get_player_resource(player, resource_type) - 1)
		_set_production_paid(building_id, resource_type, _get_production_paid(building_id, resource_type) + 1)
	return true

func _production_is_paid(building_id: int, cost: Dictionary) -> bool:
	return (
		buildings.production_paid_food[building_id] >= int(cost.get("food", 0))
		and buildings.production_paid_wood[building_id] >= int(cost.get("wood", 0))
		and buildings.production_paid_stone[building_id] >= int(cost.get("stone", 0))
	)

func _get_player_resource(player: int, resource_type: String) -> int:
	if resource_type == "food":
		return player_food[player]
	if resource_type == "wood":
		return player_wood[player]
	if resource_type == "stone":
		return player_stone[player]
	return 0

func _set_player_resource(player: int, resource_type: String, value: int) -> void:
	if resource_type == "food":
		player_food[player] = value
	elif resource_type == "wood":
		player_wood[player] = value
	elif resource_type == "stone":
		player_stone[player] = value

func _get_production_paid(building_id: int, resource_type: String) -> int:
	if resource_type == "food":
		return buildings.production_paid_food[building_id]
	if resource_type == "wood":
		return buildings.production_paid_wood[building_id]
	if resource_type == "stone":
		return buildings.production_paid_stone[building_id]
	return 0

func _set_production_paid(building_id: int, resource_type: String, value: int) -> void:
	if resource_type == "food":
		buildings.production_paid_food[building_id] = value
	elif resource_type == "wood":
		buildings.production_paid_wood[building_id] = value
	elif resource_type == "stone":
		buildings.production_paid_stone[building_id] = value

func _get_production_acc(building_id: int, resource_type: String) -> int:
	if resource_type == "food":
		return buildings.production_acc_food[building_id]
	if resource_type == "wood":
		return buildings.production_acc_wood[building_id]
	if resource_type == "stone":
		return buildings.production_acc_stone[building_id]
	return 0

func _set_production_acc(building_id: int, resource_type: String, value: int) -> void:
	if resource_type == "food":
		buildings.production_acc_food[building_id] = value
	elif resource_type == "wood":
		buildings.production_acc_wood[building_id] = value
	elif resource_type == "stone":
		buildings.production_acc_stone[building_id] = value

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open JSON: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON: %s" % path)
		return {}
	return parsed
