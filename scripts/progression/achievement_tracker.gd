class_name AchievementTracker
extends Node

## Traduce lo que pasa en la ronda a XP y estadisticas del perfil.
##
## Escucha al RoundController y al ScoreController igual que lo hace el HUD:
## se auto-cablea por grupos y no toca a nadie. El gameplay no sabe que existe
## un perfil; este nodo es el unico puente, y sin perfil en el arbol (los
## smoke tests que no lo cargan) no hace nada.
##
## Que paga XP y cuanto vive en ProgressionSettings; que logro depende de que
## estadistica vive en AchievementCatalog. Aca solo se decide cuando ocurre
## cada cosa.

## Horas locales que cuentan como "de madrugada" para el logro sorpresa.
const LATE_NIGHT_FROM := 2
const LATE_NIGHT_TO := 4

var _controller: RoundController
var _score: ScoreController
var _profile: GameProfile
var _last_step := 0


func _ready() -> void:
	add_to_group("achievement_tracker")
	_bind_available.call_deferred()


func bind(controller: RoundController, score: ScoreController, profile: GameProfile) -> void:
	if controller == null or score == null or profile == null:
		return
	if _controller != null:
		return
	_controller = controller
	_score = score
	_profile = profile
	controller.round_armed.connect(_on_round_armed)
	controller.round_started.connect(_on_round_started)
	controller.shot_resolved.connect(_on_shot_resolved)
	controller.target_resolved.connect(_on_target_resolved)
	controller.damage_taken.connect(_on_damage_taken)
	score.chain_changed.connect(_on_chain_changed)
	score.chain_banked.connect(_on_chain_banked)
	score.room_scored.connect(_on_room_scored)
	score.level_scored.connect(_on_level_scored)
	profile.badge_unlocked.connect(_on_badge_unlocked)
	profile.level_up.connect(_on_level_up)
	# El nivel arma la ronda en su _ready, antes de que este bind diferido
	# exista: la cuenta de la partida se abre aca para no perderla.
	_profile.begin_run(score.level_id)


func is_bound() -> bool:
	return _profile != null


## Solo busca a los demas si nadie los asigno antes: un bind explicito manda.
## Y solo engancha rondas de niveles de la campaña: el HUD de ronda tambien lo
## usan el laboratorio de bloques y los bancos de prueba, y jugar ahi no puede
## sumar XP ni logros de verdad. Un bind explicito (los tests) no pasa por
## este filtro.
func _bind_available() -> void:
	if _controller != null:
		return
	var profile := get_node_or_null("/root/PlayerProfile") as GameProfile
	if profile == null:
		return
	var controller: RoundController
	var score: ScoreController
	for node in get_tree().get_nodes_in_group("round_controller"):
		if is_instance_valid(node):
			controller = node as RoundController
			break
	for node in get_tree().get_nodes_in_group("score_controller"):
		if is_instance_valid(node):
			score = node as ScoreController
			break
	if score == null or not profile.is_catalog_level(score.level_id):
		return
	bind(controller, score, profile)


func _on_round_armed() -> void:
	_last_step = 0
	_profile.begin_run(_score.level_id)


func _on_round_started() -> void:
	_profile.increment_stat("runs_started")
	if _is_late_night():
		_profile.increment_stat("late_night_runs")


func _on_shot_resolved(hit: bool) -> void:
	_profile.increment_stat("shots_fired")
	if hit:
		_profile.increment_stat("shots_hit")


## Una zona valida paga; una trampa solo se anota. Cerrar la ventana paga
## aparte, y cerrarla por la X un poco mas: es la forma limpia de resolverla.
func _on_target_resolved(kind: String, _label: String, zone_id: String, closed: bool) -> void:
	if kind == "window" and _score.settings.is_trap_zone(zone_id):
		_profile.increment_stat("traps_hit")
		return
	if kind == "ball":
		_profile.increment_stat("balls_destroyed")
		_profile.award("ball")
		return
	_profile.increment_stat("zone_hits")
	_profile.award("zone_hit")
	if not closed:
		return
	_profile.increment_stat("windows_closed")
	_profile.award("window_closed")
	var zone_stat := "closed_%s" % zone_id
	if ProfileData.DEFAULT_STATS.has(zone_stat):
		_profile.increment_stat(zone_stat)
	if zone_id == "close":
		_profile.award("close_zone")


func _on_damage_taken(amount: float) -> void:
	_profile.increment_stat("hits_taken")
	_profile.add_stat("damage_taken", amount)


## Subir un escalon de la cadena paga proporcional al escalon: mantenerla
## viva es lo que el juego quiere ver.
func _on_chain_changed(hits: int, _multiplier: float, _pot: int) -> void:
	var step := _score.settings.step_for_hits(hits)
	if step > _last_step:
		_profile.award("chain_step", {}, step)
	_last_step = step


func _on_chain_banked(hits: int, _pot: int, _multiplier: float, _awarded: int, reason: String) -> void:
	if reason != ScoreController.REASON_ROOM_CLEARED:
		return
	_profile.increment_stat("chains_banked")
	if _score.settings.step_for_hits(hits) >= _score.settings.top_step():
		_profile.increment_stat("banks_at_top")


func _on_room_scored(_room_label: String, breakdown: Dictionary) -> void:
	_profile.increment_stat("rooms_cleared")
	_profile.award("room_cleared")
	if bool(breakdown.get("clean", false)):
		_profile.increment_stat("rooms_clean")
		_profile.award("room_clean")
	if bool(breakdown.get("perfect", false)):
		_profile.increment_stat("rooms_perfect")
		_profile.award("room_perfect")


func _on_level_scored(summary: Dictionary) -> void:
	_profile.add_stat("time_played", maxf(_controller.round_duration - _controller.time_remaining, 0.0))
	_profile.record_run(_score.level_id, summary)


## Los avisos del perfil dejan rastro en el log del HUD, esten o no en un globo.
func _on_badge_unlocked(badge: Dictionary, _quiet: bool) -> void:
	_log(tr("LOG_BADGE").format({"name": AchievementCatalog.display_name(badge), "xp": int(badge.get("xp", 0))}))


func _on_level_up(level: int, level_name: String, _quiet: bool) -> void:
	_log(tr("LOG_LEVEL_UP").format({"level": level, "name": level_name}))


func _log(message: String) -> void:
	if _controller != null:
		_controller.add_log(message, "score")


func _is_late_night() -> bool:
	var hour := int(Time.get_time_dict_from_system().hour)
	return hour >= LATE_NIGHT_FROM and hour <= LATE_NIGHT_TO
