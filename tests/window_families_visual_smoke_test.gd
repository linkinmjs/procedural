extends Node

## Retrata las familias con comportamiento propio, y despues la descarga con su
## confirmacion abierta, que es el estado que no se ve de entrada.

@onready var _download: DownloadWindow = $DownloadWindow


func _ready() -> void:
	await _drawn()
	if not _save("res://.godot/window-families.png"):
		return
	# Se cancela la descarga para retratar la confirmacion, que es lo que obliga
	# al segundo disparo.
	_download.find_hit_body(DownloadWindow.CANCEL_ZONE).Hit_Successful(1.0)
	await _drawn()
	if not _save("res://.godot/window-download-confirm.png"):
		return
	print("Window families visual smoke test passed.")
	get_tree().quit()


func _drawn() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save(path: String) -> bool:
	var image := get_viewport().get_texture().get_image()
	if image == null or image.save_png(path) != OK:
		push_error("Could not save %s." % path)
		get_tree().quit(1)
		return false
	return true
