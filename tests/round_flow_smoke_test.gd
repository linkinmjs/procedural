extends SceneTree

## El cronometro de la ronda no corre mientras el jugador sigue en la primera
## habitacion, arranca al salir de ella y se detiene al pisar la ultima.

var _ended_reason := ""


func _initialize() -> void:
	create_timer(15.0, true, false, true).timeout.connect(func() -> void: _fail("Round flow smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	root.get_node("LevelSequence").select_first_level()
	change_scene_to_file("res://scenes/levels/playable_level.tscn")
	await _wait_frames(8)
	var level := current_scene as PlayableLevel
	if level == null or level.level_data.is_empty():
		_fail("The playable level did not load.")
		return
	if level.room_order.size() != 4:
		_fail("The four rooms of nivel-1 should chain from Entrada to Salida.")
		return
	var first_room: Dictionary = _room_by_id(level, level.room_order[0])
	var last_room: Dictionary = _room_by_id(level, level.room_order[level.room_order.size() - 1])
	if str(first_room.name) != "Entrada" or str(last_room.name) != "Salida":
		_fail("The chain should run from Entrada to Salida, not %s to %s." % [first_room.get("name", "?"), last_room.get("name", "?")])
		return

	# El salto automatico al siguiente nivel tiene su propio test: aca se aleja
	# para que no recargue la escena en medio de las comprobaciones.
	level.level_transition_delay = 30.0
	level.round_controller.round_ended.connect(func(reason: String) -> void: _ended_reason = reason)

	if level.round_controller.is_running:
		_fail("The round should stay on standby while the player is in the entrance.")
		return
	if not is_equal_approx(level.round_controller.time_remaining, 90.0):
		_fail("The armed round should hold the full JSON time limit.")
		return

	await _wait_frames(6)
	if level.round_controller.is_running or not is_equal_approx(level.round_controller.time_remaining, 90.0):
		_fail("Standing in the entrance should not consume the round clock.")
		return

	level.player.global_position = Vector3(0.0, 1.0, 400.0)
	await _wait_frames(6)
	if not level.round_controller.is_running:
		_fail("Leaving the entrance should start the round clock.")
		return

	await _wait_frames(6)
	var elapsed := 90.0 - level.round_controller.time_remaining
	if elapsed <= 0.0:
		_fail("The round clock should tick once the player left the entrance.")
		return

	level.player.global_position = _room_center(level, str(last_room.id)) + Vector3(0.0, 1.0, 0.0)
	await _wait_frames(8)
	if level.round_controller.is_running:
		_fail("Reaching the last room should stop the round clock.")
		return
	if _ended_reason != "exit_reached":
		_fail("The round should end because the exit was reached, not '%s'." % _ended_reason)
		return
	if level.round_controller.time_remaining <= 0.0:
		_fail("The round should end with time left on the clock, not by expiry.")
		return

	print("Round flow smoke test passed.")
	quit()


func _room_by_id(level: PlayableLevel, room_id: String) -> Dictionary:
	for room_variant in level.level_data.rooms:
		var room := room_variant as Dictionary
		if str(room.id) == room_id:
			return room
	return {}


func _room_center(level: PlayableLevel, room_id: String) -> Vector3:
	var room_node := level.room_nodes.get(room_id, null) as Node3D
	return room_node.global_position if room_node != null else Vector3.ZERO


func _wait_frames(count: int) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
