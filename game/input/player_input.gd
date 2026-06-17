extends RefCounted

var selected_units: Array[int] = []
var selected_building_id := -1
var _camera: Camera2D
var _renderer
var _sim
var _feedback
var _attack_move_pending := false
var _build_mode := false
var _pending_building_type := "farm"
var _control_groups := {}
var _dragging_selection := false
var _drag_start_screen := Vector2.ZERO
var _drag_current_screen := Vector2.ZERO
var _drag_threshold := 6.0
var _build_hotkeys := {
	KEY_1: "farm",
	KEY_2: "barracks",
	KEY_3: "storehouse",
	KEY_4: "tower",
	KEY_5: "wall",
}

func setup(camera: Camera2D, renderer, sim, feedback = null) -> void:
	_camera = camera
	_renderer = renderer
	_sim = sim
	_feedback = feedback
	_select_all_player_units()

func handle_input(event: InputEvent) -> void:
	if _sim == null or _renderer == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_mouse(event)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_issue_move(event.position)
	elif event is InputEventMouseMotion and _dragging_selection:
		_drag_current_screen = event.position
		_renderer.set_selection_rect(_screen_rect(_drag_start_screen, _drag_current_screen))
	elif event is InputEventKey and event.pressed and not event.echo:
		if _is_number_key(event.keycode) and event.ctrl_pressed:
			store_control_group(_number_key_index(event.keycode))
		elif _is_number_key(event.keycode) and not _build_mode:
			recall_control_group(_number_key_index(event.keycode))
		elif event.keycode == KEY_S:
			_sim.enqueue_player_command("stop", selected_units)
		elif event.keycode == KEY_N:
			_issue_produce()
		elif event.keycode == KEY_C:
			_issue_cancel_production()
		elif event.keycode == KEY_A:
			_attack_move_pending = true
		elif event.keycode == KEY_H:
			_toggle_hold_stance()
		elif event.keycode == KEY_F:
			_sim.enqueue_player_command("form_up", selected_units)
		elif event.keycode == KEY_B:
			_build_mode = true
			_attack_move_pending = false
		elif _build_mode and _build_hotkeys.has(event.keycode):
			_pending_building_type = String(_build_hotkeys[event.keycode])
		elif event.keycode == KEY_ESCAPE:
			_build_mode = false
			_attack_move_pending = false

func _handle_left_mouse(event: InputEventMouseButton) -> void:
	if event.pressed:
		if _build_mode:
			_place_building(event.position)
			return
		_dragging_selection = true
		_drag_start_screen = event.position
		_drag_current_screen = event.position
		return
	if not _dragging_selection:
		return
	_dragging_selection = false
	_renderer.set_selection_rect(Rect2())
	if _drag_start_screen.distance_to(event.position) >= _drag_threshold:
		_select_tile_rect(_screen_to_tile_from_position(_drag_start_screen), _screen_to_tile_from_position(event.position), event.shift_pressed)
	else:
		_select_at_mouse(event.position, event.shift_pressed, event.double_click)

func _select_at_mouse(screen_pos: Vector2, additive: bool = false, double_click: bool = false) -> void:
	var tile := _screen_to_tile(screen_pos)
	var clicked_unit := _own_unit_at_tile(tile)
	if clicked_unit >= 0:
		if double_click:
			_select_same_type_near(clicked_unit, tile, additive)
		else:
			_select_unit(clicked_unit, additive)
		_renderer.set_selected_units(selected_units)
		_renderer.set_selected_building(selected_building_id)
		_play_select_feedback()
		return
	var building_id := _own_completed_building_at_tile(tile)
	if building_id >= 0:
		_select_building(building_id, additive)
		_play_select_feedback()
		return
	if not additive:
		selected_units.clear()
		selected_building_id = -1
	_renderer.set_selected_units(selected_units)
	_renderer.set_selected_building(selected_building_id)
	if not selected_units.is_empty():
		_play_select_feedback()

func _select_unit(unit_id: int, additive: bool = false) -> void:
	if not additive:
		selected_units.clear()
		selected_building_id = -1
	if not selected_units.has(unit_id):
		selected_units.append(unit_id)

func _select_building(building_id: int, additive: bool = false) -> void:
	if not additive:
		selected_units.clear()
	selected_building_id = building_id
	_renderer.set_selected_units(selected_units)
	_renderer.set_selected_building(selected_building_id)

func _select_tile_rect(a: Vector2i, b: Vector2i, additive: bool = false) -> void:
	select_units_in_tile_rect(a, b, additive)
	_renderer.set_selected_units(selected_units)
	_renderer.set_selected_building(selected_building_id)

