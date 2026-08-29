extends SceneTree

## Cada nivel de la campaña se construye en pocos frames y termina horneado:
## sin arbol CSG vivo, con una malla estatica y una colision con caras. Imprime
## los tiempos de construccion por nivel, que son la linea base de rendimiento.

const MAX_BUILD_FRAMES := 6

var _catalog: Array = []


func _initialize() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void: _fail("Level build smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	var sequence := root.get_node("LevelSequence")
	_catalog = _load_catalog()
	if _catalog.is_empty():
		_fail("level-sequence.json should list at least one level.")
		return
	sequence.select_first_level()
	change_scene_to_file("res://scenes/levels/playable_level.tscn")
	await process_frame
	for index in _catalog.size():
		if not await _check_current(index):
			return
		if index + 1 < _catalog.size():
			sequence.select_next_level()
			reload_current_scene()
			await process_frame
	sequence.select_first_level()
	print("Level build smoke test passed (%d levels)." % _catalog.size())
	quit()


func _check_current(index: int) -> bool:
	var level := current_scene as PlayableLevel
	var switching := 0
	while level == null and switching < 4:
		await process_frame
		level = current_scene as PlayableLevel
		switching += 1
	if level == null:
		_fail("Catalog entry %d did not load a PlayableLevel." % index)
		return false
	var frames := 0
	while not level.is_built and frames < MAX_BUILD_FRAMES:
		await process_frame
		frames += 1
	if not level.is_built:
		_fail("Level %s should be built within %d frames." % [str(level.level_data.get("id", index)), MAX_BUILD_FRAMES])
		return false
	var geometry := level.room_geometry
	if not geometry.find_children("*", "CSGShape3D", true, false).is_empty():
		_fail("Level %s should not keep any CSG node once baked." % str(level.level_data.id))
		return false
	var mesh_instance := geometry.get_node_or_null("LevelShellMesh") as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		_fail("Level %s should bake its shell into a static mesh with surfaces." % str(level.level_data.id))
		return false
	var body := geometry.get_node_or_null("LevelShell") as StaticBody3D
	var collision := body.get_child(0) as CollisionShape3D if body != null and body.get_child_count() > 0 else null
	var shape := collision.shape as ConcavePolygonShape3D if collision != null else null
	if shape == null or shape.get_faces().is_empty():
		_fail("Level %s should bake its shell into a concave collision shape with faces." % str(level.level_data.id))
		return false
	if body.collision_layer != 1:
		_fail("The baked shell should sit on the World layer.")
		return false
	return true


func _load_catalog() -> Array:
	var raw := FileAccess.get_file_as_string("res://level_designs/level-sequence.json")
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		return []
	return (parsed as Dictionary).get("levels", [])


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
