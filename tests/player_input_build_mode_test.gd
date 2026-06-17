extends SceneTree

const TickRunnerScript := preload("res://sim/tick.gd")
const PlayerInputScript := preload("res://game/input/player_input.gd")
const TileMapRendererScript := preload("res://game/render/tile_map_renderer.gd")

func _init() -> void:
	var sim: RefCounted = TickRunnerScript.new()
	sim.load_match("res://maps/map01.json", "res://config/balance.json", 12345)
	var camera := Camera2D.new()
	var renderer := TileMapRendererScript.new()
	root.add_child(camera)
	root.add_child(renderer)
	renderer.draw_state(sim.map_state, sim.buildings, sim.units, sim.balance)

	var input: RefCounted = PlayerInputScript.new()
	input.setup(camera, renderer, sim)

	input.handle_input(_key(KEY_B))
	if not input.build_mode_enabled():
		push_error("Expected B to enable build mode")
		quit(1)
		return
	if input.pending_building_type() != "farm":
		push_error("Expected farm to be the default pending building")
		quit(1)
		return

	input.handle_input(_key(KEY_2))
	if input.pending_building_type() != "barracks":
		push_error("Expected number key 2 to select barracks")
		quit(1)
		return

	input.handle_input(_key(KEY_ESCAPE))
	if input.build_mode_enabled():
		push_error("Expected Escape to cancel build mode")
		quit(1)
		return

	input.selected_units.clear()
	input.selected_units.append(0)
	input.selected_units.append(1)
	input.store_control_group(1)
	input.selected_units.clear()
	input.selected_units.append(2)
	input.recall_control_group(1)
	if input.selected_units.size() != 2 or input.selected_units[0] != 0 or input.selected_units[1] != 1:
		push_error("Expected control group 1 to recall stored selected units")
		quit(1)
		return

	sim.units.alive[1] = false
	input.selected_units.clear()
	input.recall_control_group(1)
	if input.selected_units.size() != 1 or input.selected_units[0] != 0:
		push_error("Expected control group recall to filter dead units")
		quit(1)
		return

	var enemy_townhall := _first_building(sim, 1, "townhall")
	if input._enemy_building_at_tile(Vector2i(sim.buildings.anchor_x[enemy_townhall], sim.buildings.anchor_y[enemy_townhall])) >= 0:
		push_error("Expected input targeting to ignore unknown enemy buildings through fog")
		quit(1)
		return
	var scout: int = sim.units.spawn(0, "warrior", sim.buildings.anchor_x[enemy_townhall], sim.buildings.anchor_y[enemy_townhall], int(sim.balance["units"]["warrior"]["hp"]))
	sim.step()
	sim.units.pos_x[scout] = 10 * 256
	sim.units.pos_y[scout] = 10 * 256
	sim.step()
	if input._enemy_building_at_tile(Vector2i(sim.buildings.anchor_x[enemy_townhall], sim.buildings.anchor_y[enemy_townhall])) != enemy_townhall:
		push_error("Expected input targeting to allow known enemy building ghosts")
		quit(1)
		return

	print("Player input build mode test passed")
	quit(0)

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event

func _first_building(sim: RefCounted, player_id: int, type_name: String) -> int:
	for id in range(sim.buildings.alive.size()):
		if sim.buildings.alive[id] and sim.buildings.owner[id] == player_id and sim.buildings.building_type[id] == type_name:
			return id
	return -1