func select_units_in_tile_rect(a: Vector2i, b: Vector2i, additive: bool = false) -> void:
	var min_x: int = mini(a.x, b.x)
	var max_x: int = maxi(a.x, b.x)
	var min_y: int = mini(a.y, b.y)
	var max_y: int = maxi(a.y, b.y)
	if not additive:
		selected_units.clear()
		selected_building_id = -1
	for id in range(_sim.units.alive.size()):
		if _sim.units.alive[id] and _sim.units.owner[id] == 0 and _sim.units.tile_x(id) >= min_x and _sim.units.tile_x(id) <= max_x and _sim.units.tile_y(id) >= min_y and _sim.units.tile_y(id) <= max_y:
			if not selected_units.has(id):
				selected_units.append(id)

func _select_same_type_near(unit_id: int, tile: Vector2i, additive: bool = false) -> void:
	if not additive:
		selected_units.clear()
		selected_building_id = -1
	var type_name: String = _sim.units.unit_type[unit_id]
	for id in range(_sim.units.alive.size()):
		if _sim.units.alive[id] and _sim.units.owner[id] == 0 and _sim.units.unit_type[id] == type_name:
			var dist: int = absi(_sim.units.tile_x(id) - tile.x) + absi(_sim.units.tile_y(id) - tile.y)
			if dist <= 16 and not selected_units.has(id):
				selected_units.append(id)

func _own_unit_at_tile(tile: Vector2i) -> int:
	for id in range(_sim.units.alive.size()):
		if _sim.units.alive[id] and _sim.units.owner[id] == 0 and _sim.units.tile_x(id) == tile.x and _sim.units.tile_y(id) == tile.y:
			return id
	return -1

func _issue_move(screen_pos: Vector2) -> void:
	if selected_units.is_empty():
		return
	var tile := _screen_to_tile(screen_pos)
	var own_frame_id := _own_incomplete_building_at_tile(tile)
	if own_frame_id >= 0:
		_sim.enqueue_player_entity_command("build_assign", selected_units, own_frame_id)
		_play_command_feedback()
		_attack_move_pending = false
		_build_mode = false
		return
	var enemy_id := _enemy_unit_at_tile(tile)
	if enemy_id >= 0:
		_sim.enqueue_player_entity_command("attack_target", selected_units, enemy_id)
		_play_command_feedback()
		_attack_move_pending = false
		return
	var enemy_building_id := _enemy_building_at_tile(tile)
	if enemy_building_id >= 0:
		_sim.enqueue_player_entity_command("attack_target", selected_units, enemy_building_id, {"target_kind": "building"})
		_play_command_feedback()
		_attack_move_pending = false
		return
	if _attack_move_pending:
		_sim.enqueue_player_command("attack_move", selected_units, [tile.x, tile.y])
		_play_command_feedback()
		_attack_move_pending = false
		return
	var resource_type: String = _sim.map_state.resource_type_at(tile.x, tile.y)
	if resource_type == "wood" or resource_type == "stone":
		_sim.enqueue_player_command("gather", selected_units, [tile.x, tile.y])
	else:
		_sim.enqueue_player_command("move", selected_units, [tile.x, tile.y])
	_play_command_feedback()

func _place_building(screen_pos: Vector2) -> void:
	var tile := _screen_to_tile(screen_pos)
	_sim.enqueue_player_command("build_place", [], [tile.x, tile.y], {"building_type": _pending_building_type})
	_play_command_feedback()
	_build_mode = false

func build_mode_enabled() -> bool:
	return _build_mode

func pending_building_type() -> String:
	return _pending_building_type

func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	return _screen_to_tile_from_position(screen_pos)

func _screen_to_tile_from_position(screen_pos: Vector2) -> Vector2i:
	var world := _camera.get_global_mouse_position()
	if _camera != null and _camera.get_viewport() != null:
		world = _camera.get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	return Vector2i(clampi(int(world.x / _renderer.tile_size), 0, _sim.map_state.size_x - 1), clampi(int(world.y / _renderer.tile_size), 0, _sim.map_state.size_y - 1))

func _screen_rect(a: Vector2, b: Vector2) -> Rect2:
	var min_pos := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var max_pos := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	return Rect2(min_pos, max_pos - min_pos)

func _enemy_unit_at_tile(tile: Vector2i) -> int:
	for id in range(_sim.units.alive.size()):
		if _sim.units.alive[id] and _sim.units.owner[id] != 0 and _sim.units.tile_x(id) == tile.x and _sim.units.tile_y(id) == tile.y and _sim.fog.is_visible(0, tile.x, tile.y):
			return id
	return -1

