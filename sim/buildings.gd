extends RefCounted

var alive: Array[bool] = []
var owner: PackedInt32Array = PackedInt32Array()
var building_type: PackedStringArray = PackedStringArray()
var anchor_x: PackedInt32Array = PackedInt32Array()
var anchor_y: PackedInt32Array = PackedInt32Array()
var hp: PackedInt32Array = PackedInt32Array()
var progress: PackedInt32Array = PackedInt32Array()
var completed: Array[bool] = []
var required_wood: PackedInt32Array = PackedInt32Array()
var required_stone: PackedInt32Array = PackedInt32Array()
var invested_wood: PackedInt32Array = PackedInt32Array()
var invested_stone: PackedInt32Array = PackedInt32Array()
var frame_ttl: PackedInt32Array = PackedInt32Array()
var production_type: PackedStringArray = PackedStringArray()
var production_ticks: PackedInt32Array = PackedInt32Array()
var production_paid_food: PackedInt32Array = PackedInt32Array()
var production_paid_wood: PackedInt32Array = PackedInt32Array()
var production_paid_stone: PackedInt32Array = PackedInt32Array()
var production_acc_food: PackedInt32Array = PackedInt32Array()
var production_acc_wood: PackedInt32Array = PackedInt32Array()
var production_acc_stone: PackedInt32Array = PackedInt32Array()
var attack_cooldown: PackedInt32Array = PackedInt32Array()
var known_mask: PackedInt32Array = PackedInt32Array()
var known_hp_p0: PackedInt32Array = PackedInt32Array()
var known_hp_p1: PackedInt32Array = PackedInt32Array()
var known_progress_p0: PackedInt32Array = PackedInt32Array()
var known_progress_p1: PackedInt32Array = PackedInt32Array()
var known_completed_mask: PackedInt32Array = PackedInt32Array()
var production_queue: Array = []
var free_list: Array[int] = []

func spawn(player_id: int, type_name: String, tile_x: int, tile_y: int, max_hp: int, build_progress: int = 1) -> int:
	var id := _allocate_slot()
	alive[id] = true
	owner[id] = player_id
	building_type[id] = type_name
	anchor_x[id] = tile_x
	anchor_y[id] = tile_y
	hp[id] = max_hp
	progress[id] = build_progress
	completed[id] = build_progress > 0
	required_wood[id] = 0
	required_stone[id] = 0
	invested_wood[id] = 0
	invested_stone[id] = 0
	frame_ttl[id] = 0
	production_type[id] = ""
	production_ticks[id] = 0
	attack_cooldown[id] = 0
	known_mask[id] = 0
	known_hp_p0[id] = 0
	known_hp_p1[id] = 0
	known_progress_p0[id] = 0
	known_progress_p1[id] = 0
	known_completed_mask[id] = 0
	production_queue[id] = []
	_reset_production_payment(id)
	if player_id == 0:
		remember_seen(0, id)
	else:
		remember_seen(1, id)
	return id

func place_frame(player_id: int, type_name: String, tile_x: int, tile_y: int, wood: int, stone: int) -> int:
	var id := spawn(player_id, type_name, tile_x, tile_y, 1, 0)
	completed[id] = false
	required_wood[id] = wood
	required_stone[id] = stone
	frame_ttl[id] = 600
	return id

func zero_progress_frame_count(player_id: int) -> int:
	var count := 0
	for id in range(alive.size()):
		if alive[id] and owner[id] == player_id and progress[id] == 0:
			count += 1
	return count

func live_count_for_player(player_id: int, include_zero_progress: bool = false) -> int:
	var count := 0
	for id in range(alive.size()):
		if alive[id] and owner[id] == player_id and (include_zero_progress or progress[id] > 0):
			count += 1
	return count

func cleanup_dead() -> void:
	for id in range(alive.size()):
		if alive[id] and hp[id] <= 0:
			alive[id] = false
		if not alive[id] and not free_list.has(id):
			free_list.append(id)
	free_list.sort()

