extends RefCounted

enum TileType { GRASS, FOREST, STONE, WATER }

var size_x := 0
var size_y := 0
var tiles: PackedInt32Array = PackedInt32Array()
var resource_amount: PackedInt32Array = PackedInt32Array()
var players := {}

func load_from_json(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open map: %s" % path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid map JSON: %s" % path)
		return
	size_x = int(parsed["size"][0])
	size_y = int(parsed["size"][1])
	tiles.resize(size_x * size_y)
	resource_amount.resize(size_x * size_y)
	players = parsed.get("players", {})

	var rows: Array = parsed.get("tiles", [])
	if rows.is_empty():
		rows = _generate_default_rows(parsed.get("regions", []))
	for y in range(size_y):
		var row := String(rows[y])
		for x in range(size_x):
			var type := _char_to_tile(row.substr(x, 1))
			var i := index(x, y)
			tiles[i] = type
			resource_amount[i] = _default_resource(type)

func index(x: int, y: int) -> int:
	return y * size_x + x

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size_x and y < size_y

func tile_type_at(x: int, y: int) -> int:
	return tiles[index(x, y)]

func resource_type_at(x: int, y: int) -> String:
	match tile_type_at(x, y):
		TileType.FOREST:
			return "wood"
		TileType.STONE:
			return "stone"
		_:
			return ""

func resource_left_at(x: int, y: int) -> int:
	return resource_amount[index(x, y)]

func take_resource(x: int, y: int, amount: int) -> int:
	var i := index(x, y)
	var taken: int = min(resource_amount[i], amount)
	resource_amount[i] -= taken
	if resource_amount[i] <= 0 and (tiles[i] == TileType.FOREST or tiles[i] == TileType.STONE):
		tiles[i] = TileType.GRASS
		resource_amount[i] = 0
	return taken

func is_walkable(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	return tile_type_at(x, y) == TileType.GRASS

func _char_to_tile(ch: String) -> int:
	match ch:
		"F":
			return TileType.FOREST
		"S":
			return TileType.STONE
		"W":
			return TileType.WATER
		_:
			return TileType.GRASS

func _default_resource(type: int) -> int:
	match type:
		TileType.FOREST:
			return 400
		TileType.STONE:
			return 600
		_:
			return 0

func _generate_default_rows(regions: Array) -> Array:
	var rows := []
	for y in range(size_y):
		rows.append(_make_row("."))
	for region in regions:
		var ch := String(region.get("tile", "."))
		var rect: Array = region.get("rect", [0, 0, 0, 0])
		var x0 := int(rect[0])
		var y0 := int(rect[1])
		var w := int(rect[2])
		var h := int(rect[3])
		for y in range(y0, min(y0 + h, size_y)):
			var chars := []
			for x in range(size_x):
				chars.append(String(rows[y]).substr(x, 1))
			for x in range(x0, min(x0 + w, size_x)):
				chars[x] = ch
			rows[y] = "".join(chars)
	return rows

func _make_row(ch: String) -> String:
	var row := ""
	for _i in range(size_x):
		row += ch
	return row
