extends RefCounted

var data: Dictionary = {}
var _texture_cache: Dictionary = {}

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

func unit_sprite(type_name: String, owner_id: int) -> Dictionary:
	var owner_key := "player_%d" % owner_id
	return _sprite_at(["units", type_name, "sprites", owner_key])

func building_sprite(type_name: String, owner_id: int) -> Dictionary:
	var owner_key := "player_%d" % owner_id
	return _sprite_at(["buildings", type_name, "sprites", owner_key])

func _sprite_at(path: Array) -> Dictionary:
	var node = _value_at(path)
	if not node is Dictionary:
		return {}
	var source_path := String(node.get("path", ""))
	if source_path == "" or not ResourceLoader.exists(source_path):
		return {}
	var texture = _texture_for(source_path)
	if texture == null:
		return {}
	var region := Rect2(Vector2.ZERO, texture.get_size())
	var raw_region = node.get("region", [])
	if raw_region is Array and raw_region.size() == 4:
		region = Rect2(
			Vector2(float(raw_region[0]), float(raw_region[1])),
			Vector2(float(raw_region[2]), float(raw_region[3]))
		)
	return { "texture": texture, "region": region }

func _texture_for(path: String):
	if _texture_cache.has(path):
		return _texture_cache[path]
	var texture = load(path)
	if texture is Texture2D:
		_texture_cache[path] = texture
		return texture
	_texture_cache[path] = null
	return null

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
