class_name ConfiguredRoomEncounter3D
extends Area3D

## Se emite al entrar a una sala que tiene bloques: es lo que sella sus puertas.
signal encounter_started(encounter: ConfiguredRoomEncounter3D)
## Se emite cuando ya no queda ningun bloque en pie, o de entrada si la sala no
## tenia ninguno.
signal encounter_cleared(encounter: ConfiguredRoomEncounter3D)

const TARGET_BLOCK_SCENE := preload("res://scenes/targets/target_block_3d.tscn")
## Aire que queda entre el bloque y los bordes de la pared. Es el minimo que
## evita que el panel roce la geometria sin dejar pasar al jugador.
const WALL_MARGIN := 0.4
## Separacion entre el bloque y la pared en la que arranca.
const WALL_OFFSET := 0.65
## Alto minimo del bloque: por debajo de esto no entra ninguna ventana.
const MIN_BLOCK_HEIGHT := 2.0

const RELATIVE_WALLS := {
	"north": {"left": "east", "front": "south", "right": "west"},
	"east": {"left": "south", "front": "west", "right": "north"},
	"south": {"left": "west", "front": "north", "right": "east"},
	"west": {"left": "north", "front": "east", "right": "south"},
}

var room_id := ""
var room_label := "Room"
var room_size := Vector2(14.0, 14.0)
## Altura de las paredes de la sala: el bloque las cubre desde el piso.
var wall_height := 6.0
## Alto maximo del bloque. Una pared muy alta llevaria las ventanas a donde no
## se apunta comodo, asi que el bloque se recorta acá y deja el resto libre.
var max_block_height := 6.0
var entry_wall := "south"
var blocks_config: Dictionary = {}
var movement_speed := 0.65
var crossing_damage := 15.0
var activated := false
var cleared := false

var _pending_blocks: Array[TargetBlock3D] = []


func configure(room: Dictionary) -> void:
	room_id = str(room.id)
	room_label = str(room.get("name", room_id))
	room_size = Vector2(float(room.size.width), float(room.size.depth))
	entry_wall = str(room.entry.wall)
	blocks_config = (room.blocks as Dictionary).duplicate(true)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(room_size.x - 1.0, 1.0), 3.0, maxf(room_size.y - 1.0, 1.0))
	collision.shape = shape
	collision.position.y = 1.5
	add_child(collision)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if activated or not body is CharacterBody3D:
		return
	activate()


func activate() -> void:
	if activated:
		return
	activated = true
	var controller := _get_round_controller()
	if controller != null:
		controller.add_log(tr("LOG_ENTERED").format({"room": room_label.to_upper()}), "system")
	for slot in ["left", "front", "right"]:
		var config: Dictionary = blocks_config.get(slot, {})
		if bool(config.get("enabled", false)):
			_spawn_block(slot, config)
	if _pending_blocks.is_empty():
		_mark_cleared()
		return
	encounter_started.emit(self)


func _spawn_block(slot: String, config: Dictionary) -> void:
	var absolute_wall: String = RELATIVE_WALLS[entry_wall][slot]
	var block := TARGET_BLOCK_SCENE.instantiate() as TargetBlock3D
	block.block_label = "%s // %s" % [room_label, slot]
	var configured_waves := LevelDefinitionLoader.get_wave_counts(config)
	block.waves = configured_waves
	block.target_count = configured_waves[0] if not configured_waves.is_empty() else 0
	block.block_color = Color.from_string(str(config.get("color", "#2ed5c5")), Color(0.08, 0.78, 1.0, 1.0))
	block.moves_to_opposite_side = str(config.get("movement", "static")) == "opposite"
	block.movement_speed = float(config.get("movementSpeed", movement_speed))
	block.crossing_damage = crossing_damage
	var wall_setup := _get_wall_setup(absolute_wall)
	block.position = wall_setup.position
	block.rotation = wall_setup.rotation
	block.movement_direction = wall_setup.direction
	block.block_size = wall_setup.size
	block.travel_distance = wall_setup.distance
	block.closed.connect(_on_block_closed)
	_pending_blocks.append(block)
	add_child(block)


func _on_block_closed(block: TargetBlock3D) -> void:
	_pending_blocks.erase(block)
	if _pending_blocks.is_empty():
		_mark_cleared()


func _mark_cleared() -> void:
	if cleared:
		return
	cleared = true
	encounter_cleared.emit(self)


## El bloque cubre el ancho entero de la pared menos un margen minimo, para que
## no quede ningun hueco por el que esquivarlo mientras avanza. A lo alto llega
## hasta el techo o hasta max_block_height, lo que sea menor.
func _get_wall_setup(wall: String) -> Dictionary:
	var available_height := maxf(wall_height - WALL_MARGIN, MIN_BLOCK_HEIGHT)
	var block_height := minf(available_height, maxf(max_block_height, MIN_BLOCK_HEIGHT))
	var center_y := block_height * 0.5
	var horizontal := wall == "north" or wall == "south"
	var block_width := maxf((room_size.x if horizontal else room_size.y) - WALL_MARGIN, 2.0)
	var size := Vector2(block_width, block_height)
	match wall:
		"north":
			return {
				"position": Vector3(0.0, center_y, -room_size.y * 0.5 + WALL_OFFSET),
				"rotation": Vector3.ZERO,
				"direction": Vector3.BACK,
				"size": size,
				"distance": room_size.y - WALL_OFFSET * 2.0,
			}
		"south":
			return {
				"position": Vector3(0.0, center_y, room_size.y * 0.5 - WALL_OFFSET),
				"rotation": Vector3(0.0, PI, 0.0),
				"direction": Vector3.FORWARD,
				"size": size,
				"distance": room_size.y - WALL_OFFSET * 2.0,
			}
		"west":
			return {
				"position": Vector3(-room_size.x * 0.5 + WALL_OFFSET, center_y, 0.0),
				"rotation": Vector3(0.0, PI * 0.5, 0.0),
				"direction": Vector3.RIGHT,
				"size": size,
				"distance": room_size.x - WALL_OFFSET * 2.0,
			}
		_:
			return {
				"position": Vector3(room_size.x * 0.5 - WALL_OFFSET, center_y, 0.0),
				"rotation": Vector3(0.0, -PI * 0.5, 0.0),
				"direction": Vector3.LEFT,
				"size": size,
				"distance": room_size.x - WALL_OFFSET * 2.0,
			}


func _get_round_controller() -> RoundController:
	var controllers := get_tree().get_nodes_in_group("round_controller")
	if controllers.is_empty():
		return null
	return controllers[0] as RoundController
