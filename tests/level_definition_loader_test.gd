extends SceneTree


func _initialize() -> void:
	var level := LevelDefinitionLoader.load_level("res://level-designs/levels/nivel-1.json")
	if level.is_empty():
		_fail("The saved level definition should load.")
		return
	if int(level.schemaVersion) != 3 or int(level.timeLimitSeconds) != 90:
		_fail("The loader should preserve schema version 3 and the 90 second limit.")
		return
	if level.rooms.size() != 4 or level.connections.size() != 3:
		_fail("The loader should preserve all rooms and connections.")
		return
	var second_level := LevelDefinitionLoader.load_level("res://level-designs/levels/nivel-2.json")
	if second_level.is_empty() or str(second_level.id) != "nivel-2":
		_fail("Nivel 2 should have a valid, unique level identity.")
		return
	if second_level.rooms.size() != 5 or second_level.connections.size() != 4:
		_fail("The loader should preserve Nivel 2 rooms and connections.")
		return
	var third_level := LevelDefinitionLoader.load_level("res://level-designs/levels/nivel-3.json")
	if third_level.is_empty() or str(third_level.id) != "nivel-3":
		_fail("Nivel 3 should have a valid identity matching the sequence catalog.")
		return
	if third_level.rooms.size() != 3 or third_level.connections.size() != 2:
		_fail("The loader should preserve Nivel 3 rooms and connections.")
		return
	print("Level definition loader test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
