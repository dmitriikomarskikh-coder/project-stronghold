extends RefCounted

var alive: Array[bool] = []
var pos_x: PackedInt32Array = PackedInt32Array()
var pos_y: PackedInt32Array = PackedInt32Array()
var resource_type: PackedStringArray = PackedStringArray()
var amount: PackedInt32Array = PackedInt32Array()
var ttl: PackedInt32Array = PackedInt32Array()

func spawn(tile_x: int, tile_y: int, type_name: String, value: int, lifetime: int = 600) -> int:
	var id := alive.size()
	alive.append(true)
	pos_x.append(tile_x)
	pos_y.append(tile_y)
	resource_type.append(type_name)
	amount.append(value)
	ttl.append(lifetime)
	return id

func step_ttl() -> void:
	for id in range(alive.size()):
		if not alive[id]:
			continue
		ttl[id] -= 1
		if ttl[id] <= 0 or amount[id] <= 0:
			alive[id] = false
