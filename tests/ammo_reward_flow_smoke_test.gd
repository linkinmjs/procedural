extends SceneTree

## La recompensa de municion pertenece a la sala que se limpio: limpiar dos
## salas seguidas deja exactamente una burbuja en cada centro, y la de una
## sala no reaparece cuando cae la siguiente.

var _level: PlayableLevel


func _initialize() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func() -> void: _fail("Ammo reward flow smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	# El nivel se elige por la secuencia, como en el juego: el tercero de la
	# campaña tiene dos salas con recompensa.
	var sequence := root.get_node("LevelSequence")
	if not sequence.select_level_by_id("nivel-03"):
		_fail("The campaign should still have nivel-03.")
		return
	var scene := load("res://scenes/levels/playable_level.tscn") as PackedScene
	_level = scene.instantiate() as PlayableLevel
	root.add_child(_level)
	await process_frame
	await process_frame
	if _level.level_data.is_empty():
		_fail("The test level should load.")
		return
	var rewarding := _rooms_with_reward()
	if rewarding.size() < 2:
		_fail("The test level needs two rooms that reward ammo.")
		return
	var first: Dictionary = rewarding[0]
	var second: Dictionary = rewarding[1]

	if not await _clear_room(first):
		return
	var bubbles := get_nodes_in_group(AmmoBubble.GROUP)
	if bubbles.size() != 1:
		_fail("Clearing one room should leave exactly one bubble, got %d." % bubbles.size())
		return
	if not _is_at_center(bubbles[0], first):
		_fail("The bubble should float in the centre of the room that was cleared.")
		return

	# La segunda sala se limpia con el jugador parado en su centro: la burbuja
	# tiene que quedarse lejos de el, dentro de la sala, no encima suyo.
	var second_center := Vector3(float(second.position.x), 0.05, float(second.position.z))
	_level.player.global_position = second_center
	if not await _clear_room(second):
		return
	bubbles = get_nodes_in_group(AmmoBubble.GROUP)
	if bubbles.size() != 2:
		_fail("Clearing a second room should add exactly one bubble, got %d." % bubbles.size())
		return
	var newest: Node3D = null
	for bubble in bubbles:
		if not _is_at_center(bubble, first):
			newest = bubble
	if newest == null:
		_fail("The second bubble should not sit in the first room.")
		return
	var flat := newest.global_position
	flat.y = 0.0
	var player_flat := _level.player.global_position
	player_flat.y = 0.0
	if flat.distance_to(player_flat) < PlayableLevel.AMMO_BUBBLE_CLEARANCE - 0.2:
		_fail("The bubble should rest away from the player, got %.1f m." % flat.distance_to(player_flat))
		return
	if absf(flat.x - float(second.position.x)) > float(second.size.width) * 0.5 or absf(flat.z - float(second.position.z)) > float(second.size.depth) * 0.5:
		_fail("The bubble should stay inside the room it rewards.")
		return
	print("Ammo reward flow smoke test passed.")
	quit()


## Activa la sala y cierra todos sus bloques como si el jugador los limpiara.
func _clear_room(room: Dictionary) -> bool:
	var encounter: ConfiguredRoomEncounter3D = _level.room_encounters.get(str(room.id), null)
	if encounter == null:
		_fail("Room %s has no encounter." % str(room.name))
		return false
	encounter.activate()
	await process_frame
	var guard := 0
	while not encounter.cleared and guard < 20:
		for child in encounter.get_children():
			if child is TargetBlock3D and not (child as TargetBlock3D)._closing:
				(child as TargetBlock3D)._close()
		await process_frame
		await process_frame
		guard += 1
	if not encounter.cleared:
		_fail("Room %s should end up cleared." % str(room.name))
		return false
	await process_frame
	# La burbuja sale del bloque y viaja: se espera a que se asiente.
	var settling := 0
	while settling < 90 and _any_bubble_travelling():
		await process_frame
		settling += 1
	return true


func _any_bubble_travelling() -> bool:
	for bubble in get_nodes_in_group(AmmoBubble.GROUP):
		if is_instance_valid(bubble) and not (bubble as AmmoBubble).settled:
			return true
	return false


func _rooms_with_reward() -> Array:
	var rooms := []
	for room_variant in _level.level_data.rooms:
		var room := room_variant as Dictionary
		if bool(LevelDefinitionLoader.get_room_ammo_reward(room).enabled):
			rooms.append(room)
	return rooms


func _is_at_center(bubble: Node, room: Dictionary) -> bool:
	var center := Vector3(float(room.position.x), 0.0, float(room.position.z))
	var flat := (bubble as Node3D).global_position
	flat.y = 0.0
	return flat.distance_to(center) < 0.5


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
