extends SceneTree

## Quedarse sin balas es perder la ronda, con tres guardas: un disparo que
## todavia no se resolvio, una burbuja con balas en el nivel o ningun objetivo
## pendiente evitan el corte. El aviso llega primero y se retira si aparecen
## balas durante la gracia.

var _ended_reason := ""
var _warnings := 0
var _cleared := 0


func _initialize() -> void:
	create_timer(20.0, true, false, true).timeout.connect(func() -> void: _fail("Ammo depletion smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	if not await _check_bare_controller_never_fails():
		return
	if not await _check_out_of_ammo_fails_after_grace():
		return
	if not await _check_bubble_holds_the_round():
		return
	if not await _check_pending_shot_holds_the_round():
		return
	if not await _check_no_targets_left_means_no_failure():
		return
	if not await _check_ammo_during_grace_clears_warning():
		return
	print("Ammo depletion smoke test passed.")
	quit()


func _make_controller() -> RoundController:
	var controller := RoundController.new()
	controller.auto_start = false
	controller.round_duration = 60.0
	root.add_child(controller)
	controller.round_ended.connect(func(reason: String) -> void: _ended_reason = reason)
	controller.ammo_depleted_warning.connect(func(_seconds: float) -> void: _warnings += 1)
	controller.ammo_depleted_cleared.connect(func() -> void: _cleared += 1)
	_ended_reason = ""
	_warnings = 0
	_cleared = 0
	controller.start_round()
	return controller


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


## Un controlador al que nadie le informo municion arranca en cero: eso no es
## quedarse sin balas, es no saber.
func _check_bare_controller_never_fails() -> bool:
	var controller := _make_controller()
	await _wait(RoundController.AMMO_GRACE_SECONDS + 0.5)
	var ok := _ended_reason == "" and _warnings == 0
	controller.queue_free()
	if not ok:
		return _fail("A controller that never heard about ammo must not fail for lack of it.")
	return true


func _check_out_of_ammo_fails_after_grace() -> bool:
	var controller := _make_controller()
	controller.report_ammo_changed([3, 0])
	await process_frame
	controller.report_ammo_changed([0, 0])
	await process_frame
	await process_frame
	if _warnings != 1:
		controller.queue_free()
		return _fail("Running dry should raise exactly one warning, got %d." % _warnings)
	if _ended_reason != "":
		controller.queue_free()
		return _fail("The round must wait out the grace before failing.")
	await _wait(RoundController.AMMO_GRACE_SECONDS + 0.3)
	var reason := _ended_reason
	controller.queue_free()
	if reason != "ammo_depleted":
		return _fail("Running dry with targets left should end the round as ammo_depleted, got '%s'." % reason)
	return true


## Una burbuja con balas en el nivel es municion en camino: no se falla.
func _check_bubble_holds_the_round() -> bool:
	var controller := _make_controller()
	var bubble := AmmoBubble.new()
	bubble.amount = 5
	root.add_child(bubble)
	controller.report_ammo_changed([0, 0])
	await _wait(RoundController.AMMO_GRACE_SECONDS + 0.3)
	var held := _ended_reason == "" and _warnings == 0
	bubble.queue_free()
	await process_frame
	await _wait(RoundController.AMMO_GRACE_SECONDS + 0.3)
	var failed_after := _ended_reason == "ammo_depleted"
	controller.queue_free()
	if not held:
		return _fail("A bubble holding ammo should keep the round alive.")
	if not failed_after:
		return _fail("Once the bubble is gone with no ammo, the round should fail.")
	return true


## La ultima bala puede estar en el aire: hasta que se resuelva no se cuenta.
func _check_pending_shot_holds_the_round() -> bool:
	var controller := _make_controller()
	controller.report_ammo_changed([1, 0])
	controller.report_attack_fired()
	controller.report_ammo_changed([0, 0])
	# El disparo se resuelve al final del frame; mientras tanto no hay aviso.
	if controller.is_out_of_ammo():
		controller.queue_free()
		return _fail("An unresolved shot should hold the out-of-ammo check.")
	await process_frame
	await process_frame
	var warned := _warnings == 1
	controller.queue_free()
	if not warned:
		return _fail("Once the last shot resolves as a miss, the warning should fire.")
	return true


## Nivel limpio y sin balas: se camina a la salida, no se pierde.
func _check_no_targets_left_means_no_failure() -> bool:
	var controller := _make_controller()
	controller.remaining_targets_query = func() -> bool: return false
	controller.report_ammo_changed([0, 0])
	await _wait(RoundController.AMMO_GRACE_SECONDS + 0.3)
	var ok := _ended_reason == "" and _warnings == 0
	controller.queue_free()
	if not ok:
		return _fail("With nothing left to shoot, running dry must not fail the round.")
	return true


func _check_ammo_during_grace_clears_warning() -> bool:
	var controller := _make_controller()
	controller.report_ammo_changed([0, 0])
	await process_frame
	await process_frame
	controller.report_ammo_changed([0, 10])
	await process_frame
	await _wait(RoundController.AMMO_GRACE_SECONDS + 0.3)
	var ok := _warnings == 1 and _cleared == 1 and _ended_reason == ""
	controller.queue_free()
	if not ok:
		return _fail("Ammo arriving during the grace should clear the warning and keep the round (warnings %d, cleared %d, ended '%s')." % [_warnings, _cleared, _ended_reason])
	return true


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
