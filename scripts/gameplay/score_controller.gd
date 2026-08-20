class_name ScoreController
extends Node

## Puntuacion de la ronda: pozo, cadena, bonos, techo y rango.
##
## Escucha al RoundController y no toca a nadie mas. La ronda administra vida y
## tiempo; el puntaje es otra responsabilidad y vive aparte porque va a cambiar
## mucho mas seguido.
##
## Los puntos no se cobran al impactar: se acumulan en un pozo que se multiplica
## entero cuando la cadena se cierra. Una cadena vive dentro de una sala, asi
## que el techo de cada sala es aritmetica sobre el JSON del nivel.
##
## El diseño esta en docs/gdd_atractivo_y_progresion_ANEXO_puntuación.md.

signal score_changed(total: int)
signal chain_changed(hits: int, multiplier: float, pot: int)
signal chain_timer_changed(remaining: float, window: float)
signal chain_banked(hits: int, pot: int, multiplier: float, awarded: int, reason: String)
signal room_scored(room_label: String, breakdown: Dictionary)
signal level_scored(summary: Dictionary)

## Motivos de cierre de cadena. Solo room_cleared cobra al multiplicador vigente.
const REASON_ROOM_CLEARED := "room_cleared"
const REASON_DAMAGE := "damage"
const REASON_TRAP := "trap"
const REASON_TIMEOUT := "timeout"
const REASON_ROUND_ENDED := "round_ended"

@export var settings: ScoreSettings

var total_score := 0
var pot := 0
var chain_hits := 0
var level_id := ""
var plan: LevelScorePlan

var _controller: RoundController
var _chain_timer := 0.0
var _consecutive_misses := 0
var _room_id := ""
var _room_label := ""
var _room_active := false
var _room_score := 0
var _room_damage := 0.0
var _room_chain_breaks := 0
var _room_forced_banks := 0
var _room_shots := 0
var _room_hits := 0
var _room_resolved := 0
var _room_started_at := 0.0
var _rooms_with_targets := 0
var _rooms_clean := 0
var _rooms_perfect := 0
var _level_damage := 0.0
var _best_multiplier := 1.0
var _best_chain := 0
var _best_bank := 0
var _finished := false


func _ready() -> void:
	add_to_group("score_controller")
	if settings == null:
		settings = ScoreSettings.new()
	_bind_available_controller.call_deferred()


func _process(delta: float) -> void:
	if _finished or _controller == null or not _controller.is_running:
		return
	# El temporizador arranca recien con el primer acierto: entrar a una sala y
	# tardar en encontrar el primer blanco no puede costar nada todavia.
	if chain_hits <= 0 and pot <= 0:
		return
	_chain_timer = maxf(_chain_timer - delta, 0.0)
	chain_timer_changed.emit(_chain_timer, settings.grace_seconds)
	if _chain_timer > 0.0:
		return
	if settings.step_for_hits(chain_hits) <= 0:
		_bank(REASON_TIMEOUT)
		return
	_drop_steps(settings.timeout_step_drop, "TIMEOUT")
	_chain_timer = settings.grace_seconds


func bind(controller: RoundController) -> void:
	if controller == null or controller == _controller:
		return
	_controller = controller
	controller.shot_resolved.connect(_on_shot_resolved)
	controller.target_resolved.connect(_on_target_resolved)
	controller.damage_taken.connect(_on_damage_taken)
	controller.room_entered.connect(_on_room_entered)
	controller.room_cleared.connect(_on_room_cleared)
	controller.round_ended.connect(_on_round_ended)
	controller.round_armed.connect(_on_round_armed)


## El nivel entrega su definicion para que el techo y el par salgan del contenido
## y no de umbrales escritos a mano.
func prepare_level(id: String, level_data: Dictionary) -> void:
	level_id = id
	plan = LevelScorePlan.new(level_data, settings)


func get_multiplier() -> float:
	return settings.multiplier_for_hits(chain_hits)


