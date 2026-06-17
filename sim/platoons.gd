extends RefCounted

var alive: Array[bool] = []
var owner: PackedInt32Array = PackedInt32Array()
var members: Array = []
var formation: PackedStringArray = PackedStringArray()
var broken: Array[bool] = []
var regroup_ticks: PackedInt32Array = PackedInt32Array()

func create(player_id: int, member_ids: Array, formation_name: String = "column_3x10") -> int:
	var id := alive.size()
	alive.append(true)
	owner.append(player_id)
	members.append(member_ids.duplicate())
	formation.append(formation_name)
	broken.append(false)
	regroup_ticks.append(0)
	return id

func clear_player(player_id: int) -> void:
	for id in range(alive.size()):
		if alive[id] and owner[id] == player_id:
			alive[id] = false

func live_count_for_player(player_id: int) -> int:
	var count := 0
	for id in range(alive.size()):
		if alive[id] and owner[id] == player_id:
			count += 1
	return count
