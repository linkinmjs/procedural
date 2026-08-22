extends SceneTree

## Verifica el sistema de puntuacion dentro del nivel jugable: que las ventanas
## reales alimenten el pozo, que limpiar una sala lo cobre al multiplicador
## vigente y que el HUD lo refleje.
##
## Usa el segundo nivel del catalogo porque el primero no declara objetivos.

const MAX_WAVE_STEPS := 40

var _level: PlayableLevel
var _score: ScoreController


func _initialize() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func() -> void: _fail("Score level smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	if not await _load_level_with_targets():
		return
	if not _check_plan():
		return
	if not _check_start_room_runs_the_round():
		return
	if not await _check_room_run():
		return
	if not await _check_hud():
		return
	if not await _check_exit_room_waits_for_targets():
		return
	print("Score level smoke test passed.")
	quit()


func _load_level_with_targets() -> bool:
	var sequence := root.get_node_or_null("/root/LevelSequence")
	if sequence == null:
		return _fail("The level sequence autoload should be available.")
	while true:
		change_scene_to_file("res://scenes/levels/playable_level.tscn")
		for _frame in 8:
			await process_frame
		_level = current_scene as PlayableLevel
		if _level == null:
			return _fail("The playable level scene did not load.")
		_score = _level.score_controller
		if _score == null:
			return _fail("The playable level should carry a score controller.")
		if _score.plan != null and _score.plan.targets_total > 0:
			return true
		if not sequence.select_next_level():
			return _fail("No level in the catalog declares targets to score.")
	return false


func _check_plan() -> bool:
	if _score.get_ceiling() <= 0:
		return _fail("A level with targets should carry a ceiling.")
	if _score.total_score != 0 or _score.pot != 0:
		return _fail("The score should start empty.")
	return true


## Una sala de inicio con objetivos no puede jugarse en STANDBY: si la ronda no
## corre, los disparos, los fallos y el daño no se cuentan, y esa sala puntuaria
## con reglas distintas al resto del nivel.
func _check_start_room_runs_the_round() -> bool:
	var start_room := LevelDefinitionLoader.get_start_room(_level.level_data)
	var encounter := _level.room_encounters.get(str(start_room.get("id", "")), null) as ConfiguredRoomEncounter3D
	if encounter == null:
		return _fail("The level should build an encounter for its start room.")
	if _score.plan.room_targets(encounter.room_id) <= 0:
		return true
	if not encounter.activated:
		return _fail("Spawning inside a start room with targets should activate its encounter.")
	if not _level.round_controller.is_running:
		return _fail("A start room with targets must run the round instead of holding it in standby.")
	return true


## Limpia entera la primera sala con objetivos, disparando a la X de cada ventana.
func _check_room_run() -> bool:
	var encounter := _first_encounter_with_blocks()
	if encounter == null:
		return _fail("The level should have a room with blocks.")
	var targets := _score.plan.room_targets(encounter.room_id)
	if targets <= 0:
		return _fail("The scored room should declare targets.")
	var shots_before := _level.round_controller.attacks
	encounter.activate()
	await process_frame
	# Arrancar un encuentro implica que el jugador ya esta peleando: en STANDBY
	# los disparos, los fallos y el daño de esa sala no se contarian.
	if not _level.round_controller.is_running:
		return _fail("Starting an encounter must start the round instead of leaving it on standby.")
	# Se cuentan por separado las ventanas que se cerraron y los disparos que
	# costaron: no son lo mismo desde que hay familias que piden mas de un tiro,
	# como la descarga, que primero pregunta y despues cierra.
	var resolved := 0
	var shots := 0
	var peak_pot := 0
	for _step in MAX_WAVE_STEPS:
		if encounter.cleared:
			break
		for _frame in 3:
			await process_frame
		for window in _live_windows(encounter):
			if not _shoot_close_zone(window):
				continue
			shots += 1
			peak_pot = maxi(peak_pot, _score.pot)
			await process_frame
			if not is_instance_valid(window):
				resolved += 1
	if not encounter.cleared:
		return _fail("Shooting every window should clear the room.")
	# La sala puede entregar menos objetivos de los que declara si no entran en su
	# bloque. Eso es un problema del nivel, no del puntaje: aca solo se exige que
	# se cobre lo que efectivamente aparecio.
	if resolved <= 0 or resolved > targets:
		return _fail("The room should hand out at most the targets its JSON declares, and at least one.")
	if shots < resolved:
		return _fail("Closing a window should never cost less than one shot.")
	if peak_pot <= 0:
		return _fail("Resolved windows should feed the pot.")
	if _level.round_controller.attacks - shots_before != shots:
		return _fail("Every shot fired in the room should reach the round counters.")
	await process_frame
	if _score.pot != 0 or _score.chain_hits != 0:
		return _fail("Clearing the room should close the chain.")
	if _score.total_score <= peak_pot:
		return _fail("Banking should pay more than the raw pot, since the multiplier applies.")
	return true


func _check_hud() -> bool:
	var hud := _level.get_node_or_null("RoundHUD/ScoreHUD") as ScoreHUD
	if hud == null:
		return _fail("The round HUD should carry the score HUD.")
	# El marcador y el cobro ruedan hasta su valor final en vez de saltar: hay
	# que dejar que las cuentas asienten antes de leerlas. La espera es de
	# tiempo real porque los tweens corren con delta, no con frames.
	await create_timer(1.2).timeout
	if hud.score_value.text.replace(" ", "") != str(_score.total_score):
		return _fail("The HUD should show the score the controller holds.")
	# El cobro queda a la vista un rato: si desapareciera con el ultimo objetivo,
	# el jugador nunca veria cuanto acumulo.
	if not hud.combo_box.visible:
		return _fail("The combo counter should hold the banked result after the chain closes.")
	if not hud.pending_value.text.ends_with(ScoreBreakdown.thousands(_score._best_bank)):
		return _fail("The held counter should show what the chain actually paid (got '%s', want suffix '%s')." % [hud.pending_value.text, ScoreBreakdown.thousands(_score._best_bank)])
	return true


## Pisar la ultima sala no cierra el nivel si todavia tiene objetivos: la ronda
## sigue corriendo hasta que caiga el ultimo.
func _check_exit_room_waits_for_targets() -> bool:
	if not await _load_level_with_a_populated_exit():
		print("No level in the catalog has a populated exit room; skipping that check.")
		return true
	var exit_encounter := _level._exit_encounter
	if exit_encounter == null:
		return _fail("The level should wire an exit encounter.")
	exit_encounter.body_entered.emit(_level.player)
	for _frame in 4:
		await process_frame
	if not _level.round_controller.is_running:
		return _fail("Entering a final room that still has targets must not end the round.")
	if _level._round_completed:
		return _fail("The round should stay open until the final room is cleared.")
	for _step in MAX_WAVE_STEPS:
		if exit_encounter.cleared:
			break
		for _frame in 3:
			await process_frame
		for window in _live_windows(exit_encounter):
			_shoot_close_zone(window)
	if not exit_encounter.cleared:
		return _fail("Shooting every window should clear the final room.")
	await process_frame
	if _level.round_controller.is_running:
		return _fail("Clearing the final room should end the round.")
	if not _level._round_completed:
		return _fail("Clearing the final room should complete the level.")
	return true


## Recorre el catalogo hasta dar con un nivel cuya sala de salida traiga
## objetivos. Sin uno asi no hay nada que comprobar sobre el cierre diferido.
func _load_level_with_a_populated_exit() -> bool:
	var sequence := root.get_node_or_null("/root/LevelSequence")
	if sequence == null:
		return false
	sequence.select_first_level()
	while true:
		change_scene_to_file("res://scenes/levels/playable_level.tscn")
		for _frame in 8:
			await process_frame
		_level = current_scene as PlayableLevel
		if _level == null or _level.score_controller == null:
			return false
		_score = _level.score_controller
		var exit_encounter := _level._exit_encounter
		if exit_encounter != null and _score.plan != null 				and _score.plan.room_targets(exit_encounter.room_id) > 0:
			return true
		if not sequence.select_next_level():
			return false
	return false


func _first_encounter_with_blocks() -> ConfiguredRoomEncounter3D:
	for room_id in _level.room_order:
		var encounter := _level.room_encounters.get(room_id, null) as ConfiguredRoomEncounter3D
		if encounter != null and _score.plan.room_targets(room_id) > 0:
			return encounter
	return null


func _live_windows(node: Node) -> Array[WindowPanel3D]:
	var windows: Array[WindowPanel3D] = []
	if node is WindowPanel3D and not node.is_queued_for_deletion():
		windows.append(node)
	for child in node.get_children():
		windows.append_array(_live_windows(child))
	return windows


## Reproduce lo que hace una bala: el disparo se contabiliza y el cuerpo de la
## zona recibe el impacto.
## Le dispara a la ventana al control que la resuelve. No todas se cierran de un
## tiro ni con la misma zona: la descarga pide cancelar y despues confirmar, asi
## que cuando no hay ningun control que cierre se le pega al que hace avanzar su
## estado y en la vuelta siguiente ya aparece el que cierra.
func _shoot_close_zone(window: WindowPanel3D) -> bool:
	var body := _closing_body(window)
	if body == null:
		body = _advancing_body(window)
	if body == null:
		return false
	_level.round_controller.report_attack_fired()
	_level.round_controller.report_attack_hit()
	body.Hit_Successful(10.0)
	return true


func _closing_body(window: WindowPanel3D) -> WindowHitBody3D:
	for body in window.get_hit_bodies():
		if body.closes_window:
			return body
	return null


## Una zona que cambia el estado de la ventana sin resolverla. Se saltean la
## barra de titulo, que solo la trae al frente, y las trampas, que castigan.
func _advancing_body(window: WindowPanel3D) -> WindowHitBody3D:
	for body in window.get_hit_bodies():
		if body.zone_id != WindowPanel3D.RAISE_ZONE and body.zone_id != "trap":
			return body
	return null


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
