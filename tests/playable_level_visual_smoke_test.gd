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
	var sala_one := _find_room(level.level_data.rooms, "Sala 1")
	level.player.global_position = Vector3(float(sala_one.position.x), 0.05, float(sala_one.position.z) - 6.5)
	level.player.rotation = Vector3(0.0, PI, 0.0)
	level.player.camera_rotation = Vector2(PI, 0.0)
	level.player.camera.rotation = Vector3.ZERO
	var encounter: ConfiguredRoomEncounter3D = level.room_encounters[str(sala_one.id)]
	encounter.activate()
	await get_tree().process_frame
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	if not _save_viewport("res://.godot/playable-level-sala-one.png"):
		return
	# Media vuelta para mirar el vano por el que se entro: al activarse el
	# encuentro la sala queda sellada por detras.
	level.player.global_position = Vector3(float(sala_one.position.x), 0.05, float(sala_one.position.z) - 3.0)
	level.player.rotation = Vector3.ZERO
	level.player.camera_rotation = Vector2.ZERO
	await get_tree().process_frame
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	if not _save_viewport("res://.godot/playable-level-sealed-door.png"):
		return
	print("Playable level visual smoke test passed.")
	get_tree().quit()


func _find_room(rooms: Array, room_name: String) -> Dictionary:
	for room_variant in rooms:
		var room := room_variant as Dictionary
		if str(room.name) == room_name:
			return room
	return {}


func _save_viewport(path: String) -> bool:
	var image := get_viewport().get_texture().get_image()
	if image == null or image.save_png(path) != OK:
		push_error("Could not save playable level preview: %s" % path)
		get_tree().quit(1)
		return false
	return true
