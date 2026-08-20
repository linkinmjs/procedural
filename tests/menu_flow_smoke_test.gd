extends SceneTree

## Recorre el flujo de menus: el juego arranca en el escritorio, jugar carga el
## nivel de la campaña, la pausa detiene el arbol y suelta el mouse, y cerrarla
## devuelve todo como estaba.

const MAIN_MENU_SCENE := "res://scenes/ui/menus/main_menu.tscn"

var _menus: Node


func _initialize() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func() -> void: _fail("Menu flow smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	_menus = root.get_node("MenuStack")
	root.get_node("LevelSequence").select_first_level()
	change_scene_to_file(MAIN_MENU_SCENE)
	await _wait_frames(4)
	var menu := current_scene as MainMenu
	if menu == null:
		_fail("The game should boot into the main menu.")
		return
	var play_button := _find_button(menu, "JUGAR")
	if play_button == null:
		_fail("The main menu should offer a button to play.")
		return
	if _find_button(menu, "SALIR") == null:
		_fail("The main menu should offer a button to quit.")
		return

	play_button.pressed.emit()
	await _wait_frames(8)
	var level := current_scene as PlayableLevel
	if level == null or level.level_data.is_empty():
		_fail("Playing from the main menu should load the campaign level.")
		return
	if _menus.is_open():
		_fail("Loading a level should leave no menu open.")
		return
	if paused:
		_fail("A level in progress should not start paused.")
		return

	if not await _open_pause():
		return
	if not paused:
		_fail("The pause menu should stop the tree.")
		return
	if not _mouse_mode_is(Input.MOUSE_MODE_VISIBLE):
		_fail("The pause menu should release the mouse.")
		return
	var pause_menu := _menus.top() as PauseMenu
	if pause_menu == null:
		_fail("The open menu should be the pause menu.")
		return

	# Abandonar es destructivo, asi que pregunta antes en vez de salir directo.
	var abandon_button := _find_button(pause_menu, "ABANDONAR NIVEL")
	if abandon_button == null:
		_fail("The pause menu should offer to abandon the level.")
		return
	abandon_button.pressed.emit()
	await _wait_frames(2)
	if _menus.top() as ConfirmMenu == null:
		_fail("Abandoning a level should ask for confirmation.")
		return
	_menus.close_top()
	await _wait_frames(2)
	if _menus.top() as PauseMenu == null:
		_fail("Cancelling the confirmation should leave the pause menu open.")
		return

	# Reanudar devuelve el control al nivel: sin menus, sin pausa y con el mouse
	# capturado otra vez.
	_find_button(pause_menu, "REANUDAR").pressed.emit()
	await _wait_frames(2)
	if _menus.is_open():
		_fail("Resuming should close the pause menu.")
		return
	if paused:
		_fail("Resuming should let the tree run again.")
		return
	if not _mouse_mode_is(Input.MOUSE_MODE_CAPTURED):
		_fail("Resuming should capture the mouse again.")
		return

	if not await _restart(level):
		return
	print("Menu flow smoke test passed.")
	quit()


## La pausa se abre con la tecla, no llamando al metodo: lo que hay que probar
## es que la accion siga llegando al nivel.
func _open_pause() -> bool:
	_press(KEY_ESCAPE)
	await _wait_frames(3)
	if _menus.is_open():
		return true
	_fail("The pause action should open the pause menu.")
	return false


## Reintentar recarga el nivel sin preguntar nada.
func _restart(level: PlayableLevel) -> bool:
	_press(KEY_BACKSPACE)
	await _wait_frames(10)
	var reloaded := current_scene as PlayableLevel
	if reloaded == null or reloaded == level:
		_fail("The restart action should reload the level.")
		return false
	if _menus.is_open() or paused:
		_fail("A restarted level should run with no menu open.")
		return false
	return true


## Sin ventana no hay mouse que capturar: el servidor headless informa siempre
## el modo visible, asi que ahi el estado del mouse no se puede verificar.
func _mouse_mode_is(mode: Input.MouseMode) -> bool:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE):
		return true
	return Input.get_mouse_mode() == mode


func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _find_button(node: Node, text: String) -> Button:
	var button := node as Button
	if button != null and button.text == text:
		return button
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func _wait_frames(count: int) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
