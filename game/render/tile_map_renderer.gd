extends Node2D

const Tile := preload("res://sim/map.gd")
const AssetsManifest := preload("res://game/render/assets_manifest.gd")

var tile_size := 32
var tile_names := {
	Tile.TileType.GRASS: "grass",
	Tile.TileType.FOREST: "forest",
	Tile.TileType.STONE: "stone",
	Tile.TileType.WATER: "water",
}
var fallback_tile_colors := {
	"grass": Color(0.22, 0.55, 0.22),
	"forest": Color(0.05, 0.28, 0.11),
	"stone": Color(0.45, 0.45, 0.48),
	"water": Color(0.10, 0.30, 0.62),
}
var fallback_unit_colors := {
	0: Color(0.92, 0.86, 0.58),
	1: Color(0.78, 0.30, 0.30),
}
var fallback_building_colors := {
	0: Color(0.55, 0.42, 0.22),
	1: Color(0.44, 0.25, 0.25),
}
var map_state
var buildings
var units
var platoons
var fog
var assets_manifest
var viewer_player_id := 0
var balance := {}
var selected_units: Array[int] = []
var selected_building_id := -1
var selection_rect := Rect2()

func _init() -> void:
	assets_manifest = AssetsManifest.new()
	assets_manifest.load_from_json("res://config/assets_manifest.json")

func draw_map(state: Tile) -> void:
	map_state = state
	queue_redraw()

func draw_state(state, buildings_state, units_state, balance_config: Dictionary) -> void:
	map_state = state
	buildings = buildings_state
	units = units_state
	balance = balance_config
	queue_redraw()

func set_platoons(platoons_state) -> void:
	platoons = platoons_state
	queue_redraw()

func set_fog(fog_state, player_id: int = 0) -> void:
	fog = fog_state
	viewer_player_id = player_id
	queue_redraw()

func set_selected_units(ids: Array) -> void:
	selected_units = []
	for id in ids:
		selected_units.append(int(id))
	queue_redraw()

func set_selected_building(id: int) -> void:
	selected_building_id = id
	queue_redraw()

func set_selection_rect(rect: Rect2) -> void:
	selection_rect = rect
	queue_redraw()

func _draw() -> void:
	if map_state == null:
		return
	for y in range(map_state.size_y):
		for x in range(map_state.size_x):
			var tile_type: int = map_state.tile_type_at(x, y)
			var tile_name: String = tile_names.get(tile_type, "grass")
			draw_rect(Rect2(x * tile_size, y * tile_size, tile_size, tile_size), assets_manifest.tile_color(tile_name, fallback_tile_colors[tile_name]))
	_draw_buildings()
	_draw_units()
	_draw_fog_overlay()
	_draw_selection_rect()
	draw_rect(Rect2(Vector2.ZERO, Vector2(map_state.size_x, map_state.size_y) * tile_size), Color.BLACK, false, 2.0)

func _draw_buildings() -> void:
	if buildings == null:
		return
	for id in range(buildings.alive.size()):
		if not buildings.alive[id]:
			continue
		var visible: bool = _building_visible(id)
		if buildings.owner[id] != viewer_player_id and not visible:
			if buildings.is_known_by(viewer_player_id, id):
				_draw_building(id, true)
			continue
		_draw_building(id, false)

func _draw_building(id: int, ghost: bool) -> void:
	var type_name: String = buildings.building_type[id]
	var footprint := _building_footprint(type_name)
	var rect := Rect2(
		buildings.anchor_x[id] * tile_size,
		buildings.anchor_y[id] * tile_size,
		footprint.x * tile_size,
		footprint.y * tile_size
	)
	var owner_id: int = buildings.owner[id]
	var color: Color = assets_manifest.building_color(type_name, owner_id, fallback_building_colors.get(owner_id, Color(0.44, 0.25, 0.25)))
	if ghost:
		color.a = 0.38
	draw_rect(rect, color)
	draw_rect(rect, Color.BLACK, false, 2.0)
	if selected_building_id == id:
		draw_rect(rect.grow(3.0), Color(0.2, 1.0, 0.2), false, 3.0)
	var text_color := Color.WHITE
	if ghost:
		text_color.a = 0.55
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, 14), assets_manifest.building_label(type_name), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_color)
	if not ghost:
		_draw_building_hp_bar(id, rect)

