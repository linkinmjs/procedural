extends SceneTree


func _initialize() -> void:
	create_timer(8.0, true, false, true).timeout.connect(func() -> void: _fail("Playable level smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/levels/playable_level.tscn")
	for _frame in 6:
		await process_frame
	var level := current_scene as PlayableLevel
	if level == null:
		_fail("Playable level scene did not load.")
		return
	if level.level_data.is_empty() or level.level_data.rooms.size() != 4:
		_fail("Expected the four rooms defined in nivel-1.json.")
		return
	if level.room_nodes.size() != 4 or level.room_encounters.size() != 4:
		_fail("Every JSON room should create geometry and an encounter.")
		return
	if level.connection_geometry.get_child_count() != 12:
		_fail("The three straight connections should create floors, walls and corridor lights.")
		return
	if not is_instance_valid(level.player):
		_fail("The player should spawn in the Entrada room.")
		return
	if not is_equal_approx(level.round_controller.round_duration, 90.0) or not level.round_controller.is_running:
		_fail("The JSON time limit should start the round at 90 seconds.")
		return
	var manager = level.player.get_node("Camera/LeanPivot/MainCamera/Weapons_Manager")
	if manager.weapon_stack.size() != 5:
		_fail("The playable level should grant the complete five-weapon loadout.")
		return
	var sala_one := _find_room(level.level_data.rooms, "Sala 1")
	var sala_two := _find_room(level.level_data.rooms, "Sala 2")
	if sala_one.is_empty() or sala_two.is_empty():
		_fail("The test rooms could not be found in the level definition.")
		return
	var first_encounter: ConfiguredRoomEncounter3D = level.room_encounters[str(sala_one.id)]
	first_encounter.activate()
	await process_frame
	var first_blocks := _direct_blocks(first_encounter)
	if first_blocks.size() != 1 or first_blocks[0].target_count != 10 or first_blocks[0].moves_to_opposite_side:
		_fail("Sala 1 should deploy one static block with ten targets.")
		return
	if first_blocks[0].position.z <= 0.0:
		_fail("Sala 1 front block should be opposite its north entry, on the south wall.")
		return
	var second_encounter: ConfiguredRoomEncounter3D = level.room_encounters[str(sala_two.id)]
	second_encounter.activate()
	await process_frame
	var second_blocks := _direct_blocks(second_encounter)
	if second_blocks.size() != 2:
		_fail("Sala 2 should deploy its left and right blocks.")
		return
	for block in second_blocks:
		if block.target_count != 5 or not block.moves_to_opposite_side:
			_fail("Sala 2 blocks should move and contain five targets each.")
			return
	if ProjectSettings.get_setting("application/run/main_scene") != "res://scenes/levels/playable_level.tscn":
		_fail("The configured JSON level should be the project main scene.")
		return
	print("Playable level smoke test passed.")
	quit()


func _find_room(rooms: Array, room_name: String) -> Dictionary:
	for room_variant in rooms:
		var room := room_variant as Dictionary
		if str(room.name) == room_name:
			return room
	return {}


func _direct_blocks(encounter: ConfiguredRoomEncounter3D) -> Array[TargetBlock3D]:
	var blocks: Array[TargetBlock3D] = []
	for child in encounter.get_children():
		if child is TargetBlock3D:
			blocks.append(child)
	return blocks


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
