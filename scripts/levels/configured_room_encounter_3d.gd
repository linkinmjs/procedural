class_name ConfiguredRoomEncounter3D
extends Area3D

const TARGET_BLOCK_SCENE := preload("res://scenes/targets/target_block_3d.tscn")

const RELATIVE_WALLS := {
	"north": {"left": "east", "front": "south", "right": "west"},
	"east": {"left": "south", "front": "west", "right": "north"},
	"south": {"left": "west", "front": "north", "right": "east"},
	"west": {"left": "north", "front": "east", "right": "south"},
}

var room_id := ""
var room_label := "Room"
var room_size := Vector2(14.0, 14.0)
var entry_wall := "south"
var blocks_config: Dictionary = {}
var movement_speed := 0.65
var crossing_damage := 15.0
var activated := false


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
		controller.add_log("ENTERED // %s" % room_label.to_upper(), "system")
	for slot in ["left", "front", "right"]:
		var config: Dictionary = blocks_config.get(slot, {})
		if bool(config.get("enabled", false)):
			_spawn_block(slot, config)


func _spawn_block(slot: String, config: Dictionary) -> void:
	var absolute_wall: String = RELATIVE_WALLS[entry_wall][slot]
	var block := TARGET_BLOCK_SCENE.instantiate() as TargetBlock3D
	block.block_label = "%s // %s" % [room_label, slot]
	var configured_waves: Array[int] = []
	for count_variant in config.get("waves", []):
		configured_waves.append(int(count_variant))
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
	add_child(block)


func _get_wall_setup(wall: String) -> Dictionary:
	var center_y := 2.4
	var block_height := 4.0
	match wall:
		"north":
			return {
				"position": Vector3(0.0, center_y, -room_size.y * 0.5 + 0.65),
				"rotation": Vector3.ZERO,
				"direction": Vector3.BACK,
				"size": Vector2(maxf(room_size.x - 3.0, 3.0), block_height),
				"distance": room_size.y - 1.3,
			}
		"south":
			return {
				"position": Vector3(0.0, center_y, room_size.y * 0.5 - 0.65),
				"rotation": Vector3(0.0, PI, 0.0),
				"direction": Vector3.FORWARD,
				"size": Vector2(maxf(room_size.x - 3.0, 3.0), block_height),
				"distance": room_size.y - 1.3,
			}
		"west":
			return {
				"position": Vector3(-room_size.x * 0.5 + 0.65, center_y, 0.0),
				"rotation": Vector3(0.0, PI * 0.5, 0.0),
				"direction": Vector3.RIGHT,
				"size": Vector2(maxf(room_size.y - 3.0, 3.0), block_height),
				"distance": room_size.x - 1.3,
			}
		_:
			return {
				"position": Vector3(room_size.x * 0.5 - 0.65, center_y, 0.0),
				"rotation": Vector3(0.0, -PI * 0.5, 0.0),
				"direction": Vector3.LEFT,
				"size": Vector2(maxf(room_size.y - 3.0, 3.0), block_height),
				"distance": room_size.x - 1.3,
			}


func _get_round_controller() -> RoundController:
	var controllers := get_tree().get_nodes_in_group("round_controller")
	if controllers.is_empty():
		return null
	return controllers[0] as RoundController