func _draw_units() -> void:
	if units == null:
		return
	for id in range(units.alive.size()):
		if not units.alive[id]:
			continue
		if units.owner[id] != viewer_player_id and not _tile_visible(units.tile_x(id), units.tile_y(id)):
			continue
		var pos := Vector2(units.pos_x[id], units.pos_y[id]) / 256.0 * tile_size
		var offset := _subslot_offset(units.subslot[id])
		var owner_id: int = units.owner[id]
		var color: Color = assets_manifest.unit_color(units.unit_type[id], owner_id, fallback_unit_colors.get(owner_id, Color(0.78, 0.30, 0.30)))
		draw_circle(pos + Vector2(tile_size * 0.5, tile_size * 0.5) + offset, 7.0, color)
		draw_circle(pos + Vector2(tile_size * 0.5, tile_size * 0.5) + offset, 7.0, Color.BLACK, false, 1.0)
		if _unit_platoon_broken(id):
			var marker_center := pos + Vector2(tile_size * 0.5, tile_size * 0.5) + offset
			draw_line(marker_center + Vector2(-8, -8), marker_center + Vector2(8, 8), Color(1.0, 0.55, 0.05), 2.0)
			draw_line(marker_center + Vector2(8, -8), marker_center + Vector2(-8, 8), Color(1.0, 0.55, 0.05), 2.0)
		if selected_units.has(id):
			draw_arc(pos + Vector2(tile_size * 0.5, tile_size * 0.5) + offset, 11.0, 0.0, TAU, 32, Color(0.2, 1.0, 0.2), 2.0)
		if selected_units.has(id) or _unit_is_damaged(id) or units.owner[id] != viewer_player_id:
			_draw_unit_hp_bar(id, pos + offset)

func _subslot_offset(slot: int) -> Vector2:
	var spread := tile_size * 0.18
	if slot == 0:
		return Vector2(-spread, -spread)
	if slot == 1:
		return Vector2(spread, -spread)
	if slot == 2:
		return Vector2(-spread, spread)
	return Vector2(spread, spread)

func _building_footprint(type_name: String) -> Vector2i:
	if balance.has("buildings") and balance["buildings"].has(type_name):
		var footprint: Array = balance["buildings"][type_name]["footprint"]
		return Vector2i(int(footprint[0]), int(footprint[1]))
	return Vector2i.ONE

func _draw_unit_hp_bar(id: int, pos: Vector2) -> void:
	var max_hp := int(balance["units"][units.unit_type[id]].get("hp", max(1, units.hp[id])))
	_draw_hp_bar(Rect2(pos + Vector2(6, -5), Vector2(20, 3)), units.hp[id], max_hp)

func _draw_building_hp_bar(id: int, rect: Rect2) -> void:
	var max_hp := int(balance["buildings"][buildings.building_type[id]].get("hp", max(1, buildings.hp[id])))
	if buildings.hp[id] >= max_hp and buildings.owner[id] == viewer_player_id:
		return
	_draw_hp_bar(Rect2(rect.position + Vector2(2, -6), Vector2(max(18.0, rect.size.x - 4.0), 4)), buildings.hp[id], max_hp)

func _draw_hp_bar(rect: Rect2, current_hp: int, max_hp: int) -> void:
	var clamped_hp: int = clampi(current_hp, 0, max(1, max_hp))
	var ratio := float(clamped_hp) / float(max(1, max_hp))
	draw_rect(rect, Color(0.05, 0.05, 0.05, 0.85))
	draw_rect(Rect2(rect.position + Vector2.ONE, Vector2(max(0.0, (rect.size.x - 2.0) * ratio), max(1.0, rect.size.y - 2.0))), Color(0.1, 0.85, 0.25))

func _unit_is_damaged(id: int) -> bool:
	if not balance.has("units") or not balance["units"].has(units.unit_type[id]):
		return false
	return units.hp[id] < int(balance["units"][units.unit_type[id]].get("hp", units.hp[id]))

func _unit_platoon_broken(id: int) -> bool:
	if platoons == null or id < 0 or id >= units.alive.size():
		return false
	var platoon_id: int = units.platoon_id[id]
	return platoon_id >= 0 and platoon_id < platoons.alive.size() and platoons.alive[platoon_id] and platoons.broken[platoon_id]

func _draw_fog_overlay() -> void:
	if fog == null:
		return
	for y in range(map_state.size_y):
		for x in range(map_state.size_x):
			var rect := Rect2(x * tile_size, y * tile_size, tile_size, tile_size)
			if not fog.is_explored(viewer_player_id, x, y):
				draw_rect(rect, Color(0.0, 0.0, 0.0, 0.82))
			elif not fog.is_visible(viewer_player_id, x, y):
				draw_rect(rect, Color(0.0, 0.0, 0.0, 0.42))

func _draw_selection_rect() -> void:
	if selection_rect.size.x < 1.0 or selection_rect.size.y < 1.0:
		return
	var transform := get_viewport().get_canvas_transform().affine_inverse()
	var a: Vector2 = transform * selection_rect.position
	var b: Vector2 = transform * (selection_rect.position + selection_rect.size)
	var world_rect := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(a.x - b.x), absf(a.y - b.y)))
	draw_rect(world_rect, Color(0.2, 0.85, 1.0, 0.12))
	draw_rect(world_rect, Color(0.2, 0.85, 1.0, 0.95), false, 2.0)

func _building_visible(id: int) -> bool:
	if fog == null:
		return true
	var footprint := _building_footprint(buildings.building_type[id])
	for y in range(buildings.anchor_y[id], buildings.anchor_y[id] + footprint.y):
		for x in range(buildings.anchor_x[id], buildings.anchor_x[id] + footprint.x):
			if _tile_visible(x, y):
				return true
	return false

func _tile_visible(x: int, y: int) -> bool:
	if fog == null:
		return true
	return fog.is_visible(viewer_player_id, x, y)
