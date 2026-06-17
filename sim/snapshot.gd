extends RefCounted

const MAGIC := "RTSSNAP"
const VERSION := 1
const SCHEMA_HASH := 0x03100013

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
	_append_i32(bytes, sim.player_food[1])
	_append_i32(bytes, sim.food_acc[0])
	_append_i32(bytes, sim.food_acc[1])
	_append_i32(bytes, sim.farm_acc[0])
	_append_i32(bytes, sim.farm_acc[1])
	for player_id in range(2):
		_append_i32(bytes, sim.food_delta_history[player_id].size())
		for value in sim.food_delta_history[player_id]:
			_append_i32(bytes, int(value))
	for player_id in range(2):
		_append_i32(bytes, sim.last_attack_tick[player_id])
		_append_i32(bytes, sim.last_attack_x[player_id])
		_append_i32(bytes, sim.last_attack_y[player_id])
	_append_i32(bytes, sim.winner_player)
	if sim.fog != null:
		_append_i32(bytes, sim.fog.player_count)
		for player_id in range(sim.fog.player_count):
			_append_i32(bytes, sim.fog.visible[player_id].size())
			for value in sim.fog.visible[player_id]:
				bytes.append(int(value) & 0xff)
			_append_i32(bytes, sim.fog.explored[player_id].size())
			for value in sim.fog.explored[player_id]:
				bytes.append(int(value) & 0xff)
	else:
		_append_i32(bytes, 0)
	_append_i32(bytes, sim.units.alive.size())
	for id in range(sim.units.alive.size()):
		_append_i32(bytes, 1 if sim.units.alive[id] else 0)
		_append_i32(bytes, sim.units.owner[id])
		_append_string(bytes, sim.units.unit_type[id])
		_append_i32(bytes, sim.units.pos_x[id])
		_append_i32(bytes, sim.units.pos_y[id])
		_append_i32(bytes, sim.units.hp[id])
		_append_i32(bytes, sim.units.facing[id])
		_append_string(bytes, sim.units.order_type[id])
		_append_i32(bytes, sim.units.target_x[id])
		_append_i32(bytes, sim.units.target_y[id])
		_append_i32(bytes, sim.units.work_x[id])
		_append_i32(bytes, sim.units.work_y[id])
		_append_i32(bytes, sim.units.gather_acc[id])
		_append_string(bytes, sim.units.carry_type[id])
		_append_i32(bytes, sim.units.carry_amount[id])
		_append_i32(bytes, sim.units.subslot[id])
		_append_i32(bytes, sim.units.path_request_seq[id])
		_append_i32(bytes, sim.units.attack_target_id[id])
		_append_string(bytes, sim.units.attack_target_kind[id])
		_append_i32(bytes, sim.units.attack_cooldown[id])
		_append_string(bytes, sim.units.stance[id])
		_append_i32(bytes, sim.units.build_target_id[id])
		_append_i32(bytes, sim.units.platoon_id[id])
		_append_i32(bytes, sim.units.platoon_slot[id])
		_append_i32(bytes, sim.units.path_index[id])
		_append_i32(bytes, sim.units.path[id].size())
		for tile in sim.units.path[id]:
			_append_i32(bytes, tile.x)
			_append_i32(bytes, tile.y)
	_append_i32(bytes, sim.loot_items.alive.size())
	for id in range(sim.loot_items.alive.size()):
		_append_i32(bytes, 1 if sim.loot_items.alive[id] else 0)
		_append_i32(bytes, sim.loot_items.pos_x[id])
		_append_i32(bytes, sim.loot_items.pos_y[id])
		_append_string(bytes, sim.loot_items.resource_type[id])
		_append_i32(bytes, sim.loot_items.amount[id])
		_append_i32(bytes, sim.loot_items.ttl[id])
	_append_i32(bytes, sim.platoons.alive.size())
	for id in range(sim.platoons.alive.size()):
		_append_i32(bytes, 1 if sim.platoons.alive[id] else 0)
		_append_i32(bytes, sim.platoons.owner[id])
		_append_string(bytes, sim.platoons.formation[id])
		_append_i32(bytes, 1 if sim.platoons.broken[id] else 0)
		_append_i32(bytes, sim.platoons.regroup_ticks[id])
		_append_i32(bytes, sim.platoons.members[id].size())
		for member_id in sim.platoons.members[id]:
			_append_i32(bytes, int(member_id))
	_append_i32(bytes, sim.buildings.alive.size())
	for id in range(sim.buildings.alive.size()):
		_append_i32(bytes, 1 if sim.buildings.alive[id] else 0)
		_append_i32(bytes, sim.buildings.owner[id])
		_append_string(bytes, sim.buildings.building_type[id])
		_append_i32(bytes, sim.buildings.anchor_x[id])
		_append_i32(bytes, sim.buildings.anchor_y[id])
		_append_i32(bytes, sim.buildings.hp[id])
		_append_i32(bytes, sim.buildings.progress[id])
		_append_i32(bytes, 1 if sim.buildings.completed[id] else 0)
		_append_i32(bytes, sim.buildings.required_wood[id])
		_append_i32(bytes, sim.buildings.required_stone[id])
		_append_i32(bytes, sim.buildings.invested_wood[id])
		_append_i32(bytes, sim.buildings.invested_stone[id])
		_append_i32(bytes, sim.buildings.frame_ttl[id])
		_append_string(bytes, sim.buildings.production_type[id])
		_append_i32(bytes, sim.buildings.production_ticks[id])
		_append_i32(bytes, sim.buildings.production_paid_food[id])
		_append_i32(bytes, sim.buildings.production_paid_wood[id])
		_append_i32(bytes, sim.buildings.production_paid_stone[id])
		_append_i32(bytes, sim.buildings.production_acc_food[id])
		_append_i32(bytes, sim.buildings.production_acc_wood[id])
		_append_i32(bytes, sim.buildings.production_acc_stone[id])
		_append_i32(bytes, sim.buildings.attack_cooldown[id])
		_append_i32(bytes, sim.buildings.known_mask[id])
		_append_i32(bytes, sim.buildings.known_hp_p0[id])
		_append_i32(bytes, sim.buildings.known_hp_p1[id])
		_append_i32(bytes, sim.buildings.known_progress_p0[id])
		_append_i32(bytes, sim.buildings.known_progress_p1[id])
		_append_i32(bytes, sim.buildings.known_completed_mask[id])
		_append_i32(bytes, sim.buildings.production_queue[id].size())
		for queued_type in sim.buildings.production_queue[id]:
			_append_string(bytes, String(queued_type))
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
