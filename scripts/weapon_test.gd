extends Node3D

const PLAYER_SCENE := preload("res://Player_Controller/player_character.tscn")
## El jugador solo usa la Glock, asi que los pickups del poligono son municion.
const AMMO_PICKUP_SCENE := preload("res://Player_Controller/Spawnable_Objects/Weapons/glock_ammo_pickup.tscn")

@onready var round_controller: RoundController = $RoundHUD/RoundController


func _ready() -> void:
	_spawn_player()
	_spawn_weapon_pickups()
	round_controller.start_round()


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
			get_tree().change_scene_to_file("res://scenes/levels/playable_level.tscn")


func _spawn_player() -> void:
	var player := PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = %PlayerSpawn.global_position
	round_controller.register_player(player)


func _spawn_weapon_pickups() -> void:
	for marker in %PickupMarkers.get_children():
		var pickup: WeaponPickUp = AMMO_PICKUP_SCENE.instantiate()
		add_child(pickup)
		pickup.global_position = (marker as Node3D).global_position
