extends SceneTree

## La radio experimental: aparece en la sala de salida del nivel, con la
## cancion en loop saliendo por un reproductor 3D enrutado al bus Music.

const LEVEL_SCENE := preload("res://scenes/levels/playable_level.tscn")
const RADIO_SCENE := preload("res://scenes/props/radio.tscn")


func _initialize() -> void:
	create_timer(15.0, true, false, true).timeout.connect(func() -> void: _fail("Radio prop smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	var radio := RADIO_SCENE.instantiate()
	root.add_child(radio)
	await process_frame
	var speaker := radio.get_node("Speaker") as AudioStreamPlayer3D
	if speaker == null or speaker.stream == null:
		_fail("The radio should carry a 3D speaker with a song.")
		return
	if not (speaker.stream is AudioStreamMP3) or not (speaker.stream as AudioStreamMP3).loop:
		_fail("The radio song should be an MP3 imported with loop enabled.")
		return
	if speaker.bus != &"Music" or str(speaker.get("output_bus")) != "Music":
		_fail("The radio should play through the Music bus so the options volume applies.")
		return
	radio.queue_free()

	var level := LEVEL_SCENE.instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	var exit_radio := level.get_node_or_null("ExitRadio")
	if exit_radio == null:
		_fail("The level should spawn the radio in its exit room.")
		return
	var exit_room: Dictionary = LevelDefinitionLoader.get_exit_room(level.level_data)
	var center := Vector3(float(exit_room.position.x), 0.0, float(exit_room.position.z))
	var half_depth := float(exit_room.size.depth) * 0.5
	if exit_radio.position.distance_to(center) > half_depth + 0.01 or absf(exit_radio.position.y) > 0.01:
		_fail("The exit radio should sit on the floor inside the exit room, got %s." % str(exit_radio.position))
		return
	level.queue_free()
	print("Radio prop smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
