extends Node

## Revisa el HUD de puntaje sin abrir el editor: arma una cadena, la deja a la
## vista y despues captura el resumen de nivel. Guarda dos PNG en .godot/.


func _ready() -> void:
	var controller := $RoundHUD/RoundController as RoundController
	var score := $RoundHUD/ScoreController as ScoreController
	var hud := $RoundHUD/ScoreHUD as ScoreHUD
	score.prepare_level("visual-test", _fake_level(14))
	controller.start_round()
	controller.report_ammo_changed([7, 24])
	await get_tree().process_frame
	controller.report_room_entered("room-a", "Sala A")
	for index in 14:
		controller.report_attack_fired()
		controller.report_attack_hit()
		controller.report_zone_hit("aviso", "close", true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not hud.combo_box.visible:
		_fail("The combo counter should be visible while a chain is live.")
		return
	if not _inside_viewport(hud.combo_box):
		_fail("The combo counter should sit inside the reference viewport.")
		return
	if not _save("res://.godot/score-hud-chain.png"):
		return

	controller.report_room_cleared("room-a", "Sala A")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not hud.combo_box.visible:
		_fail("The banked chain should stay on screen instead of vanishing with the last target.")
		return
	if not _save("res://.godot/score-hud-bank.png"):
		return

	controller.complete_round()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not hud.results_panel.visible:
		_fail("Finishing the level should show the results panel.")
		return
	if not _inside_viewport(hud.results_panel):
		_fail("The results panel should sit inside the reference viewport.")
		return
	if hud.results_rows.get_child_count() <= 0:
		_fail("The results panel should list the closing bonuses.")
		return
	if not _save("res://.godot/score-hud-results.png"):
		return
	print("Score HUD visual smoke test passed.")
	get_tree().quit()


func _inside_viewport(control: Control) -> bool:
	var bounds := get_viewport().get_visible_rect()
	var origin := control.global_position
	return origin.x >= 0.0 and origin.y >= 0.0 \
			and origin.x + control.size.x <= bounds.size.x \
			and origin.y + control.size.y <= bounds.size.y


func _save(path: String) -> bool:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_fail("The active renderer cannot capture the HUD preview image.")
		return false
	if image.save_png(path) != OK:
		_fail("Could not save %s." % path)
		return false
	return true


func _fake_level(targets: int) -> Dictionary:
	return {
		"timeLimitSeconds": 90,
		"startingAmmo": {"magazine": 17, "reserve": 51},
		"rooms": [{
			"id": "room-a",
			"blocks": {"front": {"enabled": true, "waves": [{"windows": {"normal": targets}}]}},
		}],
	}


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
