extends SceneTree

## Recorre la progresion desde el escritorio: la cabecera del perfil y el chip
## de la bandeja, el selector de niveles con su desbloqueo por completar, jugar
## un nivel elegido, la posicion de campaña recordada, la vitrina de Mi PC y
## la cola de globos de aviso.
##
## Respalda el perfil antes y lo devuelve al terminar, pase lo que pase.

const MAIN_MENU_SCENE := "res://scenes/ui/menus/main_menu.tscn"

var _menus: Node
var _sequence: Node
var _notices: Node
var _profile: GameProfile
var _catalog_ids := PackedStringArray()
var _had_saved := false
var _saved := PackedByteArray()


func _initialize() -> void:
	create_timer(40.0, true, false, true).timeout.connect(func() -> void: _fail("Level select smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	_menus = root.get_node("MenuStack")
	_sequence = root.get_node("LevelSequence")
	_notices = root.get_node("Notices")
	_profile = root.get_node("PlayerProfile") as GameProfile
	_remember()
	_profile.reset()
	_catalog_ids = _sequence.get_level_ids()
	if _catalog_ids.size() < 2:
		_fail("The catalog should have at least two levels to test unlocking.")
		return
	_sequence.select_first_level()
	change_scene_to_file(MAIN_MENU_SCENE)
	await _wait_frames(4)
	var menu := current_scene as MainMenu
	if menu == null:
		_fail("The game should boot into the main menu.")
		return
	if not _check_header(menu):
		return
	if not await _check_locked_selector(menu):
		return
	if not await _check_unlock_and_play(menu):
		return
	if not await _check_position_remembered():
		return
	if not await _check_my_computer():
		return
	if not await _check_notices():
		return
	_restore()
	print("Level select smoke test passed.")
	quit()


## La ventana del menu muestra el nivel del jugador, y la barra de tareas
## repite su nombre en la bandeja.
func _check_header(menu: MainMenu) -> bool:
	if menu.profile_header == null or not menu.profile_header.visible:
		_fail("The main menu window should show the profile header.")
		return false
	if menu.level_chip == null or menu.level_chip.text != _profile.get_level_name():
		_fail("The taskbar tray should name the player level.")
		return false
	var select_button := _find_button(menu, "MENU_SELECT_LEVEL")
	if select_button == null or select_button.disabled:
		_fail("The level select button should be enabled.")
		return false
	return true


## Con un perfil nuevo solo el primer nivel se puede jugar.
func _check_locked_selector(menu: MainMenu) -> bool:
	menu.open_level_select()
	await _wait_frames(2)
	var select := _menus.top() as LevelSelectMenu
	if select == null or select.skin != MenuScreen.MenuSkin.DESKTOP:
		_fail("The levels icon should open the level select as a desktop window.")
		return false
	if select.row_count() != _catalog_ids.size():
		_fail("The level select should list every level of the catalog.")
		return false
	var buttons := select.play_buttons()
	if buttons[0].disabled or not buttons[1].disabled:
		_fail("A fresh profile can play the first level only.")
		return false
	_menus.close_all()
	await _wait_frames(2)
	# El icono del escritorio abre lo mismo.
	var icon := _find_icon(menu, "DESKTOP_LEVELS")
	if icon == null:
		_fail("The desktop should have the levels icon.")
		return false
	icon.activate()
	await _wait_frames(2)
	if _menus.top() as LevelSelectMenu == null:
		_fail("The levels icon should open the level select.")
		return false
	_menus.close_all()
	await _wait_frames(2)
	return true


## Completar el primer nivel abre el segundo, y jugarlo desde el selector
## carga ese nivel y no el primero.
func _check_unlock_and_play(menu: MainMenu) -> bool:
	_profile.begin_run(_catalog_ids[0])
	_profile.record_run(_catalog_ids[0], _fake_summary())
	if not _sequence.is_unlocked(1):
		_fail("Completing the first level should unlock the second.")
		return false
	menu.open_level_select()
	await _wait_frames(2)
	var select := _menus.top() as LevelSelectMenu
	var buttons := select.play_buttons()
	if buttons[1].disabled:
		_fail("The second level should be playable once the first is completed.")
		return false
	if _catalog_ids.size() > 2 and not buttons[2].disabled:
		_fail("Levels past the next one should stay locked.")
		return false
	buttons[1].pressed.emit()
	await _wait_frames(10)
	var level := current_scene as PlayableLevel
	if level == null or level.level_data.is_empty():
		_fail("Playing from the level select should load a level.")
		return false
	if str(level.level_data.id) != _catalog_ids[1]:
		_fail("The level select should load the chosen level.")
		return false
	if _sequence.get_current_number() != 2:
		_fail("The sequence should point at the chosen level.")
		return false
	return true


## La posicion de campaña queda en el perfil y el menu principal la muestra.
func _check_position_remembered() -> bool:
	if _profile.get_last_played_id() != _catalog_ids[1]:
		_fail("The profile should remember the last played level.")
		return false
	_sequence.return_to_main_menu()
	await _wait_frames(6)
	var menu := current_scene as MainMenu
	if menu == null:
		_fail("Returning should land on the main menu.")
		return false
	var expected := tr("MENU_LEVEL_POSITION").format({"position": "2 / %d" % _catalog_ids.size()})
	if _find_label(menu, expected) == null:
		_fail("The main menu should show the remembered campaign position.")
		return false
	return true


## Mi PC lista el catalogo entero de logros y marca los ganados.
func _check_my_computer() -> bool:
	var menu := current_scene as MainMenu
	menu.open_my_computer()
	await _wait_frames(2)
	var vitrine := _menus.top() as MyComputerMenu
	if vitrine == null or vitrine.skin != MenuScreen.MenuSkin.DESKTOP:
		_fail("My PC should open as a desktop window.")
		return false
	var tiles := vitrine.badge_tiles()
	if tiles.size() != AchievementCatalog.all().size():
		_fail("My PC should show every badge of the catalog.")
		return false
	var earned := 0
	for tile in tiles:
		if tile.earned:
			earned += 1
		elif tile.modulate == Color(1, 1, 1, 1):
			_fail("Locked badges should be greyed out.")
			return false
	if earned != _profile.badge_count():
		_fail("My PC should mark exactly the earned badges.")
		return false
	_menus.close_all()
	await _wait_frames(2)
	return true


## Los globos salen de a uno: el segundo espera a que el primero se vaya.
func _check_notices() -> bool:
	_notices.notice_seconds = 0.2
	# Jugar el nivel de verdad ya desbloqueo logros en vivo, y sus globos
	# pueden seguir en pantalla: se espera a que la cola quede vacia.
	for _attempt in 60:
		if not _notices.is_showing() and _notices.pending_count() == 0:
			break
		await create_timer(0.2).timeout
	if _notices.is_showing():
		_fail("Live notices should drain on their own.")
		return false
	_notices.show_badge(AchievementCatalog.find("kill_9"))
	_notices.show_badge(AchievementCatalog.find("defrag_1"))
	await _wait_frames(2)
	if not _notices.is_showing() or _notices.pending_count() != 1:
		_fail("Two notices should show one at a time and queue the other.")
		return false
	await create_timer(0.8).timeout
	if not _notices.is_showing() or _notices.pending_count() != 0:
		_fail("The second notice should follow the first.")
		return false
	await create_timer(0.8).timeout
	if _notices.is_showing():
		_fail("Notices should leave on their own.")
		return false
	return true


func _fake_summary() -> Dictionary:
	return {
		"completed": true,
		"reason": "exit_reached",
		"total": 5000,
		"ceiling": 8000,
		"ratio": 0.625,
		"rank": {"letter": "C", "label": "USER", "index": 2},
		"best_multiplier": 3.0,
		"best_chain": 10,
		"best_bank": 1500,
		"no_damage": false,
		"hits": 20,
		"attacks": 25,
		"accuracy_percent": 80.0,
		"record": {"is_new": false, "had_previous": false, "previous": 0, "delta": 0},
	}


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


func _find_label(node: Node, text: String) -> Label:
	var label := node as Label
	if label != null and label.text == text:
		return label
	for child in node.get_children():
		var found := _find_label(child, text)
		if found != null:
			return found
	return null


func _wait_frames(count: int) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


## El perfil se devuelve tambien cuando la prueba falla: un test que rompe no
## tiene por que ademas borrarle el progreso a quien lo corrio.
func _remember() -> void:
	_profile.flush()
	_had_saved = FileAccess.file_exists(_profile.storage_path)
	if _had_saved:
		_saved = FileAccess.get_file_as_bytes(_profile.storage_path)


func _restore() -> void:
	if not _had_saved:
		if FileAccess.file_exists(_profile.storage_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_profile.storage_path))
		return
	var file := FileAccess.open(_profile.storage_path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_saved)


func _fail(message: String) -> void:
	_restore()
	push_error(message)
	quit(1)
