extends Node

## Revisa como se ven las opciones en las dos pieles: como ventana del
## escritorio y como panel del juego. Guarda dos PNG en .godot/.

var _menus: Node


func _ready() -> void:
	_menus = get_node("/root/MenuStack")

	if not await _shoot(MenuScreen.MenuSkin.DESKTOP, "res://.godot/options-desktop.png"):
		return
	if not await _shoot(MenuScreen.MenuSkin.GAME, "res://.godot/options-game.png"):
		return
	print("Options visual smoke test passed.")
	get_tree().quit()


func _shoot(skin: MenuScreen.MenuSkin, path: String) -> bool:
	var menu := OptionsMenu.create(skin)
	_menus.open(menu)
	await _drawn()
	if not _inside_viewport(menu.window):
		_fail("The options window should sit inside the reference viewport.")
		return false
	if not _save(path):
		return false
	_menus.close_all()
	await _drawn()
	return true


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
	if image == null or image.save_png(path) != OK:
		_fail("Could not save %s." % path)
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
