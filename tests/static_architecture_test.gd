extends SceneTree

func _init() -> void:
	var violations := []
	_scan_directory("res://sim", violations)
	if not violations.is_empty():
		for violation in violations:
			push_error(violation)
		quit(1)
		return
	print("Static architecture test passed")
	quit(0)

func _scan_directory(path: String, violations: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		violations.append("Cannot open directory: %s" % path)
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var child_path := "%s/%s" % [path, name]
		if dir.current_is_dir():
			_scan_directory(child_path, violations)
		elif name.ends_with(".gd"):
			_check_file(child_path, violations)
		name = dir.get_next()

func _check_file(path: String, violations: Array) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		violations.append("Cannot open file: %s" % path)
		return
	var text := file.get_as_text()
	if text.contains("res://game/"):
		violations.append("%s imports game layer from sim" % path)

