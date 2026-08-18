extends SceneTree


func _initialize() -> void:
	create_timer(5.0, true, false, true).timeout.connect(func() -> void: _fail("Block lab smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/block_lab.tscn")
	await process_frame
	await process_frame
	var lab := current_scene
	if lab == null:
		_fail("Block lab scene did not load.")
		return
	var preset_option := lab.get_node("ConfigInterface/ConfigPanel/Margin/VBox/PresetRow/PresetOption") as OptionButton
	var room_option := lab.get_node("ConfigInterface/ConfigPanel/Margin/VBox/RoomRow/RoomShapeOption") as OptionButton
	if preset_option.item_count != 5:
		_fail("Expected five editable level presets.")
		return
	lab._on_preset_selected(3)
	if room_option.get_selected_id() != 2 or lab.get_node("ConfigInterface/ConfigPanel/Margin/VBox/FrontRow/FrontEnabled").button_pressed:
		_fail("Corridor preset should select the corridor and disable the front block.")
		return
	lab._on_preset_selected(1)
	room_option.select(1)
	lab._apply_configuration()
	if lab.room_size != Vector2(24.0, 18.0):
		_fail("Large room configuration was not applied.")
		return
	lab._on_entry_trigger_body_entered(lab.player)
	var blocks := lab.get_node("Blocks").get_children()
	if blocks.size() != 3:
		_fail("Default lab configuration should deploy three blocks, got %d." % blocks.size())
		return
	var front_block: TargetBlock3D
	for block in blocks:
		if block.block_label == "front block":
			front_block = block
			break
	if front_block == null or front_block.target_count != 0 or not front_block.moves_to_opposite_side:
		_fail("Front block should demonstrate a moving, targetless close-control block.")
		return
	print("Block lab smoke test passed.")
	paused = false
	quit()


func _fail(message: String) -> void:
	paused = false
	push_error(message)
	quit(1)
