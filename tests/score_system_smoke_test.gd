extends SceneTree

## Prueba del sistema de puntuacion: pozo, escalones, castigo por fallar, cobro
## al cerrar la sala, bonos de sala y de nivel, techo y rango.

const LEVEL_PATH := "res://level_designs/levels/nivel-2.json"

var _controller: RoundController
var _score: ScoreController
var _settings: ScoreSettings


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_settings = ScoreSettings.new()
	if not _check_settings_tables():
		return
	if not _check_plan():
		return
	if not await _check_chain_and_bank():
		return
	if not await _check_miss_penalty():
		return
	if not await _check_damage_banks_at_one():
		return
	if not await _check_timeout_decay():
		return
	if not await _check_trap_zone():
		return
	if not await _check_level_summary():
		return
	print("Score system smoke test passed.")
	quit()


## Los escalones tienen que ser reversibles: el hit minimo de un escalon vuelve
## a ese mismo escalon, o bajar N escalones dejaria al jugador en otro lado.
func _check_settings_tables() -> bool:
	for step in _settings.chain_multipliers.size():
		var hits := _settings.hits_for_step(step)
		if _settings.step_for_hits(hits) != step:
			return _fail("Step %d does not round-trip through its minimum hit count." % step)
	if _settings.step_for_hits(0) != 0:
		return _fail("An empty chain must sit on the first step.")
	if _settings.multiplier_for_hits(100) != _settings.multiplier_for_step(_settings.top_step()):
		return _fail("A long chain must cap at the top step.")
	if _settings.value_for_zone("close") <= _settings.value_for_zone("cancel"):
		return _fail("The close zone must be worth more than a button.")
	if not _settings.is_trap_zone("trap"):
		return _fail("A negative zone value must read as a trap.")
	if _settings.miss_drop_for(1) != 2 or _settings.miss_drop_for(9) != 4:
		return _fail("Consecutive misses must escalate and then hold.")
	return true


func _check_plan() -> bool:
	var level_data := LevelDefinitionLoader.load_level(LEVEL_PATH)
	if level_data.is_empty():
		return _fail("The test level could not be loaded.")
	var plan := LevelScorePlan.new(level_data, _settings)
	if plan.targets_total <= 0:
		return _fail("The test level should declare targets.")
	if plan.ceiling <= 0:
		return _fail("A level with targets must have a ceiling.")
	if plan.par_seconds <= 0.0:
		return _fail("A level with targets must have a time par.")
	var rooms_with_targets := 0
	for room_id in plan.rooms:
		if plan.room_targets(room_id) > 0:
			rooms_with_targets += 1
			if plan.room_ceiling(room_id) <= 0:
				return _fail("A room with targets must have a ceiling.")
		elif plan.room_ceiling(room_id) != 0:
			return _fail("A room without targets must not pay bonuses.")
	if rooms_with_targets < 2:
		return _fail("The test level should have several rooms with targets.")
	return true


## Doce aciertos seguidos llegan al cuarto escalon, y limpiar la sala cobra el
## pozo entero a ese multiplicador.
func _check_chain_and_bank() -> bool:
	_build_round()
	_score.prepare_level("test-room", _fake_level(12))
	_controller.start_round()
	_controller.report_room_entered("room-a", "Sala A")
	for index in 12:
		_hit_zone("close")
	if _score.chain_hits != 12:
		return _fail("Twelve resolved targets should leave a chain of twelve.")
	var multiplier := _settings.multiplier_for_hits(12)
	if not is_equal_approx(_score.get_multiplier(), multiplier):
		return _fail("A chain of twelve should sit on its own step.")
	var expected_pot := 12 * _settings.value_for_zone("close")
	if _score.pot != expected_pot:
		return _fail("The pot should hold every target value, unmultiplied.")
	if _score.total_score != 0:
		return _fail("Points must not reach the score before the chain is banked.")
	_controller.report_room_cleared("room-a", "Sala A")
	await process_frame
	var banked := roundi(expected_pot * multiplier)
	if _score.total_score < banked:
		return _fail("Clearing the room should bank the pot at the live multiplier.")
	if _score.total_score != banked + _expected_room_bonuses(12):
		return _fail("A flawless room should pay every room bonus once.")
	if _score.pot != 0 or _score.chain_hits != 0:
		return _fail("Banking must reset the chain.")
	_teardown()
	return true


