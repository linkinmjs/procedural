class_name PlayableLevel
extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/player_character.tscn")
const ROOM_LIGHT_SCENE := preload("res://scenes/environment/room_light.tscn")
## Altura de respaldo cuando el nivel no declara la suya.
const WALL_HEIGHT := 6.0
const CEILING_THICKNESS := 0.3
const AMMO_PICKUP_SCENE := preload("res://scenes/weapons/glock_ammo_pickup.tscn")
const WALL_THICKNESS := 0.35
## Alto del vano. Deja dintel sobre la puerta en vez de abrir la pared entera,
## para que despues entre una hoja de puerta.
const DOOR_HEIGHT := 3.0
## Pared que queda como minimo sobre el vano.
const LINTEL_HEIGHT := 0.6
## Lo que puede rodear al numero en el nombre de un nivel sin volverlo un nombre
## propio: separadores y digitos.
const GENERIC_NAME_FILLER := " -_.0123456789"


@export_file("*.json") var level_definition_path := "res://level_designs/levels/nivel-1.json"
@export_range(0.05, 5.0, 0.05) var moving_block_speed := 0.65
@export_range(0.0, 100.0, 1.0) var block_crossing_damage := 15.0
## Segundos entre el cierre del nivel y la pantalla de resultados. El cobro de
## la ultima cadena sigue a la vista durante ese rato.
@export_range(0.0, 30.0, 0.1) var results_delay := 3.0

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $DirectionalLight3D
@onready var room_geometry: Node3D = %RoomGeometry
@onready var connection_geometry: Node3D = %ConnectionGeometry
@onready var encounters: Node3D = %Encounters
@onready var round_controller: RoundController = $RoundHUD/RoundController
@onready var score_controller: ScoreController = $RoundHUD/ScoreController
@onready var level_name_label: Label = %LevelNameLabel
@onready var status_label: Label = %StatusLabel

var level_data: Dictionary = {}
var player: CharacterBody3D
var room_nodes: Dictionary = {}
var room_encounters: Dictionary = {}
## Puertas por sala: se cierran al entrar y se abren al limpiar sus bloques.
var room_doors: Dictionary = {}
## IDs de las salas ordenadas de la entrada a la salida, siguiendo las conexiones.
var room_order: Array[String] = []
## Si este nivel se presento con su intertitulo al construirse. Queda como
## registro aunque la presentacion ya se haya ido de pantalla.
var announced := false
## La presentacion, mientras sigue en pantalla. Se libera sola al terminar.
var level_intro: LevelIntro
var _round_started := false
var _round_completed := false
## Encuentro de la ultima sala. Si tiene objetivos, la ronda cierra cuando cae el
## ultimo y no al pisar la sala.
var _exit_encounter: ConfiguredRoomEncounter3D
var _floor_material: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _corridor_material: StandardMaterial3D
var _ceiling_material: StandardMaterial3D
## Toda la geometria del nivel vive en un unico arbol CSG: la union elimina las
## caras internas donde las salas y los pasillos se tocan, que es lo que se veia
## como costuras y parpadeos entre cajas superpuestas.
var _shell: CSGCombiner3D
## Recortes de los vanos. Se aplican al final para que resten sobre el conjunto
## ya unido, no solo sobre la caja anterior.
var _openings: Array[CSGBox3D] = []


func _ready() -> void:
	_floor_material = _make_material(Color(0.075, 0.11, 0.14), 0.92)
	_wall_material = _make_material(Color(0.10, 0.27, 0.34), 0.74)
	_corridor_material = _make_material(Color(0.09, 0.17, 0.21), 0.86)
	_ceiling_material = _make_material(Color(0.06, 0.09, 0.12), 0.95)
	load_and_build_level()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_open_pause_menu()
		return
	# Reintentar no pregunta nada ni pasa por ningun menu: en un modo de puntaje
	# volver a empezar tiene que costar menos de un segundo.
	if event.is_action_pressed("restart_level"):
		get_viewport().set_input_as_handled()
		_level_sequence().restart_current_level()
		return
	match event.keycode:
		KEY_F1:
			get_tree().change_scene_to_file("res://scenes/sandbox/dungeon_test.tscn")
		KEY_F2:
			get_tree().change_scene_to_file("res://scenes/sandbox/weapon_test.tscn")
		KEY_F3:
			get_tree().reload_current_scene()
		KEY_F4:
			get_tree().change_scene_to_file("res://scenes/sandbox/block_lab.tscn")
		KEY_F6:
			get_tree().reload_current_scene()
		KEY_F7:
			_navigate_level(true)
		KEY_F8:
			_navigate_level(false)


