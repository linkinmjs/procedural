extends SceneTree

## Prueba el puente entre la ronda y el perfil: que cada accion valiosa pague
## XP, que disparar no pague nada, que cada logro del catalogo se pueda ganar
## desde las señales existentes y que cerrar la partida arme el reporte.
##
## Usa un RoundController, un ScoreController y un AchievementTracker
## sinteticos, como el smoke test del puntaje, y un perfil con ruta propia.

const PATH := "user://_test_profile_achievements.cfg"

var _controller: RoundController
var _score: ScoreController
var _tracker: AchievementTracker
var _profile: GameProfile
var _settings: ScoreSettings


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup_files()
	_settings = ScoreSettings.new()
	_profile = GameProfile.new()
	_profile.storage_path = PATH
	root.add_child(_profile)
	await process_frame
	if not await _check_first_run():
		return
	if not await _check_shooting_pays_nothing():
		return
	if not await _check_ladders_and_traps():
		return
	if not await _check_room_badges():
		return
	if not await _check_failures():
		return
	if not await _check_closing_badges():
		return
	if not _check_direct_stats():
		return
	if not _check_badges_are_unique():
		return
	root.remove_child(_profile)
	_profile.free()
	_cleanup_files()
	print("Achievements smoke test passed.")
	quit()


## La primera partida regala sus primeros logros: arrancar, cerrar una
## ventana y limpiar una sala.
func _check_first_run() -> bool:
	_build_round("first")
	var xp_before := _profile.get_xp()
	_controller.start_round()
	if not _profile.has_badge("hello_world"):
		return _fail("Starting the first run should unlock HELLO WORLD.")
	_controller.report_room_entered("room-a", "Sala A")
	_hit_zone("close")
	if not _profile.has_badge("kill_9"):
		return _fail("Closing the first window should unlock KILL -9.")
	var per_close := _profile.settings.xp_for("zone_hit") + _profile.settings.xp_for("window_closed") + _profile.settings.xp_for("close_zone")
	var badge_xp := int(AchievementCatalog.find("hello_world").xp) + int(AchievementCatalog.find("kill_9").xp)
	if _profile.get_xp() != xp_before + per_close + badge_xp:
		return _fail("The first window should pay its zone, its close and the badges.")
	for _index in 5:
		_hit_zone("close")
	if int(_profile.get_stat("windows_closed")) != 6 or int(_profile.get_stat("closed_close")) != 6:
		return _fail("Window closes should count per zone.")
	if not _profile.has_badge("end_task_5"):
		return _fail("Five windows should unlock END TASK.")
	if int(_profile.get_stat("zone_hits")) != 6:
		return _fail("Every valid zone should count as a zone hit.")
	_controller.report_room_cleared("room-a", "Sala A")
	await process_frame
	if not _profile.has_badge("defrag_1"):
		return _fail("Clearing the first room should unlock DEFRAG.")
	if int(_profile.get_stat("rooms_cleared")) != 1 or int(_profile.get_stat("rooms_perfect")) != 1:
		return _fail("A flawless room should count as cleared and perfect.")
	if int(_profile.get_stat("chains_banked")) != 1:
		return _fail("Clearing a room banks its chain.")
	_teardown()
	return true


## Disparar, fallar y recargar no pagan XP: solo cuentan.
func _check_shooting_pays_nothing() -> bool:
	_build_round("shots")
	_controller.start_round()
	_controller.report_room_entered("room-a", "Sala A")
	var xp_before := _profile.get_xp()
	var shots_before := int(_profile.get_stat("shots_fired"))
	for _index in 4:
		_miss()
	await process_frame
	if _profile.get_xp() != xp_before:
		return _fail("Missing must not pay XP.")
	if int(_profile.get_stat("shots_fired")) != shots_before + 4:
		return _fail("Every shot should be counted.")
	_teardown()
	return true


## Las escaleras suben con la cuenta acumulada entre partidas, y la trampa es
## un logro sorpresa que no paga nada mas.
func _check_ladders_and_traps() -> bool:
	_build_round("ladders")
	_controller.start_round()
	_controller.report_room_entered("room-a", "Sala A")
	while int(_profile.get_stat("windows_closed")) < 25:
		_hit_zone("accept")
	if not _profile.has_badge("end_task_25"):
		return _fail("Twenty-five windows should unlock END PROCESS TREE.")
	if _profile.has_badge("alt_f4_10"):
		return _fail("Button closes must not count as X closes.")
	while int(_profile.get_stat("closed_close")) < 10:
		_hit_zone("close")
	if not _profile.has_badge("alt_f4_10"):
		return _fail("Ten X closes should unlock ALT+F4.")
	var xp_before := _profile.get_xp()
	_hit_zone("trap")
	await process_frame
	if not _profile.has_badge("segfault"):
		return _fail("Hitting a trap should unlock SEGFAULT.")
	if _profile.get_xp() != xp_before + int(AchievementCatalog.find("segfault").xp):
		return _fail("A trap pays only its surprise badge, never zone XP.")
	_teardown()
	return true