## Fallar hunde el multiplicador pero no toca el pozo ni cierra la cadena.
func _check_miss_penalty() -> bool:
	_build_round()
	_score.prepare_level("test-miss", _fake_level(12))
	_controller.start_round()
	_controller.report_room_entered("room-a", "Sala A")
	for index in 10:
		_hit_zone("close")
	var pot_before := _score.pot
	var step_before := _settings.step_for_hits(_score.chain_hits)
	_miss()
	await process_frame
	var step_after := _settings.step_for_hits(_score.chain_hits)
	if step_after != step_before - 2:
		return _fail("A single miss should drop two steps.")
	if _score.pot != pot_before:
		return _fail("A miss must never touch the pot.")
	_miss()
	await process_frame
	if _settings.step_for_hits(_score.chain_hits) != maxi(step_after - 3, 0):
		return _fail("A second consecutive miss should drop three steps.")
	if _score.total_score != 0:
		return _fail("Missing must not bank anything.")
	_teardown()
	return true


## El daño cierra la cadena y la cobra al peor precio, sin perder el pozo.
func _check_damage_banks_at_one() -> bool:
	_build_round()
	_score.prepare_level("test-damage", _fake_level(12))
	_controller.start_round()
	_controller.report_room_entered("room-a", "Sala A")
	for index in 6:
		_hit_zone("close")
	var pot_before := _score.pot
	if _score.get_multiplier() <= 1.0:
		return _fail("Six hits should already carry a multiplier.")
	_controller.apply_damage(15.0)
	await process_frame
	if _score.total_score != pot_before:
		return _fail("Damage should bank the pot at x1, not lose it.")
	if _score.chain_hits != 0 or _score.pot != 0:
		return _fail("Damage should close the chain.")
	_hit_zone("close")
	if _score.pot != _settings.value_for_zone("close"):
		return _fail("A new chain should start right after the forced bank.")
	_teardown()
	return true


## Quedarse quieto decae la cadena de a un escalon, y en el piso la cierra.
func _check_timeout_decay() -> bool:
	var restore := _settings.grace_seconds
	_settings.grace_seconds = 0.05
	_build_round()
	_score.prepare_level("test-timeout", _fake_level(12))
	_controller.start_round()
	_controller.report_room_entered("room-a", "Sala A")
	for index in 10:
		_hit_zone("close")
	var pot_before := _score.pot
	var step_before := _settings.step_for_hits(_score.chain_hits)
	await create_timer(0.12).timeout
	var step_after := _settings.step_for_hits(_score.chain_hits)
	if step_after >= step_before:
		_settings.grace_seconds = restore
		return _fail("Standing still should decay the chain.")
	if _score.pot != pot_before:
		_settings.grace_seconds = restore
		return _fail("Decay must never touch the pot.")
	await create_timer(0.6).timeout
	if _score.total_score != pot_before:
		_settings.grace_seconds = restore
		return _fail("A chain abandoned down to the floor should bank at x1.")
	if _score.chain_hits != 0 or _score.pot != 0:
		_settings.grace_seconds = restore
		return _fail("Timing out should close the chain.")
	_settings.grace_seconds = restore
	_teardown()
	return true


