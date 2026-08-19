extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/sandbox/weapon_test.tscn")
	await process_frame
	await process_frame
	await physics_frame
	var player := get_first_node_in_group("player")
	if player == null:
		for node in get_nodes_in_group("World")[0].get_children():
			if node is CharacterBody3D:
				player = node
				break
	if player == null:
		_fail("Could not find the player in the weapon test scene.")
		return
	var camera := player.get_node("Camera/LeanPivot/MainCamera") as Camera3D
	var manager := camera.get_node("Weapons_Manager")
	if manager.enable_weapon_spread:
		_fail("Weapon spread must be disabled for the aim-training player.")
		return
	var viewport_center := camera.get_viewport().get_visible_rect().size * 0.5
	var sight := player.get_node("CanvasLayer/MainSight") as TextureRect
	var sight_center := sight.get_global_rect().get_center()
	if sight_center.distance_to(viewport_center) > 0.5:
		_fail("Crosshair center does not match viewport center.")
		return
	var projectile := manager.current_weapon_slot.weapon.projectile_to_load.instantiate() as Projectile
	projectile.aim_camera = camera
	manager.add_child(projectile)
	var collision: Array = projectile.Camera_Ray_Cast(Vector2.ZERO, 100.0)
	if collision[0] == null:
		_fail("Centered aim ray did not collide with the test wall.")
		return
	var hit_screen_position := camera.unproject_position(collision[1])
	if hit_screen_position.distance_to(viewport_center) > 0.5:
		_fail("Centered aim ray and crosshair differ by %.2f pixels." % hit_screen_position.distance_to(viewport_center))
		return
	print("Aim alignment smoke test passed.")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
