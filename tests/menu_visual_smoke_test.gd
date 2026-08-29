extends Node

## Revisa como se ven los menus sin abrir el editor: el escritorio del menu
## principal, el aviso pendiente en la barra de tareas, el menu de inicio, un
## globo de logro sobre el escritorio, la vitrina de Mi PC, el selector de
## niveles, la pausa sobre el nivel y la pantalla de resultados con un desglose
## de ejemplo. Guarda ocho PNG en .godot/.

const MAIN_MENU_SCENE := preload("res://scenes/ui/menus/main_menu.tscn")


func _ready() -> void:
	var menus := get_node("/root/MenuStack")

	var main_menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	add_child(main_menu)
	# El monitor encendido del todo: las capturas no dependen del reloj del
	# encendido.
	main_menu.crt.settle()
	await _drawn()
	if not _inside_viewport(main_menu.window):
		_fail("The main menu window should sit inside the reference viewport.")
		return
	if not _save("res://.godot/menu-main.png"):
		return

	# Escritorio con un aviso pendiente: la ventana esta cerrada y su boton de la
	# barra queda encendido, que es como los iconos sin destino senalan de vuelta
	# al juego.
	main_menu.close()
	main_menu.nudge_to_window()
	await _drawn()
	if not main_menu.taskbar.is_asking_attention(main_menu.task_button):
		_fail("The taskbar button should hold the pending notice.")
		return
	if not _save("res://.godot/menu-notify.png"):
		return
	main_menu.open_window()

	# El menu de inicio cuelga sobre la barra y es la otra puerta de entrada a
	# las mismas acciones que ofrece la ventana.
	main_menu.taskbar.start_button.button_pressed = true
	await _drawn()
	if not main_menu.start_menu.visible:
		_fail("The start button should open the start menu.")
		return
	if not _inside_viewport(main_menu.start_menu):
		_fail("The start menu should sit inside the reference viewport.")
		return
	if not _save("res://.godot/menu-start.png"):
		return
	main_menu.taskbar.start_button.button_pressed = false

	# El globo de logro sobre el escritorio, pegado a la bandeja.
	var notices := get_node("/root/Notices")
	notices.notice_seconds = 30.0
	notices.show_badge(AchievementCatalog.find("kill_9"))
	await _drawn()
	await get_tree().create_timer(HudStyle.DUR_SLIDE_IN).timeout
	await _drawn()
	if not notices.is_showing():
		_fail("The badge notice should be on screen.")
		return
	if not _save("res://.godot/menu-notice-badge.png"):
		return
	notices.current_balloon().play_out()
	await get_tree().create_timer(HudStyle.DUR_HIDE + 0.1).timeout

	# Mi PC: la vitrina con el catalogo entero, casi todo por ganar.
	main_menu.open_my_computer()
	await _drawn()
	var vitrine := menus.top() as MyComputerMenu
	if vitrine == null or not _inside_viewport(vitrine.window):
		_fail("The My PC window should sit inside the reference viewport.")
		return
	if not _save("res://.godot/menu-my-pc.png"):
		return
	menus.close_all()

	# El selector de niveles con la piel de Windows.
	main_menu.open_level_select()
	await _drawn()
	var select := menus.top() as LevelSelectMenu
	if select == null or not _inside_viewport(select.window):
		_fail("The level select window should sit inside the reference viewport.")
		return
	if not _save("res://.godot/menu-level-select.png"):
		return
	menus.close_all()
	main_menu.queue_free()

	menus.open(PauseMenu.create("Nivel 1", "1 / 3", 12400))
	await _drawn()
	var pause_menu := menus.top() as PauseMenu
	if pause_menu == null or not _inside_viewport(pause_menu.window):
		_fail("The pause window should sit inside the reference viewport.")
		return
	if not _save("res://.godot/menu-pause.png"):
		return
	menus.close_all()

	menus.open(LevelResults.create(_fake_summary(), "Nivel 1", true, _fake_report()))
	var results := menus.top() as LevelResults
	results.reveal_all()
	await _drawn()
	if not _inside_viewport(results.window):
		_fail("The results window should sit inside the reference viewport.")
		return
	if not _save("res://.godot/menu-results.png"):
		return
	menus.close_all()
	print("Menu visual smoke test passed.")
	get_tree().quit()


## Resumen con todas las filas posibles: bonos, techo, cadena y record previo.
func _fake_summary() -> Dictionary:
	return {
		"completed": true,
		"reason": "exit_reached",
		"total": 17890,
		"ceiling": 22400,
		"ratio": 0.798,
		"rank": {"letter": "A", "label": "ADMIN", "index": 1},
		# Los rotulos salen del mismo lugar que en la partida, asi que la vista
		# muestra el desglose en el idioma en que se juega y no uno fijo.
		"bonuses": [
			{"label": tr("BONUS_AMMO_LEFT").format({"amount": 34}), "points": 170},
			{"label": tr("BONUS_TIME_LEFT").format({"seconds": 22}), "points": 220},
			{"label": tr("BONUS_NO_DAMAGE"), "points": 2000},
		],
		"best_multiplier": 6.0,
		"best_chain": 18,
		"best_bank": 6400,
		"hits": 52,
		"attacks": 61,
		"accuracy_percent": 85.2,
		"no_damage": true,
		"record": {"previous": 15240, "delta": 2650, "is_new": true, "had_previous": true},
	}


## Reporte del perfil con todas las filas posibles: XP, subida de nivel,
## logros nuevos y nivel desbloqueado.
func _fake_report() -> Dictionary:
	return {
		"level_id": "nivel-1",
		"completed": true,
		"first_clear": true,
		"xp_earned": 1240,
		"xp_events": [],
		"level_before": 3,
		"level_name_before": "486",
		"level_after": 4,
		"leveled_up": true,
		"level_name": "PENTIUM",
		"badges": [AchievementCatalog.find("firewall_up"), AchievementCatalog.find("defrag_1")],
		"progress": {"remaining": 1380, "next_name": "PENTIUM II"},
	}


func _drawn() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _inside_viewport(control: Control) -> bool:
	var bounds := get_viewport().get_visible_rect()
	var origin := control.global_position
	var corner := origin + control.size
	return origin.x >= 0.0 and origin.y >= 0.0 and corner.x <= bounds.size.x and corner.y <= bounds.size.y


func _save(path: String) -> bool:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_fail("The active renderer cannot capture the menu preview image.")
		return false
	if image.save_png(path) != OK:
		_fail("Could not save %s." % path)
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
