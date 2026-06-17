extends RefCounted

var data: Dictionary = {}

func load_from_json(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		data = {}
		return
	var parsed = JSON.parse_string(text)
	data = parsed if parsed is Dictionary else {}

func tile_color(type_name: String, fallback: Color) -> Color:
	return _color_at(["tiles", type_name, "color"], fallback)

func unit_color(type_name: String, owner_id: int, fallback: Color) -> Color:
	var owner_key := "player_%d" % owner_id
	return _color_at(["units", type_name, "colors", owner_key], fallback)

func building_color(type_name: String, owner_id: int, fallback: Color) -> Color:
	var owner_key := "player_%d" % owner_id
	return _color_at(["buildings", type_name, "colors", owner_key], fallback)

func building_label(type_name: String) -> String:
	var node = _value_at(["buildings", type_name, "label"])
	if node is String and String(node) != "":
		return String(node)
	return type_name.substr(0, 2).to_upper()

func _color_at(path: Array, fallback: Color) -> Color:
	var node = _value_at(path)
	if not node is String:
		return fallback
	var value := String(node)
	if not value.begins_with("#"):
		return fallback
	return Color.html(value)

func _value_at(path: Array):
	var node = data
	for key in path:
		if not node is Dictionary or not node.has(key):
			return null
		node = node[key]
	return node
