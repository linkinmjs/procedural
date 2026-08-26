extends Node

## Retrata el HUD de ronda en su layout de esquinas: vitales abajo a la
## izquierda, log abajo a la derecha, y ningun panel de precision en vivo
## (ese dato es de la pantalla de resultados). Guarda un PNG en .godot/.


func _ready() -> void:
	var controller := $RoundHUD/RoundController as RoundController
	controller.start_round()
	await get_tree().process_frame
	controller.report_attack_fired()
	controller.report_attack_fired()
	controller.report_attack_hit()
	controller.report_ammo_changed([7, 24])
	controller.report_target_hit("blue ball")
	controller.report_target_left("blue ball", 15.0)
	# La entrada en cascada dura menos de un segundo: se espera a que los
	# paneles asienten antes de medir posiciones y retratar.
	await get_tree().create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	var hud := $RoundHUD/GameHUD as GameHUD
	if hud.find_child("AccuracyPanel", true, false) != null:
		_fail("The live HUD should not carry an accuracy panel any more.")
		return
	var bounds := get_viewport().get_visible_rect().size
	for panel: Control in [hud.vitals_panel, hud.log_panel]:
		if panel.global_position.x < 0.0 or panel.global_position.x + panel.size.x > bounds.x \
				or panel.global_position.y < 0.0 or panel.global_position.y + panel.size.y > bounds.y:
			_fail("HUD panel %s is outside the reference viewport." % panel.name)
			return
	if hud.ammo_value.text != "07 / 24":
		_fail("HUD should show magazine and reserve ammo counts.")
		return
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_fail("The active renderer cannot capture the HUD preview image.")
		return
	var save_error := image.save_png("res://.godot/hud-preview.png")
	if save_error != OK:
		_fail("Could not save HUD preview image.")
		return
	print("HUD visual smoke test passed.")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
