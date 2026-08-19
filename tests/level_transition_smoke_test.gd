extends SceneTree

## Al pisar la ultima habitacion el nivel se cierra y, tras la pausa
## configurada, arranca el siguiente de la secuencia con el jugador en su
## habitacion de entrada.

const TRANSITION_DELAY := 0.25


func _initialize() -> void:
	create_timer(20.0, true, false, true).timeout.connect(func() -> void: _fail("Level transition smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	var sequence := root.get_node("LevelSequence")
	sequence.select_first_level()
	change_scene_to_file("res://scenes/levels/playable_level.tscn")
	await _wait_frames(8)
	var level := current_scene as PlayableLevel
	if level == null or str(level.level_data.id) != "nivel-1":
		_fail("The transition test should start on nivel-1.")
		return
	level.level_transition_delay = TRANSITION_DELAY

	level.player.global_position = Vector3(0.0, 1.0, 400.0)
	await _wait_frames(6)
	var last_room_id: String = level.room_order[level.room_order.size() - 1]
	level.player.global_position = (level.room_nodes[last_room_id] as Node3D).global_position + Vector3(0.0, 1.0, 0.0)
	await _wait_frames(6)
	if level.round_controller.is_running:
		_fail("Reaching the last room should close the round before the transition.")
		return
	if current_scene != level:
		_fail("The level should not change before the transition delay elapses.")
		return

	await create_timer(TRANSITION_DELAY + 0.2).timeout
	await _wait_frames(8)
	var next_level := current_scene as PlayableLevel
	if next_level == null or next_level == level:
		_fail("The transition should have loaded the next level scene.")
		return
	if str(next_level.level_data.id) != "nivel-2":
		_fail("The sequence should advance to nivel-2, not to '%s'." % next_level.level_data.get("id", "?"))
		return
	if sequence.get_position_text() != "2 / 5":
		_fail("The level sequence position should follow the automatic advance.")
		return
	if next_level.round_controller.is_running:
		_fail("The new level should arm its round on standby, not start it.")
		return

	var entrance_id: String = next_level.room_order[0]
	var entrance_center: Vector3 = (next_level.room_nodes[entrance_id] as Node3D).global_position
	var offset := Vector2(next_level.player.global_position.x - entrance_center.x, next_level.player.global_position.z - entrance_center.z)
	if offset.length() > 1.0:
		_fail("The player should respawn at the entrance of the next level.")
		return

	sequence.select_first_level()
	print("Level transition smoke test passed.")
	quit()


func _wait_frames(count: int) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
