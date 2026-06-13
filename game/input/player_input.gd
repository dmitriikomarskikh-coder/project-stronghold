extends RefCounted

var selected_units: Array[int] = []
var _camera: Camera2D
var _renderer
var _sim

func setup(camera: Camera2D, renderer, sim) -> void:
	_camera = camera
	_renderer = renderer
	_sim = sim
	_select_all_player_units()

func handle_input(event: InputEvent) -> void:
	if _sim == null or _renderer == null:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_select_at_mouse(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_issue_move(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_S:
			_sim.enqueue_player_command("stop", selected_units)
		elif event.keycode == KEY_N:
			_sim.enqueue_player_command("produce", [], [], {"unit_type": "peasant"})

func _select_at_mouse(screen_pos: Vector2) -> void:
	var tile := _screen_to_tile(screen_pos)
	selected_units.clear()
	for id in range(_sim.units.alive.size()):
		if _sim.units.alive[id] and _sim.units.owner[id] == 0 and _sim.units.tile_x(id) == tile.x and _sim.units.tile_y(id) == tile.y:
			selected_units.append(id)
			break
	if selected_units.is_empty():
		_select_all_player_units()
	_renderer.set_selected_units(selected_units)

func _issue_move(screen_pos: Vector2) -> void:
	if selected_units.is_empty():
		return
	var tile := _screen_to_tile(screen_pos)
	var resource_type: String = _sim.map_state.resource_type_at(tile.x, tile.y)
	if resource_type == "wood" or resource_type == "stone":
		_sim.enqueue_player_command("gather", selected_units, [tile.x, tile.y])
	else:
		_sim.enqueue_player_command("move", selected_units, [tile.x, tile.y])

func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	var world := _camera.get_global_mouse_position()
	return Vector2i(clampi(int(world.x / _renderer.tile_size), 0, _sim.map_state.size_x - 1), clampi(int(world.y / _renderer.tile_size), 0, _sim.map_state.size_y - 1))

func _select_all_player_units() -> void:
	selected_units.clear()
	for id in range(_sim.units.alive.size()):
		if _sim.units.alive[id] and _sim.units.owner[id] == 0:
			selected_units.append(id)
