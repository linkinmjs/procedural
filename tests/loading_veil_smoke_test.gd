extends SceneTree

## Entrar a un nivel desde la secuencia pasa por el velo de carga: aparece al
## instante, sobrevive al cambio de escena, se retira solo cuando el nivel ya
## esta construido y no queda huerfano al volver al menu.

const MAIN_MENU_SCENE := "res://scenes/ui/menus/main_menu.tscn"

var _sequence: Node


func _initialize() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func() -> void: _fail("Loading veil smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	_sequence = root.get_node("LevelSequence")
	_sequence.select_first_level()
	change_scene_to_file(MAIN_MENU_SCENE)
	await _wait_frames(3)
	if LoadingVeil.current(self) != null:
		_fail("No veil should exist before playing.")
		return

	_sequence.play_current_level()
	await process_frame
	var veil := LoadingVeil.current(self)
	if veil == null or not veil.is_inside_tree():
		_fail("Playing a level should raise the loading veil on the next frame.")
		return
	# El velo tiene que seguir ahi hasta que el nivel este construido.
	var frames := 0
	while not (current_scene is PlayableLevel and (current_scene as PlayableLevel).is_built) and frames < 40:
		if not is_instance_valid(veil):
			_fail("The veil should outlive the scene change and the level build.")
			return
		await process_frame
		frames += 1
	if not (current_scene is PlayableLevel):
		_fail("The level should be the current scene after loading.")
		return
	if not is_instance_valid(veil) or not veil.is_inside_tree():
		_fail("The veil should still cover the level on the frame it finishes building.")
		return
	# Un par de frames despues se retira (con un fundido corto).
	await _wait_frames(PlayableLevel.VEIL_RELEASE_FRAMES + 2)
	await create_timer(LoadingVeil.FADE_OUT + 0.2, true, false, true).timeout
	if LoadingVeil.current(self) != null:
		_fail("The veil should be gone once the level has been visible for a couple of frames.")
		return

	_sequence.return_to_main_menu()
	await _wait_frames(4)
	if LoadingVeil.current(self) != null:
		_fail("Returning to the menu must not leave a veil behind.")
		return
	_sequence.select_first_level()
	print("Loading veil smoke test passed.")
	quit()


func _wait_frames(count: int) -> void:
	for _frame in count:
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