func _enemy_building_at_tile(tile: Vector2i) -> int:
	for id in range(_sim.buildings.alive.size()):
		if not _sim.buildings.alive[id] or _sim.buildings.owner[id] == 0:
			continue
		if not _sim.buildings.is_known_by(0, id):
			continue
		var footprint: Array = _sim.balance["buildings"][_sim.buildings.building_type[id]]["footprint"]
		var inside_x: bool = tile.x >= _sim.buildings.anchor_x[id] and tile.x < _sim.buildings.anchor_x[id] + int(footprint[0])
		var inside_y: bool = tile.y >= _sim.buildings.anchor_y[id] and tile.y < _sim.buildings.anchor_y[id] + int(footprint[1])
		if inside_x and inside_y:
			return id
	return -1

func _own_incomplete_building_at_tile(tile: Vector2i) -> int:
	for id in range(_sim.buildings.alive.size()):
		if not _sim.buildings.alive[id] or _sim.buildings.owner[id] != 0 or _sim.buildings.completed[id]:
			continue
		var footprint: Array = _sim.balance["buildings"][_sim.buildings.building_type[id]]["footprint"]
		var inside_x: bool = tile.x >= _sim.buildings.anchor_x[id] and tile.x < _sim.buildings.anchor_x[id] + int(footprint[0])
		var inside_y: bool = tile.y >= _sim.buildings.anchor_y[id] and tile.y < _sim.buildings.anchor_y[id] + int(footprint[1])
		if inside_x and inside_y:
			return id
	return -1

func _own_completed_building_at_tile(tile: Vector2i) -> int:
	for id in range(_sim.buildings.alive.size()):
		if not _sim.buildings.alive[id] or _sim.buildings.owner[id] != 0 or not _sim.buildings.completed[id]:
			continue
		var footprint: Array = _sim.balance["buildings"][_sim.buildings.building_type[id]]["footprint"]
		var inside_x: bool = tile.x >= _sim.buildings.anchor_x[id] and tile.x < _sim.buildings.anchor_x[id] + int(footprint[0])
		var inside_y: bool = tile.y >= _sim.buildings.anchor_y[id] and tile.y < _sim.buildings.anchor_y[id] + int(footprint[1])
		if inside_x and inside_y:
			return id
	return -1

func _issue_produce() -> void:
	var building_id := _valid_selected_building()
	if building_id >= 0:
		var building_type: String = _sim.buildings.building_type[building_id]
		var unit_type := "warrior" if building_type == "barracks" else "peasant"
		_sim.enqueue_player_entity_command("produce", [], building_id, {"unit_type": unit_type})
		_play_command_feedback()
		return
	_sim.enqueue_player_command("produce", [], [], {"unit_type": "peasant"})
	_play_command_feedback()

func _issue_cancel_production() -> void:
	var building_id := _valid_selected_building()
	if building_id >= 0:
		_sim.enqueue_player_entity_command("cancel_production", [], building_id)
		_play_command_feedback()

func _valid_selected_building() -> int:
	if selected_building_id < 0 or selected_building_id >= _sim.buildings.alive.size():
		return -1
	if not _sim.buildings.alive[selected_building_id] or _sim.buildings.owner[selected_building_id] != 0 or not _sim.buildings.completed[selected_building_id]:
		selected_building_id = -1
		return -1
	return selected_building_id

func _toggle_hold_stance() -> void:
	if selected_units.is_empty():
		return
	var any_not_hold := false
	for id in selected_units:
		if _sim.units.alive[id] and _sim.units.stance[id] != "hold":
			any_not_hold = true
			break
	var stance := "hold" if any_not_hold else "defense"
	_sim.enqueue_player_command("set_stance", selected_units, [], {"stance": stance})

func _select_all_player_units() -> void:
	selected_units.clear()
	selected_building_id = -1
	for id in range(_sim.units.alive.size()):
		if _sim.units.alive[id] and _sim.units.owner[id] == 0:
			selected_units.append(id)

func _play_command_feedback() -> void:
	if _feedback != null and _feedback.has_method("play_command"):
		_feedback.play_command()

func _play_select_feedback() -> void:
	if _feedback != null and _feedback.has_method("play_select"):
		_feedback.play_select()

func store_control_group(index: int) -> void:
	var group: Array[int] = []
	for unit_id in selected_units:
		group.append(int(unit_id))
	_control_groups[index] = group

func recall_control_group(index: int) -> void:
	selected_units.clear()
	selected_building_id = -1
	if not _control_groups.has(index):
		_renderer.set_selected_units(selected_units)
		_renderer.set_selected_building(selected_building_id)
		return
	var group: Array = _control_groups[index]
	for unit_id in group:
		var id := int(unit_id)
		if id >= 0 and id < _sim.units.alive.size() and _sim.units.alive[id] and _sim.units.owner[id] == 0:
			selected_units.append(id)
	_renderer.set_selected_units(selected_units)
	_renderer.set_selected_building(selected_building_id)

func _is_number_key(keycode: Key) -> bool:
	return keycode >= KEY_1 and keycode <= KEY_9

func _number_key_index(keycode: Key) -> int:
	return int(keycode - KEY_0)
