extends SceneTree

## Recorre el catalogo declarado en level-sequence.json con F7 y F8. Las
## expectativas salen del propio catalogo, asi que agregar o quitar niveles de
## la campania no invalida la prueba.

var _sequence: Node
var _catalog: Array = []


func _initialize() -> void:
	create_timer(12.0, true, false, true).timeout.connect(func() -> void: _fail("Level sequence smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	_sequence = root.get_node("LevelSequence")
	_catalog = _load_catalog()
	if _catalog.is_empty():
		_fail("level-sequence.json should list at least one level.")
		return
	if _sequence.get_level_count() != _catalog.size():
		_fail("The autoload should expose every level of the catalog.")
		return
	_sequence.select_first_level()
	change_scene_to_file("res://scenes/levels/playable_level.tscn")
	await _wait_for_scene()
	if not _check_level_at(0):
		return
	for index in range(1, _catalog.size()):
		_send_key(KEY_F7)
		await _wait_for_scene()
		if not _check_level_at(index):
			return
		if _sequence.get_position_text() != "%d / %d" % [index + 1, _catalog.size()]:
			_fail("The sequence position should follow the catalog.")
			return
	if _catalog.size() > 1:
		_send_key(KEY_F8)
		await _wait_for_scene()
		if not _check_level_at(_catalog.size() - 2):
			return
	if not await _check_direct_selection():
		return
	_sequence.select_first_level()
	print("Level sequence smoke test passed.")
	quit()


## El selector de niveles salta a cualquier indice del catalogo; fuera de
## rango no cambia nada. Los nombres salen del JSON de cada nivel.
func _check_direct_selection() -> bool:
	var last := _catalog.size() - 1
	if not _sequence.select_level(last):
		_fail("select_level should accept the last catalog index.")
		return false
	if _sequence.select_level(_catalog.size()) or _sequence.select_level(-1):
		_fail("select_level should reject indexes outside the catalog.")
		return false
	if _sequence.get_current_index() != last:
		_fail("A rejected selection must not move the sequence.")
		return false
	_sequence.play_current_level()
	await _wait_for_scene()
	if not _check_level_at(last):
		return false
	var first_id := str((_catalog[0] as Dictionary).id)
	if not _sequence.select_level_by_id(first_id) or _sequence.get_current_level_id() != first_id:
		_fail("select_level_by_id should find a level by its id.")
		return false
	if _sequence.get_level_name(0).is_empty() or _sequence.get_level_id(99) != "":
		_fail("Level names come from the catalog; unknown indexes are empty.")
		return false
	if not _sequence.is_unlocked(0):
		_fail("The first level is always unlocked.")
		return false
	if _sequence.get_level_ids().size() != _catalog.size():
		_fail("get_level_ids should list the whole catalog.")
		return false
	return true


## Cada entrada del catalogo debe abrir el archivo que declara.
func _check_level_at(index: int) -> bool:
	var level := current_scene as PlayableLevel
	if level == null or level.level_data.is_empty():
		_fail("The playable level did not load for catalog entry %d." % index)
		return false
	var expected_path := str((_catalog[index] as Dictionary).path)
	var expected := LevelDefinitionLoader.load_level(expected_path)
	if str(level.level_data.id) != str(expected.id):
		_fail("Catalog entry %d should load %s." % [index, expected_path])
		return false
	if level.level_data.rooms.size() != expected.rooms.size():
		_fail("The loaded level should keep every room of %s." % expected_path)
		return false
	return true


func _load_catalog() -> Array:
	var file := FileAccess.open("res://level_designs/level-sequence.json", FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return []
	return (parsed as Dictionary).get("levels", []) as Array


func _send_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)


## Entrar a un nivel pasa por el velo y la precarga, asi que la cantidad de
## frames varia: se espera hasta que el nivel este construido.
func _wait_for_scene() -> void:
	var previous := current_scene
	for _frame in 40:
		await process_frame
		var level := current_scene as PlayableLevel
		if level != null and level != previous and level.is_built:
			return


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
