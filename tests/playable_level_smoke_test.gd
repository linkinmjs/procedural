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
	if not _check_block_height_cap():
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


## Al entrar, la sala despliega los bloques de su PRIMERA oleada, con las capas
## que declara cada uno. Las oleadas siguientes esperan a que se limpie esta.
func _check_blocks(level: PlayableLevel) -> bool:
	for room_variant in level.level_data.rooms:
		var room := room_variant as Dictionary
		var waves := LevelDefinitionLoader.get_room_waves(room)
		var expected_layers: Array[Array] = []
		if not waves.is_empty():
			var first_blocks := LevelDefinitionLoader.get_wave_blocks(waves[0])
			for slot in first_blocks:
				expected_layers.append(LevelDefinitionLoader.get_block_layers(first_blocks[slot]))
		var encounter: ConfiguredRoomEncounter3D = level.room_encounters[str(room.id)]
		encounter.activate()
		await process_frame
		var blocks := _direct_blocks(encounter)
		if blocks.size() != expected_layers.size():
			_fail("Room %s should deploy %d blocks in its first wave." % [str(room.name), expected_layers.size()])
			return false
		for index in blocks.size():
			if blocks[index].layers != expected_layers[index]:
				_fail("Room %s should deploy the layers declared in its JSON." % str(room.name))
				return false
		if not _check_block_height(level, room, blocks):
			return false
	return true


## El bloque llega hasta el techo o hasta el tope del nivel, lo que sea menor:
## en una pared alta las ventanas no tienen que treparse fuera de la mira.
func _check_block_height(level: PlayableLevel, room: Dictionary, blocks: Array[TargetBlock3D]) -> bool:
	var wall_height := LevelDefinitionLoader.get_room_wall_height(level.level_data, room)
	var max_height := LevelDefinitionLoader.get_max_block_height(level.level_data)
	var expected := minf(wall_height - ConfiguredRoomEncounter3D.WALL_MARGIN, max_height)
	for block in blocks:
		if block.block_size.y > max_height + 0.01:
			_fail("A block of %s should not go over the %.1f m cap." % [str(room.name), max_height])
			return false
		if block.block_size.y > wall_height + 0.01:
			_fail("A block of %s should not go through its ceiling." % str(room.name))
			return false
		if not is_equal_approx(block.block_size.y, expected):
			_fail("A block of %s should be %.1f m tall." % [str(room.name), expected])
			return false
		if not is_equal_approx(block.position.y, block.block_size.y * 0.5):
			_fail("A block of %s should stand on the floor." % str(room.name))
			return false
	return true


## Una pared mas alta que el tope recorta el bloque; una mas baja lo sigue. El
## caso alto no aparece en los niveles versionados, asi que se prueba aparte.
func _check_block_height_cap() -> bool:
	var cases := [
		{"wall": 20.0, "cap": 6.0, "expected": 6.0},
		{"wall": 4.0, "cap": 6.0, "expected": 4.0 - ConfiguredRoomEncounter3D.WALL_MARGIN},
	]
	for case_variant in cases:
		var case := case_variant as Dictionary
		var encounter := ConfiguredRoomEncounter3D.new()
		encounter.room_size = Vector2(14.0, 14.0)
		encounter.wall_height = float(case.wall)
		encounter.max_block_height = float(case.cap)
		var setup := encounter._get_wall_setup("north")
		encounter.free()
		var size: Vector2 = setup.size
		if not is_equal_approx(size.y, float(case.expected)):
			_fail("A %.1f m wall with a %.1f m cap should raise a %.1f m block, not %.1f m." % [
				float(case.wall), float(case.cap), float(case.expected), size.y])
			return false
		var position: Vector3 = setup.position
		if not is_equal_approx(position.y, size.y * 0.5):
			_fail("The capped block should still stand on the floor.")
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
