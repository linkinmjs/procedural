extends SceneTree

const BLOCK_SCENE := preload("res://scenes/targets/target_block_3d.tscn")


func _initialize() -> void:
	create_timer(4.0).timeout.connect(func() -> void: _fail("Target block smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	var controller := RoundController.new()
	controller.auto_start = false
	root.add_child(controller)
	controller.start_round()
	var player := CharacterBody3D.new()
	root.add_child(player)
	var target_block := BLOCK_SCENE.instantiate() as TargetBlock3D
	target_block.target_count = 2
	target_block.crossing_damage = 15.0
	root.add_child(target_block)
	target_block._on_body_entered(player)
	if not is_equal_approx(controller.current_health, 85.0):
		_fail("Crossing a target block should remove configured HP.")
		return
	for target in target_block.spawn_volume.active_targets.duplicate():
		target.Hit_Successful(1.0)
	await process_frame
	if is_instance_valid(target_block):
		_fail("A target block should close after all targets are destroyed.")
		return
	var empty_block := BLOCK_SCENE.instantiate() as TargetBlock3D
	empty_block.target_count = 0
	root.add_child(empty_block)
	var close_target := empty_block.find_child("CloseTargetBall", true, false) as TargetBall
	if close_target == null:
		_fail("An empty block should create a close control.")
		return
	close_target.Hit_Successful(1.0)
	await process_frame
	if is_instance_valid(empty_block):
		_fail("The close control should close an empty block.")
		return
	var moving_block := BLOCK_SCENE.instantiate() as TargetBlock3D
	moving_block.target_count = 0
	moving_block.moves_to_opposite_side = true
	moving_block.movement_direction = Vector3.RIGHT
	moving_block.movement_speed = 5.0
	moving_block.travel_distance = 0.1
	root.add_child(moving_block)
	await physics_frame
	await physics_frame
	if moving_block.position.x <= 0.0 or moving_block.position.x > 0.101:
		_fail("A moving block should advance toward, but not beyond, its opposite side.")
		return
	print("Target block smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
