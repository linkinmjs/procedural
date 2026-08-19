extends Node

## Captura el arma en primera persona en reposo, disparando y recargando para
## revisar a ojo la pose del modelo y el fogonazo.

const PLAYER_SCENE := preload("res://scenes/player/player_character.tscn")

var _player: CharacterBody3D


func _ready() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var manager := _player.get_node("Camera/LeanPivot/MainCamera/Weapons_Manager")
	var animation_player := manager.animation_player as AnimationPlayer

	await _capture_animation(animation_player, manager.current_weapon_slot.weapon.pick_up_animation, 0.45, "glock-idle")
	await _capture_animation(animation_player, manager.current_weapon_slot.weapon.shoot_animation, 0.012, "glock-shoot")
	await _capture_animation(animation_player, manager.current_weapon_slot.weapon.reload_animation, 0.7, "glock-reload")
	await _capture_spread(manager, animation_player)

	print("Glock visual smoke test passed.")
	get_tree().quit()


## Vacia el cargador para ver la mira abierta por el retroceso acumulado.
func _capture_spread(manager: Node3D, animation_player: AnimationPlayer) -> void:
	manager.current_weapon_slot.current_ammo = manager.current_weapon_slot.weapon.magazine
	for i in 6:
		animation_player.stop()
		manager.shoot()
		await get_tree().process_frame
	animation_player.stop()
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.save_png("res://.godot/glock-spread.png") != OK:
		push_error("Could not save the spread preview.")
		get_tree().quit(1)


func _capture_animation(animation_player: AnimationPlayer, animation_name: String, time: float, file_name: String) -> void:
	animation_player.play(animation_name)
	animation_player.seek(time, true)
	animation_player.advance(0.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.save_png("res://.godot/%s.png" % file_name) != OK:
		push_error("Could not save the %s preview." % file_name)
		get_tree().quit(1)