func get_pending_award() -> int:
	return roundi(pot * get_multiplier())


func get_ceiling() -> int:
	return plan.ceiling if plan != null else 0


## Solo busca ronda si nadie la asigno antes: un bind explicito manda sobre lo
## que haya en el grupo.
func _bind_available_controller() -> void:
	if _controller != null:
		return
	for node in get_tree().get_nodes_in_group("round_controller"):
		if is_instance_valid(node):
			bind(node as RoundController)
			return


func _on_round_armed() -> void:
	total_score = 0
	pot = 0
	chain_hits = 0
	_chain_timer = 0.0
	_consecutive_misses = 0
	_room_active = false
	_rooms_with_targets = 0
	_rooms_clean = 0
	_rooms_perfect = 0
	_level_damage = 0.0
	_best_multiplier = 1.0
	_best_chain = 0
	_best_bank = 0
	_finished = false
	score_changed.emit(total_score)
	_emit_chain()


func _on_room_entered(room_id: String, room_label: String) -> void:
	_room_id = room_id
	_room_label = room_label
	_room_active = true
	_room_score = 0
	_room_damage = 0.0
	_room_chain_breaks = 0
	_room_forced_banks = 0
	_room_shots = 0
	_room_hits = 0
	_room_resolved = 0
	_room_started_at = _now()
	_reset_chain()


func _on_room_cleared(room_id: String, _room_label_unused: String) -> void:
	if not _room_active or room_id != _room_id:
		return
	_bank(REASON_ROOM_CLEARED)
	_room_active = false
	var targets := plan.room_targets(room_id) if plan != null else 0
	if targets <= 0:
		return
	_rooms_with_targets += 1
	_warn_on_target_shortfall(targets)
	var breakdown := _room_bonuses(room_id)
	for entry_variant in breakdown.bonuses:
		var entry := entry_variant as Dictionary
		_award(int(entry.points))
		_log("BONUS // %s +%d" % [str(entry.label), int(entry.points)], "score")
	if _room_damage <= 0.0:
		_rooms_clean += 1
	if bool(breakdown.perfect):
		_rooms_perfect += 1
		_log("PERFECT ROOM // %s" % _room_label.to_upper(), "system")
	breakdown["score"] = _room_score
	breakdown["ceiling"] = plan.room_ceiling(room_id) if plan != null else 0
	room_scored.emit(_room_label, breakdown)


## El techo sale de los objetivos que declara el JSON. Si la sala entrega menos
## de los que declara, el techo queda fuera de alcance y el rango baja para
## siempre sin que se vea el motivo, asi que conviene que grite.
func _warn_on_target_shortfall(declared: int) -> void:
	if _room_resolved >= declared:
		return
	var message := "%s resolved %d of the %d targets its level declares." % [_room_label, _room_resolved, declared]
	push_warning("ScoreController: %s The room ceiling is out of reach." % message)
	_log("CEILING UNREACHABLE // %d/%d TARGETS" % [_room_resolved, declared], "danger")


## Una sala sin objetivos no paga bonos: no hay nada que resolver bien en ella.
func _room_bonuses(room_id: String) -> Dictionary:
	var bonuses: Array[Dictionary] = []
	var clean := _room_damage <= 0.0
	var single_chain := _room_forced_banks <= 0
	var intact := _room_chain_breaks <= 0
	if clean:
		bonuses.append({"label": "NO DAMAGE", "points": settings.room_clean_bonus})
	if single_chain:
		bonuses.append({"label": "SINGLE CHAIN", "points": settings.room_single_chain_bonus})
	if intact:
		bonuses.append({"label": "CHAIN INTACT", "points": settings.room_intact_chain_bonus})
	var accuracy := float(_room_hits) / float(_room_shots) if _room_shots > 0 else 0.0
	var accuracy_bonus := settings.room_accuracy_bonus(accuracy)
	if accuracy_bonus > 0:
		bonuses.append({"label": "ACCURACY %d%%" % roundi(accuracy * 100.0), "points": accuracy_bonus})
	var par := plan.room_par(room_id) if plan != null else 0.0
	var saved := maxi(floori(par - (_now() - _room_started_at)), 0)
	if saved > 0:
		bonuses.append({"label": "UNDER PAR %ds" % saved, "points": saved * settings.par_second_bonus})
	return {
		"bonuses": bonuses,
		"clean": clean,
		"perfect": single_chain and intact,
		"accuracy": accuracy,
	}


