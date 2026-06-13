extends Node2D

const Tile := preload("res://sim/map.gd")

var tile_size := 32
var colors := {
	Tile.TileType.GRASS: Color(0.22, 0.55, 0.22),
	Tile.TileType.FOREST: Color(0.05, 0.28, 0.11),
	Tile.TileType.STONE: Color(0.45, 0.45, 0.48),
	Tile.TileType.WATER: Color(0.10, 0.30, 0.62),
}
var map_state
var buildings
var units
var balance := {}

func draw_map(state: Tile) -> void:
	map_state = state
	queue_redraw()

func draw_state(state, buildings_state, units_state, balance_config: Dictionary) -> void:
	map_state = state
	buildings = buildings_state
	units = units_state
	balance = balance_config
	queue_redraw()

func _draw() -> void:
	if map_state == null:
		return
	for y in range(map_state.size_y):
		for x in range(map_state.size_x):
			var tile_type: int = map_state.tile_type_at(x, y)
			draw_rect(Rect2(x * tile_size, y * tile_size, tile_size, tile_size), colors[tile_type])
	_draw_buildings()
	_draw_units()
	draw_rect(Rect2(Vector2.ZERO, Vector2(map_state.size_x, map_state.size_y) * tile_size), Color.BLACK, false, 2.0)

func _draw_buildings() -> void:
	if buildings == null:
		return
	for id in range(buildings.alive.size()):
		if not buildings.alive[id]:
			continue
		var type_name: String = buildings.building_type[id]
		var footprint := _building_footprint(type_name)
		var rect := Rect2(
			buildings.anchor_x[id] * tile_size,
			buildings.anchor_y[id] * tile_size,
			footprint.x * tile_size,
			footprint.y * tile_size
		)
		var color := Color(0.55, 0.42, 0.22) if buildings.owner[id] == 0 else Color(0.44, 0.25, 0.25)
		draw_rect(rect, color)
		draw_rect(rect, Color.BLACK, false, 2.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, 14), type_name.substr(0, 2).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

func _draw_units() -> void:
	if units == null:
		return
	for id in range(units.alive.size()):
		if not units.alive[id]:
			continue
		var pos := Vector2(units.pos_x[id], units.pos_y[id]) / 256.0 * tile_size
		var color := Color(0.92, 0.86, 0.58) if units.owner[id] == 0 else Color(0.78, 0.30, 0.30)
		draw_circle(pos + Vector2(tile_size * 0.5, tile_size * 0.5), 7.0, color)
		draw_circle(pos + Vector2(tile_size * 0.5, tile_size * 0.5), 7.0, Color.BLACK, false, 1.0)

func _building_footprint(type_name: String) -> Vector2i:
	if balance.has("buildings") and balance["buildings"].has(type_name):
		var footprint: Array = balance["buildings"][type_name]["footprint"]
		return Vector2i(int(footprint[0]), int(footprint[1]))
	return Vector2i.ONE
