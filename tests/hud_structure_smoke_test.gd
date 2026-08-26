extends SceneTree

## Smoke test headless del HUD de ronda rediseniado (esquinas + dinamismo):
## - los valores reaccionan a las seniales del RoundController
## - el log recorta a MAX_LOG_LINES y sus lineas se desvanecen solas
## - los vitales se atenuan en reposo y quedan encendidos con HP critico
## - el panel de precision ya no existe en vivo y la precision viaja en el
##   resumen de level_scored hacia la pantalla de resultados
##
## Corre con:
## Godot_v4.7-stable_win64_console.exe --headless --path . -s res://tests/hud_structure_smoke_test.gd

const ROUND_HUD_SCENE := preload("res://scenes/ui/round_hud.tscn")

var _summary: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var hud_root := ROUND_HUD_SCENE.instantiate()
	root.add_child(hud_root)
	var controller := hud_root.get_node("RoundController") as RoundController
	var score := hud_root.get_node("ScoreController") as ScoreController
	var hud := hud_root.get_node("GameHUD") as GameHUD
	score.prepare_level("hud-structure-test", _fake_level(3))
	score.level_scored.connect(func(summary: Dictionary) -> void: _summary = summary)
	# El bind por grupo es diferido y la entrada en cascada tarda menos de un
	# segundo; el settle al reposo llega despues del hold.
	await create_timer(0.1).timeout
	controller.start_round()
	controller.report_ammo_changed([7, 24])
	controller.report_attack_fired()
	controller.report_attack_fired()
	controller.report_attack_hit()

	if hud.find_child("AccuracyPanel", true, false) != null:
		return _fail("The live HUD should not carry an accuracy panel any more.")
	if hud.ammo_value.text != "07 / 24":
		return _fail("Ammo label should show magazine and reserve: got %s." % hud.ammo_value.text)
	if hud.health_value.text != "100 / 100":
		return _fail("Health label should show current and max HP: got %s." % hud.health_value.text)

	for index in 7:
		controller.add_log("line %d" % index, "info")
	if hud.log_lines.get_child_count() > hud.MAX_LOG_LINES:
		return _fail("The log should trim itself to %d lines." % hud.MAX_LOG_LINES)
	var newest := hud.log_lines.get_child(hud.log_lines.get_child_count() - 1) as Label
	if not newest.text.ends_with("line 6"):
		return _fail("The newest log line should be the last one added: got %s." % newest.text)

	# Reposo: despues del hold, los vitales tienen que estar atenuados.
	await create_timer(HudStyle.DIM_HOLD + HudStyle.DUR_SETTLE + 1.0).timeout
	if not is_equal_approx(hud.vitals_panel.modulate.a, HudStyle.DIM_ALPHA):
		return _fail("Idle vitals should rest at DIM_ALPHA: got %f." % hud.vitals_panel.modulate.a)

	# HP critico: el panel se enciende y no vuelve a apagarse.
	controller.report_target_left("penalty", 80.0)
	await create_timer(HudStyle.DIM_HOLD + HudStyle.DUR_SETTLE + 0.5).timeout
	if not is_equal_approx(hud.vitals_panel.modulate.a, 1.0):
		return _fail("Critical health should keep the vitals lit: got %f." % hud.vitals_panel.modulate.a)
	if hud.health_value.get_theme_color("font_color") != HudStyle.DANGER:
		return _fail("Critical health should paint the HP number in DANGER.")

	# El resumen del nivel lleva la precision a la pantalla de resultados.
	controller.complete_round()
	await create_timer(0.1).timeout
	if _summary.is_empty():
		return _fail("Completing the round should emit level_scored.")
	for key in ["hits", "attacks", "accuracy_percent"]:
		if not _summary.has(key):
			return _fail("The level summary should carry '%s' for the results screen." % key)
	if int(_summary.attacks) != 2 or int(_summary.hits) != 1:
		return _fail("The summary accuracy should match the shots fired: got %s/%s." % [_summary.hits, _summary.attacks])
	var rows := ScoreBreakdown.rows_for(_summary)
	var has_accuracy_row := false
	for row in rows:
		if str(row.label) == TranslationServer.translate("SCORE_ACCURACY"):
			has_accuracy_row = true
	if not has_accuracy_row:
		return _fail("ScoreBreakdown should include an accuracy row when shots were fired.")

	print("HUD structure smoke test passed.")
	quit()


func _fake_level(targets: int) -> Dictionary:
	return {
		"timeLimitSeconds": 90,
		"startingAmmo": {"magazine": 17, "reserve": 51},
		"rooms": [{
			"id": "room-a",
			"waves": [{"blocks": {"front": {"enabled": true, "layers": [{"windows": {"normal": targets}}]}}}],
		}],
	}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
