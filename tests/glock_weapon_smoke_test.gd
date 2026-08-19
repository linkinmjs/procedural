extends SceneTree

## Verifica el arma unica del jugador: cargador de 10 balas, recarga completa,
## animaciones declaradas y retroceso e imprecision dinamicos.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/weapon_test.tscn")
	await process_frame
	await process_frame
	var player := _find_player()
	if player == null:
		_fail("Could not find the player in the weapon test scene.")
		return
	# El jugador cae al suelo del poligono antes de medir la punteria en reposo.
	for i in 20:
		await physics_frame
	if not player.is_on_floor():
		_fail("The player should stand on the floor before measuring accuracy.")
		return

	var manager := player.get_node("Camera/LeanPivot/MainCamera/Weapons_Manager")
	var animation_player := manager.animation_player as AnimationPlayer

	if manager.weapon_stack.size() != 1:
		_fail("The player should carry a single weapon, found %d." % manager.weapon_stack.size())
		return

	var slot: WeaponSlot = manager.current_weapon_slot
	var weapon: WeaponResource = slot.weapon

	if weapon.weapon_name != "Glock":
		_fail("Expected the Glock as the only weapon, found %s." % weapon.weapon_name)
		return
	if weapon.magazine != 10:
		_fail("The Glock magazine should hold 10 rounds, found %d." % weapon.magazine)
		return
	if weapon.auto_fire:
		_fail("The Glock is semi automatic and must not auto fire.")
		return

	for animation_name in [
		weapon.pick_up_animation,
		weapon.shoot_animation,
		weapon.reload_animation,
		weapon.change_animation,
		weapon.drop_animation,
		weapon.out_of_ammo_animation,
		weapon.melee_animation,
	]:
		if not animation_player.has_animation(animation_name):
			_fail("Missing weapon animation: %s." % animation_name)
			return

	if weapon.recoil == null:
		_fail("The Glock needs a recoil profile.")
		return
	if not is_zero_approx(weapon.recoil.base_spread):
		_fail("The first standing shot must be perfectly accurate.")
		return

	# Disparando a maxima cadencia el arma tiene que abrirse: cada disparo debe
	# sumar mas dispersion de la que se recupera durante su propia animacion.
	var shot_cycle := animation_player.get_animation(weapon.shoot_animation).length
	if weapon.recoil.spread_per_shot <= weapon.recoil.spread_recovery * shot_cycle:
		_fail("Firing as fast as possible should widen the spread, not settle it.")
		return

	# Quieto y en el suelo el arma es exacta; en el aire nunca lo es.
	var resting_spread: float = manager._current_spread_degrees()
	if not is_zero_approx(resting_spread):
		_fail("Standing still the spread should be zero, found %.3f degrees." % resting_spread)
		return

	player.velocity.y = 6.0
	await physics_frame
	if manager._current_spread_degrees() < weapon.recoil.air_spread:
		_fail("Jumping should spoil the accuracy of the weapon.")
		return
	player.velocity.y = 0.0
	for i in 20:
		await physics_frame

	manager.shoot()
	if slot.current_ammo != 9:
		_fail("Firing once should leave 9 rounds, found %d." % slot.current_ammo)
		return
	if player.recoil_target.is_zero_approx():
		_fail("Firing should kick the view.")
		return
	if manager._current_spread_degrees() <= 0.0:
		_fail("Firing should widen the spread for the following shot.")
		return

	# Vaciar el cargador: cada disparo necesita que termine la animacion anterior.
	for i in 9:
		animation_player.stop()
		manager.shoot()
	if slot.current_ammo != 0:
		_fail("The magazine should be empty, found %d rounds." % slot.current_ammo)
		return

	var spread_after_burst: float = manager._current_spread_degrees()
	if spread_after_burst <= 0.5:
		_fail("A full burst should leave a wide spread, found %.3f degrees." % spread_after_burst)
		return

	# Recargar rellena el cargador desde la reserva y calma el arma.
	animation_player.stop()
	var reserve_before: int = slot.reserve_ammo
	manager.reload()
	manager.calculate_reload()
	if slot.current_ammo != 10:
		_fail("Reloading should refill the magazine, found %d." % slot.current_ammo)
		return
	if slot.reserve_ammo != reserve_before - 10:
		_fail("Reloading should take 10 rounds from the reserve.")
		return
	if manager._current_spread_degrees() > 0.0:
		_fail("Reloading should reset the accumulated spread.")
		return

	# Las cajas del poligono solo suman municion a la reserva de la Glock.
	slot.reserve_ammo = 0
	var ammo_pickup: WeaponPickUp = preload("res://Player_Controller/Spawnable_Objects/Weapons/glock_ammo_pickup.tscn").instantiate()
	player.add_sibling(ammo_pickup)
	var box_rounds: int = ammo_pickup.weapon.current_ammo + ammo_pickup.weapon.reserve_ammo
	manager._on_pick_up_detection_body_entered(ammo_pickup)
	if slot.reserve_ammo != box_rounds:
		_fail("Walking over an ammo box should refill the reserve, found %d." % slot.reserve_ammo)
		return
	if manager.weapon_stack.size() != 1:
		_fail("An ammo box must never add a second weapon to the stack.")
		return

	# La vista vuelve sola al punto de partida cuando el jugador deja de disparar.
	for i in 240:
		player.update_recoil(1.0 / 60.0)
	if not player.recoil_offset.is_zero_approx():
		_fail("The view should recover from recoil once the player stops firing.")
		return

	print("Glock weapon smoke test passed.")
	quit()


func _find_player() -> CharacterBody3D:
	for node in get_nodes_in_group("World")[0].get_children():
		if node is CharacterBody3D:
			return node
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
