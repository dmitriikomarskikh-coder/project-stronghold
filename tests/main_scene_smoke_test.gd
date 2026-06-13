extends SceneTree

func _init() -> void:
	var packed_scene: PackedScene = load("res://game/main.tscn")
	if packed_scene == null:
		push_error("Failed to load main scene")
		quit(1)
		return
	var instance := packed_scene.instantiate()
	if instance == null:
		push_error("Failed to instantiate main scene")
		quit(1)
		return
	root.add_child(instance)
	print("Main scene smoke test passed")
	quit(0)