func _on_target_resolved(kind: String, _label: String, zone_id: String, closed: bool) -> void:
	if _finished:
		return
	if kind == "window" and settings.is_trap_zone(zone_id):
		pot += settings.value_for_zone(zone_id)
		_log("TRAP // %d // CHAIN LOST" % settings.value_for_zone(zone_id), "danger")
		_bank(REASON_TRAP)
		return
	var value := settings.ball_value if kind == "ball" else settings.value_for_zone(zone_id)
	pot += value
	chain_hits += 1
	# Se cuentan objetivos cerrados, no zonas acertadas: una ventana de varias
	# etapas suma varios hits pero sigue siendo un solo objetivo de la sala.
	if closed:
		_room_resolved += 1
	_consecutive_misses = 0
	_chain_timer = settings.grace_seconds
	_best_chain = maxi(_best_chain, chain_hits)
	var multiplier := get_multiplier()
	if multiplier > _best_multiplier:
		_best_multiplier = multiplier
		_log("CHAIN x%s // %d HITS" % [_format_multiplier(multiplier), chain_hits], "score")
	_emit_chain()


## Un fallo hunde el multiplicador pero nunca toca el pozo ni cierra la cadena.
func _on_shot_resolved(hit: bool) -> void:
	if _finished:
		return
	if _room_active:
		_room_shots += 1
		if hit:
			_room_hits += 1
	if hit:
		return
	_consecutive_misses += 1
	_room_chain_breaks += 1
	_drop_steps(settings.miss_drop_for(_consecutive_misses), "SPRAY" if _consecutive_misses > 1 else "MISS")


func _on_damage_taken(_amount: float) -> void:
	if _finished:
		return
	_room_damage += _amount
	_level_damage += _amount
	if pot > 0 or chain_hits > 0:
		_log("HIT TAKEN // %d BANKED AT x1" % pot, "danger")
	_bank(REASON_DAMAGE)


func _on_round_ended(reason: String) -> void:
	if _finished:
		return
	_bank(REASON_ROUND_ENDED)
	_finished = true
	var completed := reason == "exit_reached"
	var bonuses: Array[Dictionary] = []
	if completed:
		bonuses = _level_bonuses()
		for entry_variant in bonuses:
			var entry := entry_variant as Dictionary
			_award(int(entry.points))
	var ceiling := get_ceiling()
	var ratio := float(total_score) / float(ceiling) if ceiling > 0 else 0.0
	var rank := settings.rank_for_ratio(ratio) if completed else {"letter": "-", "label": "INCOMPLETE", "index": -1}
	var summary := {
		"completed": completed,
		"reason": reason,
		"total": total_score,
		"ceiling": ceiling,
		"ratio": ratio,
		"rank": rank,
		"bonuses": bonuses,
		"best_multiplier": _best_multiplier,
		"best_chain": _best_chain,
		"best_bank": _best_bank,
		"rooms_with_targets": _rooms_with_targets,
		"rooms_clean": _rooms_clean,
		"rooms_perfect": _rooms_perfect,
		"no_damage": _level_damage <= 0.0,
	}
	summary["record"] = _store_record(summary)
	_log("SCORE %d // %s" % [total_score, str(rank.letter)], "system")
	level_scored.emit(summary)


