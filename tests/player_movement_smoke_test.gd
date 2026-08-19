extends SceneTree

## Mide la movilidad del jugador: que no quede nada del sistema de estamina, que
## el arranque y la frenada sean cortos, que el salto llegue a la altura pedida y
## que el aire conserve el impulso.

const STEP := 1.0 / 60.0

var _player: CharacterBody3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/weapon_test.tscn")
	await process_frame
	await process_frame
	_player = _find_player()
	if _player == null:
		_fail("Could not find the player in the weapon test scene.")
		return
	for i in 30:
		await physics_frame
	if not _player.is_on_floor():
		_fail("The player should be standing on the floor before measuring.")
		return

	# El sprint y su estamina ya no existen en ninguna forma.
	if _player.get("sprint_speed") != null or _player.get("sprint_time") != null:
		_fail("The stamina based sprint should be gone from the controller.")
		return
	if _player.get_node_or_null("CanvasLayer/SprintBar") != null:
		_fail("The stamina bar should be gone from the HUD.")
		return

	# Correr es el modo por defecto y se llega a la velocidad plena enseguida.
	Input.action_press("up")
	var frames_to_full := 0
	while _planar_speed() < _player.run_speed * 0.95 and frames_to_full < 120:
		await physics_frame
		frames_to_full += 1
	if frames_to_full * STEP > 0.25:
		_fail("Reaching full speed took %.2fs, it should feel instant." % (frames_to_full * STEP))
		return

	for i in 15:
		await physics_frame
	if _planar_speed() > _player.run_speed * 1.05:
		_fail("Ground speed should settle at run_speed, found %.2f m/s." % _planar_speed())
		return

	# Al soltar las teclas la friccion frena en una zancada corta.
	var stop_start := _player.global_position
	Input.action_release("up")
	var frames_to_stop := 0
	while _planar_speed() > 0.2 and frames_to_stop < 120:
		await physics_frame
		frames_to_stop += 1
	var slide_distance := stop_start.distance_to(_player.global_position)
	if frames_to_stop * STEP > 0.35 or slide_distance > 0.9:
		_fail("Stopping took %.2fs and %.2fm, it should be a short slide." % [frames_to_stop * STEP, slide_distance])
		return

	# Caminar y agacharse son mas lentos que correr.
	if _player.walk_speed >= _player.run_speed or _player.crouch_speed >= _player.walk_speed:
		_fail("Walking and crouching must be slower than running.")
		return

	# El salto llega a la altura declarada.
	var floor_height := _player.global_position.y
	await _press_jump()
	var takeoff_frames := 0
	while _player.is_on_floor() and takeoff_frames < 10:
		await physics_frame
		takeoff_frames += 1
	if _player.is_on_floor():
		_fail("The player never left the floor after pressing jump.")
		return
	var peak_height := floor_height
	var airborne_frames := 0
	while not _player.is_on_floor() and airborne_frames < 180:
		peak_height = maxf(peak_height, _player.global_position.y)
		await physics_frame
		airborne_frames += 1
	var jumped_height := peak_height - floor_height
	if absf(jumped_height - _player.jump_height) > _player.jump_height * 0.15:
		_fail("The jump reached %.2fm instead of %.2fm." % [jumped_height, _player.jump_height])
		return
	if airborne_frames * STEP > 1.0:
		_fail("The jump hung in the air for %.2fs, it should feel snappy." % (airborne_frames * STEP))
		return
	if _player.landing_dip > 0.0 and _player.recoil_target.y >= 0.0:
		_fail("Landing should dip the view down.")
		return

	# En el aire se conserva el impulso: nada de frenarse al despegar.
	Input.action_press("up")
	while _planar_speed() < _player.run_speed * 0.95:
		await physics_frame
	var launch_speed := _planar_speed()
	await _press_jump()
	for i in 10:
		await physics_frame
	if _planar_speed() < launch_speed * 0.95:
		_fail("Jumping should keep the run speed, dropped from %.2f to %.2f m/s." % [launch_speed, _planar_speed()])
		return
	Input.action_release("up")

	# Mantener el salto encadena rebotes en cuanto se toca el suelo.
	Input.action_press("ui_accept")
	var hops := 0
	var was_airborne := true
	for i in 240:
		await physics_frame
		if _player.is_on_floor():
			was_airborne = false
		elif not was_airborne:
			was_airborne = true
			hops += 1
	Input.action_release("ui_accept")
	if _player.auto_bhop and hops < 2:
		_fail("Holding jump should keep hopping, counted %d hops." % hops)
		return

	print("Player movement smoke test passed.")
	quit()


## Pulsa y suelta el salto pasando por el mismo camino que un teclado real, para
## que se ejerciten el buffer y el coyote time.
func _press_jump() -> void:
	var press := InputEventAction.new()
	press.action = "ui_accept"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	await physics_frame
	var release := InputEventAction.new()
	release.action = "ui_accept"
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _planar_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func _find_player() -> CharacterBody3D:
	for node in get_nodes_in_group("World")[0].get_children():
		if node is CharacterBody3D:
			return node
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
