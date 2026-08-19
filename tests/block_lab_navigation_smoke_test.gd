extends SceneTree


func _initialize() -> void:
	create_timer(6.0, true, false, true).timeout.connect(func() -> void: _fail("Block lab navigation test timed out."))
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/sandbox/block_lab.tscn")
	await process_frame
	await process_frame
	var original_instance_id := current_scene.get_instance_id()
	_send_key(KEY_F3)
	await process_frame
	await process_frame
	await process_frame
	if current_scene == null or current_scene.scene_file_path != "res://scenes/sandbox/block_lab.tscn":
		_fail("F3 should reload the block lab scene.")
		return
	if current_scene.get_instance_id() == original_instance_id:
		_fail("F3 did not create a fresh block lab instance.")
		return
	_send_key(KEY_F2)
	await process_frame
	await process_frame
	await process_frame
	if current_scene == null or current_scene.scene_file_path != "res://scenes/sandbox/weapon_test.tscn":
		_fail("F2 should leave the paused block lab and open the weapon test.")
		return
	if paused:
		_fail("Scene navigation should clear the paused state.")
		return
	print("Block lab navigation smoke test passed.")
	quit()


func _send_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)


func _fail(message: String) -> void:
	paused = false
	push_error(message)
	quit(1)
