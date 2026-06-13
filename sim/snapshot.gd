extends RefCounted

const MAGIC := "RTSSNAP"
const VERSION := 1
const SCHEMA_HASH := 0x03100001

func write_snapshot(sim) -> PackedByteArray:
	var bytes := PackedByteArray()
	_append_string(bytes, MAGIC)
	_append_i32(bytes, VERSION)
	_append_i32(bytes, SCHEMA_HASH)
	_append_string(bytes, "local-dev")
	_append_string(bytes, "little")
	_append_i32(bytes, sim.tick)
	_append_i32(bytes, sim.rng.snapshot_state())
	_append_i32(bytes, sim.player_wood[0])
	_append_i32(bytes, sim.player_stone[0])
	_append_i32(bytes, sim.player_food[0])
	_append_i32(bytes, sim.units.alive.size())
	for id in range(sim.units.alive.size()):
		_append_i32(bytes, 1 if sim.units.alive[id] else 0)
		_append_i32(bytes, sim.units.owner[id])
		_append_string(bytes, sim.units.unit_type[id])
		_append_i32(bytes, sim.units.pos_x[id])
		_append_i32(bytes, sim.units.pos_y[id])
		_append_i32(bytes, sim.units.hp[id])
		_append_i32(bytes, sim.units.facing[id])
	_append_i32(bytes, sim.buildings.alive.size())
	for id in range(sim.buildings.alive.size()):
		_append_i32(bytes, 1 if sim.buildings.alive[id] else 0)
		_append_i32(bytes, sim.buildings.owner[id])
		_append_string(bytes, sim.buildings.building_type[id])
		_append_i32(bytes, sim.buildings.anchor_x[id])
		_append_i32(bytes, sim.buildings.anchor_y[id])
		_append_i32(bytes, sim.buildings.hp[id])
		_append_i32(bytes, sim.buildings.progress[id])
	return bytes

func _append_i32(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 0xff)
	bytes.append((value >> 8) & 0xff)
	bytes.append((value >> 16) & 0xff)
	bytes.append((value >> 24) & 0xff)

func _append_string(bytes: PackedByteArray, value: String) -> void:
	var utf8 := value.to_utf8_buffer()
	_append_i32(bytes, utf8.size())
	bytes.append_array(utf8)
