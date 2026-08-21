extends SceneTree

## El trazado por puntos intermedios tiene que pasar por cada punto en orden,
## salir perpendicular a la pared que perfora y llegar perpendicular a la de
## destino, con todos los tramos en angulo recto. Es el mismo calculo que hace
## la herramienta en tools/level-editor/level-format.js, asi que los casos de
## aca espejan los del smoke test del editor.

var _level: PlayableLevel


func _initialize() -> void:
	create_timer(15.0, true, false, true).timeout.connect(func() -> void: _fail("Corridor waypoints smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	_level = PlayableLevel.new()
	var ok := _check_detour() and _check_aligned_waypoint() and _check_no_waypoints_unchanged() \
			and _check_door_slide() and _check_spur_collapse()
	_level.free()
	if not ok:
		return
	print("Corridor waypoints smoke test passed.")
	quit()


func _rooms() -> Array[Dictionary]:
	return [
		{"position": {"x": -20.0, "z": 0.0}, "size": {"width": 14.0, "depth": 14.0}},
		{"position": {"x": 0.0, "z": 0.0}, "size": {"width": 14.0, "depth": 14.0}},
	]


## Dos puntos que desvian el pasillo en U: el recorrido pasa por los dos, sale
## y entra perpendicular, y cada tramo es horizontal o vertical.
func _check_detour() -> bool:
	var rooms := _rooms()
	var connection := {
		"fromWall": "east", "toWall": "west", "width": 3.5,
		"waypoints": [{"x": -11.0, "z": -8.0}, {"x": -9.0, "z": -8.0}],
	}
	var points: PackedVector2Array = _level._corridor_plan(rooms[0], rooms[1], connection, 3.5).points
	if points.size() != 6:
		_fail("The detour should describe six points, got %d." % points.size())
		return false
	if points[0] != Vector2(-13, 0) or points[points.size() - 1] != Vector2(-7, 0):
		_fail("The corridor should span door to door.")
		return false
	if not absf(points[0].y - points[1].y) < 0.01:
		_fail("The corridor should leave perpendicular to the east wall.")
		return false
	if not absf(points[points.size() - 2].y - points[points.size() - 1].y) < 0.01:
		_fail("The corridor should arrive perpendicular to the west wall.")
		return false
	for waypoint in [Vector2(-11, -8), Vector2(-9, -8)]:
		if not waypoint in points:
			_fail("The corridor should pass through waypoint %s." % waypoint)
			return false
	for index in points.size() - 1:
		var delta: Vector2 = points[index + 1] - points[index]
		if absf(delta.x) >= 0.01 and absf(delta.y) >= 0.01:
			_fail("Every corridor leg should be horizontal or vertical.")
			return false
	return true


## Un punto sobre la linea recta no agrega codos: el trazado se funde en un
## unico tramo.
func _check_aligned_waypoint() -> bool:
	var rooms := _rooms()
	var connection := {
		"fromWall": "east", "toWall": "west", "width": 3.5,
		"waypoints": [{"x": -10.0, "z": 0.0}],
	}
	var points: PackedVector2Array = _level._corridor_plan(rooms[0], rooms[1], connection, 3.5).points
	if points.size() != 2:
		_fail("An aligned waypoint should keep the corridor straight, got %d points." % points.size())
		return false
	return true


## Sin puntos intermedios el trazado es el de siempre, incluido el ensanche
## cuando las puertas quedan desalineadas menos que el ancho.
func _check_no_waypoints_unchanged() -> bool:
	var rooms := _rooms()
	rooms[1].position.z = 2.0
	var connection := {"fromWall": "east", "toWall": "west", "width": 3.5, "waypoints": []}
	var plan: Dictionary = _level._corridor_plan(rooms[0], rooms[1], connection, 3.5)
	if float(plan.width) != 5.5:
		_fail("Without waypoints a small offset should widen the corridor, got %f." % float(plan.width))
		return false
	if (plan.points as PackedVector2Array).size() != 2:
		_fail("Without waypoints a small offset should keep the corridor straight.")
		return false
	return true


## Un punto enfrentado a la pared desliza la puerta hasta ese lugar: el pasillo
## sale derecho desde ahi en vez de acodarse desde el centro.
func _check_door_slide() -> bool:
	var rooms := _rooms()
	var connection := {
		"fromWall": "east", "toWall": "west", "width": 3.5,
		"waypoints": [{"x": -11.0, "z": -4.0}],
	}
	var points: PackedVector2Array = _level._corridor_plan(rooms[0], rooms[1], connection, 3.5).points
	if points.size() != 2 or points[0] != Vector2(-13, -4) or points[1] != Vector2(-7, -4):
		_fail("The waypoint should slide both doors and keep the corridor straight, got %s." % str(points))
		return false
	# El tope: un punto casi en la esquina deja la puerta entera dentro de la pared.
	connection.waypoints = [{"x": -11.0, "z": -6.9}]
	points = _level._corridor_plan(rooms[0], rooms[1], connection, 3.5).points
	if absf(points[0].y) > 7.0 - 3.5 * 0.5 - 0.35 + 0.001:
		_fail("The door should stay clear of the corner, got %s." % str(points[0]))
		return false
	return true


## Una ida y vuelta sobre la misma linea se descarta en lugar de degenerar la
## geometria del pasillo.
func _check_spur_collapse() -> bool:
	var rooms := _rooms()
	var connection := {
		"fromWall": "east", "toWall": "west", "width": 3.5,
		"waypoints": [{"x": -10.0, "z": -9.0}, {"x": -10.0, "z": 0.0}],
	}
	var points: PackedVector2Array = _level._corridor_plan(rooms[0], rooms[1], connection, 3.5).points
	if points.size() != 2:
		_fail("A detour that doubles back should collapse, got %d points." % points.size())
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
