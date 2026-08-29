extends SceneTree

## El arranque del juego: el proyecto abre en la secuencia de arranque, cuya
## primera tarjeta es la misma imagen y el mismo fondo que el boot splash del
## motor (asi del splash a la escena no hay corte); una tecla la saltea; la
## terminal tipea el nombre del estudio sola; al terminar se carga el menu
## principal, que enciende su monitor; y dos teclas seguidas van directo al
## menu.

const BOOT_SCENE := "res://scenes/ui/boot_sequence.tscn"


func _initialize() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func() -> void: _fail("Boot sequence smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	if not _check_project_settings():
		return
	change_scene_to_file(BOOT_SCENE)
	await _wait_frames(3)
	var boot := current_scene as BootSequence
	if boot == null:
		_fail("The game should boot into the boot sequence.")
		return
	if boot.current_card != BootSequence.Card.GODOT:
		_fail("The boot should open with the Godot card.")
		return
	var godot_card := boot.get_node("GodotCard") as ColorRect
	if godot_card == null or not godot_card.visible or not godot_card.color.is_equal_approx(BootSequence.GODOT_BACKGROUND):
		_fail("The Godot card should be visible over the splash background color.")
		return

	# Una tecla saltea la tarjeta en curso.
	_send_key(KEY_SPACE)
	await _wait_frames(2)
	if boot.current_card != BootSequence.Card.STUDIO:
		_fail("A key press should skip the Godot card.")
		return
	if boot.is_typing_done():
		_fail("The studio card should start with nothing typed yet.")
		return

	# La terminal tipea sola dentro de su presupuesto.
	var typing_budget := BootSequence.STUDIO_PAUSE + (BootSequence.TYPE_SECONDS + BootSequence.TYPE_JITTER) * BootSequence.STUDIO_NAME.length() + 0.5
	await create_timer(typing_budget, true, false, true).timeout
	if not boot.is_typing_done():
		_fail("The studio name should be fully typed after %.1f s." % typing_budget)
		return
	if not boot.terminal_text().begins_with(BootSequence.PROMPT + BootSequence.STUDIO_NAME):
		_fail("The terminal should show the prompt and the studio name, got %s." % boot.terminal_text())
		return

	# Termina sola: sostiene, corta a negro y carga el menu principal, que
	# enciende el monitor.
	await create_timer(BootSequence.STUDIO_HOLD + BootSequence.CUT_SECONDS + 0.5, true, false, true).timeout
	await _wait_frames(2)
	var menu := current_scene as MainMenu
	if menu == null:
		_fail("The boot sequence should end in the main menu.")
		return
	if menu.crt == null:
		_fail("The main menu should carry its monitor overlay.")
		return
	if not menu.crt.is_powered_on():
		await menu.crt.powered_on
	if not is_equal_approx(menu.crt.get_power_level(), 1.0):
		_fail("The monitor should be fully on once it reports powered on.")
		return

	# Dos teclas seguidas: directo al menu.
	change_scene_to_file(BOOT_SCENE)
	await _wait_frames(3)
	boot = current_scene as BootSequence
	if boot == null:
		_fail("The boot sequence should load again.")
		return
	boot.skip()
	boot.skip()
	if boot.current_card != BootSequence.Card.DONE:
		_fail("Two skips should end the boot.")
		return
	await create_timer(BootSequence.CUT_SECONDS + 0.3, true, false, true).timeout
	await _wait_frames(2)
	if not (current_scene is MainMenu):
		_fail("Skipping both cards should land on the main menu.")
		return
	print("Boot sequence smoke test passed.")
	quit()


## El motor y la escena tienen que mostrar lo mismo: misma imagen, mismo
## fondo, y el fondo tiene que ser el color de la imagen.
func _check_project_settings() -> bool:
	if str(ProjectSettings.get_setting("application/run/main_scene")) != BOOT_SCENE:
		_fail("The project should start at the boot sequence.")
		return false
	if str(ProjectSettings.get_setting("application/boot_splash/image")) != BootSequence.GODOT_SPLASH_PATH:
		_fail("The engine boot splash should be the same image as the first card.")
		return false
	var background: Color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	if not background.is_equal_approx(BootSequence.GODOT_BACKGROUND):
		_fail("The engine boot splash background should match the first card.")
		return false
	var image := Image.load_from_file(ProjectSettings.globalize_path(BootSequence.GODOT_SPLASH_PATH))
	if image == null:
		_fail("The splash image should be readable.")
		return false
	var corner := image.get_pixel(2, 2)
	if absf(corner.r - background.r) > 0.01 or absf(corner.g - background.g) > 0.01 or absf(corner.b - background.b) > 0.01:
		_fail("The splash background color should be the color of the image itself, got %s." % corner)
		return false
	return true


func _send_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)


func _wait_frames(count: int) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
