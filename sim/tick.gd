extends RefCounted

const Commands := preload("res://sim/commands.gd")
const GameMap := preload("res://sim/map.gd")
const Rng := preload("res://sim/rng.gd")
const Snapshot := preload("res://sim/snapshot.gd")
const Units := preload("res://sim/units.gd")
const Buildings := preload("res://sim/buildings.gd")
const LootItems := preload("res://sim/loot_items.gd")
const Platoons := preload("res://sim/platoons.gd")
const Fog := preload("res://sim/fog.gd")
const Pathfinding := preload("res://sim/pathfinding.gd")
const AiController := preload("res://sim/ai_controller.gd")

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
var loot_items: RefCounted
var platoons: RefCounted
var fog: RefCounted
var pathfinding: RefCounted
var ai_controller: RefCounted
var ai_enabled := false
var path_requests: Array = []
var pathfinds_last_tick := 0
var balance: Dictionary = {}
var player_wood := PackedInt32Array([1000, 1000])
var player_stone := PackedInt32Array([1000, 1000])
var player_food := PackedInt32Array([1000, 1000])
var food_acc := PackedInt32Array([0, 0])
var farm_acc := PackedInt32Array([0, 0])
var food_delta_history := [[], []]
var last_attack_tick := PackedInt32Array([-1000000, -1000000])
var last_attack_x := PackedInt32Array([-1, -1])
var last_attack_y := PackedInt32Array([-1, -1])
var unit_limit := 200
var winner_player := -1

func load_match(map_path: String, balance_path: String, seed_value: int) -> void:
	balance = _load_json(balance_path)
	player_wood = PackedInt32Array([int(balance["start_resources"]["wood"]), int(balance["start_resources"]["wood"])])
	player_stone = PackedInt32Array([int(balance["start_resources"]["stone"]), int(balance["start_resources"]["stone"])])
	player_food = PackedInt32Array([int(balance["start_resources"]["food"]), int(balance["start_resources"]["food"])])
	food_acc = PackedInt32Array([0, 0])
	farm_acc = PackedInt32Array([0, 0])
	food_delta_history = [[], []]
	last_attack_tick = PackedInt32Array([-1000000, -1000000])
	last_attack_x = PackedInt32Array([-1, -1])
	last_attack_y = PackedInt32Array([-1, -1])
	unit_limit = int(balance["unit_limit"])

	map_state = GameMap.new()
	map_state.load_from_json(map_path)
	commands = Commands.new()
	rng = Rng.new()
	rng.seed_rng(seed_value)
	snapshot_writer = Snapshot.new()
	units = Units.new()
	buildings = Buildings.new()
	loot_items = LootItems.new()
	platoons = Platoons.new()
	fog = Fog.new()
	fog.setup(map_state, 2)
	pathfinding = Pathfinding.new()
	ai_controller = AiController.new()
	ai_controller.setup(_load_json("res://config/ai_normal.json"))
	ai_enabled = false
	path_requests = []
	pathfinds_last_tick = 0
	winner_player = -1
	_spawn_start_buildings()
	_spawn_start_units()
	_phase_fog()
	tick = 0

func advance_render_time(delta: float) -> void:
	render_accumulator += delta
	while render_accumulator >= 0.1:
		step()
		render_accumulator -= 0.1

func step() -> void:
	var food_before := PackedInt32Array(player_food)
	_phase_ai()
	var tick_commands: Array = commands.pop_for_tick(tick)
	_apply_commands(tick_commands)
	_phase_pathfinding()
	_phase_movement()
	_phase_crowd_subslots()
	_phase_combat()
	_phase_platoon_regroup()
	_phase_gather_and_loot()
	_phase_building()
	_phase_production()
	_phase_farms()
	_phase_food_consumption()
	_record_food_delta(food_before)
	_phase_cleanup_dead()
	_phase_victory()
	_phase_fog()
	tick += 1

func _phase_ai() -> void:
	if ai_enabled and ai_controller != null and winner_player < 0:
		ai_controller.step(self, 1)

func _phase_fog() -> void:
	if fog != null:
		fog.step(self)

func snapshot_bytes() -> PackedByteArray:
	return snapshot_writer.write_snapshot(self)

func live_units_for_player(player_id: int) -> int:
	return units.live_count_for_player(player_id)

func live_buildings_for_player(player_id: int) -> int:
	return buildings.live_count_for_player(player_id)

func food_trend_10s(player_id: int) -> int:
	var trend := 0
	for value in food_delta_history[player_id]:
		trend += int(value)
	return trend

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
		elif type == "attack_move":
			_apply_attack_move_command(command)
		elif type == "attack_target":
			_apply_attack_target_command(command)
		elif type == "produce":
			_apply_produce_command(command)
		elif type == "set_stance":
			_apply_set_stance_command(command)
		elif type == "build_place":
			_apply_build_place_command(command)
		elif type == "build_assign":
			_apply_build_assign_command(command)
		elif type == "demolish":
			_apply_demolish_command(command)
		elif type == "cancel_production":
			_apply_cancel_production_command(command)
		elif type == "form_up":
			_apply_form_up_command(command)

func enqueue_player_command(type: String, unit_ids: Array, target_tile: Array = [], params: Dictionary = {}) -> void:
	var command: Dictionary = commands.make_command(tick + 1, 0, type, unit_ids, target_tile, null, params)
	commands.enqueue(command)

func enqueue_player_entity_command(type: String, unit_ids: Array, target_entity_id: int, params: Dictionary = {}) -> void:
	var command: Dictionary = commands.make_command(tick + 1, 0, type, unit_ids, [], target_entity_id, params)
	commands.enqueue(command)

func enable_ai(config_path: String = "res://config/ai_normal.json") -> void:
	if ai_controller == null:
		ai_controller = AiController.new()
	ai_controller.setup(_load_json(config_path))
	ai_enabled = true

func _phase_movement() -> void:
	for id in range(units.alive.size()):
		if units.alive[id] and (units.order_type[id] == "move" or units.order_type[id] == "attack_move" or units.order_type[id] == "attack_target" or units.order_type[id] == "gather_to_resource" or units.order_type[id] == "return_resource" or units.order_type[id] == "build_to_site"):
			_step_unit_move(id)

func _phase_pathfinding() -> void:
	pathfinds_last_tick = 0
	var budget := int(balance["pathfinding"]["max_pathfinds_per_tick"])
	while budget > 0 and not path_requests.is_empty():
		var request: Dictionary = path_requests.pop_front()
		if _apply_path_request(request):
			budget -= 1
			pathfinds_last_tick += 1

