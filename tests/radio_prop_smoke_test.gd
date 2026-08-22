extends SceneTree

## Las radios: una por sala que la pida, apoyada en la esquina elegida mirando
## al centro, con dos reproductores en el bus Music. Se rompen de un disparo y
## el director reparte la acustica de sala a la mas cercana.

const LEVEL_SCENE := preload("res://scenes/levels/playable_level.tscn")
const RADIO_SCENE := preload("res://scenes/props/radio.tscn")


func _initialize() -> void:
	create_timer(20.0, true, false, true).timeout.connect(func() -> void: _fail("Radio prop smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	var radio := RADIO_SCENE.instantiate() as RadioProp
	root.add_child(radio)
	await process_frame
	if radio == null or not radio.is_in_group("Target") or not radio.has_method("Hit_Successful"):
		_fail("The radio must follow the shootable contract: Target group + Hit_Successful.")
		return
	if (radio.collision_layer & (1 << 5)) == 0:
		_fail("The radio must sit on the Targets physics layer to catch bullets.")
		return
	for speaker_name in ["Speaker", "PlainSpeaker"]:
		var speaker := radio.get_node(speaker_name) as AudioStreamPlayer3D
		if speaker == null or speaker.stream == null:
			_fail("The radio should carry a %s with a song." % speaker_name)
			return
		if not (speaker.stream is AudioStreamMP3) or not (speaker.stream as AudioStreamMP3).loop:
			_fail("The radio song should be an MP3 imported with loop enabled.")
			return
		if speaker.bus != &"Music":
			_fail("%s should play through the Music bus so the options volume applies." % speaker_name)
			return
	if str(radio.speaker.get("output_bus")) != "Music":
		_fail("The spatial speaker reverb buses should route to Music too.")
		return
	if not radio.plain_speaker.playing:
		_fail("The plain speaker should be playing from the start.")
		return
	radio.Hit_Successful(25.0)
	await process_frame
	if not radio.is_broken or radio.is_in_group("Target") or (radio.collision_layer & (1 << 5)) != 0:
		_fail("A hit should break the radio and take it off the target layer.")
		return
	if radio.plain_speaker.playing or radio.speaker.playing:
		_fail("A broken radio should stop playing.")
		return
	radio.queue_free()

	var level := LEVEL_SCENE.instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	var director := level.get_node_or_null("RadioDirector") as RadioDirector
	if director == null:
		_fail("The level should spawn a RadioDirector.")
		return
	var expected := 0
	for room_variant in level.level_data.rooms:
		var room := room_variant as Dictionary
		var config: Dictionary = LevelDefinitionLoader.get_room_radio(room)
		if not bool(config.enabled):
			continue
		expected += 1
		var node := level.get_node_or_null("%sRadio" % level._safe_node_name(str(room.name))) as RadioProp
		if node == null:
			_fail("Room '%s' asked for a radio and got none." % str(room.name))
			return
		var center := Vector3(float(room.position.x), 0.0, float(room.position.z))
		var half_width := float(room.size.width) * 0.5
		var half_depth := float(room.size.depth) * 0.5
		var local := node.position - center
		if absf(local.x) >= half_width or absf(local.z) >= half_depth or absf(node.position.y) > 0.01:
			_fail("The radio should sit on the floor inside its room, got %s." % str(node.position))
			return
		if absf(local.x) < half_width - 1.5 or absf(local.z) < half_depth - 1.5:
			_fail("The radio should hug its corner, got local offset %s." % str(local))
			return
		var signs: Vector2 = level.CORNER_SIGNS[str(config.corner)]
		if signf(local.x) != signs.x or signf(local.z) != signs.y:
			_fail("The radio should be in corner %s, got local offset %s." % [str(config.corner), str(local)])
			return
		# El frente del modelo es +Z local; girado debe apuntar al centro.
		var forward := node.global_transform.basis.z
		var to_center := (center - node.position).normalized()
		if forward.dot(to_center) < 0.999:
			_fail("The radio should face the room center, forward %s vs %s." % [str(forward), str(to_center)])
			return
	if expected == 0:
		_fail("The default level needs at least one room with a radio for this test.")
		return
	if director.radios.size() != expected:
		_fail("The director should know every radio, expected %d got %d." % [expected, director.radios.size()])
		return
	director.poll()
	await process_frame
	if director.active == null:
		_fail("With a camera in the level the director should pick an active radio.")
		return
	if not director.active.spatial_active:
		_fail("The active radio should run its spatial speaker.")
		return
	var active := director.active
	active.break_radio()
	await process_frame
	if director.active == active:
		_fail("Breaking the active radio should hand the role over (or clear it).")
		return
	level.queue_free()
	print("Radio prop smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
