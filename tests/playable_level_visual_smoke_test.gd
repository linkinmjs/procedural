extends Node


func _ready() -> void:
	var level := $PlayableLevel as PlayableLevel

	# El nivel se presenta antes de dejarse ver. Se congela el titulo a la vista
	# para retratarlo y despues se saltea, asi las demas vistas muestran el
	# nivel y no el velo.
	if is_instance_valid(level.level_intro):
		level.level_intro.hold()
		await RenderingServer.frame_post_draw
		if not _save_viewport("res://.godot/level-intro.png"):
			return
		level.level_intro.skip()

	await get_tree().process_frame
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	if not _save_viewport("res://.godot/playable-level-entry.png"):
		return
	# La primera sala con bloques, mirando desde la puerta hacia su pared
	# frontal. No depende del nombre ni de la orientacion del nivel.
	var sala_one := _find_first_combat_room(level.level_data.rooms)
	if sala_one.is_empty():
		push_error("The first campaign level should have a room with blocks.")
		get_tree().quit(1)
		return
	var center := Vector3(float(sala_one.position.x), 0.05, float(sala_one.position.z))
	var forward := _wall_direction(OPPOSITE_WALL[str(sala_one.entry.wall)])
	_place_player(level, center - forward * 6.5, forward)
	var encounter: ConfiguredRoomEncounter3D = level.room_encounters[str(sala_one.id)]
	encounter.activate()
	await get_tree().process_frame
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	if not _save_viewport("res://.godot/playable-level-sala-one.png"):
		return
	# Media vuelta para mirar el vano por el que se entro: al activarse el
	# encuentro la sala queda sellada por detras.
	_place_player(level, center + forward * 3.0, -forward)
	await get_tree().process_frame
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	if not _save_viewport("res://.godot/playable-level-sealed-door.png"):
		return
	print("Playable level visual smoke test passed.")
	get_tree().quit()


const OPPOSITE_WALL := {"north": "south", "south": "north", "east": "west", "west": "east"}


func _find_first_combat_room(rooms: Array) -> Dictionary:
	for room_variant in rooms:
		var room := room_variant as Dictionary
		for wave in LevelDefinitionLoader.get_room_waves(room):
			if not LevelDefinitionLoader.get_wave_blocks(wave).is_empty():
				return room
	return {}


## Direccion horizontal hacia una pared de la sala (norte es -Z).
func _wall_direction(wall: String) -> Vector3:
	match wall:
		"north":
			return Vector3(0.0, 0.0, -1.0)
		"south":
			return Vector3(0.0, 0.0, 1.0)
		"east":
			return Vector3(1.0, 0.0, 0.0)
	return Vector3(-1.0, 0.0, 0.0)


## Deja al jugador parado en `position` mirando hacia `direction`.
func _place_player(level: PlayableLevel, position: Vector3, direction: Vector3) -> void:
	var yaw := atan2(-direction.x, -direction.z)
	level.player.global_position = position
	level.player.rotation = Vector3(0.0, yaw, 0.0)
	level.player.camera_rotation = Vector2(yaw, 0.0)
	level.player.camera.rotation = Vector3.ZERO


func _save_viewport(path: String) -> bool:
	var image := get_viewport().get_texture().get_image()
	if image == null or image.save_png(path) != OK:
		push_error("Could not save playable level preview: %s" % path)
		get_tree().quit(1)
		return false
	return true
