class_name ProfileData
extends RefCounted

## Estado puro del perfil del jugador: XP, nivel, estadisticas, campaña,
## logros e historial.
##
## No sabe de disco ni de señales: eso lo pone el autoload PlayerProfile. Asi
## el calculo se prueba solo, sin autoloads ni archivos, y el mismo objeto
## sirve para un perfil real o para uno sintetico de test.
##
## Se serializa a un diccionario con una clave por seccion del ConfigFile
## (`profile`, `xp`, `stats`, `campaign`, `achievements`, `xp_log`), asi que
## guardarlo es recorrer secciones y no traducir campos uno por uno.

## Version del formato de archivo. Sube cuando cambia la forma, no los valores.
const VERSION := 1

## Todas las estadisticas que el perfil acumula, con su valor inicial. Un logro
## solo puede depender de una clave de esta tabla.
const DEFAULT_STATS := {
	"runs_started": 0,
	"runs_completed": 0,
	"runs_failed": 0,
	"runs_failed_health": 0,
	"runs_failed_time": 0,
	"retries": 0,
	"zone_hits": 0,
	"windows_closed": 0,
	"balls_destroyed": 0,
	"traps_hit": 0,
	"closed_close": 0,
	"closed_accept": 0,
	"closed_cancel": 0,
	"closed_finish": 0,
	"closed_sign": 0,
	"closed_next": 0,
	"shots_fired": 0,
	"shots_hit": 0,
	"rooms_cleared": 0,
	"rooms_clean": 0,
	"rooms_perfect": 0,
	"chains_banked": 0,
	"banks_at_top": 0,
	"best_chain": 0,
	"best_multiplier": 1.0,
	"best_bank": 0,
	"best_score": 0,
	"hits_taken": 0,
	"damage_taken": 0.0,
	"no_damage_levels": 0,
	"accuracy_100_levels": 0,
	"ranks_s": 0,
	"ranks_splus": 0,
	"records_set": 0,
	"time_played": 0.0,
	"late_night_runs": 0,
	"campaign_clears": 0,
}

var version := VERSION
var progression_version := 0
var created_at := 0
var updated_at := 0
var xp := 0
var level := 1
var stats: Dictionary = DEFAULT_STATS.duplicate()
var completed: PackedStringArray = PackedStringArray()
var first_clear_at: Dictionary = {}
var last_played_id := ""
## badge_id -> unix time del desbloqueo.
var achievements: Dictionary = {}
var xp_log: Array[Dictionary] = []


# --- XP y nivel --------------------------------------------------------------

## Suma XP y devuelve que paso con el nivel. Un monto negativo o nulo no hace
## nada: la XP solo sube, esa es su gracia.
func add_xp(amount: int, reason: String, context: Dictionary, settings: ProgressionSettings) -> Dictionary:
	var level_before := level
	if amount > 0:
		xp += amount
		level = settings.level_for_xp(xp)
		_log_xp(amount, reason, context, settings)
	return {
		"total": xp,
		"delta": maxi(amount, 0),
		"level_before": level_before,
		"level_after": level,
		"leveled_up": level > level_before,
	}


## Recalcula el nivel con la tabla vigente. Devuelve si cambio.
func recalibrate(settings: ProgressionSettings) -> bool:
	var previous := level
	level = settings.level_for_xp(xp)
	progression_version = settings.progression_version
	return level != previous


func _log_xp(amount: int, reason: String, context: Dictionary, settings: ProgressionSettings) -> void:
	xp_log.append({
		"t": _now(),
		"xp": amount,
		"reason": reason,
		"level": str(context.get("level_id", "")),
		"ctx": context.duplicate(),
	})
	var limit := maxi(settings.xp_log_limit, 1)
	while xp_log.size() > limit:
		xp_log.pop_front()


