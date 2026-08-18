extends Node3D

const PLAYER_SCENE := preload("res://Player_Controller/player_character.tscn")
const PICKUP_SCENES: Array[PackedScene] = [
	preload("res://Player_Controller/Spawnable_Objects/Weapons/blaster_n.tscn"),
	preload("res://Player_Controller/Spawnable_Objects/Weapons/blaster_L.tscn"),
	preload("res://Player_Controller/Spawnable_Objects/Weapons/blaster_m.tscn"),
	preload("res://Player_Controller/Spawnable_Objects/Weapons/blasterQ.tscn"),
]
const WEAPON_RESOURCES: Array[WeaponResource] = [
	preload("res://Player_Controller/scripts/Weapon_State_Machine/Weapon_Resources/blasterN.tres"),
	preload("res://Player_Controller/scripts/Weapon_State_Machine/Weapon_Resources/blasterL.tres"),
	preload("res://Player_Controller/scripts/Weapon_State_Machine/Weapon_Resources/blasterM.tres"),
	preload("res://Player_Controller/scripts/Weapon_State_Machine/Weapon_Resources/blasterQ.tres"),
]

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
	var markers := %PickupMarkers.get_children()
	for index in mini(markers.size(), PICKUP_SCENES.size()):
		var pickup: WeaponPickUp = PICKUP_SCENES[index].instantiate()
		var slot := WeaponSlot.new()
		slot.weapon = WEAPON_RESOURCES[index]
		slot.current_ammo = slot.weapon.magazine
		slot.reserve_ammo = slot.weapon.max_ammo
		pickup.weapon = slot
		add_child(pickup)
		pickup.global_position = (markers[index] as Node3D).global_position