func load_and_build_level() -> void:
	var sequence := _level_sequence()
	var sequence_path: String = sequence.get_current_level_path()
	var active_level_path := sequence_path if not sequence_path.is_empty() else level_definition_path
	level_data = LevelDefinitionLoader.load_level(active_level_path)
	if level_data.is_empty():
		level_name_label.text = "HUD_LEVEL_LOAD_FAILED"
		status_label.text = level_definition_path
		return
	level_name_label.text = tr("HUD_LEVEL_HEADER").format({
		"name": str(level_data.get("name", "")).to_upper(),
		"position": sequence.get_position_text(),
	})
	SkyCatalog.apply(LevelDefinitionLoader.get_sky_id(level_data), world_environment, sun)
	room_order = _resolve_room_order()
	_build_shell()
	_build_rooms()
	_build_connections()
	_carve_openings()
	_spawn_player()
	round_controller.round_duration = float(level_data.timeLimitSeconds)
	round_controller.register_player(player)
	# El techo de puntaje y el par salen del contenido del nivel, asi que el
	# puntaje necesita su definicion antes de que arranque la ronda.
	score_controller.prepare_level(str(level_data.get("id", "")), level_data)
	score_controller.level_scored.connect(_on_level_scored)
	round_controller.arm_round()
	_wire_round_triggers()
	status_label.text = tr("HUD_LEVEL_STATUS").format({
		"rooms": level_data.rooms.size(),
		"connections": level_data.connections.size(),
	})
	_announce_level(sequence)


## Presenta el nivel al entrar. La secuencia decide si toca: reintentar recarga
## la escena igual que entrar, pero no vuelve a anunciarla.
func _announce_level(sequence: Node) -> void:
	if not sequence.consume_announcement():
		return
	announced = true
	var number := int(sequence.get_current_number())
	var title := tr("INTRO_LEVEL").format({"number": number})
	var level_name := str(level_data.get("name", ""))
	# El nombre propio del nivel solo acompaña al numero si dice algo mas que el
	# numero. Hoy los niveles se llaman "Nivel-1" y repetirlo no aporta nada.
	var subtitle := level_name.to_upper() if _has_own_name(level_name) else ""
	level_intro = LevelIntro.create(title, subtitle)
	add_child(level_intro)


## Un nombre es propio cuando dice algo mas que "nivel" y un numero. Se compara
## contra la palabra en los tres idiomas y no contra el titulo ya traducido: el
## nombre sale del JSON del nivel, que esta escrito en un idioma solo.
func _has_own_name(level_name: String) -> bool:
	var rest := level_name.to_upper()
	for word in ["NIVEL", "NÍVEL", "LEVEL"]:
		rest = rest.replace(word, "")
	for character in rest:
		if not GENERIC_NAME_FILLER.contains(character):
			return true
	return false


## El cronometro arranca en cuanto hay algo que cronometrar: al dejar la primera
## habitacion, o antes si esa primera habitacion trae bloques y el jugador ya
## esta peleando. Se detiene al resolver la ultima: al pisarla si esta vacia, o
## al limpiarla si tiene objetivos. Si el nivel tiene una sola sala no hay tramo
## que recorrer, asi que la ronda arranca de entrada.
func _wire_round_triggers() -> void:
	var first_encounter := _encounter_at(0)
	var exit_room := LevelDefinitionLoader.get_exit_room(level_data)
	var last_encounter := room_encounters.get(str(exit_room.get("id", "")), null) as ConfiguredRoomEncounter3D
	if last_encounter == null:
		last_encounter = _encounter_at(room_order.size() - 1)
	if room_order.size() < 2 or first_encounter == null or last_encounter == null or first_encounter == last_encounter:
		_begin_round()
		return
	_exit_encounter = last_encounter
	first_encounter.body_exited.connect(_on_first_room_exited)
	last_encounter.body_entered.connect(_on_last_room_entered)


func _encounter_at(index: int) -> ConfiguredRoomEncounter3D:
	if index < 0 or index >= room_order.size():
		return null
	return room_encounters.get(room_order[index], null) as ConfiguredRoomEncounter3D


func _on_first_room_exited(body: Node3D) -> void:
	if body != player:
		return
	_begin_round()


func _begin_round() -> void:
	if _round_started:
		return
	_round_started = true
	round_controller.start_round()


## El encuentro de la sala ya corrio su propio body_entered antes que esto, asi
## que una sala sin objetivos llega marcada como limpia y cierra la ronda al
## instante. Una con objetivos todavia no, y la ronda sigue corriendo hasta que
## caiga el ultimo.
func _on_last_room_entered(body: Node3D) -> void:
	if _round_completed or body != player:
		return
	if _exit_encounter != null and not _exit_encounter.cleared:
		round_controller.add_log(tr("LOG_FINAL_ROOM"), "system")
		return
	_complete_round()


func _complete_round() -> void:
	if _round_completed:
		return
	_round_completed = true
	round_controller.complete_round()


## Cerrar el nivel ya no arrastra al siguiente: el puntaje se resuelve, se
## muestra el resultado y el jugador decide si reintenta, avanza o se va.
func _on_level_scored(summary: Dictionary) -> void:
	round_controller.add_log(tr("LOG_RESULTS_IN").format({"seconds": "%.0f" % results_delay}), "system")
	get_tree().create_timer(results_delay).timeout.connect(_show_results.bind(summary))


func _show_results(summary: Dictionary) -> void:
	var menus := _menus()
	if menus.is_open():
		return
	var level_title := str(level_data.get("name", "Nivel"))
	menus.open(LevelResults.create(summary, level_title, _level_sequence().has_next_level()))


func _open_pause_menu() -> void:
	var menus := _menus()
	if menus.is_open():
		return
	var level_title := str(level_data.get("name", "Nivel"))
	menus.open(PauseMenu.create(level_title, _level_sequence().get_position_text(), score_controller.total_score))


func _menus() -> Node:
	return get_node("/root/MenuStack")


