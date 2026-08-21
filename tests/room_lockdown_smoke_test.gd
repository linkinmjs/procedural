extends SceneTree

## Entrar a una sala con bloques sella sus puertas; limpiar el ultimo bloque las
## vuelve a abrir. Las salas sin bloques nunca se sellan. Las salas y sus
## expectativas se derivan del JSON activo, asi que redisenar el nivel en la
## herramienta no invalida la prueba.


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
	level.results_delay = 30.0

	var combat_room := _combat_room(level)
	var quiet_room := _quiet_room(level)
	if combat_room.is_empty() or quiet_room.is_empty():
		_fail("The active level should have a room with blocks and one without.")
		return
	var combat_id := str(combat_room.id)
	var combat_name := str(combat_room.name)

	var doors: Array = level.room_doors.get(combat_id, [])
	var expected_doors := _connection_count(level, combat_id)
	if doors.size() != expected_doors:
		_fail("%s should build one door per connection (%d), got %d." % [combat_name, expected_doors, doors.size()])
		return
	for door in doors:
		if door.is_closed:
			_fail("Doors should start open, before the player walks in.")
			return

	level.player.global_position = (level.room_nodes[combat_id] as Node3D).global_position + Vector3(0.0, 1.0, 0.0)
	await _wait_frames(6)

	var encounter: ConfiguredRoomEncounter3D = level.room_encounters[combat_id]
	if not encounter.activated:
		_fail("Walking into %s should activate its encounter." % combat_name)
		return
	for door in doors:
		if not door.is_closed:
			_fail("Every opening of %s should be sealed while its blocks stand." % combat_name)
			return
		var shape := door.get_node_or_null("DoorShape") as CollisionShape3D
		if shape == null or shape.disabled:
			_fail("A sealed door should have its collision shape enabled.")
			return
	for door in level.room_doors.get(str(quiet_room.id), []):
		if door.is_closed:
			_fail("%s has no blocks, so it should never seal." % str(quiet_room.name))
			return

	var blocks := _blocks_of(encounter)
	var expected_blocks := _first_wave_block_count(combat_room)
	if blocks.size() != expected_blocks:
		_fail("%s should deploy %d blocks in its first wave, got %d." % [combat_name, expected_blocks, blocks.size()])
		return
	var cleared_targets := await _clear_encounter(encounter)
	if cleared_targets == 0:
		_fail("The %s blocks should have spawned targets to clear." % combat_name)
		return
	await _wait_frames(10)

	if not encounter.cleared:
		_fail("Clearing every wave should mark the encounter as cleared.")
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


## Primera sala del recorrido que despliega bloques: es la que se sella.
func _combat_room(level: PlayableLevel) -> Dictionary:
	for room_id in level.room_order:
		var room := _room_by_id(level, room_id)
		if _has_blocks(room):
			return room
	return {}


## Sala que nunca deberia sellarse: la de inicio si no tiene bloques, o la
## primera del recorrido sin bloques.
func _quiet_room(level: PlayableLevel) -> Dictionary:
	var start := LevelDefinitionLoader.get_start_room(level.level_data)
	if not start.is_empty() and not _has_blocks(start):
		return start
	for room_id in level.room_order:
		var room := _room_by_id(level, room_id)
		if not _has_blocks(room):
			return room
	return {}


func _room_by_id(level: PlayableLevel, room_id: String) -> Dictionary:
	for room_variant in level.level_data.rooms:
		var room := room_variant as Dictionary
		if str(room.id) == room_id:
			return room
	return {}


func _has_blocks(room: Dictionary) -> bool:
	if room.is_empty():
		return false
	for wave in LevelDefinitionLoader.get_room_waves(room):
		if not LevelDefinitionLoader.get_wave_blocks(wave).is_empty():
			return true
	return false


## Cuantas conexiones del JSON tocan la sala: cada una levanta una puerta.
func _connection_count(level: PlayableLevel, room_id: String) -> int:
	var count := 0
	for connection_variant in level.level_data.get("connections", []):
		var connection := connection_variant as Dictionary
		if str(connection.fromRoomId) == room_id or str(connection.toRoomId) == room_id:
			count += 1
	return count


func _first_wave_block_count(room: Dictionary) -> int:
	for wave in LevelDefinitionLoader.get_room_waves(room):
		var blocks := LevelDefinitionLoader.get_wave_blocks(wave)
		if not blocks.is_empty():
			return blocks.size()
	return 0


func _blocks_of(encounter: ConfiguredRoomEncounter3D) -> Array[TargetBlock3D]:
	var blocks: Array[TargetBlock3D] = []
	for child in encounter.get_children():
		if child is TargetBlock3D:
			blocks.append(child)
	return blocks


## La sala puede encadenar varias oleadas de bloques, y cada bloque varias capas
## de ventanas: se limpia todo lo que aparezca hasta que el encounter cierre.
func _clear_encounter(encounter: ConfiguredRoomEncounter3D) -> int:
	var resolved := 0
	for _attempt in 64:
		if encounter.cleared:
			break
		for block in _blocks_of(encounter):
			resolved += _clear_targets(block)
		await _wait_frames(4)
	return resolved


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
