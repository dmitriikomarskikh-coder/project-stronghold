extends SceneTree

func _init() -> void:
	var packed_scene: PackedScene = load("res://game/main.tscn")
	if packed_scene == null:
		push_error("Failed to load main scene")
		quit(1)
		return
	var instance := packed_scene.instantiate()
	root.add_child(instance)
	await process_frame
	var minimap_host: Node = instance.get_node_or_null("CanvasLayer/Hud/Minimap")
	if minimap_host == null or minimap_host.get_child_count() == 0:
		push_error("Expected minimap to be attached under HUD")
		quit(1)
		return
	print("Minimap smoke test passed")
	quit(0)