func _level_sequence() -> Node:
	return get_node("/root/LevelSequence")


## Recorre las conexiones desde la entrada. Los niveles son cadenas lineales;
## ante una bifurcacion se toma la primera salida no visitada.
func _resolve_room_order() -> Array[String]:
	var neighbours: Dictionary = {}
	for room_variant in level_data.rooms:
		neighbours[str((room_variant as Dictionary).id)] = PackedStringArray()
	for connection_variant in level_data.connections:
		var connection := connection_variant as Dictionary
		var from_id := str(connection.fromRoomId)
		var to_id := str(connection.toRoomId)
		if neighbours.has(from_id) and neighbours.has(to_id):
			neighbours[from_id].append(to_id)
			neighbours[to_id].append(from_id)
	var order: Array[String] = []
	var visited: Dictionary = {}
	var current := str(_resolve_start_room().get("id", ""))
	while not current.is_empty() and not visited.has(current):
		visited[current] = true
		order.append(current)
		var next_id := ""
		for neighbour in neighbours.get(current, PackedStringArray()) as PackedStringArray:
			if not visited.has(neighbour):
				next_id = neighbour
				break
		current = next_id
	return order


## El jugador aparece en la sala marcada como inicio.
func _resolve_start_room() -> Dictionary:
	var start := LevelDefinitionLoader.get_start_room(level_data)
	return start if not start.is_empty() else level_data.rooms[0] as Dictionary


func _navigate_level(forward: bool) -> void:
	var sequence := _level_sequence()
	var changed: bool = sequence.select_next_level() if forward else sequence.select_previous_level()
	if changed:
		sequence.play_current_level()
		return
	round_controller.add_log(tr("LOG_NO_NEXT_LEVEL" if forward else "LOG_NO_PREVIOUS_LEVEL"), "info")


## Contenedor unico de la geometria solida. La colision sale del resultado ya
## combinado, asi que los vanos quedan abiertos tambien para la fisica.
func _build_shell() -> void:
	_openings.clear()
	_shell = CSGCombiner3D.new()
	_shell.name = "LevelShell"
	_shell.use_collision = true
	room_geometry.add_child(_shell)


func _build_rooms() -> void:
	var openings := _collect_room_openings()
	for room_variant in level_data.rooms:
		var room := room_variant as Dictionary
		var room_id := str(room.id)
		var safe_name := _safe_node_name(str(room.name))
		var center := _room_center(room)
		var width := float(room.size.width)
		var depth := float(room.size.depth)
		var wall_height := LevelDefinitionLoader.get_room_wall_height(level_data, room)
		var floor_material := TextureCatalog.resolve(level_data, room, "floor", _floor_material)
		var wall_material := TextureCatalog.resolve(level_data, room, "walls", _wall_material)
		var ceiling_material := TextureCatalog.resolve(level_data, room, "ceiling", _ceiling_material)
		# El marcador sostiene lo que no es geometria solida: luz, cartel y las
		# puertas, que se mueven aparte del casco del nivel.
		var room_marker := Node3D.new()
		room_marker.name = safe_name
		room_marker.position = center
		room_geometry.add_child(room_marker)
		room_nodes[room_id] = room_marker

		_add_box(_shell, "%sFloor" % safe_name, center + Vector3(0.0, -0.15, 0.0),
				Vector3(width, 0.3, depth), floor_material)
		if LevelDefinitionLoader.room_has_ceiling(level_data, room):
			_add_box(_shell, "%sCeiling" % safe_name, center + Vector3(0.0, wall_height + CEILING_THICKNESS * 0.5, 0.0),
					Vector3(width, CEILING_THICKNESS, depth), ceiling_material)
		var room_openings: Dictionary = openings.get(room_id, {}) as Dictionary
		var doors: Array[RoomDoor3D] = []
		for wall in ["north", "east", "south", "west"]:
			_add_room_wall(safe_name, center, wall, width, depth, wall_height, wall_material)
			var opening: Dictionary = room_openings.get(wall, {}) as Dictionary
			var opening_width := float(opening.get("width", 0.0))
			if opening_width <= 0.0:
				continue
			doors.append(_add_room_opening(room_marker, wall, width, depth, wall_height,
					opening_width, float(opening.get("offset", 0.0))))
		room_doors[room_id] = doors

		_add_room_label(room_marker, str(room.name), wall_height)
		_add_room_light(room_marker, Vector3(width, wall_height, depth))
		var encounter := ConfiguredRoomEncounter3D.new()
		encounter.name = "%sEncounter" % safe_name
		encounter.position = center
		encounter.movement_speed = moving_block_speed
		encounter.crossing_damage = block_crossing_damage
		encounter.wall_height = wall_height
		encounter.max_block_height = LevelDefinitionLoader.get_max_block_height(level_data)
		encounter.configure(room)
		encounter.encounter_started.connect(_on_encounter_started)
		encounter.encounter_cleared.connect(_on_encounter_cleared)
		encounters.add_child(encounter)
		room_encounters[room_id] = encounter


