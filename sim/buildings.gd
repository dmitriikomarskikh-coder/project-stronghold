extends RefCounted

var alive: Array[bool] = []
var owner: PackedInt32Array = PackedInt32Array()
var building_type: PackedStringArray = PackedStringArray()
var anchor_x: PackedInt32Array = PackedInt32Array()
var anchor_y: PackedInt32Array = PackedInt32Array()
var hp: PackedInt32Array = PackedInt32Array()
var progress: PackedInt32Array = PackedInt32Array()
var production_type: PackedStringArray = PackedStringArray()
var production_ticks: PackedInt32Array = PackedInt32Array()
var production_paid_food: PackedInt32Array = PackedInt32Array()
var production_paid_wood: PackedInt32Array = PackedInt32Array()
var production_paid_stone: PackedInt32Array = PackedInt32Array()
var production_acc_food: PackedInt32Array = PackedInt32Array()
var production_acc_wood: PackedInt32Array = PackedInt32Array()
var production_acc_stone: PackedInt32Array = PackedInt32Array()
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
	production_type[id] = ""
	production_ticks[id] = 0
	_reset_production_payment(id)
	return id

func live_count_for_player(player_id: int, include_zero_progress: bool = false) -> int:
	var count := 0
	for id in range(alive.size()):
		if alive[id] and owner[id] == player_id and (include_zero_progress or progress[id] > 0):
			count += 1
	return count

func first_dropoff_for_player(player_id: int, balance: Dictionary, from_tile: Vector2i) -> int:
	var best_id := -1
	var best_dist := 999999999
	for id in range(alive.size()):
		if not alive[id] or owner[id] != player_id or progress[id] <= 0:
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
	production_type.append("")
	production_ticks.append(0)
	production_paid_food.append(0)
	production_paid_wood.append(0)
	production_paid_stone.append(0)
	production_acc_food.append(0)
	production_acc_wood.append(0)
	production_acc_stone.append(0)
	return id

func start_production(id: int, type_name: String) -> void:
	if id < 0 or id >= alive.size() or not alive[id]:
		return
	if production_type[id] == "":
		production_type[id] = type_name
		production_ticks[id] = 0
		_reset_production_payment(id)

func clear_production(id: int) -> void:
	if id < 0 or id >= alive.size():
		return
	production_type[id] = ""
	production_ticks[id] = 0
	_reset_production_payment(id)

func _reset_production_payment(id: int) -> void:
	production_paid_food[id] = 0
	production_paid_wood[id] = 0
	production_paid_stone[id] = 0
	production_acc_food[id] = 0
	production_acc_wood[id] = 0
	production_acc_stone[id] = 0