## Cobrar con el multiplicador al tope y la cadena unica sin fallos.
func _check_room_badges() -> bool:
	_build_round("rooms")
	_controller.start_round()
	_controller.report_room_entered("room-a", "Sala A")
	var top_hits := _settings.hits_for_step(_settings.top_step())
	var step_xp_before := _profile.get_xp()
	for _index in top_hits:
		_hit_zone("close")
	_controller.report_room_cleared("room-a", "Sala A")
	await process_frame
	if not _profile.has_badge("overclock"):
		return _fail("Banking at the top multiplier should unlock OVERCLOCK.")
	if not _profile.has_badge("clean_build"):
		return _fail("A perfect room should unlock CLEAN BUILD.")
	var expected_steps := 0
	for step in range(1, _settings.top_step() + 1):
		expected_steps += _profile.settings.xp_for("chain_step", step)
	if _profile.get_xp() - step_xp_before < expected_steps:
		return _fail("Climbing the chain should pay every step.")
	_teardown()
	return true


## Fallar tambien tiene premio: la pantalla azul y el sin tiempo son sorpresas.
func _check_failures() -> bool:
	_build_round("health")
	_controller.start_round()
	_controller.report_room_entered("room-a", "Sala A")
	_hit_zone("close")
	var report_holder: Array[Dictionary] = []
	_score.level_scored.connect(func(_summary: Dictionary) -> void: report_holder.append(_profile.last_run_report))
	_controller.apply_damage(_controller.max_health)
	await process_frame
	if not _profile.has_badge("blue_screen"):
		return _fail("Running out of HP should unlock BLUE SCREEN.")
	if int(_profile.get_stat("runs_failed")) != 1 or int(_profile.get_stat("hits_taken")) != 1:
		return _fail("A failed run should count as failed and the hit as taken.")
	if report_holder.is_empty() or bool(report_holder[0].completed):
		return _fail("A failed run should leave an incomplete report.")
	if int(report_holder[0].xp_earned) <= 0:
		return _fail("Even a failed run earns XP.")
	_teardown()

	_build_round("time", 0.05)
	_controller.start_round()
	await create_timer(0.2).timeout
	if not _profile.has_badge("not_responding"):
		return _fail("Running out of time should unlock NOT RESPONDING.")
	_teardown()
	return true


## Los logros de cierre salen del resumen: sin daño, precision, rango y campaña.
func _check_closing_badges() -> bool:
	_build_round("closing")
	_score.prepare_level("lvl-a", _fake_level(10))
	_controller.start_round()
	_controller.report_room_entered("room-a", "Sala A")
	for _index in 10:
		_hit_zone("close")
	_controller.report_room_cleared("room-a", "Sala A")
	await process_frame
	var reports: Array[Dictionary] = []
	_score.level_scored.connect(func(_summary: Dictionary) -> void: reports.append(_profile.last_run_report))
	_controller.complete_round()
	await process_frame
	if reports.is_empty():
		return _fail("Completing the round should build a run report.")
	var report := reports[0]
	if not bool(report.completed) or not bool(report.first_clear):
		return _fail("The first completion should be a first clear.")
	if not _profile.has_badge("firewall_up"):
		return _fail("A level without damage should unlock FIREWALL UP.")
	if not _profile.has_badge("pixel_perfect"):
		return _fail("Ten hits without a miss should unlock PIXEL PERFECT.")
	var badge_ids: Array[String] = []
	for badge in report.badges:
		badge_ids.append(str(badge.id))
	if not badge_ids.has("firewall_up"):
		return _fail("Closing badges should be listed in the run report.")
	if int(report.level_after) < int(report.level_before):
		return _fail("The level never goes down.")
	if not _profile.is_level_completed("lvl-a"):
		return _fail("Completing a level should mark it in the campaign.")
	_teardown()

	# Rango S y S+ y la campaña entera se validan con resumenes sinteticos:
	# alcanzar (o no) el techo en una sala falsa depende de la formula, no del
	# puente, asi que se miden los contadores y no la ausencia de un logro.
	_profile.set_catalog_ids(PackedStringArray(["lvl-a", "lvl-b"]))
	var s_before := int(_profile.get_stat("ranks_s"))
	var splus_before := int(_profile.get_stat("ranks_splus"))
	_profile.begin_run("lvl-b")
	var s_report := _profile.record_run("lvl-b", _fake_summary(4, "S"))
	if not _profile.has_badge("sudo"):
		return _fail("An S rank should unlock SUDO.")
	if int(_profile.get_stat("ranks_s")) != s_before + 1 or int(_profile.get_stat("ranks_splus")) != splus_before:
		return _fail("An S rank counts as S and not as S+.")
	if not _profile.has_badge("system_shutdown"):
		return _fail("Completing every catalog level should unlock SYSTEM SHUTDOWN.")
	if not bool(s_report.first_clear):
		return _fail("The synthetic level should be a first clear.")
	_profile.begin_run("lvl-b")
	var splus_report := _profile.record_run("lvl-b", _fake_summary(5, "S+"))
	if not _profile.has_badge("ring_0"):
		return _fail("An S+ rank should unlock RING 0.")
	if bool(splus_report.first_clear):
		return _fail("Repeating a level is not a first clear.")
	if int(_profile.get_stat("ranks_s")) != s_before + 2 or int(_profile.get_stat("ranks_splus")) != splus_before + 1:
		return _fail("S+ counts as S too.")
	return true