## Una sala se abre unicamente donde la toca un pasillo, y el vano toma el ancho
## de ese pasillo. La entrada de la sala inicial es conceptual (orienta sus
## bloques), asi que no perfora la pared si no hay nada del otro lado.
func _collect_room_openings() -> Dictionary:
	var rooms_by_id: Dictionary = {}
	var openings: Dictionary = {}
	for room_variant in level_data.rooms:
		var room := room_variant as Dictionary
		rooms_by_id[str(room.id)] = room
		openings[str(room.id)] = {}
	for connection_variant in level_data.connections:
		var connection := connection_variant as Dictionary
		var corridor_width := LevelDefinitionLoader.get_corridor_width(level_data, connection)
		var from_room: Dictionary = rooms_by_id[str(connection.fromRoomId)]
		var to_room: Dictionary = rooms_by_id[str(connection.toRoomId)]
		# El vano se talla donde el pasillo toca la pared, que con puntos
		# intermedios puede estar corrido del centro.
		(openings[str(connection.fromRoomId)] as Dictionary)[str(connection.fromWall)] = {
			"width": corridor_width,
			"offset": _door_along_offset(from_room, str(connection.fromWall), connection, true, corridor_width),
		}
		(openings[str(connection.toRoomId)] as Dictionary)[str(connection.toWall)] = {
			"width": corridor_width,
			"offset": _door_along_offset(to_room, str(connection.toWall), connection, false, corridor_width),
		}
	return openings


## Cada pared se levanta entera. Los vanos se restan despues, asi la union no
## deja los cantos de dos medias paredes a los lados de cada puerta.
func _add_room_wall(safe_name: String, center: Vector3, wall: String, width: float, depth: float, wall_height: float, wall_material: Material) -> void:
	var is_horizontal := wall == "north" or wall == "south"
	var length := width if is_horizontal else depth
	var offset := _wall_offset(wall, width, depth)
	var size := Vector3(length, wall_height, WALL_THICKNESS) if is_horizontal else Vector3(WALL_THICKNESS, wall_height, length)
	var position := center + Vector3(offset.x, wall_height * 0.5, offset.y)
	_add_box(_shell, "%s%sWall" % [safe_name, wall.capitalize()], position, size, wall_material)


## Marca el vano para recortarlo y cuelga la barrera que lo sella. along_offset
## corre la puerta a lo largo de su pared cuando el pasillo no toca el centro.
func _add_room_opening(room_marker: Node3D, wall: String, width: float, depth: float, wall_height: float, opening_width: float, along_offset: float = 0.0) -> RoomDoor3D:
	var is_horizontal := wall == "north" or wall == "south"
	var length := width if is_horizontal else depth
	var door_width := clampf(opening_width, 1.0, length - 0.2)
	var door_height := _door_height_for(wall_height)
	var offset := _wall_offset(wall, width, depth)
	var local_position := Vector3(offset.x, door_height * 0.5, offset.y)
	if is_horizontal:
		local_position.x += along_offset
	else:
		local_position.z += along_offset
	# El recorte cruza la pared de lado a lado para que no queden restos.
	var cut_depth := WALL_THICKNESS * 3.0
	var cut_size := Vector3(door_width, door_height, cut_depth) if is_horizontal else Vector3(cut_depth, door_height, door_width)
	_add_opening_cut("%sOpening" % wall.capitalize(), room_marker.position + local_position, cut_size)
	return _add_room_door(room_marker, wall, is_horizontal, local_position, door_width, door_height)


func _wall_offset(wall: String, width: float, depth: float) -> Vector2:
	match wall:
		"north":
			return Vector2(0.0, -depth * 0.5)
		"south":
			return Vector2(0.0, depth * 0.5)
		"west":
			return Vector2(-width * 0.5, 0.0)
		_:
			return Vector2(width * 0.5, 0.0)


## Alto del vano: el de una puerta, salvo que la sala sea tan baja que no deje
## lugar para el dintel.
func _door_height_for(wall_height: float) -> float:
	return clampf(minf(DOOR_HEIGHT, wall_height - LINTEL_HEIGHT), 1.8, wall_height)


func _add_opening_cut(cut_name: String, position: Vector3, size: Vector3) -> void:
	var cut := CSGBox3D.new()
	cut.name = cut_name
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut.position = position
	cut.size = size
	_openings.append(cut)


## Los recortes van al final del arbol: CSG acumula en orden, asi que restar
## despues de todas las uniones abre el vano en la pared y en el pasillo a la vez.
func _carve_openings() -> void:
	for cut in _openings:
		_shell.add_child(cut)


func _add_room_door(parent: Node3D, wall: String, is_horizontal: bool, local_position: Vector3, door_width: float, door_height: float) -> RoomDoor3D:
	var door := RoomDoor3D.new()
	door.name = "%sDoor" % wall.capitalize()
	door.door_size = Vector3(door_width, door_height, WALL_THICKNESS) if is_horizontal else Vector3(WALL_THICKNESS, door_height, door_width)
	door.position = local_position
	# El vano esta en un borde de la sala, asi que el interior queda del lado
	# opuesto al desplazamiento de esa pared.
	var fixed_offset := local_position.z if is_horizontal else local_position.x
	door.inward_direction = Vector3(0.0, 0.0, -signf(fixed_offset)) if is_horizontal else Vector3(-signf(fixed_offset), 0.0, 0.0)
	parent.add_child(door)
	return door


