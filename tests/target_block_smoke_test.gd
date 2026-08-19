extends SceneTree

const BLOCK_SCENE := preload("res://scenes/targets/target_block_3d.tscn")
const BALL_SCENE := preload("res://scenes/targets/target_ball.tscn")
const WINDOW_SCENE := preload("res://scenes/windows/shutdown_window.tscn")


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
	target_block.target_scenes = [BALL_SCENE]
	target_block.target_separation = Vector2(1.0, 1.0)
	target_block.target_padding = Vector2(0.35, 0.35)
	target_block.target_count = 0
	target_block.waves.assign([2, 3])
	target_block.block_color = Color("d84cff")
	target_block.crossing_damage = 15.0
	root.add_child(target_block)
	if target_block.spawn_volume.active_targets.size() != 2:
		_fail("The first wave should spawn two targets.")
		return
	if target_block.spawn_volume.active_targets[0].display_color.to_html(false) != "d84cff":
		_fail("Normal targets should inherit the configured block color.")
		return
	var target_mesh := target_block.spawn_volume.active_targets[0].get_node("MeshInstance3D") as MeshInstance3D
	var target_material := (target_mesh.mesh as SphereMesh).material as StandardMaterial3D
	if target_material.albedo_color.to_html(false) != "d84cff":
		_fail("The configured color should be applied to the target material.")
		return
	target_block._on_body_entered(player)
	if not is_equal_approx(controller.current_health, 85.0):
		_fail("Crossing a target block should remove configured HP.")
		return
	for target in target_block.spawn_volume.active_targets.duplicate():
		target.Hit_Successful(1.0)
	await process_frame
	await process_frame
	if not is_instance_valid(target_block) or target_block.spawn_volume.active_targets.size() != 3:
		_fail("Clearing the first wave should spawn the second wave with three targets.")
		return
	for target in target_block.spawn_volume.active_targets.duplicate():
		target.Hit_Successful(1.0)
	await process_frame
	if is_instance_valid(target_block):
		_fail("A target block should close only after every wave is destroyed.")
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
	var window_block := BLOCK_SCENE.instantiate() as TargetBlock3D
	window_block.block_size = Vector2(16.0, 4.0)
	window_block.target_count = 0
	window_block.waves.assign([3])
	root.add_child(window_block)
	if window_block.spawn_volume.active_targets.size() != 3:
		_fail("A block should spawn windows by default, got %d." % window_block.spawn_volume.active_targets.size())
		return
	for spawned in window_block.spawn_volume.active_targets:
		if not spawned is WindowPanel3D:
			_fail("Default block targets should be windows.")
			return
	await process_frame
	await process_frame
	for spawned in window_block.spawn_volume.active_targets.duplicate():
		var window := spawned as WindowPanel3D
		var zones := window.get_hit_bodies()
		if zones.is_empty():
			_fail("Spawned windows should build their hit zones inside the block.")
			return
		zones[0].Hit_Successful(1.0)
	await process_frame
	if is_instance_valid(window_block):
		_fail("Destroying every window should close the block.")
		return
	print("Target block smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
