extends SceneTree

## La luminaria de sala se atenua de forma independiente: bajar una no toca la
## luz ni el fixture de las demas, y el nivel la apaga al limpiar la sala.

const ROOM_LIGHT_SCENE := preload("res://scenes/environment/room_light.tscn")
const LEVEL_SCENE := preload("res://scenes/levels/playable_level.tscn")


func _initialize() -> void:
	create_timer(15.0, true, false, true).timeout.connect(func() -> void: _fail("Room light dim smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	var first := ROOM_LIGHT_SCENE.instantiate() as RoomLight
	var second := ROOM_LIGHT_SCENE.instantiate() as RoomLight
	first.energy = 3.0
	second.energy = 3.0
	root.add_child(first)
	root.add_child(second)
	await process_frame
	var base_emission: float = (first.fixture.material_override as StandardMaterial3D).emission_energy_multiplier
	first.dim_to(0.3, 0.0)
	if not is_equal_approx(first.light.light_energy, 0.9):
		_fail("Dimming to 0.3 should leave the light at 0.9, got %s." % first.light.light_energy)
		return
	var first_emission: float = (first.fixture.material_override as StandardMaterial3D).emission_energy_multiplier
	if not is_equal_approx(first_emission, base_emission * 0.3):
		_fail("Dimming should scale the fixture emission too, got %s." % first_emission)
		return
	var second_emission: float = (second.fixture.material_override as StandardMaterial3D).emission_energy_multiplier
	if not is_equal_approx(second.light.light_energy, 3.0) or not is_equal_approx(second_emission, base_emission):
		_fail("Dimming one room light must not affect another one.")
		return
	# Un fundido con duracion deja un tween corriendo y termina en el objetivo.
	second.dim_to(0.5, 0.05)
	await create_timer(0.3).timeout
	if not is_equal_approx(second.dim_factor, 0.5):
		_fail("A timed dim should settle on its target, got %s." % second.dim_factor)
		return
	first.queue_free()
	second.queue_free()

	var level := LEVEL_SCENE.instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	if level.room_lights.is_empty():
		_fail("The level should keep a light per room.")
		return
	var dimmed_id := ""
	for room_id in level.room_encounters:
		var encounter: ConfiguredRoomEncounter3D = level.room_encounters[room_id]
		if encounter == level._exit_encounter or encounter.waves.is_empty():
			continue
		encounter.deployed_blocks = true
		level._on_encounter_cleared(encounter)
		dimmed_id = room_id
		break
	if dimmed_id.is_empty():
		_fail("The level needs a non-exit room with blocks to test the dim.")
		return
	await create_timer(level.cleared_light_fade_seconds + 0.3).timeout
	var dimmed: RoomLight = level.room_lights[dimmed_id]
	if not is_equal_approx(dimmed.dim_factor, level.cleared_light_factor):
		_fail("Clearing a room should dim its light to %s, got %s." % [level.cleared_light_factor, dimmed.dim_factor])
		return
	for room_id in level.room_lights:
		if room_id != dimmed_id and not is_equal_approx((level.room_lights[room_id] as RoomLight).dim_factor, 1.0):
			_fail("Only the cleared room should be dimmed.")
			return
	level.queue_free()
	print("Room light dim smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
