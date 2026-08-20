extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/player_character.tscn")
const TARGET_BLOCK_SCENE := preload("res://scenes/targets/target_block_3d.tscn")

enum RoomShape {
	SMALL,
	LARGE,
	CORRIDOR,
}

const ROOM_DIMENSIONS := {
	RoomShape.SMALL: Vector2(14.0, 14.0),
	RoomShape.LARGE: Vector2(24.0, 18.0),
	RoomShape.CORRIDOR: Vector2(10.0, 28.0),
}

const LEVEL_PRESETS := [
	{"name": "Personalizado"},
	{
		"name": "Pequena // tres bloques",
		"shape": RoomShape.SMALL,
		"left": {"enabled": true, "targets": 4, "moves": false},
		"front": {"enabled": true, "targets": 0, "moves": true},
		"right": {"enabled": true, "targets": 3, "moves": false},
	},
	{
		"name": "Grande // laterales estaticos",
		"shape": RoomShape.LARGE,
		"left": {"enabled": true, "targets": 6, "moves": false},
		"front": {"enabled": false, "targets": 0, "moves": false},
		"right": {"enabled": true, "targets": 6, "moves": false},
	},
	{
		"name": "Pasillo // laterales moviles",
		"shape": RoomShape.CORRIDOR,
		"left": {"enabled": true, "targets": 4, "moves": true},
		"front": {"enabled": false, "targets": 0, "moves": false},
		"right": {"enabled": true, "targets": 4, "moves": true},
	},
	{
		"name": "Pequena // cierre frontal",
		"shape": RoomShape.SMALL,
		"left": {"enabled": false, "targets": 0, "moves": false},
		"front": {"enabled": true, "targets": 0, "moves": false},
		"right": {"enabled": false, "targets": 0, "moves": false},
	},
]

@export_range(0.05, 5.0, 0.05) var moving_block_speed := 0.65
@export_range(0.0, 100.0, 1.0) var block_crossing_damage := 15.0

@onready var room_geometry: Node3D = %RoomGeometry
@onready var blocks_container: Node3D = %Blocks
@onready var room_light: OmniLight3D = %RoomLight
@onready var round_controller: RoundController = $RoundHUD/RoundController
@onready var config_panel: Control = %ConfigPanel
@onready var preset_option: OptionButton = %PresetOption
@onready var room_shape_option: OptionButton = %RoomShapeOption

var player: CharacterBody3D
var room_size := ROOM_DIMENSIONS[RoomShape.SMALL] as Vector2
var _encounter_spawned := false
var _configured_blocks: Dictionary = {}
var _applying_preset := false


func _ready() -> void:
	_setup_room_options()
	_setup_level_presets()
	_connect_configuration_changes()
	_build_room(RoomShape.SMALL)
	_spawn_player()
	%ApplyButton.pressed.connect(_apply_configuration)
	%CloseMenuButton.pressed.connect(func() -> void: _set_config_visible(false))
	_set_config_visible(true)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var handled := true
	match event.keycode:
		KEY_TAB:
			_set_config_visible(not config_panel.visible)
		KEY_F1:
			_navigate_to("res://scenes/sandbox/dungeon_test.tscn")
		KEY_F2:
			_navigate_to("res://scenes/sandbox/weapon_test.tscn")
		KEY_F3:
			_navigate_to(scene_file_path)
		KEY_F6:
			_navigate_to("res://scenes/levels/playable_level.tscn")
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _navigate_to(path: String) -> void:
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", path)


func _setup_room_options() -> void:
	room_shape_option.clear()
	room_shape_option.add_item("Habitacion pequena", RoomShape.SMALL)
	room_shape_option.add_item("Habitacion grande", RoomShape.LARGE)
	room_shape_option.add_item("Pasillo", RoomShape.CORRIDOR)