func _apply_path_request(request: Dictionary) -> bool:
	var id := int(request["unit_id"])
	if id < 0 or id >= units.alive.size() or not units.alive[id]:
		return false
	if units.path_request_seq[id] != int(request["seq"]) or units.order_type[id] != "waiting_path":
		return false
	var start := Vector2i(units.tile_x(id), units.tile_y(id))
	var target := Vector2i(int(request["target_x"]), int(request["target_y"]))
	var path: Array = pathfinding.find_path(map_state, start, target, int(balance["pathfinding"]["max_path_tiles"]))
	if String(request["resolve_order"]) == "move":
		units.set_move_order(id, target.x, target.y, path)
	elif String(request["resolve_order"]) == "attack_move":
		units.set_attack_move_order(id, target.x, target.y, path)
	elif String(request["resolve_order"]) == "attack_target":
		units.set_attack_target_order(id, int(request["target_entity_id"]), String(request["target_kind"]), target.x, target.y, path)
	elif String(request["resolve_order"]) == "gather_to_resource":
		units.set_gather_order(
			id,
			int(request["resource_x"]),
			int(request["resource_y"]),
			target.x,
			target.y,
			String(request["resource_type"]),
			path
		)
	elif String(request["resolve_order"]) == "return_resource":
		var order_target := Vector2i(int(request["order_target_x"]), int(request["order_target_y"]))
		units.set_return_order(id, order_target.x, order_target.y, path)
	elif String(request["resolve_order"]) == "build_to_site":
		units.set_build_order(id, int(request["target_entity_id"]), target.x, target.y, path)
	return true

func _phase_crowd_subslots() -> void:
	var occupancy: Dictionary = {}
	for id in range(units.alive.size()):
		if not units.alive[id]:
			continue
		var tile: Vector2i = Vector2i(units.tile_x(id), units.tile_y(id))
		var assigned: Vector2i = _assign_subslot(id, tile, occupancy)
		if assigned.x == tile.x and assigned.y == tile.y:
			continue
		units.pos_x[id] = assigned.x * 256
		units.pos_y[id] = assigned.y * 256

func _assign_subslot(id: int, tile: Vector2i, occupancy: Dictionary) -> Vector2i:
	var key: int = map_state.index(tile.x, tile.y)
	var count: int = int(occupancy.get(key, 0))
	if count < 4:
		occupancy[key] = count + 1
		units.subslot[id] = count
		return tile
	for delta: Vector2i in Pathfinding.NEIGHBORS:
		var candidate: Vector2i = tile + delta
		if not map_state.in_bounds(candidate.x, candidate.y) or not map_state.is_walkable(candidate.x, candidate.y):
			continue
		var candidate_key: int = map_state.index(candidate.x, candidate.y)
		var candidate_count: int = int(occupancy.get(candidate_key, 0))
		if candidate_count < 4:
			occupancy[candidate_key] = candidate_count + 1
			units.subslot[id] = candidate_count
			return candidate
	occupancy[key] = count + 1
	units.subslot[id] = 3
	return tile

func _phase_combat() -> void:
	for id in range(units.alive.size()):
		if units.alive[id] and units.attack_cooldown[id] > 0:
			units.attack_cooldown[id] -= 1
	for id in range(buildings.alive.size()):
		if buildings.alive[id] and buildings.attack_cooldown[id] > 0:
			buildings.attack_cooldown[id] -= 1
	for id in range(units.alive.size()):
		if not units.alive[id] or units.hp[id] <= 0:
			continue
		if not balance["units"].has(units.unit_type[id]):
			continue
		var target: Dictionary = _combat_target_for_unit(id)
		if target.is_empty():
			continue
		_face_unit_towards_target(id, target)
		if _chebyshev_target_distance(id, target) > 1:
			_chase_attack_target(id, target)
			continue
		if units.attack_cooldown[id] > 0:
			continue
		var attack_cfg: Dictionary = balance["units"][units.unit_type[id]]
		var target_cfg: Dictionary = _target_balance(target)
		var damage: int = max(1, int(attack_cfg.get("attack", 0)) - int(target_cfg.get("armor", 0)))
		_break_platoon_for_unit(id)
		_damage_target(target, damage, "unit", id)
		units.attack_cooldown[id] = int(attack_cfg.get("attack_period_ticks", 10))
	for id in range(buildings.alive.size()):
		if not buildings.alive[id] or buildings.hp[id] <= 0 or buildings.progress[id] <= 0:
			continue
		var cfg: Dictionary = balance["buildings"][buildings.building_type[id]]
		if not cfg.has("attack_range") or buildings.attack_cooldown[id] > 0:
			continue
		var target_id := _nearest_enemy_unit_for_building(id, int(cfg["attack_range"]))
		if target_id < 0:
			continue
		var target_cfg: Dictionary = balance["units"][units.unit_type[target_id]]
		var damage: int = max(1, int(cfg.get("attack_damage", 0)) - int(target_cfg.get("armor", 0)))
		_damage_target({"kind": "unit", "id": target_id}, damage, "building", id)
		buildings.attack_cooldown[id] = int(cfg.get("attack_period_ticks", 10))

func _combat_target_for_unit(id: int) -> Dictionary:
	var current_target: int = units.attack_target_id[id]
	var current_kind: String = units.attack_target_kind[id]
	if units.order_type[id] == "attack_target" and _valid_enemy_target(id, current_kind, current_target):
		if units.stance[id] == "hold" and _chebyshev_target_distance(id, {"kind": current_kind, "id": current_target}) > 1:
			units.stop(id)
			return {}
		return {"kind": current_kind, "id": current_target}
	if units.order_type[id] == "attack_move":
		var unit_target := _nearest_enemy_unit(id, 5)
		if unit_target >= 0:
			return {"kind": "unit", "id": unit_target}
		var building_target := _nearest_enemy_building(id, 5)
		if building_target >= 0:
			return {"kind": "building", "id": building_target}
	if units.order_type[id] == "idle":
		var idle_target := _nearest_enemy_unit(id, 1)
		if idle_target >= 0:
			return {"kind": "unit", "id": idle_target}
	return {}

func _valid_enemy_target(id: int, target_kind: String, target_id: int) -> bool:
	if target_kind == "unit":
		return _valid_enemy_unit(id, target_id)
	if target_kind == "building":
		return _valid_enemy_building(id, target_id)
	return false

func _valid_enemy_unit(id: int, target_id: int) -> bool:
	return target_id >= 0 and target_id < units.alive.size() and units.alive[target_id] and units.hp[target_id] > 0 and units.owner[target_id] != units.owner[id]

