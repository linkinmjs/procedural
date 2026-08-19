class_name PlayableLevel
extends Node3D

const PLAYER_SCENE := preload("res://Player_Controller/player_character.tscn")
const ROOM_LIGHT_SCENE := preload("res://scenes/room_light.tscn")
const WALL_HEIGHT := 6.0
const WALL_THICKNESS := 0.35
const DOOR_WIDTH := 3.5
const CORRIDOR_WIDTH := 3.5

@export_file("*.json") var level_definition_path := "res://level-designs/levels/nivel-1.json"
@export_range(0.05, 5.0, 0.05) var moving_block_speed := 0.65
@export_range(0.0, 100.0, 1.0) var block_crossing_damage := 15.0

@onready var room_geometry: Node3D = %RoomGeometry
@onready var connection_geometry: Node3D = %ConnectionGeometry
@onready var encounters: Node3D = %Encounters
@onready var round_controller: RoundController = $RoundHUD/RoundController
@onready var level_name_label: Label = %LevelNameLabel
@onready var status_label: Label = %StatusLabel

var level_data: Dictionary = {}
var player: CharacterBody3D
var room_nodes: Dictionary = {}
var room_encounters: Dictionary = {}
var _floor_material: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _corridor_material: StandardMaterial3D


func _ready() -> void:
	_floor_material = _make_material(Color(0.075, 0.11, 0.14), 0.92)
	_wall_material = _make_material(Color(0.10, 0.27, 0.34), 0.74)
	_corridor_material = _make_material(Color(0.09, 0.17, 0.21), 0.86)
	load_and_build_level()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1:
			get_tree().change_scene_to_file("res://scenes/dungeon_test.tscn")
		KEY_F2:
			get_tree().change_scene_to_file("res://scenes/weapon_test.tscn")
		KEY_F3:
			get_tree().reload_current_scene()
		KEY_F4:
			get_tree().change_scene_to_file("res://scenes/block_lab.tscn")
		KEY_F6:
			get_tree().reload_current_scene()
		KEY_F7:
			_navigate_level(true)
		KEY_F8:
			_navigate_level(false)


func load_and_build_level() -> void:
	var sequence = get_node("/root/LevelSequence")
	var sequence_path: String = sequence.get_current_level_path()
	var active_level_path := sequence_path if not sequence_path.is_empty() else level_definition_path
	level_data = LevelDefinitionLoader.load_level(active_level_path)
	if level_data.is_empty():
		level_name_label.text = "LEVEL LOAD FAILED"
		status_label.text = level_definition_path
		return
	level_name_label.text = "%s // %s" % [str(level_data.get("name", "Configured level")).to_upper(), sequence.get_position_text()]
	_build_connections()
	_build_rooms()
	_spawn_player()
	round_controller.round_duration = float(level_data.timeLimitSeconds)
	round_controller.register_player(player)
	round_controller.start_round()
	status_label.text = "%d ROOMS // %d CONNECTIONS // F7 NEXT // F8 PREVIOUS" % [level_data.rooms.size(), level_data.connections.size()]


func _navigate_level(forward: bool) -> void:
	var sequence = get_node("/root/LevelSequence")
	var changed: bool = sequence.select_next_level() if forward else sequence.select_previous_level()
	if changed:
		get_tree().reload_current_scene()
		return
	round_controller.add_log("NO %s LEVEL" % ("NEXT" if forward else "PREVIOUS"), "info")


func _build_rooms() -> void:
	var openings := _collect_room_openings()
	for room_variant in level_data.rooms:
		var room := room_variant as Dictionary
		var room_root := Node3D.new()
		room_root.name = _safe_node_name(str(room.name))
		room_root.position = _room_center(room)
		room_geometry.add_child(room_root)
		room_nodes[str(room.id)] = room_root
		var width := float(room.size.width)
		var depth := float(room.size.depth)
		_add_box(room_root, "Floor", Vector3(0.0, -0.15, 0.0), Vector3(width, 0.3, depth), _floor_material)
		for wall in ["north", "east", "south", "west"]:
			_add_room_wall(room_root, wall, width, depth, (openings.get(str(room.id), []) as Array).has(wall))
		_add_room_label(room_root, str(room.name))
		_add_room_light(room_root, Vector3(width, WALL_HEIGHT, depth))
		var encounter := ConfiguredRoomEncounter3D.new()
		encounter.name = "%sEncounter" % _safe_node_name(str(room.name))
		encounter.position = room_root.position
		encounter.movement_speed = moving_block_speed
		encounter.crossing_damage = block_crossing_damage
		encounter.configure(room)
		encounters.add_child(encounter)
		room_encounters[str(room.id)] = encounter


func _collect_room_openings() -> Dictionary:
	var openings: Dictionary = {}
	for room_variant in level_data.rooms:
		var room := room_variant as Dictionary
		openings[str(room.id)] = [str(room.entry.wall)]
	for connection_variant in level_data.connections:
		var connection := connection_variant as Dictionary
		_append_unique(openings[str(connection.fromRoomId)], str(connection.fromWall))
		_append_unique(openings[str(connection.toRoomId)], str(connection.toWall))
	return openings


func _append_unique(values: Array, value: String) -> void:
	if not values.has(value):
		values.append(value)