## Entrar a una sala con bloques la sella: sus puertas se cierran detras del
## jugador y no vuelven a abrirse hasta que caiga el ultimo bloque.
func _on_encounter_started(encounter: ConfiguredRoomEncounter3D) -> void:
	# Si el jugador ya esta peleando, la ronda tiene que estar corriendo. Una sala
	# de inicio con bloques se jugaba entera en STANDBY: sus disparos, sus fallos
	# y su daño no contaban, asi que puntuaba con otras reglas que el resto del
	# nivel. La espera en la entrada solo tiene sentido si no hay nada que hacer.
	_begin_round()
	# Una sala con objetivos abre una cadena de puntaje y la cierra al limpiarse.
	round_controller.report_room_entered(encounter.room_id, encounter.room_label)
	var doors := _doors_for(encounter.room_id)
	if doors.is_empty():
		return
	for door in doors:
		door.request_close(player)
	round_controller.add_log(tr("LOG_ROOM_SEALED").format({"room": encounter.room_label.to_upper()}), "danger")


func _on_encounter_cleared(encounter: ConfiguredRoomEncounter3D) -> void:
	round_controller.report_room_cleared(encounter.room_id, encounter.room_label)
	var was_sealed := false
	for door in _doors_for(encounter.room_id):
		was_sealed = was_sealed or door.is_closed
		door.open()
	if was_sealed:
		round_controller.add_log(tr("LOG_ROOM_CLEAR").format({"room": encounter.room_label.to_upper()}), "system")
	# La recompensa se gana limpiando: una sala sin bloques no suelta nada aunque
	# declare ammoReward (si no, caeria a los pies del jugador al entrar).
	if encounter.deployed_blocks:
		_spawn_ammo_reward(encounter.room_id)
	else:
		_warn_unused_ammo_reward(encounter.room_id)
	# El puntaje de la sala ya se cobro arriba, asi que cerrar aca deja el
	# resumen del nivel con la ultima sala ya contada.
	if encounter == _exit_encounter and encounter.activated:
		_complete_round()


## Un ammoReward habilitado sobre una sala sin bloques queda sin efecto; avisar
## para que el dato del editor no se pierda en silencio.
func _warn_unused_ammo_reward(room_id: String) -> void:
	var room := _room_by_id(room_id)
	if room.is_empty():
		return
	var reward := LevelDefinitionLoader.get_room_ammo_reward(room)
	if bool(reward.enabled) and int(reward.amount) > 0:
		push_warning("La sala '%s' declara ammoReward pero no tiene bloques: la recompensa no se entrega." % str(room.name))


## Limpiar una sala configurada como recompensa deja un cargador en su centro.
func _spawn_ammo_reward(room_id: String) -> void:
	var room := _room_by_id(room_id)
	if room.is_empty():
		return
	var reward := LevelDefinitionLoader.get_room_ammo_reward(room)
	if not bool(reward.enabled) or int(reward.amount) <= 0:
		return
	var pickup := AMMO_PICKUP_SCENE.instantiate() as WeaponPickUp
	pickup.name = "%sAmmoReward" % _safe_node_name(str(room.name))
	pickup.position = _room_center(room) + Vector3(0.0, 1.2, 0.0)
	var magazine: int = pickup.weapon.weapon.magazine
	pickup.weapon.current_ammo = mini(int(reward.amount), magazine)
	pickup.weapon.reserve_ammo = maxi(int(reward.amount) - magazine, 0)
	add_child(pickup)
	round_controller.add_log(tr("LOG_AMMO_REWARD").format({
		"room": str(room.name).to_upper(),
		"amount": int(reward.amount),
	}), "system")


func _room_by_id(room_id: String) -> Dictionary:
	for room_variant in level_data.rooms:
		var room := room_variant as Dictionary
		if str(room.id) == room_id:
			return room
	return {}


func _doors_for(room_id: String) -> Array[RoomDoor3D]:
	var doors: Array[RoomDoor3D] = []
	doors.assign(room_doors.get(room_id, []))
	return doors


func _build_connections() -> void:
	var rooms_by_id: Dictionary = {}
	for room_variant in level_data.rooms:
		var room := room_variant as Dictionary
		rooms_by_id[str(room.id)] = room
	for connection_variant in level_data.connections:
		var connection := connection_variant as Dictionary
		var from_room: Dictionary = rooms_by_id[str(connection.fromRoomId)]
		var to_room: Dictionary = rooms_by_id[str(connection.toRoomId)]
		var corridor_width := LevelDefinitionLoader.get_corridor_width(level_data, connection)
		# El pasillo llega justo a la altura del vano mas bajo que une, asi el
		# techo del pasillo apoya contra el dintel en vez de cortarlo.
		var corridor_height := minf(
				_door_height_for(LevelDefinitionLoader.get_room_wall_height(level_data, from_room)),
				_door_height_for(LevelDefinitionLoader.get_room_wall_height(level_data, to_room)))
		var plan := _corridor_plan(from_room, to_room, connection, corridor_width)
		var surfaces := {
			"floor": TextureCatalog.resolve(level_data, from_room, "floor", _corridor_material),
			"walls": TextureCatalog.resolve(level_data, from_room, "walls", _wall_material),
			"ceiling": TextureCatalog.resolve(level_data, from_room, "ceiling", _ceiling_material),
		}
		_add_corridor(plan.points, float(plan.width), corridor_height, surfaces)