func first_dropoff_for_player(player_id: int, balance: Dictionary, from_tile: Vector2i) -> int:
	var best_id := -1
	var best_dist := 999999999
	for id in range(alive.size()):
		if not alive[id] or owner[id] != player_id or not completed[id]:
			continue
		var cfg: Dictionary = balance["buildings"].get(building_type[id], {})
		if not bool(cfg.get("accepts_resources", false)):
			continue
		var footprint: Array = cfg.get("footprint", [1, 1])
		var center := Vector2i(anchor_x[id] + int(footprint[0] / 2), anchor_y[id] + int(footprint[1] / 2))
		var dist := (center.x - from_tile.x) * (center.x - from_tile.x) + (center.y - from_tile.y) * (center.y - from_tile.y)
		if dist < best_dist or (dist == best_dist and id < best_id):
			best_dist = dist
			best_id = id
	return best_id

func _allocate_slot() -> int:
	if free_list.size() > 0:
		return free_list.pop_front()
	var id := alive.size()
	alive.append(false)
	owner.append(0)
	building_type.append("")
	anchor_x.append(0)
	anchor_y.append(0)
	hp.append(0)
	progress.append(0)
	completed.append(false)
	required_wood.append(0)
	required_stone.append(0)
	invested_wood.append(0)
	invested_stone.append(0)
	frame_ttl.append(0)
	production_type.append("")
	production_ticks.append(0)
	production_paid_food.append(0)
	production_paid_wood.append(0)
	production_paid_stone.append(0)
	production_acc_food.append(0)
	production_acc_wood.append(0)
	production_acc_stone.append(0)
	attack_cooldown.append(0)
	known_mask.append(0)
	known_hp_p0.append(0)
	known_hp_p1.append(0)
	known_progress_p0.append(0)
	known_progress_p1.append(0)
	known_completed_mask.append(0)
	production_queue.append([])
	return id

func remember_seen(player_id: int, id: int) -> void:
	if id < 0 or id >= alive.size():
		return
	known_mask[id] = known_mask[id] | (1 << player_id)
	if player_id == 0:
		known_hp_p0[id] = hp[id]
		known_progress_p0[id] = progress[id]
	else:
		known_hp_p1[id] = hp[id]
		known_progress_p1[id] = progress[id]
	if completed[id]:
		known_completed_mask[id] = known_completed_mask[id] | (1 << player_id)
	else:
		known_completed_mask[id] = known_completed_mask[id] & ~(1 << player_id)

func is_known_by(player_id: int, id: int) -> bool:
	if id < 0 or id >= alive.size():
		return false
	return (known_mask[id] & (1 << player_id)) != 0

func start_production(id: int, type_name: String) -> void:
	if id < 0 or id >= alive.size() or not alive[id]:
		return
	if production_type[id] == "":
		production_type[id] = type_name
		production_ticks[id] = 0
		_reset_production_payment(id)
	else:
		production_queue[id].append(type_name)

func clear_production(id: int) -> void:
	if id < 0 or id >= alive.size():
		return
	production_type[id] = ""
	production_ticks[id] = 0
	production_queue[id] = []
	_reset_production_payment(id)

func finish_current_production(id: int) -> void:
	if id < 0 or id >= alive.size():
		return
	if production_queue[id].is_empty():
		production_type[id] = ""
		production_ticks[id] = 0
	else:
		production_type[id] = String(production_queue[id].pop_front())
		production_ticks[id] = 0
	_reset_production_payment(id)

func cancel_current_production(id: int) -> void:
	if id < 0 or id >= alive.size():
		return
	if production_queue[id].is_empty():
		production_type[id] = ""
		production_ticks[id] = 0
	else:
		production_type[id] = String(production_queue[id].pop_front())
		production_ticks[id] = 0
	_reset_production_payment(id)

func _reset_production_payment(id: int) -> void:
	production_paid_food[id] = 0
	production_paid_wood[id] = 0
	production_paid_stone[id] = 0
	production_acc_food[id] = 0
	production_acc_wood[id] = 0
	production_acc_stone[id] = 0
