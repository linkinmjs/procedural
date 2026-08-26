extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/player_character.tscn")
const TARGET_BLOCK_SCENE := preload("res://scenes/targets/target_block_3d.tscn")

enum RoomShape {
	SMALL,
	LARGE,
	CORRIDOR,
}

## Familias que se pueden probar, en el orden del desplegable. "mezcla" reparte
## una de cada una para ver como conviven en la misma capa.
const FAMILY_CHOICES := [
	{"id": "normal", "label": "Normal"},
	{"id": "popup", "label": "Publicidad"},
	{"id": "firewall", "label": "Firewall"},
	{"id": "critical-error", "label": "Error critico"},
	{"id": "download", "label": "Descarga"},
	{"id": "infected-download", "label": "Descarga infectada"},
	{"id": "mixed", "label": "Mezcla"},
]
## La mezcla deja afuera la descarga infectada a proposito: cuelga el bloque
## entero, asi que repartida al azar arruinaria cualquier otra prueba antes de
## que se llegue a ver.
const MIXED_FAMILIES := ["normal", "popup", "firewall", "critical-error", "download"]
## Oleadas que ofrece el laboratorio. Coincide con el tope del control de la
## configuracion; para probar mas hace falta un nivel de verdad.
const MAX_LAB_WAVES := 3

const ROOM_DIMENSIONS := {
	RoomShape.SMALL: Vector2(14.0, 14.0),
	RoomShape.LARGE: Vector2(24.0, 18.0),
	RoomShape.CORRIDOR: Vector2(10.0, 28.0),
}

