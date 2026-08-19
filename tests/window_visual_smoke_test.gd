extends Node


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.save_png("res://.godot/window-preview.png") != OK:
		push_error("Could not save the window preview.")
		get_tree().quit(1)
		return
	print("Window visual smoke test passed.")
	get_tree().quit()
