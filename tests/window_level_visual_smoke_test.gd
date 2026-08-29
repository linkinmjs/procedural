extends Node

## Vuelca a PNG una sala real con su bloque de ventanas desplegado. El nivel y
## la sala se buscan en el catalogo activo —el primero que tenga un bloque con
## ventanas—, asi que la prueba no depende de ningun nivel con nombre fijo.

## Hacia donde apunta cada pared absoluta, vista desde el centro de la sala.
const WALL_DIRECTIONS := {
	"north": Vector3.FORWARD,
	"south": Vector3.BACK,
	"east": Vector3.RIGHT,
	"west": Vector3.LEFT,
}
## Yaw que deja la camara mirando a esa pared.
const WALL_YAWS := {
	"north": 0.0,
	"south": PI,
	"east": -PI * 0.5,
	"west": PI * 0.5,
}


func _ready() -> void:
	var sequence = get_node("/root/LevelSequence")
	sequence.select_first_level()
	var found := _find_window_room(sequence)
	if found.is_empty():
		push_error("No level in the catalog deploys a block with windows.")
		get_tree().quit(1)
		return
	# Sin esto el nivel se presenta con su intertitulo y la captura sale tapada.
	sequence.consume_announcement()
	var level_scene := preload("res://scenes/levels/playable_level.tscn").instantiate() as PlayableLevel
	add_child(level_scene)
	while not level_scene.is_built:
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	var room := _room_by_id(level_scene.level_data.rooms, str(found.room_id))
	var slot := str(found.slot)
	var wall: String = ConfiguredRoomEncounter3D.RELATIVE_WALLS[str(room.entry.wall)][slot]
	var center := (level_scene.room_nodes[str(room.id)] as Node3D).global_position
	var depth := float(room.size.depth)
	var direction: Vector3 = WALL_DIRECTIONS[wall]
	level_scene.player.global_position = center - direction * depth * 0.3 + Vector3(0.0, 0.05, 0.0)
	var yaw: float = WALL_YAWS[wall]
	level_scene.player.rotation = Vector3(0.0, yaw, 0.0)
	level_scene.player.camera.rotation = Vector3.ZERO
	level_scene.player.update_camera_rotation()
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


## Recorre el catalogo y deja seleccionado el primer nivel con una sala cuya
## primera oleada traiga un bloque con ventanas. Devuelve la sala y el slot.
func _find_window_room(sequence) -> Dictionary:
	while true:
		var level := LevelDefinitionLoader.load_level(sequence.get_current_level_path())
		for room_variant in level.get("rooms", []):
			var room := room_variant as Dictionary
			for wave in LevelDefinitionLoader.get_room_waves(room):
				var blocks := LevelDefinitionLoader.get_wave_blocks(wave)
				if blocks.is_empty():
					continue
				for slot in blocks:
					if not LevelDefinitionLoader.get_block_layers(blocks[slot]).is_empty():
						return {"room_id": str(room.id), "slot": str(slot)}
				break
		if not sequence.select_next_level():
			break
	return {}


func _room_by_id(rooms: Array, room_id: String) -> Dictionary:
	for room_variant in rooms:
		var room := room_variant as Dictionary
		if str(room.id) == room_id:
			return room
	return {}