func _add_room_wall(parent: Node3D, wall: String, width: float, depth: float, has_opening: bool) -> void:
	var is_horizontal := wall == "north" or wall == "south"
	var length := width if is_horizontal else depth
	var fixed_offset := (-depth * 0.5 if wall == "north" else depth * 0.5) if is_horizontal else (-width * 0.5 if wall == "west" else width * 0.5)
	if not has_opening:
		var size := Vector3(length, WALL_HEIGHT, WALL_THICKNESS) if is_horizontal else Vector3(WALL_THICKNESS, WALL_HEIGHT, length)
		var position := Vector3(0.0, WALL_HEIGHT * 0.5, fixed_offset) if is_horizontal else Vector3(fixed_offset, WALL_HEIGHT * 0.5, 0.0)
		_add_box(parent, "%sWall" % wall.capitalize(), position, size, _wall_material)
		return
	var segment_length := maxf((length - DOOR_WIDTH) * 0.5, 0.1)
	var segment_offset := DOOR_WIDTH * 0.5 + segment_length * 0.5
	for side in [-1.0, 1.0]:
		var segment_size := Vector3(segment_length, WALL_HEIGHT, WALL_THICKNESS) if is_horizontal else Vector3(WALL_THICKNESS, WALL_HEIGHT, segment_length)
		var segment_position := Vector3(side * segment_offset, WALL_HEIGHT * 0.5, fixed_offset) if is_horizontal else Vector3(fixed_offset, WALL_HEIGHT * 0.5, side * segment_offset)
		_add_box(parent, "%sWallSegment" % wall.capitalize(), segment_position, segment_size, _wall_material)


func _build_connections() -> void:
	var rooms_by_id: Dictionary = {}
	for room_variant in level_data.rooms:
		var room := room_variant as Dictionary
		rooms_by_id[str(room.id)] = room
	for connection_variant in level_data.connections:
		var connection := connection_variant as Dictionary
		var from_room: Dictionary = rooms_by_id[str(connection.fromRoomId)]
		var to_room: Dictionary = rooms_by_id[str(connection.toRoomId)]
		var start := _wall_point(from_room, str(connection.fromWall))
		var end := _wall_point(to_room, str(connection.toWall))
		if is_equal_approx(start.x, end.x) or is_equal_approx(start.y, end.y):
			_add_corridor_segment(start, end)
		else:
			var corner := Vector2((start.x + end.x) * 0.5, start.y)
			var corner_two := Vector2(corner.x, end.y)
			_add_corridor_segment(start, corner)
			_add_corridor_segment(corner, corner_two)
			_add_corridor_segment(corner_two, end)


func _add_corridor_segment(start: Vector2, end: Vector2) -> void:
	var delta := end - start
	var length := delta.length()
	if length < 0.05:
		return
	var center := (start + end) * 0.5
	var horizontal := absf(delta.x) >= absf(delta.y)
	var floor_size := Vector3(length, 0.3, CORRIDOR_WIDTH) if horizontal else Vector3(CORRIDOR_WIDTH, 0.3, length)
	_add_box(connection_geometry, "CorridorFloor", Vector3(center.x, -0.15, center.y), floor_size, _corridor_material)
	var corridor_light := OmniLight3D.new()
	corridor_light.name = "CorridorLight"
	corridor_light.position = Vector3(center.x, 3.2, center.y)
	corridor_light.light_color = Color(0.58, 0.84, 1.0)
	corridor_light.light_energy = 1.8
	corridor_light.omni_range = clampf(length * 0.65, 6.0, 16.0)
	corridor_light.shadow_enabled = false
	connection_geometry.add_child(corridor_light)
	for side in [-1.0, 1.0]:
		var wall_size := Vector3(length, WALL_HEIGHT, WALL_THICKNESS) if horizontal else Vector3(WALL_THICKNESS, WALL_HEIGHT, length)
		var wall_position := Vector3(center.x, WALL_HEIGHT * 0.5, center.y + side * CORRIDOR_WIDTH * 0.5) if horizontal else Vector3(center.x + side * CORRIDOR_WIDTH * 0.5, WALL_HEIGHT * 0.5, center.y)
		_add_box(connection_geometry, "CorridorWall", wall_position, wall_size, _wall_material)


func _spawn_player() -> void:
	var start_room: Dictionary = level_data.rooms[0]
	for room_variant in level_data.rooms:
		var room := room_variant as Dictionary
		if str(room.name).to_lower() == "entrada":
			start_room = room
			break
	var spawn_position := _room_center(start_room) + Vector3(0.0, 0.05, 0.0)
	var look_target := _connected_room_center(str(start_room.id))
	player = PLAYER_SCENE.instantiate()
	player.position = spawn_position
	if look_target != spawn_position:
		var direction := (look_target - spawn_position).normalized()
		player.rotation.y = atan2(-direction.x, -direction.z)
	add_child(player)


func _connected_room_center(room_id: String) -> Vector3:
	for connection_variant in level_data.connections:
		var connection := connection_variant as Dictionary
		var other_id := ""
		if str(connection.fromRoomId) == room_id:
			other_id = str(connection.toRoomId)
		elif str(connection.toRoomId) == room_id:
			other_id = str(connection.fromRoomId)
		if not other_id.is_empty():
			for room_variant in level_data.rooms:
				var room := room_variant as Dictionary
				if str(room.id) == other_id:
					return _room_center(room)
	return Vector3.ZERO


func _add_room_light(parent: Node3D, room_size: Vector3) -> void:
	var room_light := ROOM_LIGHT_SCENE.instantiate()
	room_light.energy = 3.0
	room_light.max_range = 24.0
	parent.add_child(room_light)
	room_light.position = Vector3(0.0, 3.2, 0.0)
	room_light.configure_for_room(room_size)


func _add_room_label(parent: Node3D, label_text: String) -> void:
	var label := Label3D.new()
	label.text = label_text.to_upper()
	label.position = Vector3(0.0, 5.25, 0.0)
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
	box.use_collision = true
	parent.add_child(box)


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