func _valid_enemy_building(id: int, target_id: int) -> bool:
	return target_id >= 0 and target_id < buildings.alive.size() and buildings.alive[target_id] and buildings.hp[target_id] > 0 and buildings.progress[target_id] > 0 and buildings.owner[target_id] != units.owner[id]

func _nearest_enemy_unit(id: int, radius: int) -> int:
	var best_id := -1
	var best_dist := 999999999
	var best_hp := 999999999
	for target_id in range(units.alive.size()):
		if not _valid_enemy_unit(id, target_id):
			continue
		var chebyshev := _chebyshev_unit_distance(id, target_id)
		if chebyshev > radius:
			continue
		var dist := _unit_distance_sq(id, target_id)
		var hp: int = units.hp[target_id]
		if dist < best_dist or (dist == best_dist and hp < best_hp) or (dist == best_dist and hp == best_hp and (best_id < 0 or target_id < best_id)):
			best_id = target_id
			best_dist = dist
			best_hp = hp
	return best_id

func _nearest_enemy_building(id: int, radius: int) -> int:
	var best_id := -1
	var best_dist := 999999999
	var best_hp := 999999999
	for target_id in range(buildings.alive.size()):
		if not _valid_enemy_building(id, target_id):
			continue
		var target := {"kind": "building", "id": target_id}
		var chebyshev := _chebyshev_target_distance(id, target)
		if chebyshev > radius:
			continue
		var dist := _target_distance_sq(id, target)
		var hp: int = buildings.hp[target_id]
		if dist < best_dist or (dist == best_dist and hp < best_hp) or (dist == best_dist and hp == best_hp and (best_id < 0 or target_id < best_id)):
			best_id = target_id
			best_dist = dist
			best_hp = hp
	return best_id

func _nearest_enemy_unit_for_building(building_id: int, radius: int) -> int:
	var best_id := -1
	var best_dist := 999999999
	var best_hp := 999999999
	for target_id in range(units.alive.size()):
		if not units.alive[target_id] or units.hp[target_id] <= 0 or units.owner[target_id] == buildings.owner[building_id]:
			continue
		var chebyshev := _chebyshev_building_to_unit_distance(building_id, target_id)
		if chebyshev > radius:
			continue
		var center := _building_center_tile(building_id)
		var dx: int = units.tile_x(target_id) - center.x
		var dy: int = units.tile_y(target_id) - center.y
		var dist := dx * dx + dy * dy
		var hp: int = units.hp[target_id]
		if dist < best_dist or (dist == best_dist and hp < best_hp) or (dist == best_dist and hp == best_hp and (best_id < 0 or target_id < best_id)):
			best_id = target_id
			best_dist = dist
			best_hp = hp
	return best_id

func _chase_attack_target(id: int, target: Dictionary) -> void:
	if units.order_type[id] == "waiting_path":
		return
	if units.stance[id] == "hold":
		return
	var from_tile := Vector2i(units.tile_x(id), units.tile_y(id))
	var target_id := int(target["id"])
	var target_kind := String(target["kind"])
	var slot := Vector2i(-1, -1)
	if target_kind == "unit":
		slot = _attack_slot(Vector2i(units.tile_x(target_id), units.tile_y(target_id)), from_tile)
	elif target_kind == "building":
		slot = _building_attack_slot(target_id, from_tile)
	if slot.x < 0:
		return
	_queue_path_request(id, "attack_target", slot, Vector2i(-1, -1), "", slot, target_id, target_kind)

