extends SceneTree

## Los pasillos tienen que salir perpendiculares a la pared que perforan y
## quedar transitables de punta a punta, tambien cuando describen un codo. Se
## comprueba sobre todos los niveles de la campania.

const EYE_HEIGHT := 1.0
## Margen para no arrancar el rayo dentro de la pared de la sala ni terminarlo
## dentro de la del otro extremo.
const PROBE_MARGIN := 0.6
## Cuanto se separan de la pared los rayos que recorren los costados.
const LANE_MARGIN := 0.5

var _catalog: Array = []
var _level: PlayableLevel


func _initialize() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func() -> void: _fail("Corridor layout smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	var sequence := root.get_node("LevelSequence")
	_catalog = _load_catalog()
	if _catalog.is_empty():
		_fail("level-sequence.json should list at least one level.")
		return
	sequence.select_first_level()
	change_scene_to_file("res://scenes/levels/playable_level.tscn")
	await _wait_frames(8)
	for index in _catalog.size():
		_level = current_scene as PlayableLevel
		if _level == null or _level.level_data.is_empty():
			_fail("Catalog entry %d did not load." % index)
			return
		_level.level_transition_delay = 60.0
		if not _check_corridors():
			return
		if index + 1 < _catalog.size():
			sequence.select_next_level()
			reload_current_scene()
			await _wait_frames(8)
	sequence.select_first_level()
	print("Corridor layout smoke test passed.")
	quit()


func _check_corridors() -> bool:
	var rooms_by_id: Dictionary = {}
	for room_variant in _level.level_data.rooms:
		var room := room_variant as Dictionary
		rooms_by_id[str(room.id)] = room
	for connection_variant in _level.level_data.connections:
		var connection := connection_variant as Dictionary
		var from_room: Dictionary = rooms_by_id[str(connection.fromRoomId)]
		var to_room: Dictionary = rooms_by_id[str(connection.toRoomId)]
		var corridor_width := LevelDefinitionLoader.get_corridor_width(_level.level_data, connection)
		var plan := _level._corridor_plan(from_room, to_room, connection, corridor_width)
		var path: PackedVector2Array = plan.points
		if not _check_exit_direction(path, connection, from_room, to_room):
			return false
		if not _check_walkable(path, float(plan.width), str(from_room.name), str(to_room.name)):
			return false
		if not _check_covered(path, float(plan.width), str(from_room.name), str(to_room.name)):
			return false
	return true


## El primer y el ultimo tramo tienen que avanzar en la direccion en la que
## mira su pared, no de costado.
func _check_exit_direction(path: PackedVector2Array, connection: Dictionary, from_room: Dictionary, to_room: Dictionary) -> bool:
	if path.size() < 2:
		_fail("A corridor needs at least two points.")
		return false
	if not _leaves_along_wall_normal(path[0], path[1], str(connection.fromWall)):
		_fail("The corridor out of %s should leave through its %s wall, not sideways." % [str(from_room.name), str(connection.fromWall)])
		return false
	if not _leaves_along_wall_normal(path[path.size() - 1], path[path.size() - 2], str(connection.toWall)):
		_fail("The corridor into %s should meet its %s wall head on." % [str(to_room.name), str(connection.toWall)])
		return false
	return true


func _leaves_along_wall_normal(origin: Vector2, towards: Vector2, wall: String) -> bool:
	var delta := towards - origin
	if delta.length() < 0.01:
		return true
	var normal := {
		"north": Vector2(0.0, -1.0),
		"south": Vector2(0.0, 1.0),
		"east": Vector2(1.0, 0.0),
		"west": Vector2(-1.0, 0.0),
	}[wall] as Vector2
	return delta.normalized().dot(normal) > 0.9


## Recorre el pasillo con rayos a la altura de los ojos, por su eje y pegado a
## cada lado: si algo los corta, el jugador no puede pasar.
func _check_walkable(path: PackedVector2Array, corridor_width: float, from_name: String, to_name: String) -> bool:
	var space := _level.get_world_3d().direct_space_state
	var lanes := [0.0, corridor_width * 0.5 - LANE_MARGIN, LANE_MARGIN - corridor_width * 0.5]
	for index in path.size() - 1:
		var start := path[index]
		var end := path[index + 1]
		var direction := (end - start)
		if direction.length() < 0.01:
			continue
		direction = direction.normalized()
		# El primer y el ultimo tramo nacen en la pared de una sala, asi que se
		# arrancan un poco mas adelante para no chocar contra ella.
		var probe_start := start + direction * (PROBE_MARGIN if index == 0 else 0.0)
		var probe_end := end - direction * (PROBE_MARGIN if index == path.size() - 2 else 0.0)
		if (probe_end - probe_start).length() < 0.05:
			continue
		var side := Vector2(-direction.y, direction.x)
		for lane in lanes:
			var lane_offset: Vector2 = side * float(lane)
			var query := PhysicsRayQueryParameters3D.create(
				Vector3(probe_start.x + lane_offset.x, EYE_HEIGHT, probe_start.y + lane_offset.y),
				Vector3(probe_end.x + lane_offset.x, EYE_HEIGHT, probe_end.y + lane_offset.y))
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				_fail("The corridor between %s and %s is blocked by %s at %s." % [
					from_name, to_name, str(hit.collider.name), str(hit.position)])
				return false
	return true


## El pasillo va cerrado: sobre el eje de cada tramo tiene que haber techo.
func _check_covered(path: PackedVector2Array, corridor_width: float, from_name: String, to_name: String) -> bool:
	var space := _level.get_world_3d().direct_space_state
	for index in path.size() - 1:
		var middle := (path[index] + path[index + 1]) * 0.5
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(middle.x, EYE_HEIGHT, middle.y),
			Vector3(middle.x, EYE_HEIGHT + 12.0, middle.y))
		if space.intersect_ray(query).is_empty():
			_fail("The corridor between %s and %s should be covered by a ceiling." % [from_name, to_name])
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


func _wait_frames(count: int) -> void:
	for _frame in count:
		await physics_frame
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