## Reintentos y madrugada llegan como estadisticas directas.
func _check_direct_stats() -> bool:
	_profile.increment_stat("retries", 10)
	if not _profile.has_badge("ctrl_z"):
		return _fail("Ten retries should unlock CTRL+Z.")
	_profile.increment_stat("late_night_runs")
	if not _profile.has_badge("cron_job"):
		return _fail("A late night run should unlock CRON JOB.")
	return true


## Un logro se gana una vez: repetir la condicion no lo duplica ni paga de nuevo.
func _check_badges_are_unique() -> bool:
	var count := _profile.badge_count()
	var xp := _profile.get_xp()
	_profile.increment_stat("retries", 10)
	if _profile.badge_count() != count or _profile.get_xp() != xp:
		return _fail("Repeating a badge condition must not award it twice.")
	var view := _profile.badges_view()
	if view.size() != AchievementCatalog.all().size():
		return _fail("badges_view should list the whole catalog.")
	var earned := 0
	for entry in view:
		if bool(entry.earned):
			earned += 1
	if earned != count:
		return _fail("badges_view should flag exactly the earned badges.")
	return true


func _build_round(level_id: String, duration := 120.0) -> void:
	_controller = RoundController.new()
	_controller.auto_start = false
	_controller.round_duration = duration
	root.add_child(_controller)
	_score = ScoreController.new()
	_score.settings = _settings
	root.add_child(_score)
	_score.bind(_controller)
	_score.prepare_level(level_id, _fake_level(12))
	_tracker = AchievementTracker.new()
	root.add_child(_tracker)
	_tracker.bind(_controller, _score, _profile)


func _teardown() -> void:
	root.remove_child(_tracker)
	root.remove_child(_score)
	root.remove_child(_controller)
	_tracker.free()
	_score.free()
	_controller.free()


func _hit_zone(zone_id: String) -> void:
	_controller.report_attack_fired()
	_controller.report_attack_hit()
	_controller.report_zone_hit("ventana", zone_id, true)


func _miss() -> void:
	_controller.report_attack_fired()


func _fake_level(targets: int) -> Dictionary:
	return {
		"timeLimitSeconds": 120,
		"startingAmmo": {"magazine": 17, "reserve": 51},
		"rooms": [{
			"id": "room-a",
			"waves": [{"blocks": {
				"front": {
					"enabled": true,
					"layers": [{"windows": {"normal": targets}}],
				},
			}}],
		}],
	}


func _fake_summary(rank_index: int, letter: String) -> Dictionary:
	return {
		"completed": true,
		"reason": "exit_reached",
		"total": 9000,
		"ceiling": 9000,
		"ratio": 1.0,
		"rank": {"letter": letter, "label": "ROOT", "index": rank_index},
		"best_multiplier": 8.0,
		"best_chain": 25,
		"best_bank": 5000,
		"no_damage": true,
		"hits": 25,
		"attacks": 25,
		"accuracy_percent": 100.0,
		"record": {"is_new": true, "had_previous": false, "previous": 0, "delta": 9000},
	}


func _cleanup_files() -> void:
	for path in [PATH, PATH + GameProfile.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> bool:
	_cleanup_files()
	push_error(message)
	quit(1)
	return false