## Traza el pasillo entre dos salas y decide su ancho efectivo. Es el mismo
## calculo que hace la herramienta en tools/level-editor/level-format.js.
##
## El primer tramo sale perpendicular a la pared que perfora, o el pasillo
## arrancaria de costado y dejaria la puerta contra una pared: una conexion
## norte / sur avanza primero en profundidad y una este / oeste, primero a lo
## ancho. Si las dos puertas estan desalineadas menos que el ancho del pasillo
## no hay lugar para un codo, asi que va recto y se ensancha lo justo para
## cubrir ambas bocas.
func _corridor_plan(from_room: Dictionary, to_room: Dictionary, connection: Dictionary, corridor_width: float) -> Dictionary:
	var from_wall := str(connection.fromWall)
	var start := _wall_point(from_room, from_wall)
	var end := _wall_point(to_room, str(connection.toWall))
	var exits_along_depth := from_wall == "north" or from_wall == "south"
	var waypoints_variant: Variant = connection.get("waypoints", [])
	var waypoints: Array = waypoints_variant if waypoints_variant is Array else []
	if not waypoints.is_empty():
		var slid_start := _door_point(from_room, from_wall, connection, true, corridor_width)
		var slid_end := _door_point(to_room, str(connection.toWall), connection, false, corridor_width)
		return {"points": _waypoint_path(slid_start, slid_end, waypoints, connection), "width": corridor_width}
	var offset := absf(start.x - end.x) if exits_along_depth else absf(start.y - end.y)
	if offset < 0.01:
		return {"points": PackedVector2Array([start, end]), "width": corridor_width}
	if offset <= corridor_width:
		var widened := corridor_width + offset
		if exits_along_depth:
			var mid_x := (start.x + end.x) * 0.5
			return {"points": PackedVector2Array([Vector2(mid_x, start.y), Vector2(mid_x, end.y)]), "width": widened}
		var mid_y := (start.y + end.y) * 0.5
		return {"points": PackedVector2Array([Vector2(start.x, mid_y), Vector2(end.x, mid_y)]), "width": widened}
	if exits_along_depth:
		var elbow_y := (start.y + end.y) * 0.5
		return {"points": PackedVector2Array([start, Vector2(start.x, elbow_y), Vector2(end.x, elbow_y), end]), "width": corridor_width}
	var elbow_x := (start.x + end.x) * 0.5
	return {"points": PackedVector2Array([start, Vector2(elbow_x, start.y), Vector2(elbow_x, end.y), end]), "width": corridor_width}


## Punta del pasillo sobre una pared, el mismo calculo que doorPoint en
## tools/level-editor/level-format.js. Sin puntos intermedios es el centro de
## la pared; con puntos, el primero (o el ultimo, del lado destino) desliza la
## puerta sobre la pared cuando queda enfrentado a ella. Un punto fuera del
## frente de la pared no la mueve: el recorrido lo alcanza con codos.
func _door_point(room: Dictionary, wall: String, connection: Dictionary, is_from: bool, corridor_width: float) -> Vector2:
	var point := _wall_point(room, wall)
	var waypoints_variant: Variant = connection.get("waypoints", [])
	var waypoints: Array = waypoints_variant if waypoints_variant is Array else []
	if waypoints.is_empty():
		return point
	var target := (waypoints[0] if is_from else waypoints[waypoints.size() - 1]) as Dictionary
	# Una pared norte/sur corre a lo ancho (x); una este/oeste, en profundidad.
	var along_x := wall == "north" or wall == "south"
	var half_length := float(room.size.width if along_x else room.size.depth) * 0.5
	var center := float(room.position.x if along_x else room.position.z)
	var candidate := float(target.get("x" if along_x else "z", center))
	if absf(candidate - center) > half_length:
		return point
	# La puerta entera tiene que quedar dentro de la pared, lejos de la esquina.
	var limit := half_length - corridor_width * 0.5 - WALL_THICKNESS
	if limit <= 0.0:
		return point
	var slid := clampf(candidate, center - limit, center + limit)
	return Vector2(slid, point.y) if along_x else Vector2(point.x, slid)


## Desplazamiento de la puerta a lo largo de su pared, para tallar el vano y
## colgar la barrera donde el pasillo realmente toca la sala.
func _door_along_offset(room: Dictionary, wall: String, connection: Dictionary, is_from: bool, corridor_width: float) -> float:
	var point := _door_point(room, wall, connection, is_from, corridor_width)
	var along_x := wall == "north" or wall == "south"
	return point.x - float(room.position.x) if along_x else point.y - float(room.position.z)


