extends SceneTree

## Verifica el apuntado con click derecho (ADS): mientras se mantiene
## Secondary_Fire la camara hace zoom, el rig del arma se centra, la dispersion
## baja, la mira del HUD se funde y el mouse se frena; al soltar, todo vuelve.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/sandbox/weapon_test.tscn")
	await process_frame
	await process_frame
	var player := _find_player()
	if player == null:
		_fail("Could not find the player in the weapon test scene.")
		return
	for i in 20:
		await physics_frame

	var manager := player.get_node("Camera/LeanPivot/MainCamera/Weapons_Manager")
	var camera := player.get_node("Camera/LeanPivot/MainCamera") as Camera3D
	var main_sight := player.get_node("CanvasLayer/MainSight") as Control
	var spread_sight := player.get_node("CanvasLayer/SpreadSight") as Control
	var profile: RecoilProfile = manager.current_weapon_slot.weapon.recoil
	var base_fov: float = camera.fov
	var rest_position: Vector3 = manager.position

	if not manager.enable_ads:
		_fail("ADS should be enabled on the player's weapon rig.")
		return
	if not is_zero_approx(manager.aim_blend()):
		_fail("The player should start from the hip, aim blend was %.3f." % manager.aim_blend())
		return
	if manager.ads_fov >= base_fov:
		_fail("ads_fov (%.1f) must be narrower than the base FOV (%.1f)." % [manager.ads_fov, base_fov])
		return
	if profile.ads_multiplier <= 0.0 or profile.ads_multiplier >= 1.0:
		_fail("ads_multiplier should shrink the spread, found %.2f." % profile.ads_multiplier)
		return

	# Mantener el click derecho lleva el rig a la mira y la camara al zoom.
	Input.action_press("Secondary_Fire")
	await _settle()
	if not is_equal_approx(manager.aim_blend(), 1.0):
		_fail("Holding Secondary_Fire should reach full aim, blend was %.3f." % manager.aim_blend())
		return
	if not is_equal_approx(camera.fov, manager.ads_fov):
		_fail("The camera should zoom to ads_fov (%.1f), found %.1f." % [manager.ads_fov, camera.fov])
		return
	if not manager.position.is_equal_approx(manager.ads_offset):
		_fail("The weapon rig should sit at ads_offset while aiming, found %s." % manager.position)
		return
	if not is_zero_approx(main_sight.modulate.a) or not is_zero_approx(spread_sight.modulate.a):
		_fail("Both crosshairs should fade out while aiming.")
		return
	var expected_scale: float = manager.ads_fov / base_fov
	if not is_equal_approx(player._aim_sensitivity_scale, expected_scale):
		_fail("Mouse sensitivity should scale with the FOV ratio (%.3f), found %.3f." % [expected_scale, player._aim_sensitivity_scale])
		return

	# La dispersion acumulada por disparos se reduce con el multiplicador ADS.
	manager._shot_spread = 2.0
	var aimed_spread: float = manager._current_spread_degrees()
	var expected_spread: float = 2.0 * profile.ads_multiplier
	if not is_equal_approx(aimed_spread, expected_spread):
		_fail("Aimed spread should be %.3f degrees, found %.3f." % [expected_spread, aimed_spread])
		return
	manager._shot_spread = 0.0

	# Al soltar, el arma vuelve a la cadera y la mira reaparece.
	Input.action_release("Secondary_Fire")
	await _settle()
	if not is_zero_approx(manager.aim_blend()):
		_fail("Releasing Secondary_Fire should return to the hip, blend was %.3f." % manager.aim_blend())
		return
	if not is_equal_approx(camera.fov, base_fov):
		_fail("The camera FOV should return to %.1f, found %.1f." % [base_fov, camera.fov])
		return
	if not manager.position.is_equal_approx(rest_position):
		_fail("The weapon rig should return to its rest pose, found %s." % manager.position)
		return
	if not is_equal_approx(main_sight.modulate.a, 1.0):
		_fail("The crosshair should be fully visible again after aiming.")
		return
	if not is_equal_approx(player._aim_sensitivity_scale, 1.0):
		_fail("Mouse sensitivity should be back to normal after aiming.")
		return

	print("ADS smoke test passed.")
	quit()


## El fundido es por tiempo real, no por frames: en headless los frames duran
## microsegundos y un contador de frames no alcanza a completarlo.
func _settle() -> void:
	await create_timer(1.0).timeout
	await process_frame


func _find_player() -> CharacterBody3D:
	for node in get_nodes_in_group("World")[0].get_children():
		if node is CharacterBody3D:
			return node
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