func _setup_level_presets() -> void:
	preset_option.clear()
	for index in LEVEL_PRESETS.size():
		preset_option.add_item(LEVEL_PRESETS[index].name, index)
	preset_option.item_selected.connect(_on_preset_selected)
	preset_option.select(1)
	_on_preset_selected(1)


func _connect_configuration_changes() -> void:
	room_shape_option.item_selected.connect(func(_index: int) -> void: _mark_configuration_custom())
	for checkbox in [%LeftEnabled, %LeftMoves, %FrontEnabled, %FrontMoves, %RightEnabled, %RightMoves]:
		checkbox.toggled.connect(func(_pressed: bool) -> void: _mark_configuration_custom())
	for spinbox in [%LeftTargets, %FrontTargets, %RightTargets]:
		spinbox.value_changed.connect(func(_value: float) -> void: _mark_configuration_custom())


func _on_preset_selected(index: int) -> void:
	if index <= 0 or index >= LEVEL_PRESETS.size():
		return
	_applying_preset = true
	var preset: Dictionary = LEVEL_PRESETS[index]
	room_shape_option.select(preset.shape)
	_apply_block_preset(%LeftEnabled, %LeftTargets, %LeftMoves, preset.left)
	_apply_block_preset(%FrontEnabled, %FrontTargets, %FrontMoves, preset.front)
	_apply_block_preset(%RightEnabled, %RightTargets, %RightMoves, preset.right)
	_applying_preset = false


func _apply_block_preset(enabled: CheckBox, targets: SpinBox, moves: CheckBox, config: Dictionary) -> void:
	enabled.button_pressed = config.enabled
	targets.value = config.targets
	moves.button_pressed = config.moves


func _mark_configuration_custom() -> void:
	if not _applying_preset and preset_option.selected != 0:
		preset_option.select(0)


func _apply_configuration() -> void:
	var shape := room_shape_option.get_selected_id() as RoomShape
	_configured_blocks = {
		"left": _read_block_config(%LeftEnabled, %LeftTargets, %LeftMoves),
		"front": _read_block_config(%FrontEnabled, %FrontTargets, %FrontMoves),
		"right": _read_block_config(%RightEnabled, %RightTargets, %RightMoves),
	}
	_clear_blocks()
	_build_room(shape)
	_reset_player_at_entrance()
	_encounter_spawned = false
	round_controller.start_round()
	round_controller.add_log(tr("LOG_LAB_CONFIGURED"), "system")
	_set_config_visible(false)


func _read_block_config(enabled: CheckBox, targets: SpinBox, moves: CheckBox) -> Dictionary:
	return {
		"enabled": enabled.button_pressed,
		"target_count": int(targets.value),
		"moves": moves.button_pressed,
	}


func _build_room(shape: RoomShape) -> void:
	_clear_children(room_geometry)
	room_size = ROOM_DIMENSIONS[shape]
	var width := room_size.x
	var depth := room_size.y
	var wall_height := 6.0
	var wall_thickness := 0.35
	var door_width := 3.5
	var floor_material := _make_material(Color(0.09, 0.12, 0.16), 0.9)
	var wall_material := _make_material(Color(0.12, 0.3, 0.38), 0.72)
	_add_box("Floor", Vector3(0.0, -0.15, 3.0), Vector3(width, 0.3, depth + 6.0), floor_material)
	_add_box("FrontWall", Vector3(0.0, wall_height * 0.5, -depth * 0.5), Vector3(width, wall_height, wall_thickness), wall_material)
	_add_box("LeftWall", Vector3(-width * 0.5, wall_height * 0.5, 0.0), Vector3(wall_thickness, wall_height, depth), wall_material)
	_add_box("RightWall", Vector3(width * 0.5, wall_height * 0.5, 0.0), Vector3(wall_thickness, wall_height, depth), wall_material)
	var back_segment_width := (width - door_width) * 0.5
	var back_segment_offset := door_width * 0.5 + back_segment_width * 0.5
	_add_box("BackWallLeft", Vector3(-back_segment_offset, wall_height * 0.5, depth * 0.5), Vector3(back_segment_width, wall_height, wall_thickness), wall_material)
	_add_box("BackWallRight", Vector3(back_segment_offset, wall_height * 0.5, depth * 0.5), Vector3(back_segment_width, wall_height, wall_thickness), wall_material)
	_add_entry_trigger(depth)
	room_light.position = Vector3(0.0, 4.5, 0.0)
	room_light.omni_range = maxf(width, depth) * 0.8


