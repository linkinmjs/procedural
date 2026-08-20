extends SceneTree

## Prueba las opciones: que cada ajuste se aplique donde corresponde, que
## sobreviva a cerrar y volver a abrir el menu, y que quede escrito en disco.
##
## Los valores se tocan por el autoload y no moviendo controles del menu: lo que
## importa es que el ajuste llegue a AudioServer, TranslationServer y al jugador,
## no por que camino de la interfaz se pidio.

const MAIN_MENU_SCENE := "res://scenes/ui/menus/main_menu.tscn"

var _menus: Node
var _settings: GameSettings
## Los ajustes viven en user://, que es el archivo de verdad del jugador. La
## prueba se lo lleva prestado y lo devuelve como estaba.
var _saved: PackedByteArray = PackedByteArray()
var _had_saved := false


func _initialize() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func() -> void: _fail("Options smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	_menus = root.get_node("MenuStack")
	_settings = root.get_node("Settings") as GameSettings
	if _settings == null:
		_fail("The settings autoload should be available.")
		return

	_remember()
	if not _check_buses():
		return
	if not await _check_menu_opens():
		return
	if not _check_volume():
		return
	if not _check_locale():
		return
	if not _check_sensitivity():
		return
	if not _check_persistence():
		return
	if not _check_deferred_save():
		return
	_restore()
	print("Options smoke test passed.")
	quit()


## Los tres buses tienen que existir con el nombre que el menu espera, o los
## sliders moverian volumenes que no van a ningun lado.
func _check_buses() -> bool:
	for bus_variant in GameSettings.AUDIO_BUSES:
		if AudioServer.get_bus_index(str(bus_variant)) < 0:
			_fail("The audio bus %s should exist in the bus layout." % bus_variant)
			return false
	return true


## Se abre desde el escritorio, con la piel de Windows, y se cierra volviendo al
## menu principal sin dejar nada en la pila.
func _check_menu_opens() -> bool:
	change_scene_to_file(MAIN_MENU_SCENE)
	await _wait_frames(4)
	var menu := current_scene as MainMenu
	if menu == null:
		_fail("The game should boot into the main menu.")
		return false
	menu.open_options()
	await _wait_frames(2)
	var options := _menus.top() as OptionsMenu
	if options == null:
		_fail("The options button should open the options menu.")
		return false
	if options.skin != MenuScreen.MenuSkin.DESKTOP:
		_fail("Options opened from the desktop should wear the Windows skin.")
		return false
	options.close()
	await _wait_frames(2)
	if _menus.is_open():
		_fail("Closing the options menu should leave the stack empty.")
		return false
	return true


func _check_volume() -> bool:
	_settings.set_volume("SFX", 0.5)
	var index := AudioServer.get_bus_index("SFX")
	if not is_equal_approx(_settings.get_volume("SFX"), 0.5):
		_fail("The settings should remember the volume that was set.")
		return false
	if AudioServer.is_bus_mute(index):
		_fail("Half volume should not mute the bus.")
		return false
	# Silencio total apaga el bus en vez de dejarlo sonando por debajo de lo
	# audible, que es lo que pasaria con un volumen muy chico pero no nulo.
	_settings.set_volume("SFX", 0.0)
	if not AudioServer.is_bus_mute(index):
		_fail("Zero volume should mute the bus.")
		return false
	_settings.set_volume("SFX", 1.0)
	if AudioServer.is_bus_mute(index):
		_fail("Raising the volume again should unmute the bus.")
		return false
	return true


func _check_locale() -> bool:
	_settings.set_locale("pt")
	if TranslationServer.get_locale().substr(0, 2) != "pt":
		_fail("Choosing a language should change the translation server locale.")
		return false
	if tr("MENU_PLAY") != "JOGAR":
		_fail("The new locale should be the one that translates the interface.")
		return false
	_settings.set_locale("es")
	if tr("MENU_PLAY") != "JUGAR":
		_fail("Going back to Spanish should translate the interface again.")
		return false
	# Un idioma que no existe no puede dejar el juego sin traducir.
	_settings.set_locale("de")
	if _settings.get_locale() != "es":
		_fail("An unsupported locale should be ignored.")
		return false
	# Ni dejar al selector sin saber en que posicion esta: si el idioma del
	# sistema no esta traducido, el que se informa tiene que ser uno de la lista.
	if not GameSettings.LOCALES.has(_settings.get_locale()):
		_fail("The reported locale should always be one the game speaks.")
		return false
	return true


## La sensibilidad la lee el jugador del autoload, y cambiarla con la partida en
## curso tiene que llegarle sin recargar el nivel.
func _check_sensitivity() -> bool:
	_settings.set_sensitivity(GameSettings.MAX_SENSITIVITY * 2.0)
	if not is_equal_approx(_settings.get_sensitivity(), GameSettings.MAX_SENSITIVITY):
		_fail("The sensitivity should be clamped to the playable range.")
		return false
	if _settings.get_sensitivity_percent() != 100:
		_fail("The top of the range should read as 100.")
		return false
	_settings.set_sensitivity(GameSettings.MIN_SENSITIVITY)
	if _settings.get_sensitivity_percent() != 0:
		_fail("The bottom of the range should read as 0.")
		return false
	_settings.set_sensitivity(GameSettings.DEFAULT_SENSITIVITY)
	return true


## Lo elegido tiene que sobrevivir a cerrar el juego, que es todo el sentido de
## tener un menu de opciones.
##
## La escritura es diferida, para no reescribir el archivo en cada paso de un
## slider, asi que la prueba la fuerza en vez de esperar el retardo.
func _check_persistence() -> bool:
	_settings.set_volume("Music", 0.35)
	_settings.set_sensitivity(0.002)
	_settings.flush()
	var config := ConfigFile.new()
	if config.load(GameSettings.SETTINGS_PATH) != OK:
		_fail("Changing a setting should write the settings file.")
		return false
	if not is_equal_approx(float(config.get_value("audio", "Music", 1.0)), 0.35):
		_fail("The saved file should carry the volume that was set.")
		return false
	if not is_equal_approx(float(config.get_value("input", "sensitivity", 0.0)), 0.002):
		_fail("The saved file should carry the sensitivity that was set.")
		return false
	if str(config.get_value("game", "locale", "")) != "es":
		_fail("The saved file should carry the chosen language.")
		return false
	return true


## Guardar diferido no puede convertirse en no guardar: el ultimo valor tocado
## tiene que estar en el archivo aunque no se haya cumplido la espera.
func _check_deferred_save() -> bool:
	_settings.set_volume("Master", 0.6)
	var config := ConfigFile.new()
	config.load(GameSettings.SETTINGS_PATH)
	if is_equal_approx(float(config.get_value("audio", "Master", 1.0)), 0.6):
		_fail("The save should be deferred instead of hitting the disk on every step.")
		return false
	_settings.flush()
	config = ConfigFile.new()
	config.load(GameSettings.SETTINGS_PATH)
	if not is_equal_approx(float(config.get_value("audio", "Master", 1.0)), 0.6):
		_fail("Flushing should write the pending change.")
		return false
	return true


func _wait_frames(count: int) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


## Se devuelve tambien cuando la prueba falla: un test que rompe no tiene por
## que ademas dejarle el volumen cambiado a quien lo corrio.
func _remember() -> void:
	_had_saved = FileAccess.file_exists(GameSettings.SETTINGS_PATH)
	if _had_saved:
		_saved = FileAccess.get_file_as_bytes(GameSettings.SETTINGS_PATH)


func _restore() -> void:
	if not _had_saved:
		DirAccess.remove_absolute(GameSettings.SETTINGS_PATH)
		return
	var file := FileAccess.open(GameSettings.SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_saved)


func _fail(message: String) -> void:
	_restore()
	push_error(message)
	quit(1)
