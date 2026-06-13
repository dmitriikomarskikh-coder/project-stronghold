extends RefCounted

var alive: Array[bool] = []
var owner: PackedInt32Array = PackedInt32Array()
var building_type: PackedStringArray = PackedStringArray()
var anchor_x: PackedInt32Array = PackedInt32Array()
var anchor_y: PackedInt32Array = PackedInt32Array()
var hp: PackedInt32Array = PackedInt32Array()
var progress: PackedInt32Array = PackedInt32Array()
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
	return id

func live_count_for_player(player_id: int, include_zero_progress: bool = false) -> int:
	var count := 0
	for id in range(alive.size()):
		if alive[id] and owner[id] == player_id and (include_zero_progress or progress[id] > 0):
			count += 1
	return count

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
	return id