## Trazado por puntos intermedios, el mismo calculo que waypointPath en
## tools/level-editor/level-format.js: el pasillo pasa por cada punto en orden
## uniendo tramos en angulo recto, sale perpendicular a la pared que perfora y
## llega perpendicular a la de destino.
func _waypoint_path(start: Vector2, end: Vector2, waypoints: Array, connection: Dictionary) -> PackedVector2Array:
	var points: Array[Vector2] = [start]
	# true = el proximo tramo avanza en profundidad (z del juego).
	var vertical := str(connection.fromWall) == "north" or str(connection.fromWall) == "south"
	for waypoint_variant in waypoints:
		var waypoint := waypoint_variant as Dictionary
		var target := Vector2(float(waypoint.get("x", 0.0)), float(waypoint.get("z", 0.0)))
		var current: Vector2 = points[points.size() - 1]
		var aligned := absf(current.x - target.x) < 0.01 or absf(current.y - target.y) < 0.01
		if not aligned:
			points.append(Vector2(current.x, target.y) if vertical else Vector2(target.x, current.y))
		points.append(target)
		var previous: Vector2 = points[points.size() - 2]
		vertical = absf(target.x - previous.x) < 0.01
	var last: Vector2 = points[points.size() - 1]
	var enters_along_depth := str(connection.toWall) == "north" or str(connection.toWall) == "south"
	if absf(last.x - end.x) >= 0.01 and absf(last.y - end.y) >= 0.01:
		# El ultimo tramo entra derecho a la puerta: el codo comparte con el
		# destino el eje por el que no se entra.
		points.append(Vector2(end.x, last.y) if enters_along_depth else Vector2(last.x, end.y))
	points.append(end)
	return _simplify_path(points)


## Limpia el trazado: quita puntos repetidos y funde tres puntos sobre el mismo
## eje en un solo tramo. Eso incluye las idas y vueltas: un pasillo que vuelve
## sobre su propia linea no se puede construir sano, asi que el desvio
## redundante se descarta en lugar de degenerar.
func _simplify_path(points: Array[Vector2]) -> PackedVector2Array:
	var result: Array[Vector2] = []
	for point in points:
		if not result.is_empty() and result[result.size() - 1].distance_to(point) < 0.01:
			continue
		result.append(point)
		while result.size() >= 3:
			var a: Vector2 = result[result.size() - 3]
			var b: Vector2 = result[result.size() - 2]
			var c: Vector2 = result[result.size() - 1]
			var same_axis := (absf(a.x - b.x) < 0.01 and absf(b.x - c.x) < 0.01) \
					or (absf(a.y - b.y) < 0.01 and absf(b.y - c.y) < 0.01)
			if not same_axis:
				break
			result.remove_at(result.size() - 2)
			# Si la vuelta termina donde arranco, el punto duplicado sobra.
			if result.size() >= 2 and result[result.size() - 2].distance_to(result[result.size() - 1]) < 0.01:
				result.remove_at(result.size() - 1)
	return PackedVector2Array(result)


## Arma el pasillo como un tubo continuo: cada tramo aporta piso, techo y sus
## dos paredes, y cada codo se cierra con un cubo del ancho del pasillo. Los
## extremos que dan a un codo se recortan medio ancho, o las paredes del tramo
## cruzarian el giro y lo taparian.
func _add_corridor(points: PackedVector2Array, corridor_width: float, corridor_height: float, surfaces: Dictionary) -> void:
	for index in points.size() - 1:
		_add_corridor_segment(points[index], points[index + 1], corridor_width, corridor_height,
				index > 0, index < points.size() - 2, surfaces)
	for index in range(1, points.size() - 1):
		_add_corridor_corner(points[index - 1], points[index], points[index + 1], corridor_width, corridor_height, surfaces)


func _add_corridor_segment(start: Vector2, end: Vector2, corridor_width: float, corridor_height: float, trim_start: bool, trim_end: bool, surfaces: Dictionary) -> void:
	var delta := end - start
	var full_length := delta.length()
	if full_length < 0.05:
		return
	var direction := delta / full_length
	var trimmed_start := start + direction * (corridor_width * 0.5 if trim_start else 0.0)
	var trimmed_end := end - direction * (corridor_width * 0.5 if trim_end else 0.0)
	var length := (trimmed_end - trimmed_start).length()
	if length < 0.05:
		return
	var center := (trimmed_start + trimmed_end) * 0.5
	var horizontal := absf(delta.x) >= absf(delta.y)
	var floor_size := Vector3(length, 0.3, corridor_width) if horizontal else Vector3(corridor_width, 0.3, length)
	_add_box(_shell, "CorridorFloor", Vector3(center.x, -0.15, center.y), floor_size, surfaces.floor)
	var ceiling_size := Vector3(length, CEILING_THICKNESS, corridor_width) if horizontal else Vector3(corridor_width, CEILING_THICKNESS, length)
	_add_box(_shell, "CorridorCeiling", Vector3(center.x, corridor_height + CEILING_THICKNESS * 0.5, center.y), ceiling_size, surfaces.ceiling)
	_add_corridor_light(center, full_length, corridor_height)
	for side in [-1.0, 1.0]:
		var wall_size := Vector3(length, corridor_height, WALL_THICKNESS) if horizontal else Vector3(WALL_THICKNESS, corridor_height, length)
		var wall_position := Vector3(center.x, corridor_height * 0.5, center.y + side * (corridor_width + WALL_THICKNESS) * 0.5) if horizontal else Vector3(center.x + side * (corridor_width + WALL_THICKNESS) * 0.5, corridor_height * 0.5, center.y)
		_add_box(_shell, "CorridorWall", wall_position, wall_size, surfaces.walls)


