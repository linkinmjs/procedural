extends Node


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
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var panels := $RoundHUD/GameHUD/BottomBar/Panels as HBoxContainer
	for panel_name in ["LogPanel", "AccuracyPanel", "VitalsPanel"]:
		var panel := panels.get_node(panel_name) as Control
		if panel.global_position.x < 0.0 or panel.global_position.x + panel.size.x > get_viewport().get_visible_rect().size.x:
			_fail("HUD panel %s is outside the reference viewport." % panel_name)
			return
	var ammo_value := $RoundHUD/GameHUD/BottomBar/Panels/VitalsPanel/Margin/VBox/AmmoRow/AmmoValue as Label
	if ammo_value.text != "07 / 24":
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
