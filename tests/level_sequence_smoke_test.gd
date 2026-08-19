extends SceneTree


func _initialize() -> void:
	create_timer(8.0, true, false, true).timeout.connect(func() -> void: _fail("Level sequence smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	var sequence = root.get_node("LevelSequence")
	if sequence.get_level_count() != 5:
		_fail("The level catalog should contain Nivel 1 through Nivel 4 plus the window test level.")
		return
	sequence.select_first_level()
	change_scene_to_file("res://scenes/levels/playable_level.tscn")
	await _wait_for_scene()
	var first_level := current_scene as PlayableLevel
	if first_level == null or str(first_level.level_data.id) != "nivel-1" or first_level.level_data.rooms.size() != 4:
		_fail("The sequence should start at Nivel 1.")
		return
	_send_key(KEY_F7)
	await _wait_for_scene()
	var second_level := current_scene as PlayableLevel
	if second_level == null or str(second_level.level_data.id) != "nivel-2" or second_level.level_data.rooms.size() != 5:
		_fail("F7 should load Nivel 2 without evaluating victory conditions.")
		return
	if sequence.get_position_text() != "2 / 5":
		_fail("The sequence position should reflect the second level.")
		return
	_send_key(KEY_F7)
	await _wait_for_scene()
	var third_level := current_scene as PlayableLevel
	if third_level == null or str(third_level.level_data.id) != "nivel-3" or third_level.level_data.rooms.size() != 3:
		_fail("F7 should continue from Nivel 2 to Nivel 3.")
		return
	_send_key(KEY_F7)
	await _wait_for_scene()
	var fourth_level := current_scene as PlayableLevel
	if fourth_level == null or str(fourth_level.level_data.id) != "nivel-4" or fourth_level.level_data.rooms.size() != 3:
		_fail("F7 should continue from Nivel 3 to Nivel 4.")
		return
	_send_key(KEY_F8)
	await _wait_for_scene()
	var returned_level := current_scene as PlayableLevel
	if returned_level == null or str(returned_level.level_data.id) != "nivel-3":
		_fail("F8 should return from Nivel 4 to Nivel 3.")
		return
	sequence.select_first_level()
	print("Level sequence smoke test passed.")
	quit()


func _send_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)


func _wait_for_scene() -> void:
	for _frame in 5:
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
