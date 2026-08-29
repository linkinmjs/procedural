extends SceneTree

## La derrota se siente distinta de la victoria: al caer la ronda el jugador
## pierde el control, aparece la pantalla de fallo con el motivo y no hay
## camara lenta. Ademas, en un nivel real quedarse sin balas con ventanas por
## cerrar avisa y despues corta la ronda como `ammo_depleted`.

var _level: PlayableLevel
var _ended_reason := ""
var _warned := false


func _initialize() -> void:
	create_timer(40.0, true, false, true).timeout.connect(func() -> void: _fail("Level failure smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	if not await _check_health_failure():
		return
	if not await _check_ammo_failure():
		return
	if not await _check_sealed_room_ignores_far_bubbles():
		return
	print("Level failure smoke test passed.")
	quit()


func _load_level() -> bool:
	var sequence := root.get_node("LevelSequence")
	if not sequence.select_level_by_id("nivel-01"):
		_fail("The campaign should still have nivel-01.")
		return false
	var scene := load("res://scenes/levels/playable_level.tscn") as PackedScene
	_level = scene.instantiate() as PlayableLevel
	root.add_child(_level)
	var frames := 0
	while not _level.is_built and frames < 40:
		await process_frame
		frames += 1
	if not _level.is_built:
		_fail("The level should build.")
		return false
	_ended_reason = ""
	_level.round_controller.round_ended.connect(func(reason: String) -> void: _ended_reason = reason)
	_level.round_controller.start_round()
	await process_frame
	return true


func _unload_level() -> void:
	_level.queue_free()
	await process_frame
	await process_frame


func _check_health_failure() -> bool:
	if not await _load_level():
		return false
	var controller := _level.round_controller
	if not bool(_level.player.get("controls_enabled")):
		return _fail("The player should start with controls enabled.")
	controller.apply_damage(controller.max_health)
	await process_frame
	await process_frame
	if _ended_reason != "health_depleted":
		return _fail("Losing every HP should end the round as health_depleted, got '%s'." % _ended_reason)
	var screen := _level.get_node_or_null("FailureScreen") as FailureScreen
	if screen == null:
		return _fail("A failed round should show the failure screen under the level.")
	if screen.reason != "health_depleted":
		return _fail("The failure screen should carry the round's reason.")
	var title := screen.find_child("Title", true, false) as Label
	if title == null or not title.text.contains(tr("REASON_HEALTH_DEPLETED")):
		return _fail("The failure title should name the reason.")
	if bool(_level.player.get("controls_enabled")):
		return _fail("A failed round should switch the player's controls off.")
	if not is_equal_approx(Engine.time_scale, 1.0):
		return _fail("Failing must not start the victory slow motion.")
	# El daño no rompe una segunda vez: la pantalla es una sola.
	controller.apply_damage(10.0)
	await process_frame
	var screens := 0
	for child in _level.get_children():
		if child is FailureScreen:
			screens += 1
	if screens != 1:
		return _fail("There should be exactly one failure screen, got %d." % screens)
	await _unload_level()
	return true


func _check_ammo_failure() -> bool:
	if not await _load_level():
		return false
	var controller := _level.round_controller
	_warned = false
	controller.ammo_depleted_warning.connect(func(_seconds: float) -> void: _warned = true)
	# Con las salas de combate sin limpiar, quedarse sin balas es el final.
	if not _level._has_pending_targets():
		return _fail("nivel-01 should still have targets to shoot at the start.")
	controller.report_ammo_changed([0, 0])
	await process_frame
	await process_frame
	if not _warned:
		return _fail("Running dry with rooms left should warn the player.")
	if _ended_reason != "":
		return _fail("The warning should precede the failure.")
	await create_timer(RoundController.AMMO_GRACE_SECONDS + 0.4, true, false, true).timeout
	if _ended_reason != "ammo_depleted":
		return _fail("After the grace the round should end as ammo_depleted, got '%s'." % _ended_reason)
	var screen := _level.get_node_or_null("FailureScreen") as FailureScreen
	if screen == null or screen.reason != "ammo_depleted":
		return _fail("Running dry should show the failure screen with its own reason.")
	await _unload_level()
	return true


## Una burbuja olvidada en otra sala no cuenta mientras la sala del jugador
## este sellada: no hay forma de ir a buscarla sin balas. Con las puertas
## abiertas vuelve a contar, y una burbuja adentro de la sala sellada cuenta
## siempre.
func _check_sealed_room_ignores_far_bubbles() -> bool:
	if not await _load_level():
		return false
	var sealed_id := ""
	for room_id in _level.room_doors:
		if not _level._doors_for(str(room_id)).is_empty():
			sealed_id = str(room_id)
			break
	if sealed_id.is_empty():
		return _fail("nivel-01 should have a room with doors to seal.")
	var room: Dictionary = _level._room_by_id(sealed_id)
	var far := AmmoBubble.new()
	far.amount = 8
	far.position = _level._room_center(room) + Vector3(500.0, 1.5, 500.0)
	_level.add_child(far)
	await process_frame
	if not _level._has_reachable_ammo():
		return _fail("With every door open, any bubble with ammo is reachable.")
	for door in _level._doors_for(sealed_id):
		door.close()
	if _level._has_reachable_ammo():
		return _fail("A bubble left in another room is out of reach while this one is sealed.")
	var near := AmmoBubble.new()
	near.amount = 8
	near.position = _level._room_center(room) + Vector3(0.0, 1.5, 0.0)
	_level.add_child(near)
	await process_frame
	if not _level._has_reachable_ammo():
		return _fail("A bubble inside the sealed room is within reach.")
	for door in _level._doors_for(sealed_id):
		door.open()
	near.queue_free()
	await process_frame
	if not _level._has_reachable_ammo():
		return _fail("Opening the doors puts the far bubble back within reach.")
	await _unload_level()
	return true


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
