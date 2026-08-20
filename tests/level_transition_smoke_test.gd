extends SceneTree

## Al pisar la sala marcada como salida el nivel se cierra y, tras la pausa
## configurada, aparece la pantalla de resultados. Desde ahi avanzar carga el
## nivel siguiente con el jugador en su sala de inicio; si era el ultimo de la
## campania, los resultados no ofrecen a donde avanzar.

const RESULTS_DELAY := 0.25

var _sequence: Node


func _initialize() -> void:
	create_timer(20.0, true, false, true).timeout.connect(func() -> void: _fail("Level transition smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	_sequence = root.get_node("LevelSequence")
	_sequence.select_first_level()
	change_scene_to_file("res://scenes/levels/playable_level.tscn")
	await _wait_frames(8)
	var level := current_scene as PlayableLevel
	if level == null or level.level_data.is_empty():
		_fail("The transition test should start on the first level of the sequence.")
		return
	level.results_delay = RESULTS_DELAY
	# La escena anterior se libera al avanzar, asi que su identidad se guarda
	# antes de mostrar los resultados.
	var previous_id := str(level.level_data.id)

	# Salir de la sala de inicio arranca la ronda; pisar la salida la cierra.
	level.player.global_position = Vector3(0.0, 1.0, 400.0)
	await _wait_frames(6)
	var exit_room := LevelDefinitionLoader.get_exit_room(level.level_data)
	if exit_room.is_empty():
		_fail("The level should declare an exit room.")
		return
	var exit_node := level.room_nodes[str(exit_room.id)] as Node3D
	level.player.global_position = exit_node.global_position + Vector3(0.0, 1.0, 0.0)
	await _wait_frames(6)
	if level.round_controller.is_running:
		_fail("Reaching the exit room should close the round.")
		return
	if current_scene != level:
		_fail("The level should not change on its own when the round closes.")
		return

	var menus := root.get_node("MenuStack")
	var expects_next: bool = _sequence.has_next_level()
	await create_timer(RESULTS_DELAY + 0.2).timeout
	await _wait_frames(8)
	var results := menus.top() as LevelResults
	if results == null:
		_fail("Closing the level should show its results.")
		return
	if current_scene != level:
		_fail("The results should open over the level instead of replacing it.")
		return
	results.reveal_all()
	if not expects_next:
		menus.close_all()
		print("Level transition smoke test passed.")
		quit()
		return

	# Avanzar es una decision del jugador: el nivel siguiente carga recien
	# cuando la pantalla de resultados lo pide.
	results.advance()
	await _wait_frames(8)
	if menus.is_open() or paused:
		_fail("Advancing should close the results and let the next level run.")
		return
	# El cambio de escena se difiere y el nivel nuevo se construye entero al
	# entrar al arbol, asi que puede tardar mas de un puñado de cuadros.
	for _attempt in 10:
		if current_scene != level:
			break
		await _wait_frames(4)
	var next_level := current_scene as PlayableLevel
	if next_level == null or not is_instance_valid(next_level):
		_fail("The transition should have loaded the next level scene.")
		return
	if str(next_level.level_data.id) == previous_id:
		_fail("The sequence should advance to a different level.")
		return
	if _sequence.get_position_text() != "2 / %d" % _sequence.get_level_count():
		_fail("The level sequence position should follow the automatic advance.")
		return
	if not _check_round_start_state(next_level):
		return
	if not _check_spawn(next_level):
		return
	_sequence.select_first_level()
	print("Level transition smoke test passed.")
	quit()


## La ronda del nivel nuevo queda en STANDBY solo si su sala de inicio no tiene
## nada que hacer. Si trae bloques, el jugador ya esta peleando y el cronometro
## tiene que correr: en STANDBY sus disparos y su daño no se contarian.
func _check_round_start_state(level: PlayableLevel) -> bool:
	var start_room := LevelDefinitionLoader.get_start_room(level.level_data)
	var plan := level.score_controller.plan
	var targets := plan.room_targets(str(start_room.get("id", ""))) if plan != null else 0
	if targets > 0 and not level.round_controller.is_running:
		_fail("A start room with targets should start the round instead of holding it on standby.")
		return false
	if targets <= 0 and level.round_controller.is_running:
		_fail("An empty start room should arm the round on standby, not start it.")
		return false
	return true


## El jugador reaparece en la sala de inicio del nivel nuevo.
func _check_spawn(level: PlayableLevel) -> bool:
	var start_room := LevelDefinitionLoader.get_start_room(level.level_data)
	var start_center: Vector3 = (level.room_nodes[str(start_room.id)] as Node3D).global_position
	var offset := Vector2(level.player.global_position.x - start_center.x, level.player.global_position.z - start_center.z)
	if offset.length() > 1.0:
		_fail("The player should respawn at the start room of the next level.")
		return false
	return true


func _wait_frames(count: int) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
