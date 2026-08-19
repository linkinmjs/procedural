extends Node


func _ready() -> void:
	var sequence = get_node("/root/LevelSequence")
	while sequence.get_current_level_id() != "nivel-ventanas":
		if not sequence.select_next_level():
			push_error("The window test level is missing from the catalog.")
			get_tree().quit(1)
			return
	var level_scene := preload("res://scenes/levels/playable_level.tscn").instantiate() as PlayableLevel
	add_child(level_scene)
	await get_tree().process_frame
	await get_tree().physics_frame
	var room := _find_room(level_scene.level_data.rooms, "Sala estatica")
	level_scene.player.global_position = Vector3(float(room.position.x), 0.05, float(room.position.z) - 6.0)
	level_scene.player.rotation = Vector3(0.0, PI, 0.0)
	level_scene.player.camera_rotation = Vector2(PI, 0.0)
	level_scene.player.camera.rotation = Vector3.ZERO
	var encounter: ConfiguredRoomEncounter3D = level_scene.room_encounters[str(room.id)]
	encounter.activate()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.save_png("res://.godot/window-level.png") != OK:
		push_error("Could not save the window level preview.")
		get_tree().quit(1)
		return
	sequence.select_first_level()
	print("Window level visual smoke test passed.")
	get_tree().quit()


func _find_room(rooms: Array, room_name: String) -> Dictionary:
	for room_variant in rooms:
		var room := room_variant as Dictionary
		if str(room.name) == room_name:
			return room
	return {}
