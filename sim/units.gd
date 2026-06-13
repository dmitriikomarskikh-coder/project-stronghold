extends RefCounted

var alive: Array[bool] = []
var owner: PackedInt32Array = PackedInt32Array()
var unit_type: PackedStringArray = PackedStringArray()
var pos_x: PackedInt32Array = PackedInt32Array()
var pos_y: PackedInt32Array = PackedInt32Array()
var hp: PackedInt32Array = PackedInt32Array()
var facing: PackedInt32Array = PackedInt32Array()
var skills: Array = []
var free_list: Array[int] = []

func spawn(player_id: int, type_name: String, tile_x: int, tile_y: int, max_hp: int) -> int:
	var id := _allocate_slot()
	alive[id] = true
	owner[id] = player_id
	unit_type[id] = type_name
	pos_x[id] = tile_x * 256
	pos_y[id] = tile_y * 256
	hp[id] = max_hp
	facing[id] = 4
	skills[id] = []
	return id

func mark_dead(id: int) -> void:
	if id >= 0 and id < alive.size():
		alive[id] = false

func cleanup_dead() -> void:
	for id in range(alive.size()):
		if not alive[id] and not free_list.has(id):
			free_list.append(id)
	free_list.sort()

func live_count_for_player(player_id: int) -> int:
	var count := 0
	for id in range(alive.size()):
		if alive[id] and owner[id] == player_id:
			count += 1
	return count

func _allocate_slot() -> int:
	if free_list.size() > 0:
		return free_list.pop_front()
	var id := alive.size()
	alive.append(false)
	owner.append(0)
	unit_type.append("")
	pos_x.append(0)
	pos_y.append(0)
	hp.append(0)
	facing.append(0)
	skills.append([])
	return id

