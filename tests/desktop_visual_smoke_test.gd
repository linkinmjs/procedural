extends Node

## Retrata el escritorio limpio: la ventana del juego cerrada a la barra, el
## menu de inicio plegado y el monitor encendido, con la marca de agua de acceso
## anticipado abajo a la derecha. Es la imagen de cabecera de la pagina del
## juego, asi que guarda un PNG en .godot/.

const MAIN_MENU_SCENE := preload("res://scenes/ui/menus/main_menu.tscn")


func _ready() -> void:
	var settings := get_node_or_null("/root/Settings") as GameSettings
	if settings != null and not settings.is_crt_enabled():
		_fail("The monitor filter must be on to picture it; turn it on in the options first.")
		return
	var menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	add_child(menu)
	menu.close()
	menu.crt.settle()
	await _drawn()
	if menu.window.visible:
		_fail("Closing the game window should leave the bare desktop.")
		return
	if menu.watermark == null or not menu.watermark.visible or not _inside_viewport(menu.watermark):
		_fail("The early access watermark should sit inside the reference viewport.")
		return
	var taskbar_top := menu.taskbar.get_global_rect().position.y
	if menu.watermark.get_global_rect().end.y > taskbar_top:
		_fail("The early access watermark should sit above the taskbar.")
		return
	if not _save("res://.godot/desktop-crt.png"):
		return
	print("Desktop visual smoke test passed.")
	get_tree().quit()


func _drawn() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _inside_viewport(control: Control) -> bool:
	var bounds := get_viewport().get_visible_rect().size
	var rect := control.get_global_rect()
	return rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= bounds.x and rect.end.y <= bounds.y


func _save(path: String) -> bool:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_fail("The active renderer cannot capture the preview image.")
		return false
	if image.save_png(path) != OK:
		_fail("Could not save %s." % path)
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
