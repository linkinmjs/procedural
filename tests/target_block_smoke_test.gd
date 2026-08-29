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
	# Con pelotas: el bloque reparte target_scenes en vez de consultar el
	# catalogo de familias de ventana.
	target_block.uses_window_families = false
	target_block.target_scenes = [BALL_SCENE]
	target_block.target_separation = Vector2(1.0, 1.0)
	target_block.target_padding = Vector2(0.35, 0.35)
	target_block.target_count = 0
	# Dos capas: la primera de dos objetivos, la segunda de tres.
	target_block.layers.assign([
		PackedStringArray(["normal", "normal"]),
		PackedStringArray(["normal", "normal", "normal"]),
	])
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
	# Un bloque quieto es una pared de ventanas: rozarlo no cuesta vida ni lo
	# apaga, asi que no se lo puede "comprar" chocandolo.
	target_block._on_body_entered(player)
	if not is_equal_approx(controller.current_health, 100.0):
		_fail("Touching a static block must not cost HP.")
		return
	if target_block.spawn_volume.active_targets.size() != 2:
		_fail("Touching a static block must not discharge it.")
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
	window_block.layers.assign([PackedStringArray(["normal", "normal", "normal"])])
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
		# Se busca una zona que resuelva: la barra de titulo tambien es zona pero
		# solo trae la ventana al frente.
		var closing: WindowHitBody3D = null
		for zone in zones:
			if zone.closes_window:
				closing = zone
				break
		if closing == null:
			_fail("A spawned window should offer a control that closes it.")
			return
		closing.Hit_Successful(1.0)
	await process_frame
	if is_instance_valid(window_block):
		_fail("Destroying every window should close the block.")
		return
	if not await _check_crossing(controller, player):
		return
	print("Target block smoke test passed.")
	quit()


## Un bloque que avanza y alcanza al jugador lo atraviesa: cobra la vida
## configurada y se descarga —avisa que quedo resuelto, pierde sus ventanas y
## las capas que faltaban, y se va— sin cerrar ninguna ventana.
func _check_crossing(controller: RoundController, player: CharacterBody3D) -> bool:
	var block := BLOCK_SCENE.instantiate() as TargetBlock3D
	block.target_count = 0
	block.layers.assign([
		PackedStringArray(["normal", "normal"]),
		PackedStringArray(["normal"]),
	])
	block.moves_to_opposite_side = true
	block.movement_direction = Vector3.FORWARD
	block.movement_speed = 0.5
	block.travel_distance = 10.0
	block.crossing_damage = 40.0
	root.add_child(block)
	var counts := {"closed": 0, "resolved": 0}
	block.closed.connect(func(_block: TargetBlock3D) -> void: counts.closed += 1)
	controller.target_resolved.connect(func(_kind: String, _label: String, _zone: String, _closed: bool) -> void: counts.resolved += 1)
	var health_before := controller.current_health
	block._on_body_entered(player)
	if not is_equal_approx(controller.current_health, health_before - 40.0):
		return _fail("A moving block running through the player should cost its crossing damage.")
	if counts.closed != 1:
		return _fail("A discharged block should report itself resolved exactly once, got %d." % counts.closed)
	if not block.spawn_volume.active_targets.is_empty():
		return _fail("A discharged block should drop its windows.")
	# Un segundo cruce (salir y volver a entrar) no cobra dos veces.
	block._on_body_exited(player)
	block._on_body_entered(player)
	if not is_equal_approx(controller.current_health, health_before - 40.0):
		return _fail("A discharged block must not charge again.")
	await create_timer(TargetBlock3D.DISCHARGE_FLATTEN_SECONDS + TargetBlock3D.DISCHARGE_CLOSE_SECONDS + 0.2, true, false, true).timeout
	await process_frame
	if is_instance_valid(block):
		return _fail("A discharged block should switch off and leave.")
	if counts.resolved != 0:
		return _fail("Discharging must not count any window as resolved (no points).")
	if counts.closed != 1:
		return _fail("Leaving must not report a second close.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
