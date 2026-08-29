extends Node

## Retrata las dos caras de la derrota: el HUD con el aviso de "sin municion"
## latiendo junto al contador, y despues la pantalla de fallo con el motivo
## sobre el fondo apagado. Guarda dos PNG en .godot/.


func _ready() -> void:
	var controller := $RoundHUD/RoundController as RoundController
	controller.start_round()
	await get_tree().process_frame
	controller.report_ammo_changed([3, 0])
	controller.report_attack_fired()
	controller.report_ammo_changed([0, 0])
	# Sin consulta de objetivos el controlador asume que queda algo que
	# disparar: el aviso tiene que llegar antes de la gracia.
	await get_tree().create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	var hud := $RoundHUD/GameHUD as GameHUD
	var warning := hud.ammo_value.get_node_or_null("AmmoOut") as Label
	if warning == null or warning.text != tr("HUD_AMMO_OUT"):
		_fail("Running dry should show the out-of-ammo warning next to the counter.")
		return
	if not _save("res://.godot/hud-ammo-out-preview.png"):
		return

	var screen := FailureScreen.new()
	add_child(screen)
	screen.show_reason("ammo_depleted")
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var title := screen.find_child("Title", true, false) as Label
	var hint := screen.find_child("Hint", true, false) as Label
	if title == null or not title.text.contains(tr("REASON_AMMO_DEPLETED")):
		_fail("The failure title should name the reason.")
		return
	if hint == null or hint.text.is_empty():
		_fail("The failure screen should explain the reason in one line.")
		return
	var bounds := get_viewport().get_visible_rect().size
	for label: Label in [title, hint]:
		if label.global_position.x < 0.0 or label.global_position.x + label.size.x > bounds.x:
			_fail("Failure text %s is outside the reference viewport." % label.name)
			return
	if not _save("res://.godot/failure-screen-preview.png"):
		return
	print("Failure screen visual smoke test passed.")
	get_tree().quit()


func _save(path: String) -> bool:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_fail("The active renderer cannot capture the preview image.")
		return false
	if image.save_png(path) != OK:
		_fail("Could not save %s." % path)
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