## Una zona trampa resta y cierra la cadena al peor precio.
func _check_trap_zone() -> bool:
	_build_round()
	_score.prepare_level("test-trap", _fake_level(12))
	_controller.start_round()
	_controller.report_room_entered("room-a", "Sala A")
	for index in 6:
		_hit_zone("close")
	var pot_before := _score.pot
	_hit_zone("trap")
	await process_frame
	var expected := pot_before + _settings.value_for_zone("trap")
	if _score.total_score != expected:
		return _fail("A trap should subtract its value and bank the rest at x1.")
	if _score.chain_hits != 0 or _score.pot != 0:
		return _fail("A trap should close the chain.")
	_teardown()
	return true


## Terminar el nivel paga los bonos de cierre y entrega rango solo si se llego a
## la salida.
func _check_level_summary() -> bool:
	_build_round()
	_score.prepare_level("test-summary", _fake_level(6))
	_controller.start_round()
	_controller.report_ammo_changed([5, 10])
	_controller.report_room_entered("room-a", "Sala A")
	for index in 6:
		_hit_zone("close")
	_controller.report_room_cleared("room-a", "Sala A")
	await process_frame
	# La lambda captura los locales por valor, asi que el resumen se recoge en un
	# contenedor compartido y no en una asignacion.
	var published: Array[Dictionary] = []
	_score.level_scored.connect(func(value: Dictionary) -> void: published.append(value))
	_controller.complete_round()
	await process_frame
	if published.is_empty():
		return _fail("Finishing the round should publish a summary.")
	var summary := published[0]
	if not bool(summary.completed):
		return _fail("Reaching the exit should count as completed.")
	if int(summary.ceiling) <= 0:
		return _fail("The summary should carry the level ceiling.")
	if float(summary.ratio) <= 0.0:
		return _fail("The summary should carry the share of the ceiling reached.")
	if str((summary.rank as Dictionary).letter).is_empty():
		return _fail("A completed level should get a rank.")
	if not bool(summary.no_damage):
		return _fail("An untouched run should report no damage.")
	var ammo_bonus := (5 + 10) * _settings.ammo_bonus_per_round
	if not _summary_has_bonus(summary, ammo_bonus):
		return _fail("Unspent ammo should pay its bonus.")
	if not _summary_has_bonus(summary, _settings.level_no_damage_bonus):
		return _fail("A run without damage should pay its bonus.")
	if not _summary_has_bonus(summary, _settings.level_perfect_bonus):
		return _fail("A flawless run should pay the perfect level bonus.")
	_teardown()
	return true


func _summary_has_bonus(summary: Dictionary, points: int) -> bool:
	for entry_variant in summary.bonuses:
		if int((entry_variant as Dictionary).points) == points:
			return true
	return false


func _expected_room_bonuses(targets: int) -> int:
	return _settings.room_clean_bonus \
			+ _settings.room_single_chain_bonus \
			+ _settings.room_intact_chain_bonus \
			+ _settings.room_accuracy_bonus(1.0) \
			+ _under_par_bonus(targets)


## La sala se limpia en el mismo cuadro, asi que el par entero queda de sobra.
func _under_par_bonus(targets: int) -> int:
	var par := targets * _settings.par_seconds_per_target + _settings.par_transit_seconds
	return floori(par) * _settings.par_second_bonus


func _build_round() -> void:
	_controller = RoundController.new()
	_controller.auto_start = false
	_controller.round_duration = 120.0
	root.add_child(_controller)
	_score = ScoreController.new()
	_score.settings = _settings
	root.add_child(_score)
	_score.bind(_controller)


func _teardown() -> void:
	root.remove_child(_score)
	root.remove_child(_controller)
	_score.free()
	_controller.free()


## Un acierto es un disparo que se resuelve contra una zona.
func _hit_zone(zone_id: String) -> void:
	_controller.report_attack_fired()
	_controller.report_attack_hit()
	_controller.report_zone_hit("ventana", zone_id, true)


func _miss() -> void:
	_controller.report_attack_fired()


## Nivel sintetico de una sola sala, para no depender del contenido del catalogo.
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


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
