extends Node


func _ready() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not _save_viewport("res://.godot/block-lab-menu.png"):
		return
	var lab := $BlockLab
	lab._apply_configuration()
	lab.player.global_position = Vector3(0.0, 0.05, lab.room_size.y * 0.5 - 2.2)
	lab._on_entry_trigger_body_entered(lab.player)
	await get_tree().process_frame
	await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	if not _save_viewport("res://.godot/block-lab-gameplay.png"):
		return
	print("Block lab visual smoke test passed.")
	get_tree().quit()


func _save_viewport(path: String) -> bool:
	var image := get_viewport().get_texture().get_image()
	if image == null or image.save_png(path) != OK:
		push_error("Could not save block lab preview: %s" % path)
		get_tree().paused = false
		get_tree().quit(1)
		return false
	return true
