class_name GameProfile
extends Node

## Perfil persistente del jugador: XP, nivel, estadisticas, campaña y logros.
##
## El nodo se busca por su nombre de autoload (`/root/PlayerProfile`), como el
## resto de los autoloads; el `class_name` esta para tipar y para que los tests
## puedan instanciar uno aparte con otra ruta de guardado.
##
## El calculo vive en ProfileData; este nodo le agrega las señales, la escritura
## diferida a disco y la evaluacion de logros. Es el unico que sabe donde se
## guarda el perfil. El diseño esta en
## docs/gdd_atractivo_y_progresion_ANEXO_gamificacion.md.

## Se emite con cada XP ganada. `quiet` marca lo que se paga al cerrar el
## nivel, que ya se muestra en los resultados y no merece un globo aparte.
signal xp_changed(total: int, delta: int, reason: String)
signal level_up(level: int, level_name: String, quiet: bool)
signal badge_unlocked(badge: Dictionary, quiet: bool)
signal profile_changed

const PROFILE_PATH := "user://profile.cfg"
## Los smoke tests headless juegan niveles de verdad: escriben en un perfil
## aparte para no sumarle XP fantasma al jugador.
const TEST_PROFILE_PATH := "user://profile.test.cfg"
const BACKUP_SUFFIX := ".bak"
const SETTINGS_PATH := "res://resources/gameplay/progression_settings.tres"

var settings: ProgressionSettings
var data: ProfileData
## Se fija antes de entrar al arbol: `_ready` carga desde aca.
var storage_path := PROFILE_PATH
## Lo que dejo la ultima partida cerrada, para la pantalla de resultados.
var last_run_report: Dictionary = {}

var _catalog_ids := PackedStringArray()
var _dirty := false
var _save_timer: Timer
## Partida en curso: XP y logros ganados desde begin_run(), para el reporte.
var _run_open := false
var _run_level_id := ""
var _run_xp_start := 0
var _run_level_start := 1
var _run_events: Array[Dictionary] = []
var _run_badges: Array[Dictionary] = []
## Mientras se cierra una partida los avisos salen en silencio: el desglose de
## resultados ya los cuenta.
var _quiet := false


func _ready() -> void:
	if settings == null:
		settings = load(SETTINGS_PATH) as ProgressionSettings
	if settings == null:
		settings = ProgressionSettings.new()
	_resolve_storage_path()
	_build_save_timer()
	load_profile()


## Cerrar el juego no puede perder la ultima partida.
func _exit_tree() -> void:
	flush()


# --- Consulta ----------------------------------------------------------------

func get_xp() -> int:
	return data.xp


func get_level() -> int:
	return data.level


func get_level_name() -> String:
	return settings.level_name(data.level)


func get_progress() -> Dictionary:
	return settings.progress(data.xp)


func get_stat(key: String) -> Variant:
	return data.get_stat(key)


func has_badge(badge_id: String) -> bool:
	return data.has_badge(badge_id)


func badge_count() -> int:
	return data.achievements.size()


## El catalogo entero con el estado del jugador en cada logro, en el orden de
## la vitrina.
func badges_view() -> Array[Dictionary]:
	var view: Array[Dictionary] = []
	for badge in AchievementCatalog.all():
		var entry := badge.duplicate()
		var badge_id := str(badge.id)
		entry["earned"] = data.has_badge(badge_id)
		entry["earned_at"] = int(data.achievements.get(badge_id, 0))
		entry["progress"] = int(data.get_stat(str(badge.stat)))
		view.append(entry)
	return view


func recent_xp(count: int) -> Array[Dictionary]:
	return data.recent_xp(count)


func is_level_completed(level_id: String) -> bool:
	return data.is_completed(level_id)


func completed_count() -> int:
	var count := 0
	for level_id in _catalog_ids:
		if data.is_completed(level_id):
			count += 1
	return count


func get_last_played_id() -> String:
	return data.last_played_id


# --- Campaña -----------------------------------------------------------------

## La secuencia declara que niveles existen; el perfil solo recuerda cuales se
## completaron. Con los dos se sabe si la campaña esta entera.
func set_catalog_ids(ids: PackedStringArray) -> void:
	_catalog_ids = PackedStringArray(ids)


## Solo los niveles de la campaña alimentan el perfil: el laboratorio, los
## bancos de prueba y los niveles sinteticos de los tests no cuentan.
func is_catalog_level(level_id: String) -> bool:
	return not level_id.is_empty() and _catalog_ids.has(level_id)