func _add_box(node_name: String, box_position: Vector3, box_size: Vector3, material: Material) -> void:
	var box := CSGBox3D.new()
	box.name = node_name
	box.position = box_position
	box.size = box_size
	box.material = material
	box.use_collision = true
	room_geometry.add_child(box)


func _add_entry_trigger(depth: float) -> void:
	var trigger := Area3D.new()
	trigger.name = "EntryTrigger"
	trigger.position = Vector3(0.0, 1.5, depth * 0.5 - 0.8)
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	trigger.monitorable = false
	trigger.process_mode = Node.PROCESS_MODE_PAUSABLE
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.4, 3.0, 1.2)
	collision.shape = shape
	trigger.add_child(collision)
	room_geometry.add_child(trigger)
	trigger.body_entered.connect(_on_entry_trigger_body_entered)


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	round_controller.register_player(player)
	_reset_player_at_entrance()


func _reset_player_at_entrance() -> void:
	if not is_instance_valid(player):
		return
	player.global_position = Vector3(0.0, 0.05, room_size.y * 0.5 + 2.2)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.camera_rotation = Vector2.ZERO
	player.camera.rotation = Vector3.ZERO


func _on_entry_trigger_body_entered(body: Node3D) -> void:
	if body != player or _encounter_spawned:
		return
	_encounter_spawned = true
	_spawn_configured_blocks()


func _spawn_configured_blocks() -> void:
	if _configured_blocks.is_empty():
		return
	var width := room_size.x
	var depth := room_size.y
	var height := 4.0
	var center_y := 2.4
	_spawn_block("left", Vector3(-width * 0.5 + 0.65, center_y, 0.0), Vector3(0.0, PI * 0.5, 0.0), Vector3.RIGHT, Vector2(maxf(depth - 3.0, 3.0), height), width - 1.3)
	_spawn_block("front", Vector3(0.0, center_y, -depth * 0.5 + 0.65), Vector3.ZERO, Vector3.BACK, Vector2(maxf(width - 3.0, 3.0), height), depth - 1.3)
	_spawn_block("right", Vector3(width * 0.5 - 0.65, center_y, 0.0), Vector3(0.0, -PI * 0.5, 0.0), Vector3.LEFT, Vector2(maxf(depth - 3.0, 3.0), height), width - 1.3)


func _spawn_block(slot: String, block_position: Vector3, block_rotation: Vector3, direction: Vector3, size: Vector2, distance: float) -> void:
	var config: Dictionary = _configured_blocks.get(slot, {})
	if config.is_empty() or not config.enabled:
		return
	var block := TARGET_BLOCK_SCENE.instantiate() as TargetBlock3D
	block.block_label = "%s block" % slot
	block.target_count = config.target_count
	block.moves_to_opposite_side = config.moves
	block.movement_speed = moving_block_speed
	block.travel_distance = maxf(distance, 0.0)
	block.crossing_damage = block_crossing_damage
	block.movement_direction = direction
	block.block_size = size
	block.position = block_position
	block.rotation = block_rotation
	blocks_container.add_child(block)
	round_controller.add_log(tr("LOG_BLOCK_DEPLOYED").format({"slot": slot.to_upper()}), "info")


func _clear_blocks() -> void:
	_clear_children(blocks_container)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _set_config_visible(is_visible: bool) -> void:
	config_panel.visible = is_visible
	get_tree().paused = is_visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if is_visible else Input.MOUSE_MODE_CAPTURED)


func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
