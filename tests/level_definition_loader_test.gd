extends SceneTree


func _initialize() -> void:
	var level := LevelDefinitionLoader.load_level("res://level_designs/levels/nivel-1.json")
	if level.is_empty():
		_fail("The saved level definition should load.")
		return
	if int(level.schemaVersion) != LevelDefinitionLoader.SUPPORTED_SCHEMA_VERSION:
		_fail("The loader should preserve the supported schema version.")
		return
	if int(level.timeLimitSeconds) != 90:
		_fail("The loader should preserve the 90 second limit of nivel-1.")
		return
	if not SkyCatalog.has_sky(LevelDefinitionLoader.get_sky_id(level)):
		_fail("The loader should resolve the sky of the level.")
		return
	var starting_ammo := LevelDefinitionLoader.get_starting_ammo(level)
	if int(starting_ammo.magazine) != int(level.startingAmmo.magazine) or int(starting_ammo.reserve) != int(level.startingAmmo.reserve):
		_fail("The loader should expose the level starting ammo as declared.")
		return
	if level.rooms.size() != level.connections.size() + 1:
		_fail("The loader should preserve every room and connection of the chain.")
		return
	if not _check_roles(level):
		return
	if not _check_room_settings():
		return
	print("Level definition loader test passed.")
	quit()


## Un nivel declara donde empieza y donde termina el recorrido.
func _check_roles(level: Dictionary) -> bool:
	var start := LevelDefinitionLoader.get_start_room(level)
	var exit := LevelDefinitionLoader.get_exit_room(level)
	if start.is_empty() or str(start.get("role", "")) != "start":
		_fail("The level should declare its start room.")
		return false
	if exit.is_empty() or str(exit.get("role", "")) != "exit":
		_fail("The level should declare its exit room.")
		return false
	if str(start.id) == str(exit.id):
		_fail("The start and exit rooms should be different.")
		return false
	for connection_variant in level.connections:
		var width := LevelDefinitionLoader.get_corridor_width(level, connection_variant as Dictionary)
		if width < LevelDefinitionLoader.MIN_CORRIDOR_WIDTH or width > LevelDefinitionLoader.MAX_CORRIDOR_WIDTH:
			_fail("Every corridor should declare a usable width.")
			return false
	return true


## El ejemplo versionado cubre los tres modos nuevos: altura propia, cielo
## abierto y recompensa de municion al limpiar la sala.
func _check_room_settings() -> bool:
	var example := LevelDefinitionLoader.load_level("res://level_designs/three-room-example.json")
	if example.is_empty():
		_fail("The versioned example should load.")
		return false
	var entry := LevelDefinitionLoader.get_start_room(example)
	var arena := example.rooms[1] as Dictionary
	if not is_equal_approx(LevelDefinitionLoader.get_room_facing(entry), 90.0):
		_fail("The example start room should face its corridor.")
		return false
	if not is_equal_approx(LevelDefinitionLoader.get_room_wall_height(example, entry), 6.0):
		_fail("A room without its own height should inherit the level default.")
		return false
	if not is_equal_approx(LevelDefinitionLoader.get_room_wall_height(example, arena), 9.0):
		_fail("The arena should use its own wall height.")
		return false
	if not LevelDefinitionLoader.room_has_ceiling(example, entry):
		_fail("A room without its own ceiling flag should inherit the level default.")
		return false
	if LevelDefinitionLoader.room_has_ceiling(example, arena):
		_fail("The arena should stay open to the sky.")
		return false
	var entry_reward := LevelDefinitionLoader.get_room_ammo_reward(entry)
	var arena_reward := LevelDefinitionLoader.get_room_ammo_reward(arena)
	if bool(entry_reward.enabled) or int(entry_reward.amount) != 0:
		_fail("The entry room should not reward ammo.")
		return false
	if not bool(arena_reward.enabled) or int(arena_reward.amount) != 40:
		_fail("The arena should reward forty rounds once cleared.")
		return false
	if not LevelDefinitionLoader.get_room_texture(example, arena, "walls").is_empty():
		_fail("Textures are still unassigned in the versioned example.")
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
