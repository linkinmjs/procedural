extends Node

## Retrata el arranque y el monitor: la tarjeta de Godot, la terminal del
## estudio con el nombre tipeado y el cursor, el escritorio a mitad del
## encendido del tubo y el escritorio con el monitor encendido. Guarda cuatro
## PNG en .godot/.

const BOOT_SCENE := preload("res://scenes/ui/boot_sequence.tscn")
const MAIN_MENU_SCENE := preload("res://scenes/ui/menus/main_menu.tscn")
## A mitad del despliegue vertical: la imagen ya se abrio a lo ancho y esta
## creciendo a lo alto.
const POWER_ON_SAMPLE := 0.72


func _ready() -> void:
	var boot := BOOT_SCENE.instantiate() as BootSequence
	boot.autoplay = false
	add_child(boot)
	boot.show_card(BootSequence.Card.GODOT)
	await _drawn()
	if not _save("res://.godot/boot-godot.png"):
		return

	boot.show_card(BootSequence.Card.STUDIO)
	boot.type_all()
	await _drawn()
	var terminal := boot.get_node("StudioCard/Terminal") as Label
	if terminal == null or not _inside_viewport(terminal):
		_fail("The terminal line should sit inside the reference viewport.")
		return
	if not _save("res://.godot/boot-ominoso.png"):
		return
	boot.queue_free()
	await get_tree().process_frame

	var settings := get_node_or_null("/root/Settings") as GameSettings
	if settings != null and not settings.is_crt_enabled():
		_fail("The monitor filter must be on to picture it; turn it on in the options first.")
		return
	var menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	add_child(menu)
	menu.crt.settle()
	menu.crt.set_power_level(POWER_ON_SAMPLE)
	await _drawn()
	if not _save("res://.godot/menu-crt-power-on.png"):
		return
	menu.crt.settle()
	await _drawn()
	if not _inside_viewport(menu.window):
		_fail("The main menu window should sit inside the reference viewport.")
		return
	if not _save("res://.godot/menu-crt.png"):
		return
	# El filtro no puede comerse el borde de abajo (ahi vive la barra de
	# tareas): el centro del borde inferior queda visible, y la esquina del
	# tubo si es redondeada y oscura.
	var shot := Image.load_from_file(ProjectSettings.globalize_path("res://.godot/menu-crt.png"))
	if shot == null:
		_fail("The captured preview should be readable back.")
		return
	var bottom := shot.get_pixel(shot.get_width() / 2, shot.get_height() - 3)
	if bottom.get_luminance() < 0.05:
		_fail("The bottom edge of the screen should stay visible under the CRT filter.")
		return
	var corner := shot.get_pixel(4, 4)
	if corner.get_luminance() > 0.2:
		_fail("The tube corners should stay rounded and dark.")
		return
	print("Boot visual smoke test passed.")
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