func set_last_played(level_id: String) -> void:
	if level_id.is_empty() or data.last_played_id == level_id:
		return
	data.last_played_id = level_id
	_save()


# --- XP y estadisticas -------------------------------------------------------

## Paga la XP tabulada para un motivo. Devuelve lo que se sumo.
func award(reason: String, context := {}, count := 1) -> int:
	return _grant_xp(settings.xp_for(reason, count), reason, context)


func increment_stat(key: String, amount := 1) -> void:
	data.increment_stat(key, amount)
	_evaluate_badges(key)
	_save()


func raise_stat(key: String, value: float) -> void:
	if data.raise_stat(key, value):
		_evaluate_badges(key)
		_save()


func add_stat(key: String, amount: float) -> void:
	data.add_stat(key, amount)
	_save()


# --- Partida -----------------------------------------------------------------

## Abre la cuenta de una partida: lo que se gane desde aca entra al reporte.
func begin_run(level_id: String) -> void:
	_run_open = true
	_run_level_id = level_id
	_run_xp_start = data.xp
	_run_level_start = data.level
	_run_events.clear()
	_run_badges.clear()


## Cierra la partida con el resumen del ScoreController: marca la campaña,
## paga los bonos de XP de cierre, evalua los logros de fin de nivel y arma el
## reporte para la pantalla de resultados. Es el unico lugar que marca un nivel
## como completado, y escribe el perfil en el acto.
func record_run(level_id: String, summary: Dictionary) -> Dictionary:
	if not _run_open:
		begin_run(level_id)
	_quiet = true
	var context := {"level_id": level_id}
	var completed := bool(summary.get("completed", false))
	var first_clear := false
	if completed:
		first_clear = data.mark_completed(level_id)
		increment_stat("runs_completed")
		award("level_completed", context)
		if first_clear:
			award("first_clear", context)
		if bool(summary.get("no_damage", false)):
			increment_stat("no_damage_levels")
			award("no_damage", context)
		if int(summary.get("attacks", 0)) >= 10 and float(summary.get("accuracy_percent", 0.0)) >= 100.0:
			increment_stat("accuracy_100_levels")
		var rank: Dictionary = summary.get("rank", {})
		var rank_index := int(rank.get("index", -1))
		if rank_index >= 4:
			increment_stat("ranks_s")
		if rank_index >= 5:
			increment_stat("ranks_splus")
		var rank_context := context.duplicate()
		rank_context["rank"] = str(rank.get("letter", ""))
		_grant_xp(settings.rank_xp_for(rank_index), "rank", rank_context)
		var score_context := context.duplicate()
		score_context["score"] = int(summary.get("total", 0))
		_grant_xp(settings.score_xp_for(int(summary.get("total", 0))), "score", score_context)
		var record: Dictionary = summary.get("record", {})
		if bool(record.get("is_new", false)):
			increment_stat("records_set")
			award("new_record", context)
		if first_clear and _campaign_complete():
			increment_stat("campaign_clears")
	else:
		increment_stat("runs_failed")
		match str(summary.get("reason", "")):
			"health_depleted":
				increment_stat("runs_failed_health")
			"time_expired":
				increment_stat("runs_failed_time")
		award("level_failed", context)
	raise_stat("best_score", float(summary.get("total", 0)))
	raise_stat("best_chain", float(summary.get("best_chain", 0)))
	raise_stat("best_multiplier", float(summary.get("best_multiplier", 1.0)))
	raise_stat("best_bank", float(summary.get("best_bank", 0)))
	_quiet = false
	last_run_report = {
		"level_id": level_id,
		"completed": completed,
		"first_clear": first_clear,
		"xp_earned": data.xp - _run_xp_start,
		"xp_events": _run_events.duplicate(),
		"level_before": _run_level_start,
		"level_name_before": settings.level_name(_run_level_start),
		"level_after": data.level,
		"leveled_up": data.level > _run_level_start,
		"level_name": get_level_name(),
		"badges": _run_badges.duplicate(),
		"progress": get_progress(),
	}
	_run_open = false
	flush()
	return last_run_report


func _campaign_complete() -> bool:
	if _catalog_ids.is_empty():
		return false
	for level_id in _catalog_ids:
		if not data.is_completed(level_id):
			return false
	return true


# --- Internos ----------------------------------------------------------------

func _grant_xp(amount: int, reason: String, context: Dictionary) -> int:
	if amount <= 0:
		return 0
	var result := data.add_xp(amount, reason, context, settings)
	if _run_open:
		_run_events.append({"reason": reason, "xp": amount, "ctx": context.duplicate()})
	xp_changed.emit(data.xp, amount, reason)
	if bool(result.leveled_up):
		level_up.emit(data.level, get_level_name(), _quiet)
	_save()
	return amount


