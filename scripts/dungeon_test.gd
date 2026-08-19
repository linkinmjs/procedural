extends Node3D

const PLAYER_SCENE := preload("res://Player_Controller/player_character.tscn")
const ROOM_LIGHT_SCENE := preload("res://scenes/room_light.tscn")
@onready var generator: DungeonGenerator3D = %DungeonGenerator3D
@onready var target_populator: DungeonTargetPopulator3D = %TargetPopulator
@onready var status_label: Label = %StatusLabel
@onready var seed_label: Label = %SeedLabel
@onready var round_controller: RoundController = $RoundHUD/RoundController

var current_seed: int
var player: CharacterBody3D


func _ready() -> void:
	generator.done_generating.connect(_on_dungeon_generated)
	generator.generating_failed.connect(_on_generation_failed)
	call_deferred("generate_new_dungeon")


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
		KEY_F5:
			generate_new_dungeon()
		KEY_F6:
			get_tree().change_scene_to_file("res://scenes/levels/playable_level.tscn")


func generate_new_dungeon() -> void:
	if generator.is_currently_generating:
		return
	if is_instance_valid(player):
		player.queue_free()
		player = null
	current_seed = randi()
	seed_label.text = "Semilla: %s" % current_seed
	status_label.text = "Generando dungeon..."
	generator.generate(current_seed)


func _on_dungeon_generated() -> void:
	_add_room_lights()
	target_populator.populate(generator)
	var spawn_points := get_tree().get_nodes_in_group("player_spawn_point")
	if spawn_points.is_empty():
		status_label.text = "Dungeon generado, pero no se encontro un spawn."
		return
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_transform = (spawn_points.back() as Node3D).global_transform
	round_controller.register_player(player)
	round_controller.start_round()
	status_label.text = "Dungeon listo | F5: nueva semilla | F2: probar armas"


func _on_generation_failed() -> void:
	status_label.text = "La generacion fallo. Presiona F5 para reintentar."


func _add_room_lights() -> void:
	for room in generator.find_children("*", "DungeonRoom3D", true, false):
		var room_size: Vector3 = Vector3(room.size_in_voxels) * room.voxel_scale
		var room_light := ROOM_LIGHT_SCENE.instantiate()
		room.add_child(room_light)
		room_light.position = Vector3(0.0, minf(room_size.y * 0.3, 3.2), 0.0)
		room_light.configure_for_room(room_size)
