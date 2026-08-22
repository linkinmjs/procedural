extends SceneTree

## Sonidos de la Glock: cuatro disparos aleatorios y tres etapas de recarga
## disparadas por la animacion. Verifica el cableado de punta a punta: que el
## recurso del arma tenga los streams, que la animacion llame al arma en el
## orden cargador-sale / cargador-entra / corredera, y que una recarga real
## reproduzca los tres.

const PLAYER_SCENE := preload("res://scenes/player/player_character.tscn")
const GLOCK := preload("res://resources/weapons/glock.tres")
const EXPECTED_STAGES: Array[String] = ["unload", "load", "recharge"]


func _initialize() -> void:
	create_timer(10.0, true, false, true).timeout.connect(func() -> void: _fail("Glock sounds smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	var weapon := GLOCK as WeaponResource
	var randomizer := weapon.fire_sound as AudioStreamRandomizer
	if randomizer == null or randomizer.streams_count != 4:
		_fail("The Glock should fire one of four randomized shots.")
		return
	for index in randomizer.streams_count:
		if randomizer.get_stream(index) == null:
			_fail("Shot slot %d of the Glock randomizer is empty." % index)
			return
	if weapon.unload_sound == null or weapon.load_sound == null or weapon.recharge_sound == null:
		_fail("The Glock should carry unload, load and recharge sounds.")
		return
	if weapon.empty_sound == null:
		_fail("The Glock should click when fired empty.")
		return

	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	await process_frame
	var manager := player.get_node("Camera/LeanPivot/MainCamera/Weapons_Manager")
	if manager == null or not manager.has_method("play_handling_sound"):
		_fail("Weapons_Manager should expose play_handling_sound for the animation.")
		player.queue_free()
		return
	var animation_player: AnimationPlayer = manager.animation_player
	var reload := animation_player.get_animation(weapon.reload_animation)
	if reload == null:
		_fail("The Glock reload animation should exist.")
		player.queue_free()
		return
	# El method track tiene que apuntar al Weapons_Manager desde el root del
	# AnimationPlayer, y llamar a las tres etapas en orden temporal.
	var stages: Array[String] = []
	for track in reload.get_track_count():
		if reload.track_get_type(track) != Animation.TYPE_METHOD:
			continue
		var target := animation_player.get_node(animation_player.root_node).get_node_or_null(reload.track_get_path(track))
		if target != manager:
			continue
		for key in reload.track_get_key_count(track):
			if reload.method_track_get_name(track, key) == &"play_handling_sound":
				stages.append(str(reload.method_track_get_params(track, key)[0]))
	if stages != EXPECTED_STAGES:
		_fail("The reload animation should call unload, load and recharge in that order; got %s." % str(stages))
		player.queue_free()
		return
	# Una recarga real reproduce los tres: se cuenta cada play() del reproductor
	# de manipulacion a lo largo de la animacion (1.7 s, a tiempo real).
	var reload_audio: AudioStreamPlayer = manager.reload_audio
	if reload_audio == null:
		_fail("Weapons_Manager should have its handling audio player wired.")
		player.queue_free()
		return
	var played: Array[String] = []
	var last_stream: AudioStream = null
	manager.current_weapon_slot.current_ammo = 3
	animation_player.play(weapon.reload_animation)
	while animation_player.is_playing():
		if reload_audio.stream != last_stream and reload_audio.stream != null:
			last_stream = reload_audio.stream
			played.append(last_stream.resource_path.get_file())
		await process_frame
	var expected_files: Array[String] = ["glock_unload.wav", "glock_load.wav", "glock_recharge.wav"]
	if played != expected_files:
		_fail("A real reload should play unload, load and recharge; got %s." % str(played))
		player.queue_free()
		return
	player.queue_free()
	print("Glock sounds smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
