extends RefCounted

const TYPES := {
	"move": true,
	"stop": true,
	"gather": true,
	"attack_move": true,
	"attack_target": true,
	"build_place": true,
	"build_assign": true,
	"demolish": true,
	"produce": true,
	"cancel_production": true,
	"set_rally": true,
	"form_up": true,
	"disband": true,
	"set_stance": true,
	"set_priority": true,
}

var queued_by_tick := {}
var log := []
var next_seq_by_player := {}

func make_command(tick: int, player_id: int, type: String, unit_ids: Array = [], target_tile: Array = [], target_entity_id = null, params: Dictionary = {}) -> Dictionary:
	if not TYPES.has(type):
		push_error("Unknown command type: %s" % type)
	var seq := int(next_seq_by_player.get(player_id, 0))
	next_seq_by_player[player_id] = seq + 1
	return {
		"tick": tick,
		"player_id": player_id,
		"seq": seq,
		"type": type,
		"unit_ids": unit_ids.duplicate(),
		"target_tile": target_tile.duplicate(),
		"target_entity_id": target_entity_id,
		"params": params.duplicate(true),
	}

func enqueue(command: Dictionary) -> void:
	var tick := int(command["tick"])
	if not queued_by_tick.has(tick):
		queued_by_tick[tick] = []
	queued_by_tick[tick].append(command.duplicate(true))
	log.append(command.duplicate(true))

func pop_for_tick(tick: int) -> Array:
	var commands: Array = queued_by_tick.get(tick, [])
	queued_by_tick.erase(tick)
	commands.sort_custom(func(a, b): return _command_less(a, b))
	return commands

func _command_less(a: Dictionary, b: Dictionary) -> bool:
	if int(a["player_id"]) != int(b["player_id"]):
		return int(a["player_id"]) < int(b["player_id"])
	return int(a["seq"]) < int(b["seq"])
