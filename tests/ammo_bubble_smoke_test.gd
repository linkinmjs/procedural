extends SceneTree

## La burbuja de municion: flota con la cantidad escrita, se toma disparandole
## o tocandola, entrega solo lo que entra en la reserva (y se queda con el
## resto) y revienta sin dar nada cuando el nivel termina.

const STUB_MANAGER := """
extends Node
var current_weapon_slot := WeaponSlot.new()
var granted := 0
func _init() -> void:
	current_weapon_slot.weapon = load("res://resources/weapons/glock.tres")
	current_weapon_slot.reserve_ammo = 50
func add_ammo(slot: WeaponSlot, ammo: int) -> int:
	var required: int = slot.weapon.max_ammo - slot.reserve_ammo
	var accepted: int = mini(ammo, required)
	slot.reserve_ammo += accepted
	granted += accepted
	return ammo - accepted
"""

var _manager: Node


func _initialize() -> void:
	create_timer(20.0, true, false, true).timeout.connect(func() -> void: _fail("Ammo bubble smoke test timed out."))
	_run.call_deferred()


func _run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var script := GDScript.new()
	script.source_code = STUB_MANAGER
	if script.reload() != OK:
		_fail("The stub weapons manager should compile.")
		return
	_manager = Node.new()
	_manager.name = "Weapons_Manager"
	_manager.set_script(script)
	camera.add_child(_manager)

	if not await _check_shot():
		return
	if not await _check_burst():
		return
	if not await _check_touch():
		return
	if not await _check_travel():
		return
	print("Ammo bubble smoke test passed.")
	quit()


## Un disparo la toma. Con la reserva a 50/60 solo entran 10 de 12: la burbuja
## se queda con las 2 que sobran, y al vaciarse la reserva el segundo disparo
## la revienta.
func _check_shot() -> bool:
	var bubble := AmmoBubble.new()
	bubble.amount = 12
	root.add_child(bubble)
	await process_frame
	if not bubble.is_in_group("Target") or bubble.collision_layer != AmmoBubble.TARGET_LAYER:
		return _fail("The bubble must be a shootable target on the target layer.")
	if not bubble.is_in_group(AmmoBubble.GROUP):
		return _fail("The bubble must join its own group so the level can burst it.")
	var label := bubble.get_node_or_null("Face/Amount") as Label3D
	if label == null or label.text != "12":
		return _fail("The bubble should show its amount.")
	if bubble.get_node_or_null("Face/Bullet") == null:
		return _fail("The bubble should show a bullet next to the amount.")
	bubble.Hit_Successful(25.0)
	await process_frame
	if int(_manager.granted) != 10:
		return _fail("The bubble should hand over only what fits in the reserve, got %d." % int(_manager.granted))
	if not is_instance_valid(bubble) or bubble.amount != 2 or label.text != "2":
		return _fail("A bubble with leftovers should stay with the remainder.")
	_manager.current_weapon_slot.reserve_ammo = 30
	bubble.Hit_Successful(25.0)
	await process_frame
	if int(_manager.granted) != 12:
		return _fail("The second shot should hand over the remainder.")
	await create_timer(0.6, true, false, true).timeout
	if is_instance_valid(bubble):
		return _fail("An emptied bubble should pop and free itself.")
	return true


## Reventar no entrega nada.
func _check_burst() -> bool:
	var bubble := AmmoBubble.new()
	bubble.amount = 20
	root.add_child(bubble)
	await process_frame
	var before := int(_manager.granted)
	bubble.burst()
	await create_timer(0.6, true, false, true).timeout
	if is_instance_valid(bubble):
		return _fail("A burst bubble should free itself.")
	if int(_manager.granted) != before:
		return _fail("Bursting must not grant ammo.")
	return true


## Caminar hasta la burbuja tambien la toma.
func _check_touch() -> bool:
	var bubble := AmmoBubble.new()
	bubble.amount = 5
	bubble.position = Vector3(10.0, 1.5, 0.0)
	root.add_child(bubble)
	var body := CharacterBody3D.new()
	body.collision_layer = AmmoBubble.PLAYER_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	shape.shape = capsule
	body.add_child(shape)
	root.add_child(body)
	body.position = Vector3(10.0, 1.5, 0.0)
	var before := int(_manager.granted)
	for _index in 6:
		await physics_frame
	await process_frame
	if int(_manager.granted) != before + 5:
		return _fail("Touching the bubble should hand over its ammo, got %d." % (int(_manager.granted) - before))
	return true


## Mientras viaja desde el bloque hasta su reposo no se puede tomar; al llegar
## queda quieta en el punto pedido y recien entonces se entrega.
func _check_travel() -> bool:
	var bubble := AmmoBubble.new()
	bubble.amount = 5
	root.add_child(bubble)
	bubble.travel_from(Vector3(6.0, 2.5, 0.0), Vector3(0.0, 1.5, 0.0), 0.2)
	if bubble.settled:
		return _fail("A travelling bubble should not count as settled.")
	var before := int(_manager.granted)
	bubble.Hit_Successful(25.0)
	await process_frame
	if int(_manager.granted) != before:
		return _fail("A travelling bubble must not hand over ammo yet.")
	await create_timer(0.6, true, false, true).timeout
	if not bubble.settled or bubble.global_position.distance_to(Vector3(0.0, 1.5, 0.0)) > 0.3:
		return _fail("The bubble should settle at its rest point, got %s." % str(bubble.global_position))
	bubble.Hit_Successful(25.0)
	await process_frame
	if int(_manager.granted) != before + 5:
		return _fail("A settled bubble should hand over its ammo.")
	return true


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
