extends RefCounted

var width := 0
var height := 0
var player_count := 2
var visible: Array = []
var explored: Array = []

func setup(map_state, players: int = 2) -> void:
	width = int(map_state.size_x)
	height = int(map_state.size_y)
	player_count = players
	visible = []
	explored = []
	var cell_count := width * height
	for _player_id in range(player_count):
		visible.append(PackedByteArray())
		explored.append(PackedByteArray())
		visible[-1].resize(cell_count)
		explored[-1].resize(cell_count)

func step(sim) -> void:
	if visible.is_empty():
		setup(sim.map_state, 2)
	for player_id in range(player_count):
		_clear_visible(player_id)
	_reveal_units(sim)
	_reveal_buildings(sim)
	_update_known_buildings(sim)

func is_visible(player_id: int, x: int, y: int) -> bool:
	if player_id < 0 or player_id >= player_count or not _in_bounds(x, y):
		return false
	return int(visible[player_id][_index(x, y)]) != 0

func is_explored(player_id: int, x: int, y: int) -> bool:
	if player_id < 0 or player_id >= player_count or not _in_bounds(x, y):
		return false
	return int(explored[player_id][_index(x, y)]) != 0

func _clear_visible(player_id: int) -> void:
	visible[player_id].fill(0)

func _reveal_units(sim) -> void:
	for id in range(sim.units.alive.size()):
		if not sim.units.alive[id]:
			continue
		var owner: int = sim.units.owner[id]
		var cfg: Dictionary = sim.balance["units"].get(sim.units.unit_type[id], {})
		_reveal_disc(owner, sim.units.tile_x(id), sim.units.tile_y(id), int(cfg.get("vision_radius", 0)))

func _reveal_buildings(sim) -> void:
	for id in range(sim.buildings.alive.size()):
		if not sim.buildings.alive[id]:
			continue
		var owner: int = sim.buildings.owner[id]
		var cfg: Dictionary = sim.balance["buildings"].get(sim.buildings.building_type[id], {})
		var footprint: Array = cfg.get("footprint", [1, 1])
		var center_x: int = sim.buildings.anchor_x[id] + int(footprint[0] / 2)
		var center_y: int = sim.buildings.anchor_y[id] + int(footprint[1] / 2)
		_reveal_disc(owner, center_x, center_y, int(cfg.get("vision_radius", 0)))

func _update_known_buildings(sim) -> void:
	for building_id in range(sim.buildings.alive.size()):
		if not sim.buildings.alive[building_id]:
			continue
		for player_id in range(player_count):
			if _building_visible_to_player(sim, building_id, player_id):
				sim.buildings.remember_seen(player_id, building_id)

func _building_visible_to_player(sim, building_id: int, player_id: int) -> bool:
	var cfg: Dictionary = sim.balance["buildings"].get(sim.buildings.building_type[building_id], {})
	var footprint: Array = cfg.get("footprint", [1, 1])
	for y in range(sim.buildings.anchor_y[building_id], sim.buildings.anchor_y[building_id] + int(footprint[1])):
		for x in range(sim.buildings.anchor_x[building_id], sim.buildings.anchor_x[building_id] + int(footprint[0])):
			if is_visible(player_id, x, y):
				return true
	return false

func _reveal_disc(player_id: int, center_x: int, center_y: int, radius: int) -> void:
	if player_id < 0 or player_id >= player_count:
		return
	for y in range(center_y - radius, center_y + radius + 1):
		for x in range(center_x - radius, center_x + radius + 1):
			if not _in_bounds(x, y):
				continue
			if max(abs(x - center_x), abs(y - center_y)) > radius:
				continue
			var index := _index(x, y)
			visible[player_id][index] = 1
			explored[player_id][index] = 1

func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height

func _index(x: int, y: int) -> int:
	return y * width + x
