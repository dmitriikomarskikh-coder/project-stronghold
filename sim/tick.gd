extends RefCounted

const Commands := preload("res://sim/commands.gd")
const GameMap := preload("res://sim/map.gd")
const Rng := preload("res://sim/rng.gd")
const Snapshot := preload("res://sim/snapshot.gd")
const Units := preload("res://sim/units.gd")
const Buildings := preload("res://sim/buildings.gd")

const TICK_MS := 100

var tick := 0
var render_accumulator := 0.0
var map_state: RefCounted
var commands: RefCounted
var command_log: Array:
	get:
		return commands.log
var rng: RefCounted
var snapshot_writer: RefCounted
var units: RefCounted
var buildings: RefCounted
var balance: Dictionary = {}
var player_wood := PackedInt32Array([1000, 1000])
var player_stone := PackedInt32Array([1000, 1000])
var player_food := PackedInt32Array([1000, 1000])
var food_acc := PackedInt32Array([0, 0])
var farm_acc := PackedInt32Array([0, 0])
var unit_limit := 200

func load_match(map_path: String, balance_path: String, seed_value: int) -> void:
	balance = _load_json(balance_path)
	player_wood = PackedInt32Array([int(balance["start_resources"]["wood"]), int(balance["start_resources"]["wood"])])
	player_stone = PackedInt32Array([int(balance["start_resources"]["stone"]), int(balance["start_resources"]["stone"])])
	player_food = PackedInt32Array([int(balance["start_resources"]["food"]), int(balance["start_resources"]["food"])])
	unit_limit = int(balance["unit_limit"])

	map_state = GameMap.new()
	map_state.load_from_json(map_path)
	commands = Commands.new()
	rng = Rng.new()
	rng.seed_rng(seed_value)
	snapshot_writer = Snapshot.new()
	units = Units.new()
	buildings = Buildings.new()
	_spawn_start_buildings()
	_spawn_start_units()
	tick = 0

func advance_render_time(delta: float) -> void:
	render_accumulator += delta
	while render_accumulator >= 0.1:
		step()
		render_accumulator -= 0.1

func step() -> void:
	var tick_commands: Array = commands.pop_for_tick(tick)
	_apply_commands(tick_commands)
	_phase_movement()
	_phase_combat()
	_phase_gather_and_loot()
	_phase_building()
	_phase_production()
	_phase_food_consumption()
	_phase_cleanup_dead()
	tick += 1

func snapshot_bytes() -> PackedByteArray:
	return snapshot_writer.write_snapshot(self)

func live_units_for_player(player_id: int) -> int:
	return units.live_count_for_player(player_id)

func live_buildings_for_player(player_id: int) -> int:
	return buildings.live_count_for_player(player_id)

func food_trend_10s(_player_id: int) -> int:
	return 0

func _apply_commands(_tick_commands: Array) -> void:
	pass

func _phase_movement() -> void:
	pass

func _phase_combat() -> void:
	pass

func _phase_gather_and_loot() -> void:
	pass

func _phase_building() -> void:
	pass

func _phase_production() -> void:
	pass

func _phase_food_consumption() -> void:
	for player_id in range(2):
		food_acc[player_id] += live_units_for_player(player_id)
		if food_acc[player_id] >= 100:
			var due := int(food_acc[player_id] / 100)
			var actual: int = min(player_food[player_id], due)
			player_food[player_id] -= actual
			food_acc[player_id] %= 100

func _phase_cleanup_dead() -> void:
	units.cleanup_dead()

func _spawn_start_units() -> void:
	for player_key in map_state.players.keys():
		var player_id := int(player_key)
		var area: Array = map_state.players[player_key]["start_workers_area"]
		for i in range(5):
			units.spawn(player_id, "peasant", int(area[0]) + i % 3, int(area[1]) + int(i / 3), int(balance["units"]["peasant"]["hp"]))

func _spawn_start_buildings() -> void:
	for player_key in map_state.players.keys():
		var player_id := int(player_key)
		var townhall_anchor: Array = map_state.players[player_key]["start_townhall"]
		buildings.spawn(player_id, "townhall", int(townhall_anchor[0]), int(townhall_anchor[1]), int(balance["buildings"]["townhall"]["hp"]), 1)

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open JSON: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON: %s" % path)
		return {}
	return parsed
