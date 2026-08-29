extends SceneTree

## El monitor del menu principal: el vidrio esta por encima de la pila de
## menus y no se interpone a los clics, se enciende desde negro al llegar al
## escritorio, y el filtro se apaga desde los ajustes (y con el filtro apagado
## no hay encendido que esperar).
##
## Los ajustes viven en user://: la prueba se los lleva prestados y los
## devuelve como estaban.

const MAIN_MENU_SCENE := "res://scenes/ui/menus/main_menu.tscn"

var _settings: GameSettings
var _saved: PackedByteArray = PackedByteArray()
var _had_saved := false


func _initialize() -> void:
	create_timer(20.0, true, false, true).timeout.connect(func() -> void: _fail("CRT overlay smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	_settings = root.get_node("Settings") as GameSettings
	_remember()
	_settings.set_crt_enabled(true)
	change_scene_to_file(MAIN_MENU_SCENE)
	await _wait_frames(2)
	var menu := current_scene as MainMenu
	if menu == null or menu.crt == null:
		_fail("The main menu should carry its monitor overlay.")
		return
	var crt := menu.crt
	var menus := root.get_node("MenuStack") as CanvasLayer
	if crt.layer <= menus.layer:
		_fail("The monitor glass should sit above the menu stack, so the options window is behind it too.")
		return
	var screen := crt.get_node_or_null("Screen") as ColorRect
	if screen == null or screen.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("The glass must let clicks through to the desktop.")
		return
	var material := screen.material as ShaderMaterial
	if material == null or material.shader != CrtOverlay.SHADER:
		_fail("The glass should carry the CRT shader.")
		return
	# El primer frame despues de cargar el menu puede ser largo y el encendido
	# ya haber arrancado: lo que importa es que todavia no termino.
	if crt.is_powered_on() or crt.get_power_level() >= 1.0:
		_fail("Arriving at the desktop should find the monitor still turning on.")
		return
	# Se espera el aviso y no un reloj: en headless los frames que siguen a una
	# carga larga reparten el tiempo atrasado y los temporizadores no van a la
	# par de los tweens.
	await crt.powered_on
	if not crt.is_powered_on() or not is_equal_approx(crt.get_power_level(), 1.0):
		_fail("The monitor should be fully on after the power-on animation.")
		return

	# El filtro se apaga y se prende desde los ajustes, en el acto.
	_settings.set_crt_enabled(false)
	await process_frame
	if screen.visible or crt.is_enabled():
		_fail("Turning the filter off should hide the glass.")
		return
	_settings.set_crt_enabled(true)
	await process_frame
	if not screen.visible or not crt.is_enabled():
		_fail("Turning the filter back on should show the glass again.")
		return

	# Sin filtro no hay nada que encender: el escritorio aparece de una.
	_settings.set_crt_enabled(false)
	crt.power_on()
	if not crt.is_powered_on():
		_fail("Without the filter the desktop should show at once.")
		return
	_restore()
	print("CRT overlay smoke test passed.")
	quit()


func _wait_frames(count: int) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


func _remember() -> void:
	_had_saved = FileAccess.file_exists(GameSettings.SETTINGS_PATH)
	if _had_saved:
		_saved = FileAccess.get_file_as_bytes(GameSettings.SETTINGS_PATH)


func _restore() -> void:
	if _settings != null:
		_settings.flush()
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
