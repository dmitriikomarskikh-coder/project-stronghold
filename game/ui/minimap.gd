extends Control

var sim
var camera: Camera2D
var player_input
var viewer_player_id := 0

func setup(sim_state, camera_node: Camera2D, input_controller, player_id: int = 0) -> void:
	sim = sim_state
	camera = camera_node
	player_input = input_controller
	viewer_player_id = player_id
	queue_redraw()

func _draw() -> void:
	if sim == null or sim.map_state == null:
		return
	var cell := size / Vector2(sim.map_state.size_x, sim.map_state.size_y)
	for y in range(sim.map_state.size_y):
		for x in range(sim.map_state.size_x):
			var color := _tile_color(sim.map_state.tile_type_at(x, y))
			if not sim.fog.is_explored(viewer_player_id, x, y):
				color = Color(0.0, 0.0, 0.0)
			elif not sim.fog.is_visible(viewer_player_id, x, y):
				color = color.darkened(0.55)
			draw_rect(Rect2(Vector2(x, y) * cell, cell), color)
	_draw_building_points(cell)
	_draw_unit_points(cell)
	_draw_attack_flash(cell)
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, false, 1.0)

func _gui_input(event: InputEvent) -> void:
	if sim == null or camera == null:
		return
	if event is InputEventMouseButton and event.pressed:
		var tile := _event_tile(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			camera.global_position = Vector2(tile.x + 0.5, tile.y + 0.5) * 32.0
		elif event.button_index == MOUSE_BUTTON_RIGHT and player_input != null and not player_input.selected_units.is_empty():
			sim.enqueue_player_command("move", player_input.selected_units, [tile.x, tile.y])

func _event_tile(position: Vector2) -> Vector2i:
	var x := clampi(int(position.x / max(1.0, size.x) * sim.map_state.size_x), 0, sim.map_state.size_x - 1)
	var y := clampi(int(position.y / max(1.0, size.y) * sim.map_state.size_y), 0, sim.map_state.size_y - 1)
	return Vector2i(x, y)

func _draw_unit_points(cell: Vector2) -> void:
	for id in range(sim.units.alive.size()):
		if not sim.units.alive[id]:
			continue
		var tile := Vector2i(sim.units.tile_x(id), sim.units.tile_y(id))
		if sim.units.owner[id] != viewer_player_id and not sim.fog.is_visible(viewer_player_id, tile.x, tile.y):
			continue
		var color := Color(0.85, 0.95, 0.55) if sim.units.owner[id] == viewer_player_id else Color(0.95, 0.25, 0.25)
		draw_rect(Rect2(Vector2(tile) * cell, Vector2(max(1.0, cell.x), max(1.0, cell.y))), color)

func _draw_building_points(cell: Vector2) -> void:
	for id in range(sim.buildings.alive.size()):
		if not sim.buildings.alive[id]:
			continue
		if sim.buildings.owner[id] != viewer_player_id and not sim.buildings.is_known_by(viewer_player_id, id):
			continue
		var tile := Vector2i(sim.buildings.anchor_x[id], sim.buildings.anchor_y[id])
		var color := Color(0.25, 0.75, 1.0) if sim.buildings.owner[id] == viewer_player_id else Color(1.0, 0.25, 0.25)
		if sim.buildings.owner[id] != viewer_player_id and not sim.fog.is_visible(viewer_player_id, tile.x, tile.y):
			color.a = 0.45
		draw_rect(Rect2(Vector2(tile) * cell, cell * 2.0), color)

func _draw_attack_flash(cell: Vector2) -> void:
	if sim.tick - sim.last_attack_tick[viewer_player_id] > 100:
		return
	var tile := Vector2i(sim.last_attack_x[viewer_player_id], sim.last_attack_y[viewer_player_id])
	if tile.x < 0:
		return
	var rect := Rect2(Vector2(tile) * cell - cell * 2.0, cell * 5.0)
	var alpha := 0.45 + 0.35 * float((sim.tick / 5) % 2)
	draw_rect(rect, Color(1.0, 0.08, 0.05, alpha), false, 2.0)

func _tile_color(tile_type: int) -> Color:
	match tile_type:
		0:
			return Color(0.18, 0.43, 0.18)
		1:
			return Color(0.04, 0.22, 0.08)
		2:
			return Color(0.38, 0.38, 0.40)
		3:
			return Color(0.08, 0.20, 0.48)
		_:
			return Color(0.18, 0.43, 0.18)
