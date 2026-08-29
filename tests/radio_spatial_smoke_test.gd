extends SceneTree

## La radio nunca suena duplicada y la Web no paga la acustica de sala:
## - Master lleva un limitador.
## - En el perfil medio (Web) la radio entra al arbol sin Speaker, no crea
##   buses y el director no activa ninguna.
## - En el perfil alto el cruce es en serie: el plain se calla antes de que
##   arranque el espacial, y el espacial se corta antes de que vuelva el plain.

const RADIO_SCENE := preload("res://scenes/props/radio.tscn")


func _initialize() -> void:
	create_timer(20.0, true, false, true).timeout.connect(func() -> void: _fail("Radio spatial smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	if not _check_master_limiter():
		return
	if not await _check_medium_profile():
		return
	if not await _check_high_profile():
		return
	Quality.override_profile = -1
	print("Radio spatial smoke test passed.")
	quit()


func _check_master_limiter() -> bool:
	var master := AudioServer.get_bus_index("Master")
	for index in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, index) is AudioEffectHardLimiter and AudioServer.is_bus_effect_enabled(master, index):
			return true
	return _fail("Master should carry an enabled hard limiter so summed radios cannot clip.")


func _check_medium_profile() -> bool:
	Quality.override_profile = Quality.Profile.MEDIUM
	var buses_before := AudioServer.bus_count
	var radio := RADIO_SCENE.instantiate() as RadioProp
	root.add_child(radio)
	await process_frame
	await process_frame
	var ok := true
	if radio.has_spatial() or radio.get_node_or_null("Speaker") != null:
		ok = _fail("Without spatial audio the radio should enter the tree without its Speaker.")
	elif AudioServer.bus_count != buses_before:
		ok = _fail("Without spatial audio the radio must not add buses, got %d extra." % (AudioServer.bus_count - buses_before))
	elif not radio.plain_speaker.playing:
		ok = _fail("The plain speaker should still carry the song.")
	if ok:
		radio.set_spatial_active(true)
		if radio.spatial_active or radio.is_spatial_playing():
			ok = _fail("Without a Speaker the radio must ignore spatial activation.")
	if ok:
		var director := RadioDirector.new()
		root.add_child(director)
		director.register(radio)
		director.poll()
		if director.active != null:
			ok = _fail("Without spatial audio the director must not activate any radio.")
		director.queue_free()
	radio.queue_free()
	await process_frame
	return ok


func _check_high_profile() -> bool:
	Quality.override_profile = Quality.Profile.HIGH
	var buses_before := AudioServer.bus_count
	var radio := RADIO_SCENE.instantiate() as RadioProp
	root.add_child(radio)
	await process_frame
	await process_frame
	if not radio.has_spatial() or AudioServer.bus_count <= buses_before:
		return _fail("In the high profile the radio should keep its spatial Speaker and its buses.")
	var plain_volume := radio.plain_speaker.volume_db
	radio.set_spatial_active(true)
	await process_frame
	# Mitad del cruce: el plain baja pero el espacial todavia no arranco.
	if radio.is_spatial_playing():
		return _fail("The spatial speaker must not start while the plain speaker is still audible.")
	await create_timer(radio.crossfade_seconds + 0.15, true, false, true).timeout
	await process_frame
	if not radio.is_spatial_playing():
		return _fail("Once the plain speaker is silent the spatial speaker should be playing.")
	if radio.plain_speaker.volume_db > RadioProp.SILENT_DB + 1.0:
		return _fail("The plain speaker should be silent while the spatial one carries the song, got %.1f dB." % radio.plain_speaker.volume_db)
	radio.set_spatial_active(false)
	if radio.is_spatial_playing():
		return _fail("Switching off must stop the spatial speaker immediately.")
	await create_timer(radio.crossfade_seconds + 0.15, true, false, true).timeout
	if not is_equal_approx(radio.plain_speaker.volume_db, plain_volume):
		return _fail("The plain speaker should return to its volume, got %.1f dB." % radio.plain_speaker.volume_db)
	radio.queue_free()
	await process_frame
	return true


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
