extends SceneTree

const AssetsManifestScript := preload("res://game/render/assets_manifest.gd")

func _init() -> void:
	var manifest: RefCounted = AssetsManifestScript.new()
	manifest.load_from_json("res://config/assets_manifest.json")
	for tile_name in ["grass", "forest", "stone", "water"]:
		if not manifest.data.get("tiles", {}).has(tile_name):
			push_error("Expected tile asset entry for %s" % tile_name)
			quit(1)
			return
	for unit_name in ["peasant", "warrior"]:
		var entry: Dictionary = manifest.data.get("units", {}).get(unit_name, {})
		if String(entry.get("source", "")) == "placeholder":
			push_error("Expected non-placeholder unit manifest source for %s" % unit_name)
			quit(1)
			return
		if not entry.has("animations"):
			push_error("Expected animation map for %s" % unit_name)
			quit(1)
			return
	for building_name in ["townhall", "farm", "barracks", "storehouse", "wall", "tower"]:
		var entry: Dictionary = manifest.data.get("buildings", {}).get(building_name, {})
		if not entry.has("states"):
			push_error("Expected building state map for %s" % building_name)
			quit(1)
			return
	var peasant_color: Color = manifest.unit_color("peasant", 0, Color.BLACK)
	if peasant_color == Color.BLACK:
		push_error("Expected manifest unit color to override fallback")
		quit(1)
		return
	print("Assets manifest test passed")
	quit(0)
