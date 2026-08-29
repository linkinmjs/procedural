extends SceneTree

## Recorre el flujo de menus: el juego arranca en el escritorio, los iconos se
## seleccionan de a uno, los que no llevan a ningun lado hacen que la ventana
## pida atencion, el menu de inicio abre y cierra, el icono del juego abre su
## ventana, jugar carga el nivel de la campaña, la pausa detiene el arbol y
## suelta el mouse, y cerrarla devuelve todo como estaba.
##
## Los controles guardan la clave de traduccion en su texto, no la frase, asi
## que la prueba busca por clave y corre igual en cualquier idioma.

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
	var play_button := _find_button(menu, "MENU_PLAY")
	if play_button == null or _find_button(menu, "MENU_QUIT") == null:
		_fail("The main menu window should offer buttons to play and to quit.")
		return
	var desktop_icon := _find_icon(menu, "procedural.exe")
	if desktop_icon == null:
		_fail("The desktop should have an icon for the game.")
		return
	var recycle_icon := _find_icon(menu, "DESKTOP_RECYCLE")
	if recycle_icon == null:
		_fail("The desktop should have the decorative icons.")
		return

	# La seleccion es de a uno: elegir un icono suelta el anterior.
	desktop_icon.select()
	recycle_icon.select()
	await _wait_frames(2)
	if desktop_icon.is_selected() or not recycle_icon.is_selected():
		_fail("Selecting a desktop icon should deselect the previous one.")
		return

	# El ejecutable del escritorio abre la ventana del juego, no la partida.
	menu.close()
	await _wait_frames(2)
	if menu.window.visible:
		_fail("Closing the window should leave the desktop alone.")
		return

	# Los iconos que no llevan a ningun lado devuelven al jugador a la ventana:
	# su boton de la barra pide atencion en vez de no hacer nada.
	recycle_icon.activate()
	await _wait_frames(2)
	if not menu.taskbar.is_asking_attention(menu.task_button):
		_fail("Opening a dead-end icon should make the game window ask for attention.")
		return

	desktop_icon.activate()
	await _wait_frames(2)
	if not menu.window.visible:
		_fail("Opening the game icon should bring its window back.")
		return
	if menu.taskbar.is_asking_attention(menu.task_button):
		_fail("Opening the window should clear the pending notice.")
		return

	# El boton de inicio abre y cierra el menu, como en un escritorio de verdad.
	menu.taskbar.start_button.button_pressed = true
	await _wait_frames(2)
	if not menu.start_menu.visible:
		_fail("The start button should open the start menu.")
		return
	menu.taskbar.start_button.button_pressed = false
	await _wait_frames(2)
	if menu.start_menu.visible:
		_fail("Releasing the start button should close the start menu.")
		return

	play_button.pressed.emit()
	await _wait_for_level()
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
	# Entrar al nivel lo presenta; reintentar, mas abajo, no.
	if not level.announced:
		_fail("Entering a level from the menu should announce it.")
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
	var abandon_button := _find_button(pause_menu, "MENU_ABANDON")
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
	_find_button(pause_menu, "MENU_RESUME").pressed.emit()
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
	# Volver a empezar tiene que costar nada: nadie mira el intertitulo dos veces.
	if reloaded.announced:
		_fail("Restarting should not announce the level again.")
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


func _find_icon(node: Node, text: String) -> DesktopIcon:
	var icon := node as DesktopIcon
	if icon != null:
		for child in icon.find_children("", "Label", true, false):
			if (child as Label).text == text:
				return icon
	for child in node.get_children():
		var found := _find_icon(child, text)
		if found != null:
			return found
	return null


func _find_button(node: Node, text: String) -> Button:
	var button := node as Button
	if button != null and button.text == text:
		return button
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


## Entrar al nivel pasa por la precarga, que reparte las cargas por
## presupuesto de frame: cuantos frames tarda depende del disco y de la cache
## (entre 8 y 14 en la misma maquina). Se espera al nivel, con tope.
func _wait_for_level() -> void:
	for _frame in 60:
		await _wait_frames(1)
		if current_scene is PlayableLevel:
			return


func _wait_frames(count: int) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
