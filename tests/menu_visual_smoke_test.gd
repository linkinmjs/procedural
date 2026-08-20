extends Node

## Revisa como se ven los menus sin abrir el editor: el escritorio del menu
## principal, la pausa sobre el nivel y la pantalla de resultados con un
## desglose de ejemplo. Guarda tres PNG en .godot/.

const MAIN_MENU_SCENE := preload("res://scenes/ui/menus/main_menu.tscn")


func _ready() -> void:
	var menus := get_node("/root/MenuStack")

	var main_menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	add_child(main_menu)
	await _drawn()
	if not _inside_viewport(main_menu.window):
		_fail("The main menu window should sit inside the reference viewport.")
		return
	if not _save("res://.godot/menu-main.png"):
		return
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

	menus.open(LevelResults.create(_fake_summary(), "Nivel 1", true))
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
		"bonuses": [
			{"label": "AMMO LEFT 34", "points": 170},
			{"label": "TIME LEFT 22s", "points": 220},
			{"label": "NO DAMAGE", "points": 2000},
		],
		"best_multiplier": 6.0,
		"best_chain": 18,
		"best_bank": 6400,
		"no_damage": true,
		"record": {"previous": 15240, "delta": 2650, "is_new": true, "had_previous": true},
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