func _level_bonuses() -> Array[Dictionary]:
	var bonuses: Array[Dictionary] = []
	var ammo_left := _controller.magazine_ammo + _controller.reserve_ammo
	if ammo_left > 0:
		bonuses.append({"label": "AMMO LEFT %d" % ammo_left, "points": ammo_left * settings.ammo_bonus_per_round})
	var seconds_left := floori(_controller.time_remaining)
	if seconds_left > 0:
		bonuses.append({"label": "TIME LEFT %ds" % seconds_left, "points": seconds_left * settings.time_bonus_per_second})
	if _level_damage <= 0.0:
		bonuses.append({"label": "NO DAMAGE", "points": settings.level_no_damage_bonus})
	if _rooms_with_targets > 0 and _rooms_clean >= _rooms_with_targets:
		bonuses.append({"label": "ALL ROOMS CLEAN", "points": settings.level_all_rooms_clean_bonus})
	if _rooms_with_targets > 0 and _rooms_perfect >= _rooms_with_targets:
		bonuses.append({"label": "PERFECT LEVEL", "points": settings.level_perfect_bonus})
	return bonuses


func _store_record(summary: Dictionary) -> Dictionary:
	var previous := ScoreRecords.load_record(level_id)
	var attempt := {
		"score": total_score,
		"ratio": float(summary.ratio),
		"chain": _best_chain,
		"bank": _best_bank,
		"no_damage": bool(summary.no_damage),
		"formula_version": settings.formula_version,
	}
	if bool(summary.completed):
		attempt["time"] = _controller.round_duration - _controller.time_remaining
	var improved := ScoreRecords.save_attempt(level_id, attempt)
	return {
		"previous": int(previous.get("score", 0)),
		"delta": total_score - int(previous.get("score", 0)),
		"is_new": improved.has("score"),
		"had_previous": previous.has("score"),
	}


## Cierra la cadena y cobra el pozo. Solo limpiar la sala cobra al multiplicador
## vigente: cualquier otro cierre paga a x1.
func _bank(reason: String) -> void:
	if pot == 0 and chain_hits == 0:
		_reset_chain()
		return
	var multiplier := get_multiplier() if reason == REASON_ROOM_CLEARED else 1.0
	var awarded := roundi(pot * multiplier)
	var banked_pot := pot
	var banked_hits := chain_hits
	_award(awarded)
	_best_bank = maxi(_best_bank, awarded)
	if reason == REASON_DAMAGE or reason == REASON_TRAP:
		_room_forced_banks += 1
	if reason == REASON_TIMEOUT:
		_room_forced_banks += 1
		_room_chain_breaks += 1
		_log("CHAIN TIMED OUT // %d BANKED" % banked_pot, "info")
	elif reason == REASON_ROOM_CLEARED:
		_log("ROOM CLEARED // %d x%s = %d" % [banked_pot, _format_multiplier(multiplier), awarded], "score")
	chain_banked.emit(banked_hits, banked_pot, multiplier, awarded, reason)
	_reset_chain()


func _drop_steps(count: int, label: String) -> void:
	var step := settings.step_for_hits(chain_hits)
	var target := maxi(step - count, 0)
	if target == step:
		return
	chain_hits = settings.hits_for_step(target)
	_log("%s // x%s -> x%s" % [label, _format_multiplier(settings.multiplier_for_step(step)), _format_multiplier(settings.multiplier_for_step(target))], "miss")
	_emit_chain()


func _reset_chain() -> void:
	pot = 0
	chain_hits = 0
	_consecutive_misses = 0
	_chain_timer = settings.grace_seconds
	_emit_chain()
	chain_timer_changed.emit(_chain_timer, settings.grace_seconds)


func _award(points: int) -> void:
	if points == 0:
		return
	total_score = maxi(total_score + points, 0)
	_room_score += points
	score_changed.emit(total_score)


func _emit_chain() -> void:
	chain_changed.emit(chain_hits, get_multiplier(), pot)


func _log(message: String, kind: String) -> void:
	if _controller != null:
		_controller.add_log(message, kind)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


static func _format_multiplier(multiplier: float) -> String:
	return "%.1f" % multiplier
