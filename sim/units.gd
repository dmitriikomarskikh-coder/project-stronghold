extends RefCounted

var alive: Array[bool] = []
var owner: PackedInt32Array = PackedInt32Array()
var unit_type: PackedStringArray = PackedStringArray()
var pos_x: PackedInt32Array = PackedInt32Array()
var pos_y: PackedInt32Array = PackedInt32Array()
var hp: PackedInt32Array = PackedInt32Array()
var facing: PackedInt32Array = PackedInt32Array()
var order_type: PackedStringArray = PackedStringArray()
var target_x: PackedInt32Array = PackedInt32Array()
var target_y: PackedInt32Array = PackedInt32Array()
var work_x: PackedInt32Array = PackedInt32Array()
var work_y: PackedInt32Array = PackedInt32Array()
var gather_acc: PackedInt32Array = PackedInt32Array()
var carry_type: PackedStringArray = PackedStringArray()
var carry_amount: PackedInt32Array = PackedInt32Array()
var subslot: PackedInt32Array = PackedInt32Array()
var path_request_seq: PackedInt32Array = PackedInt32Array()
var attack_target_id: PackedInt32Array = PackedInt32Array()
var attack_target_kind: PackedStringArray = PackedStringArray()
var attack_cooldown: PackedInt32Array = PackedInt32Array()
var stance: PackedStringArray = PackedStringArray()
var build_target_id: PackedInt32Array = PackedInt32Array()
var platoon_id: PackedInt32Array = PackedInt32Array()
var platoon_slot: PackedInt32Array = PackedInt32Array()
var path: Array = []
var path_index: PackedInt32Array = PackedInt32Array()
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
	order_type[id] = "idle"
	target_x[id] = tile_x
	target_y[id] = tile_y
	work_x[id] = 0
	work_y[id] = 0
	gather_acc[id] = 0
	carry_type[id] = ""
	carry_amount[id] = 0
	subslot[id] = 0
	path_request_seq[id] = 0
	attack_target_id[id] = -1
	attack_target_kind[id] = ""
	attack_cooldown[id] = 0
	stance[id] = "defense"
	build_target_id[id] = -1
	platoon_id[id] = -1
	platoon_slot[id] = -1
	path[id] = []
	path_index[id] = 0
	skills[id] = []
	return id

func mark_dead(id: int) -> void:
	if id >= 0 and id < alive.size():
		alive[id] = false

func cleanup_dead() -> void:
	for id in range(alive.size()):
		if alive[id] and hp[id] <= 0:
			alive[id] = false
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
	order_type.append("idle")
	target_x.append(0)
	target_y.append(0)
	work_x.append(0)
	work_y.append(0)
	gather_acc.append(0)
	carry_type.append("")
	carry_amount.append(0)
	subslot.append(0)
	path_request_seq.append(0)
	attack_target_id.append(-1)
	attack_target_kind.append("")
	attack_cooldown.append(0)
	stance.append("defense")
	build_target_id.append(-1)
	platoon_id.append(-1)
	platoon_slot.append(-1)
	path.append([])
	path_index.append(0)
	skills.append([])
	return id

func set_move_order(id: int, tile_x: int, tile_y: int, new_path: Array) -> void:
	if id < 0 or id >= alive.size() or not alive[id]:
		return
	order_type[id] = "move"
	target_x[id] = tile_x
	target_y[id] = tile_y
	gather_acc[id] = 0
	path[id] = new_path.duplicate()
	path_index[id] = 0

func set_gather_order(id: int, resource_x: int, resource_y: int, slot_x: int, slot_y: int, resource_type: String, new_path: Array) -> void:
	if id < 0 or id >= alive.size() or not alive[id]:
		return
	order_type[id] = "gather_to_resource"
	target_x[id] = slot_x
	target_y[id] = slot_y
	work_x[id] = resource_x
	work_y[id] = resource_y
	carry_type[id] = resource_type
	gather_acc[id] = 0
	path[id] = new_path.duplicate()
	path_index[id] = 0

func set_return_order(id: int, drop_x: int, drop_y: int, new_path: Array) -> void:
	if id < 0 or id >= alive.size() or not alive[id]:
		return
	order_type[id] = "return_resource"
	target_x[id] = drop_x
	target_y[id] = drop_y
	path[id] = new_path.duplicate()
	path_index[id] = 0

func set_attack_move_order(id: int, tile_x: int, tile_y: int, new_path: Array) -> void:
	if id < 0 or id >= alive.size() or not alive[id]:
		return
	order_type[id] = "attack_move"
	target_x[id] = tile_x
	target_y[id] = tile_y
	attack_target_id[id] = -1
	attack_target_kind[id] = ""
	gather_acc[id] = 0
	path[id] = new_path.duplicate()
	path_index[id] = 0

func set_attack_target_order(id: int, target_id: int, target_kind: String, tile_x: int, tile_y: int, new_path: Array) -> void:
	if id < 0 or id >= alive.size() or not alive[id]:
		return
	order_type[id] = "attack_target"
	attack_target_id[id] = target_id
	attack_target_kind[id] = target_kind
	target_x[id] = tile_x
	target_y[id] = tile_y
	gather_acc[id] = 0
	path[id] = new_path.duplicate()
	path_index[id] = 0

func set_build_order(id: int, building_id: int, slot_x: int, slot_y: int, new_path: Array) -> void:
	if id < 0 or id >= alive.size() or not alive[id]:
		return
	order_type[id] = "build_to_site"
	build_target_id[id] = building_id
	target_x[id] = slot_x
	target_y[id] = slot_y
	gather_acc[id] = 0
	path[id] = new_path.duplicate()
	path_index[id] = 0

func stop(id: int) -> void:
	if id < 0 or id >= alive.size():
		return
	order_type[id] = "idle"
	path_request_seq[id] += 1
	attack_target_id[id] = -1
	attack_target_kind[id] = ""
	build_target_id[id] = -1
	gather_acc[id] = 0
	path[id] = []
	path_index[id] = 0

func set_stance(id: int, new_stance: String) -> void:
	if id < 0 or id >= alive.size() or not alive[id]:
		return
	if new_stance == "defense" or new_stance == "hold":
		stance[id] = new_stance

func tile_x(id: int) -> int:
	return int(pos_x[id] / 256)

func tile_y(id: int) -> int:
	return int(pos_y[id] / 256)