## Ultimas entradas del historial, la mas reciente primero.
func recent_xp(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var index := xp_log.size() - 1
	while index >= 0 and result.size() < count:
		result.append(xp_log[index])
		index -= 1
	return result


# --- Estadisticas ------------------------------------------------------------

func get_stat(key: String) -> Variant:
	return stats.get(key, DEFAULT_STATS.get(key, 0))


func increment_stat(key: String, amount := 1) -> int:
	var value := int(get_stat(key)) + amount
	stats[key] = value
	return value


## Guarda un maximo. Devuelve true si supero al anterior.
func raise_stat(key: String, value: float) -> bool:
	if value <= float(get_stat(key)):
		return false
	stats[key] = value
	return true


func add_stat(key: String, amount: float) -> float:
	var value := float(get_stat(key)) + amount
	stats[key] = value
	return value


# --- Campaña -----------------------------------------------------------------

func is_completed(level_id: String) -> bool:
	return not level_id.is_empty() and completed.has(level_id)


## Marca un nivel como completado. Devuelve true la primera vez.
func mark_completed(level_id: String) -> bool:
	if level_id.is_empty() or completed.has(level_id):
		return false
	completed.append(level_id)
	first_clear_at[level_id] = _now()
	return true


# --- Logros ------------------------------------------------------------------

func has_badge(badge_id: String) -> bool:
	return achievements.has(badge_id)


## Otorga un logro. Devuelve true si es nuevo: un logro se gana una sola vez y
## nunca se pierde.
func grant_badge(badge_id: String) -> bool:
	if badge_id.is_empty() or achievements.has(badge_id):
		return false
	achievements[badge_id] = _now()
	return true


# --- Serializacion -----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"profile": {
			"version": VERSION,
			"progression_version": progression_version,
			"created_at": created_at,
			"updated_at": updated_at,
		},
		"xp": {
			"total": xp,
			"level": level,
		},
		"stats": stats.duplicate(),
		"campaign": {
			"last_played_id": last_played_id,
			"completed": PackedStringArray(completed),
			"first_clear_at": first_clear_at.duplicate(),
		},
		"achievements": achievements.duplicate(),
		"xp_log": {
			"entries": xp_log.duplicate(true),
		},
	}


## Reconstruye un perfil desde lo que haya. Lo que falta toma su valor por
## defecto, asi que un archivo viejo o incompleto se carga en vez de romper.
static func from_dict(data: Dictionary) -> ProfileData:
	var profile := ProfileData.new()
	var header: Dictionary = data.get("profile", {})
	profile.version = int(header.get("version", 0))
	profile.progression_version = int(header.get("progression_version", 0))
	profile.created_at = int(header.get("created_at", 0))
	profile.updated_at = int(header.get("updated_at", 0))
	var xp_section: Dictionary = data.get("xp", {})
	profile.xp = maxi(int(xp_section.get("total", 0)), 0)
	profile.level = maxi(int(xp_section.get("level", 1)), 1)
	var saved_stats: Dictionary = data.get("stats", {})
	for key in DEFAULT_STATS:
		if saved_stats.has(key):
			profile.stats[key] = saved_stats[key]
	var campaign: Dictionary = data.get("campaign", {})
	profile.last_played_id = str(campaign.get("last_played_id", ""))
	for entry in campaign.get("completed", PackedStringArray()):
		var level_id := str(entry)
		if not level_id.is_empty() and not profile.completed.has(level_id):
			profile.completed.append(level_id)
	var clears: Variant = campaign.get("first_clear_at", {})
	if clears is Dictionary:
		profile.first_clear_at = (clears as Dictionary).duplicate()
	var badges: Variant = data.get("achievements", {})
	if badges is Dictionary:
		for badge_id in badges:
			profile.achievements[str(badge_id)] = int(badges[badge_id])
	var log_section: Dictionary = data.get("xp_log", {})
	for entry in log_section.get("entries", []):
		if entry is Dictionary:
			profile.xp_log.append(entry as Dictionary)
	profile.version = VERSION
	return profile


static func _now() -> int:
	return int(Time.get_unix_time_from_system())
