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

	input.select_units_in_tile_rect(Vector2i(18, 22), Vector2i(18, 22))
	if input.selected_units.is_empty():
		push_error("Expected rectangle selection to select own units in the tile range")
		quit(1)
		return
	var first_count: int = input.selected_units.size()

	var extra_unit := _first_own_unit_outside(sim, 18, 18, 22, 22)
	input.select_units_in_tile_rect(Vector2i(sim.units.tile_x(extra_unit), sim.units.tile_y(extra_unit)), Vector2i(sim.units.tile_x(extra_unit), sim.units.tile_y(extra_unit)), true)
	if input.selected_units.size() != first_count + 1:
		push_error("Expected additive rectangle selection to keep the old group and add one unit")
		quit(1)
		return

	var peasant := _first_own_unit_of_type(sim, "peasant")
	input._select_same_type_near(peasant, Vector2i(sim.units.tile_x(peasant), sim.units.tile_y(peasant)))
	for unit_id in input.selected_units:
		if sim.units.unit_type[int(unit_id)] != "peasant":
			push_error("Expected same-type selection to include only peasants")
			quit(1)
			return

	var barracks: int = sim.buildings.spawn(0, "barracks", 35, 35, int(sim.balance["buildings"]["barracks"]["hp"]), 1)
	input._select_building(barracks)
	input.handle_input(_key(KEY_N))
	var command: Dictionary = sim.command_log[sim.command_log.size() - 1]
	if command["type"] != "produce" or int(command["target_entity_id"]) != barracks or String(command["params"]["unit_type"]) != "warrior":
		push_error("Expected N on selected barracks to queue warrior production at that barracks")
		quit(1)
		return

	input.handle_input(_key(KEY_C))
	command = sim.command_log[sim.command_log.size() - 1]
	if command["type"] != "cancel_production" or int(command["target_entity_id"]) != barracks:
		push_error("Expected C on selected building to queue cancel_production")
		quit(1)
		return

	print("Player input selection test passed")
	quit(0)

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event

func _first_own_unit_of_type(sim: RefCounted, type_name: String) -> int:
	for id in range(sim.units.alive.size()):
		if sim.units.alive[id] and sim.units.owner[id] == 0 and sim.units.unit_type[id] == type_name:
			return id
	return -1

func _first_own_unit_outside(sim: RefCounted, min_x: int, max_x: int, min_y: int, max_y: int) -> int:
	for id in range(sim.units.alive.size()):
		if not sim.units.alive[id] or sim.units.owner[id] != 0:
			continue
		var x: int = sim.units.tile_x(id)
		var y: int = sim.units.tile_y(id)
		if x < min_x or x > max_x or y < min_y or y > max_y:
			return id
	return -1
