extends Node

## Vista previa de las skins cruzadas: escenas XP vestidas de Retro 97 y la
## descarga retro vestida de XP. Guarda la imagen en
## .godot/window-skins-preview.png para revisarla a ojo. Necesita ventana real:
## con --headless no se puede capturar.

var _windows: Array[WindowPanel3D] = []

const SHUTDOWN := preload("res://scenes/windows/shutdown_window.tscn")
const DOWNLOAD := preload("res://scenes/windows/download_window.tscn")
const POPUP := preload("res://scenes/windows/popup_window.tscn")
const FIREWALL := preload("res://scenes/windows/firewall_window.tscn")


func _ready() -> void:
	_spawn(SHUTDOWN, Vector3(-2.6, 1.2, 0.0), {
		"skin": "retro",
		"title": "Banco Central",
		"message": "Tiene (1) transferencia retenida a su nombre.",
	})
	_spawn(DOWNLOAD, Vector3(2.6, 1.2, 0.0), {
		"skin": "xp",
		"title": "Bajando parche",
		"message": "parche_critico.exe",
	})
	_spawn(POPUP, Vector3(-2.6, -1.2, 0.0), {"skin": "retro"})
	_spawn(FIREWALL, Vector3(2.6, -1.2, 0.0), {"skin": "retro"})
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	# La X retro sobre una escena XP lleva el boton gris detras (sin el, el
	# glifo negro desaparecia sobre la barra azul); la XP no lo necesita.
	for window in _windows:
		var is_retro: bool = str(window.variant_config.get("skin", "")) == "retro"
		if is_retro and not _close_has_backing(window):
			push_error("A retro-skinned X should sit on the gray button chip.")
			get_tree().quit(1)
			return
		if not is_retro and _close_has_backing(window):
			push_error("The XP X is a full drawn button and should carry no chip.")
			get_tree().quit(1)
			return
	var first: WindowPanel3D = _windows[0]
	first.sub_viewport.get_texture().get_image().save_png("res://.godot/window-skins-ui.png")
	var image := get_viewport().get_texture().get_image()
	if image == null or image.save_png("res://.godot/window-skins-preview.png") != OK:
		push_error("Could not save the window skins preview.")
		get_tree().quit(1)
		return
	print("Window skins visual smoke test passed.")
	get_tree().quit()


func _close_has_backing(window: WindowPanel3D) -> bool:
	for close_name in ["TitleClose", "CloseZone"]:
		for node in window.content.find_children(close_name, "TextureRect", true, false):
			var rect := node as TextureRect
			var backing := rect.get_parent().get_node_or_null(NodePath(rect.name + "SkinBacking")) as NinePatchRect
			if backing != null and backing.visible and backing.get_index() == rect.get_index() - 1:
				return true
	return false


func _spawn(scene: PackedScene, at: Vector3, config: Dictionary) -> void:
	var window := scene.instantiate() as WindowPanel3D
	window.variant_config = config
	window.position = at
	add_child(window)
	_windows.append(window)
