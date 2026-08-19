extends SceneTree

## Entrar a una sala con bloques sella sus puertas; limpiar el ultimo bloque las
## vuelve a abrir. Las salas sin bloques (Entrada, Salida) nunca se sellan.


func _initialize() -> void:
	create_timer(20.0, true, false, true).timeout.connect(func() -> void: _fail("Room lockdown smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	root.get_node("LevelSequence").select_first_level()
	change_scene_to_file("res://scenes/levels/playable_level.tscn")
	await _wait_frames(8)
	var level := current_scene as PlayableLevel
	if level == null or level.level_data.is_empty():
		_fail("The playable level did not load.")
		return
	level.level_transition_delay = 30.0

	var sala_one_id := _room_id(level, "Sala 1")
	var entrada_id := _room_id(level, "Entrada")
	if sala_one_id.is_empty() or entrada_id.is_empty():
		_fail("The test rooms could not be found in nivel-1.")
		return

	var doors: Array = level.room_doors.get(sala_one_id, [])
	if doors.size() != 2:
		_fail("Sala 1 should build a door for its entry wall and for its exit, got %d." % doors.size())
		return
	for door in doors:
		if door.is_closed:
			_fail("Doors should start open, before the player walks in.")
			return

	level.player.global_position = (level.room_nodes[sala_one_id] as Node3D).global_position + Vector3(0.0, 1.0, 0.0)
	await _wait_frames(6)

	var encounter: ConfiguredRoomEncounter3D = level.room_encounters[sala_one_id]
	if not encounter.activated:
		_fail("Walking into Sala 1 should activate its encounter.")
		return
	for door in doors:
		if not door.is_closed:
			_fail("Every opening of Sala 1 should be sealed while its blocks stand.")
			return
		var shape := door.get_node_or_null("DoorShape") as CollisionShape3D
		if shape == null or shape.disabled:
			_fail("A sealed door should have its collision shape enabled.")
			return
	for door in level.room_doors.get(entrada_id, []):
		if door.is_closed:
			_fail("Entrada has no blocks, so it should never seal.")
			return

	var blocks := _blocks_of(encounter)
	if blocks.size() != 1:
		_fail("Sala 1 should deploy exactly one block.")
		return
	var cleared_targets := _clear_targets(blocks[0])
	if cleared_targets == 0:
		_fail("The Sala 1 block should have spawned targets to clear.")
		return
	await _wait_frames(10)

	if not encounter.cleared:
		_fail("Clearing every block should mark the encounter as cleared.")
		return
	for door in doors:
		if door.is_closed:
			_fail("Clearing the room should open its doors again.")
			return
		var shape := door.get_node_or_null("DoorShape") as CollisionShape3D
		if shape == null or not shape.disabled:
			_fail("An open door should have its collision shape disabled.")
			return

	if not await _door_respects_the_inside():
		return

	print("Room lockdown smoke test passed.")
	quit()


## Una puerta pedida de cierre no se cierra mientras el jugador este del lado de
## afuera: si no, retroceder al pasillo lo dejaria encerrado fuera de la sala.
func _door_respects_the_inside() -> bool:
	var door := RoomDoor3D.new()
	door.safe_close_distance = 2.0
	door.inward_direction = Vector3.BACK
	root.add_child(door)
	var body := Node3D.new()
	root.add_child(body)
	await _wait_frames(1)

	body.global_position = Vector3(0.0, 0.0, -6.0)
	door.request_close(body)
	await _wait_frames(3)
	if door.is_closed:
		_fail("A door should stay open while the player stands outside the room.")
		return false

	body.global_position = Vector3(0.0, 0.0, 1.0)
	await _wait_frames(3)
	if door.is_closed:
		_fail("A door should not close on a player still standing in the opening.")
		return false

	body.global_position = Vector3(0.0, 0.0, 6.0)
	await _wait_frames(3)
	if not door.is_closed:
		_fail("A door should close once the player is inside and clear of the opening.")
		return false

	door.queue_free()
	body.queue_free()
	return true


func _room_id(level: PlayableLevel, room_name: String) -> String:
	for room_variant in level.level_data.rooms:
		var room := room_variant as Dictionary
		if str(room.name) == room_name:
			return str(room.id)
	return ""


func _blocks_of(encounter: ConfiguredRoomEncounter3D) -> Array[TargetBlock3D]:
	var blocks: Array[TargetBlock3D] = []
	for child in encounter.get_children():
		if child is TargetBlock3D:
			blocks.append(child)
	return blocks


func _clear_targets(block: TargetBlock3D) -> int:
	var resolved := 0
	for target in block.spawn_volume.active_targets.duplicate():
		if not is_instance_valid(target):
			continue
		if target.has_method("close"):
			target.close()
		elif target.has_method("Hit_Successful"):
			target.Hit_Successful(100.0)
		else:
			continue
		resolved += 1
	return resolved


func _wait_frames(count: int) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