const LEVEL_PRESETS := [
	{"name": "Personalizado"},
	{
		"name": "Tres oleadas // frontal, lateral y lateral",
		"shape": RoomShape.SMALL,
		"front": {"enabled": true, "targets": 5, "layers": 2, "family": "normal", "wave": 1, "moves": false},
		"left": {"enabled": true, "targets": 5, "layers": 2, "family": "normal", "wave": 2, "moves": false},
		"right": {"enabled": true, "targets": 10, "layers": 1, "family": "normal", "wave": 3, "moves": false},
	},
	{
		"name": "Familias // una de cada una",
		"shape": RoomShape.LARGE,
		"left": {"enabled": true, "targets": 4, "layers": 1, "family": "popup", "wave": 1, "moves": false},
		"front": {"enabled": true, "targets": 5, "layers": 1, "family": "mixed", "wave": 1, "moves": false},
		"right": {"enabled": true, "targets": 4, "layers": 1, "family": "download", "wave": 1, "moves": false},
	},
	{
		"name": "Publicidad // se llama sola",
		"shape": RoomShape.SMALL,
		"left": {"enabled": false, "targets": 0, "layers": 1, "family": "normal", "wave": 1, "moves": false},
		"front": {"enabled": true, "targets": 2, "layers": 1, "family": "popup", "wave": 1, "moves": false},
		"right": {"enabled": false, "targets": 0, "layers": 1, "family": "normal", "wave": 1, "moves": false},
	},
	{
		"name": "Descarga // rapido paga mas que tarde",
		"shape": RoomShape.SMALL,
		"left": {"enabled": false, "targets": 0, "layers": 1, "family": "normal", "wave": 1, "moves": false},
		"front": {"enabled": true, "targets": 4, "layers": 1, "family": "download", "wave": 1, "moves": false},
		"right": {"enabled": false, "targets": 0, "layers": 1, "family": "normal", "wave": 1, "moves": false},
	},
	{
		"name": "Descarga infectada // no la dejes terminar",
		"shape": RoomShape.CORRIDOR,
		"left": {"enabled": false, "targets": 0, "layers": 1, "family": "normal", "wave": 1, "moves": false},
		"front": {"enabled": true, "targets": 3, "layers": 3, "family": "infected-download", "wave": 1, "moves": true},
		"right": {"enabled": false, "targets": 0, "layers": 1, "family": "normal", "wave": 1, "moves": false},
	},
	{
		"name": "Apiladas // la barra las trae al frente",
		"shape": RoomShape.SMALL,
		"left": {"enabled": false, "targets": 0, "layers": 1, "family": "normal", "wave": 1, "moves": false},
		"front": {"enabled": true, "targets": 10, "layers": 1, "family": "normal", "wave": 1, "moves": false},
		"right": {"enabled": false, "targets": 0, "layers": 1, "family": "normal", "wave": 1, "moves": false},
	},
	{
		"name": "Firewall // hay que desactivarlo primero",
		"shape": RoomShape.SMALL,
		"left": {"enabled": false, "targets": 0, "layers": 1, "family": "normal", "wave": 1, "moves": false},
		"front": {"enabled": true, "targets": 6, "layers": 1, "family": "firewall", "wave": 1, "moves": false},
		"right": {"enabled": false, "targets": 0, "layers": 1, "family": "normal", "wave": 1, "moves": false},
	},
	{
		"name": "Capas // el bloque se pela de a poco",
		"shape": RoomShape.SMALL,
		"left": {"enabled": false, "targets": 0, "layers": 1, "family": "normal", "wave": 1, "moves": false},
		"front": {"enabled": true, "targets": 4, "layers": 4, "family": "normal", "wave": 1, "moves": false},
		"right": {"enabled": false, "targets": 0, "layers": 1, "family": "normal", "wave": 1, "moves": false},
	},
	{
		"name": "Pasillo // laterales moviles en dos oleadas",
		"shape": RoomShape.CORRIDOR,
		"left": {"enabled": true, "targets": 4, "layers": 1, "family": "normal", "wave": 1, "moves": true},
		"front": {"enabled": false, "targets": 0, "layers": 1, "family": "normal", "wave": 1, "moves": false},
		"right": {"enabled": true, "targets": 4, "layers": 1, "family": "normal", "wave": 2, "moves": true},
	},
	{
		"name": "Pequena // cierre frontal",
		"shape": RoomShape.SMALL,
		"left": {"enabled": false, "targets": 0, "layers": 1, "family": "normal", "wave": 1, "moves": false},
		"front": {"enabled": true, "targets": 0, "layers": 1, "family": "normal", "wave": 1, "moves": false},
		"right": {"enabled": false, "targets": 0, "layers": 1, "family": "normal", "wave": 1, "moves": false},
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
## FAMILY_CHOICES mas los diseños del Window Workshop, que se leen del catalogo
## al abrir el laboratorio: un diseño nuevo se prueba aca sin armar un nivel.
var _family_choices: Array = []
## Oleada que se esta peleando, contando desde 1. Las siguientes esperan a que
## se limpie esta, igual que en una sala de la campania.
var _current_wave := 0
var _pending_blocks: Array[TargetBlock3D] = []


func _ready() -> void:
	_setup_room_options()
	_setup_family_options()
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


func _setup_family_options() -> void:
	_family_choices = FAMILY_CHOICES.duplicate()
	for slug in WindowDesignCatalog.get_slugs():
		_family_choices.append({
			"id": WindowCatalog.CUSTOM_PREFIX + slug,
			"label": WindowDesignCatalog.design_name(slug),
		})
	for option in [%LeftFamily, %FrontFamily, %RightFamily]:
		option.clear()
		for index in _family_choices.size():
			option.add_item(str(_family_choices[index].label), index)
		option.select(0)


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
	for spinbox in [%LeftTargets, %FrontTargets, %RightTargets,
			%LeftLayers, %FrontLayers, %RightLayers,
			%LeftWave, %FrontWave, %RightWave]:
		spinbox.value_changed.connect(func(_value: float) -> void: _mark_configuration_custom())
	for option in [%LeftFamily, %FrontFamily, %RightFamily]:
		option.item_selected.connect(func(_index: int) -> void: _mark_configuration_custom())


func _on_preset_selected(index: int) -> void:
	if index <= 0 or index >= LEVEL_PRESETS.size():
		return
	_applying_preset = true
	var preset: Dictionary = LEVEL_PRESETS[index]
	room_shape_option.select(preset.shape)
	_apply_block_preset("Left", preset.left)
	_apply_block_preset("Front", preset.front)
	_apply_block_preset("Right", preset.right)
	_applying_preset = false


func _apply_block_preset(slot: String, config: Dictionary) -> void:
	_slot_check(slot, "Enabled").button_pressed = config.enabled
	_slot_spin(slot, "Targets").value = config.targets
	_slot_spin(slot, "Layers").value = config.get("layers", 1)
	_slot_spin(slot, "Wave").value = config.get("wave", 1)
	_slot_check(slot, "Moves").button_pressed = config.moves
	var family := str(config.get("family", "normal"))
	var option := _slot_option(slot)
	option.select(0)
	for index in _family_choices.size():
		if str(_family_choices[index].id) == family:
			option.select(index)
			return


## Los controles de un slot se nombran por convencion: LeftTargets,
## FrontLayers y asi. Se buscan por nombre para no repetir tres veces la misma
## linea con el slot cambiado.
func _slot_check(slot: String, field: String) -> CheckBox:
	return get_node("%" + slot + field) as CheckBox


func _slot_spin(slot: String, field: String) -> SpinBox:
	return get_node("%" + slot + field) as SpinBox


func _slot_option(slot: String) -> OptionButton:
	return get_node("%" + slot + "Family") as OptionButton


func _mark_configuration_custom() -> void:
	if not _applying_preset and preset_option.selected != 0:
		preset_option.select(0)


func _apply_configuration() -> void:
	var shape := room_shape_option.get_selected_id() as RoomShape
	_configured_blocks = {
		"left": _read_block_config("Left"),
		"front": _read_block_config("Front"),
		"right": _read_block_config("Right"),
	}
	_current_wave = 0
	_pending_blocks.clear()
	_clear_blocks()
	_build_room(shape)
	_reset_player_at_entrance()
	_encounter_spawned = false
	round_controller.start_round()
	round_controller.add_log(tr("LOG_LAB_CONFIGURED"), "system")
	_set_config_visible(false)


func _read_block_config(slot: String) -> Dictionary:
	var family_index := maxi(_slot_option(slot).selected, 0)
	return {
		"enabled": _slot_check(slot, "Enabled").button_pressed,
		"target_count": int(_slot_spin(slot, "Targets").value),
		"layer_count": int(_slot_spin(slot, "Layers").value),
		"wave": int(_slot_spin(slot, "Wave").value),
		"family": str(_family_choices[family_index].id),
		"moves": _slot_check(slot, "Moves").button_pressed,
	}


## Capas del bloque, ya expandidas a la familia que va en cada lugar. Es el
## mismo formato que arma el cargador desde el JSON, asi que el laboratorio y
## la campania ejercitan el mismo camino.
func build_layers(config: Dictionary) -> Array[PackedStringArray]:
	var layers: Array[PackedStringArray] = []
	var per_layer := int(config.get("target_count", 0))
	if per_layer <= 0:
		return layers
	var family := str(config.get("family", "normal"))
	for _layer_index in int(config.get("layer_count", 1)):
		var types := PackedStringArray()
		for target_index in per_layer:
			if family == "mixed":
				types.append(MIXED_FAMILIES[target_index % MIXED_FAMILIES.size()])
			else:
				types.append(family)
		layers.append(types)
	return layers


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
	_start_next_wave()


## La oleada que sigue con bloques. Las vacias se saltean: si nadie puso nada en
## la oleada 2, la 3 no tiene por que quedarse esperando.
func _start_next_wave() -> void:
	_current_wave += 1
	while _current_wave <= MAX_LAB_WAVES:
		if _spawn_wave(_current_wave):
			return
		_current_wave += 1
	round_controller.add_log(tr("LOG_LAB_CLEARED"), "system")


## Devuelve si la oleada puso algun bloque en pie.
func _spawn_wave(wave: int) -> bool:
	var width := room_size.x
	var depth := room_size.y
	var height := 4.0
	var center_y := 2.4
	_spawn_block(wave, "left", Vector3(-width * 0.5 + 0.65, center_y, 0.0), Vector3(0.0, PI * 0.5, 0.0), Vector3.RIGHT, Vector2(maxf(depth - 3.0, 3.0), height), width - 1.3)
	_spawn_block(wave, "front", Vector3(0.0, center_y, -depth * 0.5 + 0.65), Vector3.ZERO, Vector3.BACK, Vector2(maxf(width - 3.0, 3.0), height), depth - 1.3)
	_spawn_block(wave, "right", Vector3(width * 0.5 - 0.65, center_y, 0.0), Vector3(0.0, -PI * 0.5, 0.0), Vector3.LEFT, Vector2(maxf(depth - 3.0, 3.0), height), width - 1.3)
	if _pending_blocks.is_empty():
		return false
	if _has_later_wave(wave):
		round_controller.add_log(tr("LOG_ROOM_WAVE").format({
			"room": tr("LOG_LAB_ROOM"),
			"wave": wave,
			"total": _declared_wave_count(),
		}), "system")
	return true


## Cuantas oleadas declaro la configuracion. Es la mayor de las que pidio algun
## bloque habilitado, no el tope del control.
func _declared_wave_count() -> int:
	var highest := 0
	for slot in _configured_blocks:
		var config: Dictionary = _configured_blocks[slot]
		if bool(config.get("enabled", false)) and not build_layers(config).is_empty():
			highest = maxi(highest, int(config.get("wave", 1)))
	return maxi(highest, 1)


func _has_later_wave(wave: int) -> bool:
	return _declared_wave_count() > wave


func _on_lab_block_closed(block: TargetBlock3D) -> void:
	_pending_blocks.erase(block)
	if _pending_blocks.is_empty():
		call_deferred("_start_next_wave")


func _spawn_block(wave: int, slot: String, block_position: Vector3, block_rotation: Vector3, direction: Vector3, size: Vector2, distance: float) -> void:
	var config: Dictionary = _configured_blocks.get(slot, {})
	if config.is_empty() or not config.enabled or int(config.get("wave", 1)) != wave:
		return
	var block := TARGET_BLOCK_SCENE.instantiate() as TargetBlock3D
	block.block_label = "%s block" % slot
	var layers := build_layers(config)
	block.layers = layers
	block.target_count = layers[0].size() if not layers.is_empty() else 0
	block.moves_to_opposite_side = config.moves
	block.movement_speed = moving_block_speed
	block.travel_distance = maxf(distance, 0.0)
	block.crossing_damage = block_crossing_damage
	block.movement_direction = direction
	block.block_size = size
	block.position = block_position
	block.rotation = block_rotation
	block.closed.connect(_on_lab_block_closed)
	_pending_blocks.append(block)
	blocks_container.add_child(block)
	round_controller.add_log(tr("LOG_BLOCK_DEPLOYED").format({"slot": slot.to_upper()}), "info")
	round_controller.add_log(tr("LOG_LAB_BLOCK_RECIPE").format({
		"family": _family_label(str(config.get("family", "normal"))).to_upper(),
		"layers": layers.size(),
		"targets": layers[0].size() if not layers.is_empty() else 0,
	}), "info")


## Nombre legible de una familia, para el registro.
func _family_label(family: String) -> String:
	for choice in _family_choices:
		if str(choice.id) == family:
			return str(choice.label)
	return family


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