## Cierra un codo: piso y techo del giro, y pared en las dos caras por las que
## el pasillo no entra ni sale.
func _add_corridor_corner(previous: Vector2, corner: Vector2, next: Vector2, corridor_width: float, corridor_height: float, surfaces: Dictionary) -> void:
	var incoming := (corner - previous).normalized()
	var outgoing := (next - corner).normalized()
	_add_box(_shell, "CorridorCornerFloor", Vector3(corner.x, -0.15, corner.y),
			Vector3(corridor_width, 0.3, corridor_width), surfaces.floor)
	_add_box(_shell, "CorridorCornerCeiling", Vector3(corner.x, corridor_height + CEILING_THICKNESS * 0.5, corner.y),
			Vector3(corridor_width, CEILING_THICKNESS, corridor_width), surfaces.ceiling)
	for face in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		if face.is_equal_approx(-incoming) or face.is_equal_approx(outgoing):
			continue
		var offset := (corridor_width + WALL_THICKNESS) * 0.5
		var horizontal_face := absf(face.x) > absf(face.y)
		var wall_length := corridor_width + WALL_THICKNESS * 2.0
		var wall_size := Vector3(WALL_THICKNESS, corridor_height, wall_length) if horizontal_face else Vector3(wall_length, corridor_height, WALL_THICKNESS)
		var wall_position := Vector3(corner.x + face.x * offset, corridor_height * 0.5, corner.y + face.y * offset)
		_add_box(_shell, "CorridorCornerWall", wall_position, wall_size, surfaces.walls)


func _add_corridor_light(center: Vector2, length: float, corridor_height: float) -> void:
	var corridor_light := OmniLight3D.new()
	corridor_light.name = "CorridorLight"
	corridor_light.position = Vector3(center.x, corridor_height - 0.4, center.y)
	corridor_light.light_color = Color(0.58, 0.84, 1.0)
	corridor_light.light_energy = 1.8
	corridor_light.omni_range = clampf(length * 0.65, 6.0, 16.0)
	corridor_light.shadow_enabled = false
	connection_geometry.add_child(corridor_light)


func _spawn_player() -> void:
	var start_room := _resolve_start_room()
	player = PLAYER_SCENE.instantiate()
	player.position = _room_center(start_room) + Vector3(0.0, 0.05, 0.0)
	# La brujula del editor mide 0 grados al norte y crece hacia el este; en
	# Godot el norte es -Z y los angulos de Y crecen al oeste.
	player.rotation.y = -deg_to_rad(LevelDefinitionLoader.get_room_facing(start_room))
	add_child(player)
	_apply_starting_ammo()


## El nivel decide con cuantas balas arranca el jugador, por encima de las que
## trae configuradas la escena del personaje.
func _apply_starting_ammo() -> void:
	var manager := player.get_node_or_null("Camera/LeanPivot/MainCamera/Weapons_Manager")
	if manager == null:
		push_warning("PlayableLevel could not find the player's Weapons_Manager.")
		return
	var slot: WeaponSlot = manager.get("current_weapon_slot")
	if slot == null:
		push_warning("PlayableLevel could not find the player's active weapon slot.")
		return
	var starting_ammo := LevelDefinitionLoader.get_starting_ammo(level_data)
	slot.current_ammo = mini(int(starting_ammo.magazine), slot.weapon.magazine)
	slot.reserve_ammo = mini(int(starting_ammo.reserve), slot.weapon.max_ammo)
	manager.update_ammo.emit([slot.current_ammo, slot.reserve_ammo])


func _add_room_light(parent: Node3D, room_size: Vector3) -> void:
	var room_light := ROOM_LIGHT_SCENE.instantiate()
	room_light.energy = 3.0
	room_light.max_range = 24.0
	parent.add_child(room_light)
	# La luz cuelga bajo el techo, asi que sigue a la altura de la sala.
	room_light.position = Vector3(0.0, minf(room_size.y - 0.8, 3.2), 0.0)
	room_light.configure_for_room(room_size)


func _add_room_label(parent: Node3D, label_text: String, wall_height: float) -> void:
	var label := Label3D.new()
	label.text = label_text.to_upper()
	label.position = Vector3(0.0, maxf(wall_height - 0.75, 1.5), 0.0)
	label.font_size = 48
	label.modulate = Color(0.36, 0.92, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	parent.add_child(label)


func _add_box(parent: Node3D, box_name: String, box_position: Vector3, box_size: Vector3, material: Material) -> void:
	var box := CSGBox3D.new()
	box.name = box_name
	box.position = box_position
	box.size = box_size
	box.material = material
	parent.add_child(box)


func _level_wall_height() -> float:
	var defaults: Dictionary = level_data.get("defaults", {}) as Dictionary
	return clampf(float(defaults.get("wallHeight", WALL_HEIGHT)), 2.0, 20.0)


func _room_center(room: Dictionary) -> Vector3:
	return Vector3(float(room.position.x), 0.0, float(room.position.z))


func _wall_point(room: Dictionary, wall: String) -> Vector2:
	var center := Vector2(float(room.position.x), float(room.position.z))
	var half_width := float(room.size.width) * 0.5
	var half_depth := float(room.size.depth) * 0.5
	match wall:
		"north":
			return center + Vector2(0.0, -half_depth)
		"east":
			return center + Vector2(half_width, 0.0)
		"south":
			return center + Vector2(0.0, half_depth)
		_:
			return center + Vector2(-half_width, 0.0)


func _safe_node_name(value: String) -> String:
	return value.validate_node_name().replace(" ", "")


func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