func _evaluate_badges(stat: String) -> void:
	var value := float(data.get_stat(stat))
	for badge in AchievementCatalog.by_stat(stat):
		if value + 0.0001 >= float(badge.threshold):
			_unlock(badge)


## Otorga un logro una sola vez, paga su XP y avisa.
func _unlock(badge: Dictionary) -> bool:
	var badge_id := str(badge.id)
	if not data.grant_badge(badge_id):
		return false
	if _run_open:
		_run_badges.append(badge)
	_grant_xp(int(badge.get("xp", 0)), "badge", {"badge": badge_id, "level_id": _run_level_id})
	badge_unlocked.emit(badge, _quiet)
	_save()
	return true


# --- Persistencia ------------------------------------------------------------

func _resolve_storage_path() -> void:
	if storage_path == PROFILE_PATH and DisplayServer.get_name() == "headless":
		storage_path = TEST_PROFILE_PATH


func _build_save_timer() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = settings.save_delay
	# El perfil cambia mientras el nivel corre y tambien con la pausa abierta.
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.timeout.connect(_write)
	add_child(_save_timer)


## Lee el perfil de disco. Un archivo que no existe es un jugador nuevo: recibe
## su bienvenida y arranca en el primer nivel con la barra ya empezada. Un
## archivo ilegible se aparta como copia y se empieza de nuevo, con aviso.
func load_profile() -> void:
	var config := ConfigFile.new()
	var exists := FileAccess.file_exists(storage_path)
	if exists and config.load(storage_path) != OK:
		_backup_file()
		push_warning("PlayerProfile could not read %s; starting a fresh profile." % storage_path)
		exists = false
	data = ProfileData.from_dict(_config_to_dict(config)) if exists else ProfileData.new()
	if not exists or data.created_at <= 0:
		data.created_at = int(Time.get_unix_time_from_system())
		data.progression_version = settings.progression_version
		_grant_xp(settings.xp_for("welcome"), "welcome", {})
		_save()
	elif int(config.get_value("profile", "version", 0)) > ProfileData.VERSION:
		# Un archivo de una version mas nueva: se lee lo que se entiende, pero
		# la primera escritura lo pisaria, asi que se guarda copia antes.
		_backup_file()
	if data.progression_version != settings.progression_version:
		var changed := data.recalibrate(settings)
		if changed:
			data.xp_log.append({"t": int(Time.get_unix_time_from_system()), "xp": 0, "reason": "recalibrated", "level": "", "ctx": {}})
		_save()
	profile_changed.emit()


## Escribe ya lo que este pendiente, sin esperar el retardo.
func flush() -> void:
	if _dirty:
		_write()


## Vuelve al perfil de un jugador nuevo. Solo lo usan los tests.
func reset() -> void:
	data = ProfileData.new()
	data.created_at = int(Time.get_unix_time_from_system())
	data.progression_version = settings.progression_version
	last_run_report = {}
	_run_open = false
	_grant_xp(settings.xp_for("welcome"), "welcome", {})
	_write()
	profile_changed.emit()


## Marca que hay algo para guardar y reinicia la espera: una sala entera se
## escribe una sola vez, que en la exportacion web es una transaccion.
func _save() -> void:
	_dirty = true
	if _save_timer != null and _save_timer.is_inside_tree():
		_save_timer.start()


func _write() -> void:
	_dirty = false
	if data == null:
		return
	data.updated_at = int(Time.get_unix_time_from_system())
	var config := ConfigFile.new()
	var sections := data.to_dict()
	for section in sections:
		var values: Dictionary = sections[section]
		for key in values:
			config.set_value(str(section), str(key), values[key])
	if config.save(storage_path) != OK:
		push_warning("PlayerProfile could not write %s." % storage_path)
	profile_changed.emit()


func _config_to_dict(config: ConfigFile) -> Dictionary:
	var result: Dictionary = {}
	for section in config.get_sections():
		var values: Dictionary = {}
		for key in config.get_section_keys(section):
			values[key] = config.get_value(section, key)
		result[section] = values
	return result


func _backup_file() -> void:
	if not FileAccess.file_exists(storage_path):
		return
	var bytes := FileAccess.get_file_as_bytes(storage_path)
	var backup := FileAccess.open(storage_path + BACKUP_SUFFIX, FileAccess.WRITE)
	if backup != null:
		backup.store_buffer(bytes)