func _attack_slot(target_tile: Vector2i, from_tile: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := 999999999
	for delta: Vector2i in Pathfinding.NEIGHBORS:
		var candidate := target_tile + delta
		if not map_state.in_bounds(candidate.x, candidate.y) or not map_state.is_walkable(candidate.x, candidate.y):
			continue
		var dist := (candidate.x - from_tile.x) * (candidate.x - from_tile.x) + (candidate.y - from_tile.y) * (candidate.y - from_tile.y)
		if dist < best_dist:
			best = candidate
			best_dist = dist
	return best

func _building_attack_slot(building_id: int, from_tile: Vector2i) -> Vector2i:
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

func _building_rect(building_id: int) -> Rect2i:
	var cfg: Dictionary = balance["buildings"][buildings.building_type[building_id]]
	var footprint: Array = cfg["footprint"]
	return Rect2i(buildings.anchor_x[building_id], buildings.anchor_y[building_id], int(footprint[0]), int(footprint[1]))

func _building_center_tile(building_id: int) -> Vector2i:
	var rect := _building_rect(building_id)
	return Vector2i(rect.position.x + int(rect.size.x / 2), rect.position.y + int(rect.size.y / 2))

func _chebyshev_unit_distance(a: int, b: int) -> int:
	return max(abs(units.tile_x(a) - units.tile_x(b)), abs(units.tile_y(a) - units.tile_y(b)))

func _chebyshev_target_distance(id: int, target: Dictionary) -> int:
	if String(target["kind"]) == "unit":
		return _chebyshev_unit_distance(id, int(target["id"]))
	var rect := _building_rect(int(target["id"]))
	var tx: int = units.tile_x(id)
	var ty: int = units.tile_y(id)
	var dx := 0
	if tx < rect.position.x:
		dx = int(rect.position.x) - tx
	elif tx >= rect.end.x:
		dx = tx - int(rect.end.x) + 1
	var dy := 0
	if ty < rect.position.y:
		dy = int(rect.position.y) - ty
	elif ty >= rect.end.y:
		dy = ty - int(rect.end.y) + 1
	return max(dx, dy)

func _chebyshev_building_to_unit_distance(building_id: int, unit_id: int) -> int:
	var rect := _building_rect(building_id)
	var tx: int = units.tile_x(unit_id)
	var ty: int = units.tile_y(unit_id)
	var dx := 0
	if tx < rect.position.x:
		dx = int(rect.position.x) - tx
	elif tx >= rect.end.x:
		dx = tx - int(rect.end.x) + 1
	var dy := 0
	if ty < rect.position.y:
		dy = int(rect.position.y) - ty
	elif ty >= rect.end.y:
		dy = ty - int(rect.end.y) + 1
	return max(dx, dy)

func _unit_distance_sq(a: int, b: int) -> int:
	var dx: int = units.tile_x(a) - units.tile_x(b)
	var dy: int = units.tile_y(a) - units.tile_y(b)
	return dx * dx + dy * dy

func _target_distance_sq(id: int, target: Dictionary) -> int:
	if String(target["kind"]) == "unit":
		return _unit_distance_sq(id, int(target["id"]))
	var center := _building_center_tile(int(target["id"]))
	var dx: int = units.tile_x(id) - center.x
	var dy: int = units.tile_y(id) - center.y
	return dx * dx + dy * dy

func _face_unit_towards_target(id: int, target: Dictionary) -> void:
	var target_tile := Vector2i.ZERO
	if String(target["kind"]) == "unit":
		var target_id := int(target["id"])
		target_tile = Vector2i(units.tile_x(target_id), units.tile_y(target_id))
	else:
		target_tile = _building_center_tile(int(target["id"]))
	var dx: int = clampi(target_tile.x - units.tile_x(id), -1, 1)
	var dy: int = clampi(target_tile.y - units.tile_y(id), -1, 1)
	var dirs := {
		Vector2i(0, -1): 0,
		Vector2i(1, -1): 1,
		Vector2i(1, 0): 2,
		Vector2i(1, 1): 3,
		Vector2i(0, 1): 4,
		Vector2i(-1, 1): 5,
		Vector2i(-1, 0): 6,
		Vector2i(-1, -1): 7,
	}
	units.facing[id] = int(dirs.get(Vector2i(dx, dy), units.facing[id]))

func _target_balance(target: Dictionary) -> Dictionary:
	if String(target["kind"]) == "unit":
		return balance["units"][units.unit_type[int(target["id"])]]
	return balance["buildings"][buildings.building_type[int(target["id"])]]

func _damage_target(target: Dictionary, damage: int, attacker_kind: String = "", attacker_id: int = -1) -> void:
	if String(target["kind"]) == "unit":
		var target_id := int(target["id"])
		units.hp[target_id] -= damage
		_break_platoon_for_unit(target_id)
		_record_attack_event(units.owner[target_id], Vector2i(units.tile_x(target_id), units.tile_y(target_id)))
		_apply_threat_reaction(target_id, attacker_kind, attacker_id)
	else:
		var building_id := int(target["id"])
		buildings.hp[building_id] -= damage
		_record_attack_event(buildings.owner[building_id], _building_center_tile(building_id))

func _record_attack_event(player_id: int, tile: Vector2i) -> void:
	if player_id < 0 or player_id >= last_attack_tick.size():
		return
	last_attack_tick[player_id] = tick
	last_attack_x[player_id] = tile.x
	last_attack_y[player_id] = tile.y

func _break_platoon_for_unit(unit_id: int) -> void:
	if unit_id < 0 or unit_id >= units.alive.size():
		return
	var platoon_id: int = units.platoon_id[unit_id]
	if platoon_id < 0 or platoon_id >= platoons.alive.size() or not platoons.alive[platoon_id]:
		return
	platoons.broken[platoon_id] = true
	platoons.regroup_ticks[platoon_id] = 0

func _phase_platoon_regroup() -> void:
	for platoon_id in range(platoons.alive.size()):
		if not platoons.alive[platoon_id] or not platoons.broken[platoon_id]:
			continue
		if _live_platoon_members(platoon_id).is_empty():
			platoons.alive[platoon_id] = false
			continue
		if _platoon_ready_to_regroup(platoon_id):
			platoons.regroup_ticks[platoon_id] += 1
		else:
			platoons.regroup_ticks[platoon_id] = 0
		if platoons.regroup_ticks[platoon_id] >= 30:
			_regroup_platoon(platoon_id)

func _live_platoon_members(platoon_id: int) -> Array:
	var live_members: Array = []
	for member in platoons.members[platoon_id]:
		var id := int(member)
		if id >= 0 and id < units.alive.size() and units.alive[id] and units.platoon_id[id] == platoon_id:
			live_members.append(id)
	return live_members

func _platoon_ready_to_regroup(platoon_id: int) -> bool:
	for id_value in _live_platoon_members(platoon_id):
		var id := int(id_value)
		if units.order_type[id] != "idle":
			return false
		if units.attack_cooldown[id] > 0:
			return false
	return true

func _regroup_platoon(platoon_id: int) -> void:
	var anchor := _platoon_center_anchor(platoon_id)
	_apply_platoon_move_group(platoon_id, _platoon_member_lookup(platoon_id), anchor)
	platoons.broken[platoon_id] = false
	platoons.regroup_ticks[platoon_id] = 0

func _platoon_center_anchor(platoon_id: int) -> Vector2i:
	var live_members := _live_platoon_members(platoon_id)
	if live_members.is_empty():
		return Vector2i.ZERO
	var sum_x := 0
	var sum_y := 0
	for id_value in live_members:
		var id := int(id_value)
		sum_x += units.tile_x(id)
		sum_y += units.tile_y(id)
	return Vector2i(int(sum_x / live_members.size()), int(sum_y / live_members.size()))

func _platoon_member_lookup(platoon_id: int) -> Dictionary:
	var selected: Dictionary = {}
	for id_value in _live_platoon_members(platoon_id):
		selected[int(id_value)] = true
	return selected

func _apply_threat_reaction(id: int, attacker_kind: String, attacker_id: int) -> void:
	if attacker_id < 0 or not units.alive[id] or units.hp[id] <= 0:
		return
	if units.stance[id] != "defense":
		return
	if units.order_type[id] == "attack_move" or units.order_type[id] == "attack_target":
		return
	if not _valid_enemy_target(id, attacker_kind, attacker_id):
		return
	units.order_type[id] = "attack_target"
	units.attack_target_id[id] = attacker_id
	units.attack_target_kind[id] = attacker_kind
	units.path[id] = []
	units.path_index[id] = 0

func _phase_gather_and_loot() -> void:
	for id in range(units.alive.size()):
		if not units.alive[id] or units.unit_type[id] != "peasant":
			continue
		_try_pickup_loot(id)
		if units.order_type[id] == "gathering":
			_step_gather(id)
		elif units.order_type[id] == "return_resource":
			_try_deposit(id)
	loot_items.step_ttl()

func _try_pickup_loot(id: int) -> void:
	var capacity := int(balance["units"]["peasant"]["carry_capacity"])
	if units.carry_amount[id] >= capacity:
		return
	for loot_id in range(loot_items.alive.size()):
		if not loot_items.alive[loot_id] or loot_items.amount[loot_id] <= 0:
			continue
		if loot_items.pos_x[loot_id] != units.tile_x(id) or loot_items.pos_y[loot_id] != units.tile_y(id):
			continue
		if units.carry_type[id] != "" and units.carry_type[id] != loot_items.resource_type[loot_id]:
			continue
		units.carry_type[id] = loot_items.resource_type[loot_id]
		var taken: int = min(capacity - units.carry_amount[id], loot_items.amount[loot_id])
		units.carry_amount[id] += taken
		loot_items.amount[loot_id] -= taken
		if loot_items.amount[loot_id] <= 0:
			loot_items.alive[loot_id] = false
		return

func _phase_building() -> void:
	_phase_building_frames()
	for id in range(units.alive.size()):
		if not units.alive[id] or units.unit_type[id] != "peasant" or units.order_type[id] != "building":
			continue
		_step_builder(id)

func _phase_building_frames() -> void:
	for id in range(buildings.alive.size()):
		if not buildings.alive[id] or buildings.progress[id] > 0 or buildings.frame_ttl[id] <= 0:
			continue
		if _has_builder_assigned(id):
			continue
		buildings.frame_ttl[id] -= 1
		if buildings.frame_ttl[id] <= 0:
			buildings.alive[id] = false

func _has_builder_assigned(building_id: int) -> bool:
	for id in range(units.alive.size()):
		if units.alive[id] and units.build_target_id[id] == building_id and (units.order_type[id] == "waiting_path" or units.order_type[id] == "build_to_site" or units.order_type[id] == "building"):
			return true
	return false

func _step_builder(id: int) -> void:
	var building_id: int = units.build_target_id[id]
	if building_id < 0 or building_id >= buildings.alive.size() or not buildings.alive[building_id] or buildings.completed[building_id]:
		units.stop(id)
		return
	if _unit_inside_building_footprint(id, building_id):
		return
	var invested := false
	for resource_type in balance["build_resource_order"]:
		if _building_needs_resource(building_id, String(resource_type)):
			invested = _invest_build_resource(building_id, units.owner[id], String(resource_type))
			break
	if not invested:
		return
	_update_building_progress(building_id)
	buildings.frame_ttl[building_id] = 0
	if _building_is_fully_invested(building_id):
		buildings.completed[building_id] = true
		buildings.progress[building_id] = max(1, buildings.required_wood[building_id] + buildings.required_stone[building_id])
		buildings.hp[building_id] = int(balance["buildings"][buildings.building_type[building_id]]["hp"])
		units.stop(id)

func _building_needs_resource(building_id: int, resource_type: String) -> bool:
	if resource_type == "wood":
		return buildings.invested_wood[building_id] < buildings.required_wood[building_id]
	if resource_type == "stone":
		return buildings.invested_stone[building_id] < buildings.required_stone[building_id]
	return false

func _invest_build_resource(building_id: int, player: int, resource_type: String) -> bool:
	if _get_player_resource(player, resource_type) <= 0:
		return false
	_set_player_resource(player, resource_type, _get_player_resource(player, resource_type) - 1)
	if resource_type == "wood":
		buildings.invested_wood[building_id] += 1
	elif resource_type == "stone":
		buildings.invested_stone[building_id] += 1
	return true

func _update_building_progress(building_id: int) -> void:
	var invested: int = buildings.invested_wood[building_id] + buildings.invested_stone[building_id]
	var required: int = max(1, buildings.required_wood[building_id] + buildings.required_stone[building_id])
	buildings.progress[building_id] = invested
	var full_hp := int(balance["buildings"][buildings.building_type[building_id]]["hp"])
	buildings.hp[building_id] = int(full_hp * (20 * required + 80 * invested) / (100 * required))

func _building_is_fully_invested(building_id: int) -> bool:
	return buildings.invested_wood[building_id] >= buildings.required_wood[building_id] and buildings.invested_stone[building_id] >= buildings.required_stone[building_id]

func _unit_inside_building_footprint(unit_id: int, building_id: int) -> bool:
	var rect := _building_rect(building_id)
	var tile := Vector2i(units.tile_x(unit_id), units.tile_y(unit_id))
	return tile.x >= rect.position.x and tile.x < rect.end.x and tile.y >= rect.position.y and tile.y < rect.end.y

func _phase_production() -> void:
	for id in range(buildings.alive.size()):
		if not buildings.alive[id] or not buildings.completed[id] or buildings.production_type[id] == "":
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

func _phase_farms() -> void:
	for building_id in range(buildings.alive.size()):
		if not buildings.alive[building_id] or not buildings.completed[building_id]:
			continue
		if buildings.building_type[building_id] != "farm":
			continue
		var player: int = buildings.owner[building_id]
		var cfg: Dictionary = balance["buildings"]["farm"]
		farm_acc[player] += 1
		var period := int(cfg.get("food_per_ticks", 10))
		if farm_acc[player] >= period:
			var produced := int(farm_acc[player] / period)
			player_food[player] += produced
			farm_acc[player] %= period

func _record_food_delta(food_before: PackedInt32Array) -> void:
	for player_id in range(2):
		var history: Array = food_delta_history[player_id]
		history.append(player_food[player_id] - food_before[player_id])
		while history.size() > 100:
			history.pop_front()

func _phase_cleanup_dead() -> void:
	_drop_loot_from_dead_units()
	units.cleanup_dead()
	buildings.cleanup_dead()

func _drop_loot_from_dead_units() -> void:
	for id in range(units.alive.size()):
		if not units.alive[id] or units.hp[id] > 0 or units.carry_amount[id] <= 0:
			continue
		var tile := _loot_drop_tile(Vector2i(units.tile_x(id), units.tile_y(id)))
		if tile.x >= 0:
			loot_items.spawn(tile.x, tile.y, units.carry_type[id], units.carry_amount[id], 600)
		units.carry_amount[id] = 0
		units.carry_type[id] = ""

func _loot_drop_tile(origin: Vector2i) -> Vector2i:
	if _can_drop_loot_at(origin):
		return origin
	for radius in range(1, 4):
		for delta in Pathfinding.NEIGHBORS:
			var candidate: Vector2i = origin + delta * radius
			if _can_drop_loot_at(candidate):
				return candidate
	return Vector2i(-1, -1)

func _can_drop_loot_at(tile: Vector2i) -> bool:
	return map_state.in_bounds(tile.x, tile.y) and map_state.is_walkable(tile.x, tile.y) and _building_at_tile(tile) < 0

func _phase_victory() -> void:
	if winner_player >= 0:
		return
	var player0_alive := live_buildings_for_player(0) > 0
	var player1_alive := live_buildings_for_player(1) > 0
	if player0_alive and player1_alive:
		return
	if player0_alive:
		winner_player = 0
	elif player1_alive:
		winner_player = 1
	else:
		winner_player = -2

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
	var selected: Dictionary = {}
	for unit_id in ids:
		selected[int(unit_id)] = true
	var handled_platoons: Array = []
	var loose_reserved: Dictionary = {}
	var loose_index := 0
	for unit_id in ids:
		var id := int(unit_id)
		if id < 0 or id >= units.alive.size() or not units.alive[id]:
			continue
		if units.owner[id] != int(command["player_id"]):
			continue
		var platoon_id: int = units.platoon_id[id]
		if platoon_id >= 0 and platoon_id < platoons.alive.size() and platoons.alive[platoon_id] and platoons.owner[platoon_id] == int(command["player_id"]):
			if handled_platoons.has(platoon_id):
				continue
			handled_platoons.append(platoon_id)
			_apply_platoon_move_group(platoon_id, selected, target_tile)
			continue
		var preferred_tile := _group_fan_tile(target_tile, loose_index)
		var assigned_tile := _nearest_clear_formation_tile(preferred_tile, target_tile, loose_reserved)
		if assigned_tile.x < 0:
			assigned_tile = target_tile
		if map_state.in_bounds(assigned_tile.x, assigned_tile.y):
			loose_reserved[map_state.index(assigned_tile.x, assigned_tile.y)] = true
		_queue_path_request(id, "move", assigned_tile)
		loose_index += 1

func _apply_platoon_move_group(platoon_id: int, selected: Dictionary, target_tile: Vector2i) -> void:
	var reserved: Dictionary = {}
	var members: Array = platoons.members[platoon_id]
	for member in members:
		var id := int(member)
		if not selected.has(id):
			continue
		if id < 0 or id >= units.alive.size() or not units.alive[id]:
			continue
		var slot: int = units.platoon_slot[id]
		if slot < 0:
			slot = members.find(id)
		var formation_tile := _platoon_formation_tile(target_tile, slot)
		var assigned_tile := _nearest_clear_formation_tile(formation_tile, target_tile, reserved)
		if assigned_tile.x < 0:
			assigned_tile = target_tile
		if map_state.in_bounds(assigned_tile.x, assigned_tile.y):
			reserved[map_state.index(assigned_tile.x, assigned_tile.y)] = true
		_queue_path_request(id, "move", assigned_tile)

func _platoon_formation_tile(anchor: Vector2i, slot: int) -> Vector2i:
	var column: int = posmod(slot, 3)
	var row: int = int(slot / 3)
	return anchor + Vector2i(column - 1, row)

func _group_fan_tile(anchor: Vector2i, index: int) -> Vector2i:
	if index <= 0:
		return anchor
	var ring: int = int((index - 1) / 8) + 1
	var direction: int = posmod(index - 1, 8)
	var offsets := [
		Vector2i(0, -ring),
		Vector2i(ring, 0),
		Vector2i(0, ring),
		Vector2i(-ring, 0),
		Vector2i(ring, -ring),
		Vector2i(ring, ring),
		Vector2i(-ring, ring),
		Vector2i(-ring, -ring),
	]
	return anchor + offsets[direction]

func _nearest_clear_formation_tile(preferred: Vector2i, anchor: Vector2i, reserved: Dictionary) -> Vector2i:
	if _is_clear_walkable_tile(preferred) and not reserved.has(map_state.index(preferred.x, preferred.y)):
		return preferred
	for radius in range(1, 6):
		for y in range(preferred.y - radius, preferred.y + radius + 1):
			for x in range(preferred.x - radius, preferred.x + radius + 1):
				if abs(x - preferred.x) != radius and abs(y - preferred.y) != radius:
					continue
				if not map_state.in_bounds(x, y) or not map_state.is_walkable(x, y):
					continue
				if _building_at_tile(Vector2i(x, y)) >= 0:
					continue
				var key: int = map_state.index(x, y)
				if reserved.has(key):
					continue
				return Vector2i(x, y)
	if _is_clear_walkable_tile(anchor) and not reserved.has(map_state.index(anchor.x, anchor.y)):
		return anchor
	return Vector2i(-1, -1)

func _is_clear_walkable_tile(tile: Vector2i) -> bool:
	return map_state.in_bounds(tile.x, tile.y) and map_state.is_walkable(tile.x, tile.y) and _building_at_tile(tile) < 0

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
	var reserved_slots: Dictionary = {}
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
		var slot := _resource_work_slot(assigned_resource, start, reserved_slots)
		if slot.x < 0:
			units.stop(id)
			continue
		reserved_slots[map_state.index(slot.x, slot.y)] = true
		_queue_path_request(id, "gather_to_resource", slot, assigned_resource, resource_type)

func _apply_attack_move_command(command: Dictionary) -> void:
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
		_queue_path_request(id, "attack_move", target_tile)

func _apply_attack_target_command(command: Dictionary) -> void:
	var target_id := int(command["target_entity_id"]) if command["target_entity_id"] != null else -1
	var target_kind := String(command["params"].get("target_kind", "unit"))
	if target_kind == "unit" and (target_id < 0 or target_id >= units.alive.size() or not units.alive[target_id]):
		return
	if target_kind == "building" and (target_id < 0 or target_id >= buildings.alive.size() or not buildings.alive[target_id]):
		return
	var ids: Array = command["unit_ids"].duplicate()
	ids.sort()
	for unit_id in ids:
		var id := int(unit_id)
		if id < 0 or id >= units.alive.size() or not units.alive[id]:
			continue
		if units.owner[id] != int(command["player_id"]):
			continue
		if target_kind == "unit" and units.owner[target_id] == units.owner[id]:
			continue
		if target_kind == "building" and buildings.owner[target_id] == units.owner[id]:
			continue
		var from_tile := Vector2i(units.tile_x(id), units.tile_y(id))
		var target_info := {"kind": target_kind, "id": target_id}
		var slot := Vector2i(-1, -1)
		if _chebyshev_target_distance(id, target_info) <= 1:
			slot = from_tile
		elif target_kind == "unit":
			slot = _attack_slot(Vector2i(units.tile_x(target_id), units.tile_y(target_id)), from_tile)
		elif target_kind == "building":
			slot = _building_attack_slot(target_id, from_tile)
		if slot.x < 0:
			continue
		_queue_path_request(id, "attack_target", slot, Vector2i(-1, -1), "", slot, target_id, target_kind)

func _apply_set_stance_command(command: Dictionary) -> void:
	var new_stance := String(command["params"].get("stance", "defense"))
	var ids: Array = command["unit_ids"].duplicate()
	ids.sort()
	for unit_id in ids:
		var id := int(unit_id)
		if id < 0 or id >= units.alive.size() or not units.alive[id]:
			continue
		if units.owner[id] != int(command["player_id"]):
			continue
		units.set_stance(id, new_stance)

func _apply_build_place_command(command: Dictionary) -> void:
	var target: Array = command["target_tile"]
	if target.size() < 2:
		return
	var type_name := String(command["params"].get("building_type", ""))
	if not balance["buildings"].has(type_name):
		return
	if buildings.zero_progress_frame_count(int(command["player_id"])) >= 20:
		return
	var anchor := Vector2i(int(target[0]), int(target[1]))
	if not _can_place_building(int(command["player_id"]), type_name, anchor):
		return
	var cost: Dictionary = balance["buildings"][type_name].get("cost", {})
	buildings.place_frame(int(command["player_id"]), type_name, anchor.x, anchor.y, int(cost.get("wood", 0)), int(cost.get("stone", 0)))

func _apply_build_assign_command(command: Dictionary) -> void:
	var building_id := int(command["target_entity_id"]) if command["target_entity_id"] != null else -1
	if building_id < 0 or building_id >= buildings.alive.size() or not buildings.alive[building_id]:
		return
	if buildings.owner[building_id] != int(command["player_id"]) or buildings.completed[building_id]:
		return
	var ids: Array = command["unit_ids"].duplicate()
	ids.sort()
	var reserved_slots: Dictionary = {}
	for unit_id in ids:
		var id := int(unit_id)
		if id < 0 or id >= units.alive.size() or not units.alive[id] or units.unit_type[id] != "peasant":
			continue
		if units.owner[id] != int(command["player_id"]):
			continue
		var start := Vector2i(units.tile_x(id), units.tile_y(id))
		var slot := _building_work_slot(building_id, start, reserved_slots)
		if slot.x < 0:
			units.stop(id)
			continue
		reserved_slots[map_state.index(slot.x, slot.y)] = true
		_queue_path_request(id, "build_to_site", slot, Vector2i(-1, -1), "", slot, building_id, "building")

func _apply_demolish_command(command: Dictionary) -> void:
	var building_id := int(command["target_entity_id"]) if command["target_entity_id"] != null else -1
	if building_id < 0 or building_id >= buildings.alive.size() or not buildings.alive[building_id]:
		return
	if buildings.owner[building_id] != int(command["player_id"]):
		return
	var refund := _demolish_refund(building_id)
	player_wood[int(command["player_id"])] += int(refund.get("wood", 0))
	player_stone[int(command["player_id"])] += int(refund.get("stone", 0))
	buildings.alive[building_id] = false

func _demolish_refund(building_id: int) -> Dictionary:
	if buildings.completed[building_id]:
		var cost: Dictionary = balance["buildings"][buildings.building_type[building_id]].get("cost", {})
		return {
			"wood": int(cost.get("wood", 0)) / 2,
			"stone": int(cost.get("stone", 0)) / 2,
		}
	return {
		"wood": int(buildings.invested_wood[building_id] / 2),
		"stone": int(buildings.invested_stone[building_id] / 2),
	}

func _can_place_building(player_id: int, type_name: String, anchor: Vector2i) -> bool:
	var cfg: Dictionary = balance["buildings"][type_name]
	var footprint: Array = cfg["footprint"]
	var has_builder_in_radius := false
	for id in range(units.alive.size()):
		if not units.alive[id] or units.owner[id] != player_id or units.unit_type[id] != "peasant":
			continue
		if max(abs(units.tile_x(id) - anchor.x), abs(units.tile_y(id) - anchor.y)) <= 8:
			has_builder_in_radius = true
			break
	if not has_builder_in_radius:
		return false
	for y in range(anchor.y, anchor.y + int(footprint[1])):
		for x in range(anchor.x, anchor.x + int(footprint[0])):
			if not map_state.in_bounds(x, y) or not map_state.is_walkable(x, y):
				return false
			if map_state.resource_type_at(x, y) != "":
				return false
			if _building_at_tile(Vector2i(x, y)) >= 0:
				return false
	return true

func _building_at_tile(tile: Vector2i) -> int:
	for id in range(buildings.alive.size()):
		if not buildings.alive[id]:
			continue
		var rect := _building_rect(id)
		if tile.x >= rect.position.x and tile.x < rect.end.x and tile.y >= rect.position.y and tile.y < rect.end.y:
			return id
	return -1

func _building_work_slot(building_id: int, from_tile: Vector2i, reserved_slots: Dictionary = {}) -> Vector2i:
	var cfg: Dictionary = balance["buildings"][buildings.building_type[building_id]]
	var footprint: Array = cfg["footprint"]
	var best := Vector2i(-1, -1)
	var best_cost := 999999999
	for y in range(buildings.anchor_y[building_id] - 1, buildings.anchor_y[building_id] + int(footprint[1]) + 1):
		for x in range(buildings.anchor_x[building_id] - 1, buildings.anchor_x[building_id] + int(footprint[0]) + 1):
			var on_perimeter: bool = x < buildings.anchor_x[building_id] or y < buildings.anchor_y[building_id] or x >= buildings.anchor_x[building_id] + int(footprint[0]) or y >= buildings.anchor_y[building_id] + int(footprint[1])
			if not on_perimeter or not map_state.in_bounds(x, y) or not map_state.is_walkable(x, y):
				continue
			if reserved_slots.has(map_state.index(x, y)):
				continue
			var candidate := Vector2i(x, y)
			var path: Array = pathfinding.find_path(map_state, from_tile, candidate, int(balance["pathfinding"]["max_path_tiles"]))
			if from_tile != candidate and path.is_empty():
				continue
			var cost := _path_cost(from_tile, path)
			if cost < best_cost:
				best = candidate
				best_cost = cost
	return best

func _queue_path_request(id: int, resolve_order: String, target_tile: Vector2i, resource_tile: Vector2i = Vector2i(-1, -1), resource_type: String = "", order_target_tile: Vector2i = Vector2i(-1, -1), target_entity_id: int = -1, target_kind: String = "unit") -> void:
	if id < 0 or id >= units.alive.size() or not units.alive[id]:
		return
	if order_target_tile.x < 0:
		order_target_tile = target_tile
	units.path_request_seq[id] += 1
	units.order_type[id] = "waiting_path"
	units.target_x[id] = target_tile.x
	units.target_y[id] = target_tile.y
	units.path[id] = []
	units.path_index[id] = 0
	path_requests.append({
		"unit_id": id,
		"seq": units.path_request_seq[id],
		"resolve_order": resolve_order,
		"target_x": target_tile.x,
		"target_y": target_tile.y,
		"resource_x": resource_tile.x,
		"resource_y": resource_tile.y,
		"resource_type": resource_type,
		"order_target_x": order_target_tile.x,
		"order_target_y": order_target_tile.y,
		"target_entity_id": target_entity_id,
		"target_kind": target_kind,
	})

func _step_unit_move(id: int) -> void:
	if units.path_index[id] >= units.path[id].size():
		_finish_path_order(id)
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
			_finish_path_order(id)

func _finish_path_order(id: int) -> void:
	if units.order_type[id] == "gather_to_resource":
		units.order_type[id] = "gathering"
	elif units.order_type[id] == "return_resource":
		_try_deposit(id)
	elif units.order_type[id] == "build_to_site":
		units.order_type[id] = "building"
		units.path[id] = []
		units.path_index[id] = 0
	elif units.order_type[id] == "attack_target":
		units.path[id] = []
		units.path_index[id] = 0
	elif units.order_type[id] == "attack_move":
		if units.tile_x(id) == units.target_x[id] and units.tile_y(id) == units.target_y[id]:
			units.stop(id)
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

func _resource_work_slot(resource_tile: Vector2i, from_tile: Vector2i, reserved_slots: Dictionary = {}) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_cost := 999999999
	for delta: Vector2i in Pathfinding.NEIGHBORS:
		var candidate := resource_tile + delta
		if not map_state.in_bounds(candidate.x, candidate.y) or not map_state.is_walkable(candidate.x, candidate.y):
			continue
		if reserved_slots.has(map_state.index(candidate.x, candidate.y)):
			continue
		var path: Array = pathfinding.find_path(map_state, from_tile, candidate, int(balance["pathfinding"]["max_path_tiles"]))
		if from_tile != candidate and path.is_empty():
			continue
		var cost := _path_cost(from_tile, path)
		if cost < best_cost:
				best = candidate
				best_cost = cost
	return best

func _path_cost(start: Vector2i, path: Array) -> int:
	var cost := 0
	var current := start
	for next_tile: Vector2i in path:
		var dx: int = abs(next_tile.x - current.x)
		var dy: int = abs(next_tile.y - current.y)
		cost += Pathfinding.DIAGONAL_COST if dx != 0 and dy != 0 else Pathfinding.STRAIGHT_COST
		current = next_tile
	return cost

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
	if slot.x < 0:
		units.stop(id)
		return
	_queue_path_request(id, "return_resource", slot, Vector2i(-1, -1), units.carry_type[id], drop_tile)

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
		if slot.x < 0:
			units.stop(id)
			return
		_queue_path_request(id, "gather_to_resource", slot, resource_tile, units.carry_type[id])
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
	if buildings.owner[building_id] != int(command["player_id"]) or not buildings.completed[building_id]:
		return
	var unit_type := String(command["params"].get("unit_type", "peasant"))
	if not _building_can_produce(buildings.building_type[building_id], unit_type):
		return
	buildings.start_production(building_id, unit_type)

func _apply_cancel_production_command(command: Dictionary) -> void:
	var building_id := int(command["target_entity_id"]) if command["target_entity_id"] != null else -1
	if building_id < 0 or building_id >= buildings.alive.size() or not buildings.alive[building_id]:
		return
	if buildings.owner[building_id] != int(command["player_id"]) or not buildings.completed[building_id]:
		return
	if buildings.production_type[building_id] == "":
		return
	var player: int = buildings.owner[building_id]
	player_food[player] += buildings.production_paid_food[building_id]
	player_wood[player] += buildings.production_paid_wood[building_id]
	player_stone[player] += buildings.production_paid_stone[building_id]
	buildings.cancel_current_production(building_id)

func _apply_form_up_command(command: Dictionary) -> void:
	var player_id := int(command["player_id"])
	var ids: Array = command["unit_ids"].duplicate()
	ids.sort()
	var warriors: Array = []
	for unit_id in ids:
		var id := int(unit_id)
		if id < 0 or id >= units.alive.size() or not units.alive[id]:
			continue
		if units.owner[id] != player_id or units.unit_type[id] != "warrior":
			continue
		warriors.append(id)
	if warriors.is_empty():
		return
	if _selected_warriors_are_platooned(warriors, player_id):
		_disband_selected_platoons(warriors, player_id)
		return
	_clear_player_platoon_membership(player_id)
	platoons.clear_player(player_id)
	var start := 0
	while start < warriors.size():
		var members: Array = warriors.slice(start, min(start + 30, warriors.size()))
		var platoon_id: int = platoons.create(player_id, members)
		for i in range(members.size()):
			var member_id := int(members[i])
			units.platoon_id[member_id] = platoon_id
			units.platoon_slot[member_id] = i
		start += 30

func _selected_warriors_are_platooned(warriors: Array, player_id: int) -> bool:
	for id_value in warriors:
		var id := int(id_value)
		var platoon_id: int = units.platoon_id[id]
		if platoon_id < 0 or platoon_id >= platoons.alive.size() or not platoons.alive[platoon_id] or platoons.owner[platoon_id] != player_id:
			return false
	return true

func _disband_selected_platoons(warriors: Array, player_id: int) -> void:
	var platoons_to_clear: Dictionary = {}
	for id_value in warriors:
		var platoon_id: int = units.platoon_id[int(id_value)]
		if platoon_id >= 0:
			platoons_to_clear[platoon_id] = true
	for platoon_id_value in platoons_to_clear.keys():
		var platoon_id := int(platoon_id_value)
		if platoon_id < 0 or platoon_id >= platoons.alive.size() or platoons.owner[platoon_id] != player_id:
			continue
		platoons.alive[platoon_id] = false
		platoons.broken[platoon_id] = false
		platoons.regroup_ticks[platoon_id] = 0
		for member in platoons.members[platoon_id]:
			var member_id := int(member)
			if member_id >= 0 and member_id < units.alive.size() and units.platoon_id[member_id] == platoon_id:
				units.platoon_id[member_id] = -1
				units.platoon_slot[member_id] = -1

func _clear_player_platoon_membership(player_id: int) -> void:
	for id in range(units.alive.size()):
		if units.owner[id] == player_id:
			units.platoon_id[id] = -1
			units.platoon_slot[id] = -1

func _building_can_produce(building_type: String, unit_type: String) -> bool:
	if building_type == "townhall":
		return unit_type == "peasant"
	if building_type == "barracks":
		return unit_type == "warrior"
	return false

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
	buildings.finish_current_production(building_id)

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
