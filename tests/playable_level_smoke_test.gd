extends SceneTree

## Verifica que la escena jugable construya lo que declara el JSON activo de la
## secuencia. Las expectativas se derivan del propio archivo, asi que rediseniar
## un nivel en la herramienta no invalida la prueba.


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
	if level.level_data.is_empty() or level.level_data.rooms.is_empty():
		_fail("The active level definition should declare at least one room.")
		return
	var room_count: int = level.level_data.rooms.size()
	if level.room_nodes.size() != room_count or level.room_encounters.size() != room_count:
		_fail("Every JSON room should create geometry and an encounter.")
		return
	if not is_instance_valid(level.player):
		_fail("The player should spawn in the start room.")
		return
	if not is_equal_approx(level.round_controller.round_duration, float(level.level_data.timeLimitSeconds)) or level.round_controller.is_running:
		_fail("The JSON time limit should arm the round without starting it.")
		return
	var manager = level.player.get_node("Camera/LeanPivot/MainCamera/Weapons_Manager")
	if manager.weapon_stack.size() != 1 or manager.current_weapon_slot.weapon.weapon_name != "Glock":
		_fail("The playable level should arm the player with the Glock alone.")
		return
	if not _check_starting_ammo(level, manager):
		return
	if not _check_room_volumes(level):
		return
	if not await _check_blocks(level):
		return
	if ProjectSettings.get_setting("application/run/main_scene") != "res://scenes/levels/playable_level.tscn":
		_fail("The configured JSON level should be the project main scene.")
		return
	print("Playable level smoke test passed.")
	quit()


func _check_starting_ammo(level: PlayableLevel, manager: Node) -> bool:
	var expected := LevelDefinitionLoader.get_starting_ammo(level.level_data)
	var slot: WeaponSlot = manager.current_weapon_slot
	if slot.current_ammo != mini(int(expected.magazine), slot.weapon.magazine):
		_fail("The level should load the magazine declared by startingAmmo.")
		return false
	if slot.reserve_ammo != mini(int(expected.reserve), slot.weapon.max_ammo):
		_fail("The level should load the reserve declared by startingAmmo.")
		return false
	return true


## Cada sala levanta sus paredes a la altura configurada, tapa arriba salvo que
## este a cielo abierto, y abre sus vanos dejando dintel sobre la puerta.
func _check_room_volumes(level: PlayableLevel) -> bool:
	var shell := level.get_node_or_null("RoomGeometry/LevelShell") as CSGCombiner3D
	if shell == null:
		_fail("The level geometry should live in a single CSG shell.")
		return false
	if not shell.use_collision:
		_fail("The level shell should generate its collision from the combined result.")
		return false
	for room_variant in level.level_data.rooms:
		var room := room_variant as Dictionary
		var safe_name: String = str(room.name).validate_node_name().replace(" ", "")
		var wall_height := LevelDefinitionLoader.get_room_wall_height(level.level_data, room)
		var has_ceiling := LevelDefinitionLoader.room_has_ceiling(level.level_data, room)
		var ceiling := shell.get_node_or_null("%sCeiling" % safe_name) as CSGBox3D
		if has_ceiling and ceiling == null:
			_fail("Room %s should be closed by a ceiling." % str(room.name))
			return false
		if not has_ceiling and ceiling != null:
			_fail("Room %s should stay open to the sky." % str(room.name))
			return false
		if ceiling != null and not is_equal_approx(ceiling.position.y - ceiling.size.y * 0.5, wall_height):
			_fail("The ceiling of %s should rest on top of its walls." % str(room.name))
			return false
		for wall in ["North", "East", "South", "West"]:
			var box := shell.get_node_or_null("%s%sWall" % [safe_name, wall]) as CSGBox3D
			if box == null:
				_fail("Room %s should raise its %s wall." % [str(room.name), wall])
				return false
			if not is_equal_approx(box.size.y, wall_height):
				_fail("Room %s should raise its walls to %.1f m." % [str(room.name), wall_height])
				return false
		if not _check_openings(level, room, shell, wall_height):
			return false
	return true


## El vano no llega al techo: sobre la puerta queda pared para colgar una hoja.
func _check_openings(level: PlayableLevel, room: Dictionary, shell: CSGCombiner3D, wall_height: float) -> bool:
	var doors: Array = level.room_doors.get(str(room.id), [])
	var expected_height: float = level._door_height_for(wall_height)
	for door_variant in doors:
		var door := door_variant as RoomDoor3D
		if not is_equal_approx(door.door_size.y, expected_height):
			_fail("The doors of %s should match the opening height." % str(room.name))
			return false
		if door.door_size.y >= wall_height:
			_fail("The opening of %s should leave a lintel above the door." % str(room.name))
			return false
		var cut := shell.get_node_or_null(door.name.replace("Door", "Opening")) as CSGBox3D
		if cut == null or cut.operation != CSGShape3D.OPERATION_SUBTRACTION:
			_fail("Every door of %s needs its opening carved out of the shell." % str(room.name))
			return false
		if not is_equal_approx(cut.size.y, expected_height):
			_fail("The carved opening of %s should match its door." % str(room.name))
			return false
	return true


## Cada sala despliega un bloque por cada slot habilitado, con sus oleadas.
func _check_blocks(level: PlayableLevel) -> bool:
	for room_variant in level.level_data.rooms:
		var room := room_variant as Dictionary
		var expected_waves: Array[Array] = []
		for slot in ["left", "front", "right"]:
			var config := room.blocks[slot] as Dictionary
			if not bool(config.enabled):
				continue
			var waves: Array[int] = []
			for count_variant in config.waves:
				waves.append(int(count_variant))
			expected_waves.append(waves)
		var encounter: ConfiguredRoomEncounter3D = level.room_encounters[str(room.id)]
		encounter.activate()
		await process_frame
		var blocks := _direct_blocks(encounter)
		if blocks.size() != expected_waves.size():
			_fail("Room %s should deploy %d blocks." % [str(room.name), expected_waves.size()])
			return false
		for index in blocks.size():
			if blocks[index].waves != expected_waves[index]:
				_fail("Room %s should deploy the waves declared in its JSON." % str(room.name))
				return false
	return true


func _direct_blocks(encounter: ConfiguredRoomEncounter3D) -> Array[TargetBlock3D]:
	var blocks: Array[TargetBlock3D] = []
	for child in encounter.get_children():
		if child is TargetBlock3D:
			blocks.append(child)
	return blocks


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
